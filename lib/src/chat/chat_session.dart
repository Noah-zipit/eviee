import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiktoken_tokenizer_gpt4o_o1/tiktoken_tokenizer_gpt4o_o1.dart';

import '../core/pricing.dart';
import '../history/database.dart';
import '../providers/app_providers.dart';
import 'chat_service.dart';

/// One message in the active session (mirrors the DB row).
class SessionMessage {
  final String id;
  final String role; // user | assistant
  final String content;
  final int tokensIn;
  final int tokensOut;
  final double costUsd;
  final bool streaming;

  const SessionMessage({
    required this.id,
    required this.role,
    required this.content,
    this.tokensIn = 0,
    this.tokensOut = 0,
    this.costUsd = 0,
    this.streaming = false,
  });

  SessionMessage copyWith({
    String? content,
    int? tokensIn,
    int? tokensOut,
    double? costUsd,
    bool? streaming,
  }) =>
      SessionMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        tokensIn: tokensIn ?? this.tokensIn,
        tokensOut: tokensOut ?? this.tokensOut,
        costUsd: costUsd ?? this.costUsd,
        streaming: streaming ?? this.streaming,
      );
}

class ChatSessionState {
  final String? conversationId;
  final List<SessionMessage> messages;
  final bool busy;
  final String? error;
  final int liveTokensOut;
  final double liveCostUsd;

  const ChatSessionState({
    this.conversationId,
    this.messages = const [],
    this.busy = false,
    this.error,
    this.liveTokensOut = 0,
    this.liveCostUsd = 0,
  });

  double get sessionCost =>
      messages.fold(0.0, (s, m) => s + m.costUsd) + liveCostUsd;

  ChatSessionState copyWith({
    String? conversationId,
    List<SessionMessage>? messages,
    bool? busy,
    String? error,
    int? liveTokensOut,
    double? liveCostUsd,
  }) =>
      ChatSessionState(
        conversationId: conversationId ?? this.conversationId,
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
        error: error,
        liveTokensOut: liveTokensOut ?? this.liveTokensOut,
        liveCostUsd: liveCostUsd ?? this.liveCostUsd,
      );
}

/// Active chat session: streaming, persistence, token/cost accounting.
class ChatSession extends StateNotifier<ChatSessionState> {
  final Ref ref;
  CancelToken? _cancel;
  int _chunkCount = 0;
  int _idSeq = 0;

  ChatSession(this.ref) : super(const ChatSessionState());

  AppDatabase get _db => ref.read(appDatabaseProvider);

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_idSeq++}';

  /// Open an existing conversation from history.
  Future<void> openConversation(String conversationId) async {
    _cancel?.cancel();
    final rows = await (_db.select(_db.messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get();
    state = ChatSessionState(
      conversationId: conversationId,
      messages: [
        for (final r in rows)
          SessionMessage(
            id: r.id,
            role: r.role,
            content: r.content,
            tokensIn: r.tokensIn,
            tokensOut: r.tokensOut,
            costUsd: r.costUsd,
          ),
      ],
    );
  }

  /// Start a blank session (used by Home before the first send).
  void newSession() {
    _cancel?.cancel();
    state = const ChatSessionState();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;

    final provider = ref.read(activeProviderProvider);
    if (provider == null) {
      state = state.copyWith(error: 'Add a provider and API key first.');
      return;
    }
    final repo = ref.read(providerRepositoryProvider);
    final apiKey = await repo.readKey(provider.id);
    if (apiKey == null || apiKey.trim().isEmpty) {
      state = state.copyWith(error: 'No API key saved for ${provider.name}.');
      return;
    }
    final model = provider.resolvedModel;

    // Ensure a conversation row exists.
    var convId = state.conversationId;
    if (convId == null) {
      convId = 'c_${DateTime.now().millisecondsSinceEpoch}';
      await _db.upsertConversation(ConversationsCompanion(
        id: Value(convId),
        title: Value(_titleFor(trimmed)),
        providerId: Value(provider.id),
        model: Value(model),
      ));
    }

    final userMsg = SessionMessage(
      id: _newId('u'),
      role: 'user',
      content: trimmed,
    );
    final asstMsg = SessionMessage(
      id: _newId('a'),
      role: 'assistant',
      content: '',
      streaming: true,
    );
    state = state.copyWith(
      conversationId: convId,
      messages: [...state.messages, userMsg, asstMsg],
      busy: true,
      error: null,
      liveTokensOut: 0,
      liveCostUsd: 0,
    );

    await _db.insertMessage(MessagesCompanion(
      id: Value(userMsg.id),
      conversationId: Value(convId),
      role: const Value('user'),
      content: Value(trimmed),
    ));
    await _db.insertMessage(MessagesCompanion(
      id: Value(asstMsg.id),
      conversationId: Value(convId),
      role: const Value('assistant'),
      content: const Value(''),
    ));
    await _db.touchConversation(convId);

    final history = <WireMessage>[
      for (final m in state.messages)
        if (m.id != asstMsg.id && m.content.isNotEmpty)
          WireMessage(m.role, m.content),
    ];

    _cancel = CancelToken();
    _chunkCount = 0;
    final buf = StringBuffer();
    final service = ref.read(chatServiceProvider);
    final savedIn = await ref.read(defaultPriceInProvider.future);
    final savedOut = await ref.read(defaultPriceOutProvider.future);
    final custom = await _db.getSetting('price_custom') == '1';
    final pin = custom ? savedIn : priceFor(model).per1MIn;
    final pout = custom ? savedOut : priceFor(model).per1MOut;

    try {
      await for (final delta in service.streamCompletion(
        provider: provider,
        apiKey: apiKey,
        model: model,
        messages: history,
        cancelToken: _cancel!,
      )) {
        buf.write(delta);
        _chunkCount++;
        // Throttle token accounting: every 12 chunks.
        if (_chunkCount % 12 == 0) {
          _updateLive(buf.toString(), pout, asstId: asstMsg.id);
        } else {
          _appendText(asstMsg.id, buf.toString());
        }
      }
      await _finalize(
        asstMsg.id,
        buf.toString(),
        history,
        model,
        priceIn: pin,
        priceOut: pout,
        convId: convId,
      );
    } on ChatException catch (e) {
      await _fail(asstMsg.id, e.message, convId);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      await _fail(asstMsg.id, msg, convId);
    }
  }

  void stop() {
    _cancel?.cancel();
  }

  /// Regenerate the last assistant reply.
  Future<void> regenerate() async {
    if (state.busy || state.messages.length < 2) return;
    final last = state.messages.last;
    if (last.role != 'assistant') return;
    final userMsg = state.messages[state.messages.length - 2];
    if (userMsg.role != 'user') return;
    final userText = userMsg.content;
    // Drop both rows from the DB and state, then re-send cleanly.
    await _db.deleteMessage(last.id);
    await _db.deleteMessage(userMsg.id);
    state = state.copyWith(
        messages: state.messages.sublist(0, state.messages.length - 2));
    await send(userText);
  }

  void clearError() => state = state.copyWith(error: null);

  // ---------- internals ----------
  void _appendText(String asstId, String full) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == asstId) m.copyWith(content: full) else m,
      ],
    );
  }

  void _updateLive(String full, double priceOut, {required String asstId}) {
    final out = _countTokens(full);
    _appendText(asstId, full);
    state = state.copyWith(
      liveTokensOut: out,
      liveCostUsd: (out * priceOut) / 1000000.0,
    );
  }

  /// Cached encoder — constructing Tiktoken loads the rank table once.
  static Tiktoken? _encoder;

  int _countTokens(String text) {
    try {
      _encoder ??= Tiktoken(OpenAiModel.gpt_4o);
      return _encoder!.count(text);
    } catch (_) {
      return (text.length / 4).ceil();
    }
  }

  Future<void> _finalize(
    String asstId,
    String full,
    List<WireMessage> history,
    String model, {
    required double priceIn,
    required double priceOut,
    required String convId,
  }) async {
    final inText = history.map((m) => m.content).join('\n');
    final tokensIn = _countTokens(inText);
    final tokensOut = _countTokens(full);
    final cost = (tokensIn * priceIn + tokensOut * priceOut) / 1000000.0;
    await _db.updateMessage(
      asstId,
      MessagesCompanion(
        content: Value(full),
        tokensIn: Value(tokensIn),
        tokensOut: Value(tokensOut),
        costUsd: Value(cost),
      ),
    );
    await _db.touchConversation(convId);
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == asstId)
            m.copyWith(
                content: full,
                tokensIn: tokensIn,
                tokensOut: tokensOut,
                costUsd: cost,
                streaming: false)
          else
            m,
      ],
      busy: false,
      liveTokensOut: 0,
      liveCostUsd: 0,
    );
  }

  Future<void> _fail(String asstId, String message, String convId) async {
    final existing = state.messages
        .firstWhere((m) => m.id == asstId)
        .content;
    final content =
        existing.isEmpty ? '⚠ $message' : '$existing\n\n⚠ $message';
    await _db.updateMessage(
        asstId, MessagesCompanion(content: Value(content)));
    await _db.touchConversation(convId);
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == asstId)
            m.copyWith(content: content, streaming: false)
          else
            m,
      ],
      busy: false,
      error: message,
      liveTokensOut: 0,
      liveCostUsd: 0,
    );
  }

  String _titleFor(String text) {
    final one = text.replaceAll('\n', ' ').trim();
    return one.length > 42 ? '${one.substring(0, 42)}…' : one;
  }
}

final chatSessionProvider =
    StateNotifierProvider<ChatSession, ChatSessionState>(
  (ref) => ChatSession(ref),
);
