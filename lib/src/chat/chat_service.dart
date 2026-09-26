import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../providers/ai_provider.dart';

/// A single chat message in the wire format.
class WireMessage {
  final String role; // user | assistant | system
  final String content;
  const WireMessage(this.role, this.content);
}

/// Streaming chat over HTTP SSE for the three backend types.
/// Yields text deltas. Throws [ChatException] on HTTP/API errors.
class ChatService {
  final Dio _dio;

  ChatService([Dio? dio]) : _dio = dio ?? Dio();

  Stream<String> streamCompletion({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required List<WireMessage> messages,
    required CancelToken cancelToken,
  }) {
    switch (provider.type) {
      case ProviderType.openaiCompatible:
        return _openAiStream(provider, apiKey, model, messages, cancelToken);
      case ProviderType.gemini:
        return _geminiStream(provider, apiKey, model, messages, cancelToken);
      case ProviderType.anthropic:
        return _anthropicStream(provider, apiKey, model, messages, cancelToken);
    }
  }

  // ---------------- OpenAI-compatible ----------------
  Stream<String> _openAiStream(
    AiProvider provider,
    String apiKey,
    String model,
    List<WireMessage> messages,
    CancelToken cancelToken,
  ) async* {
    final url = '${_trimSlash(provider.baseUrl)}/chat/completions';
    final stream = _postSse(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        ...provider.extraHeaders,
      },
      body: {
        'model': model,
        'stream': true,
        'messages': [
          for (final m in messages) {'role': m.role, 'content': m.content},
        ],
      },
      cancelToken: cancelToken,
    );
    await for (final data in stream) {
      if (data == '[DONE]') break;
      final delta = _pick(data, ['choices', 0, 'delta', 'content']);
      if (delta is String && delta.isNotEmpty) yield delta;
      final err = _pick(data, ['error', 'message']);
      if (err is String && err.isNotEmpty) throw ChatException(err);
    }
  }

  // ---------------- Gemini ----------------
  Stream<String> _geminiStream(
    AiProvider provider,
    String apiKey,
    String model,
    List<WireMessage> messages,
    CancelToken cancelToken,
  ) async* {
    final url =
        '${_trimSlash(provider.baseUrl)}/models/$model:streamGenerateContent?alt=sse';
    final contents = <Map<String, dynamic>>[];
    for (final m in messages) {
      if (m.role == 'system') continue; // folded into first user turn below
      contents.add({
        'role': m.role == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': m.content}
        ],
      });
    }
    final stream = _postSse(
      url,
      headers: {
        'x-goog-api-key': apiKey,
        'Content-Type': 'application/json',
        ...provider.extraHeaders,
      },
      body: {'contents': contents},
      cancelToken: cancelToken,
    );
    await for (final data in stream) {
      final cands = _pick(data, ['candidates']);
      if (cands is List) {
        for (final c in cands) {
          final parts = _pick(c, ['content', 'parts']);
          if (parts is List) {
            for (final part in parts) {
              final text = _pick(part, ['text']);
              if (text is String && text.isNotEmpty) yield text;
            }
          }
        }
      }
      final err = _pick(data, ['error', 'message']);
      if (err is String && err.isNotEmpty) throw ChatException(err);
    }
  }

  // ---------------- Anthropic ----------------
  Stream<String> _anthropicStream(
    AiProvider provider,
    String apiKey,
    String model,
    List<WireMessage> messages,
    CancelToken cancelToken,
  ) async* {
    final url = '${_trimSlash(provider.baseUrl)}/messages';
    String? system;
    final rest = <Map<String, String>>[];
    for (final m in messages) {
      if (m.role == 'system') {
        system = m.content;
      } else {
        rest.add({'role': m.role, 'content': m.content});
      }
    }
    final stream = _postSse(
      url,
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
        ...provider.extraHeaders,
      },
      body: {
        'model': model,
        'max_tokens': 4096,
        'stream': true,
        if (system != null) 'system': system,
        'messages': rest,
      },
      cancelToken: cancelToken,
    );
    await for (final data in stream) {
      final type = _pick(data, ['type']);
      if (type == 'content_block_delta') {
        final text = _pick(data, ['delta', 'text']);
        if (text is String && text.isNotEmpty) yield text;
      } else if (type == 'message_stop') {
        break;
      }
      final err = _pick(data, ['error', 'message']);
      if (err is String && err.isNotEmpty) throw ChatException(err);
    }
  }

  // ---------------- SSE plumbing ----------------
  /// Yields decoded JSON maps for `data:` lines, or the String sentinel
  /// `'[DONE]'` when the stream terminator arrives.
  Stream<dynamic> _postSse(
    String url, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required CancelToken cancelToken,
  }) async* {
    late final Response<ResponseBody> res;
    try {
      res = await _dio.post<ResponseBody>(
        url,
        data: jsonEncode(body),
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          sendTimeout: const Duration(seconds: 30),
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      throw ChatException(_dioError(e));
    }
    if (res.data == null) throw const ChatException('Empty response stream');
    final buffer = StringBuffer();
    try {
      await for (final chunk in res.data!.stream) {
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        var text = buffer.toString();
        var idx = text.indexOf('\n');
        while (idx != -1) {
          final line = text.substring(0, idx).trim();
          text = text.substring(idx + 1);
          final parsed = _parseSseLine(line);
          if (parsed != null) yield parsed;
          idx = text.indexOf('\n');
        }
        buffer.clear();
        buffer.write(text);
      }
      final tail = buffer.toString().trim();
      final parsed = _parseSseLine(tail);
      if (parsed != null) yield parsed;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      throw ChatException(_dioError(e));
    }
  }

  /// Returns the JSON payload of an SSE `data:` line, a sentinel string for
  /// `[DONE]`, or null for non-data lines.
  dynamic _parseSseLine(String line) {
    if (line.isEmpty) return null;
    if (!line.startsWith('data:')) return null;
    final payload = line.substring(5).trim();
    if (payload == '[DONE]') return '[DONE]';
    try {
      return jsonDecode(payload);
    } catch (_) {
      return null;
    }
  }

  dynamic _pick(dynamic node, List<dynamic> path) {
    dynamic cur = node;
    for (final seg in path) {
      if (seg is int) {
        if (cur is List && seg < cur.length) {
          cur = cur[seg];
        } else {
          return null;
        }
      } else if (seg is String) {
        if (cur is Map && cur.containsKey(seg)) {
          cur = cur[seg];
        } else {
          return null;
        }
      }
    }
    return cur;
  }

  String _trimSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;

  String _dioError(DioException e) {
    final code = e.response?.statusCode;
    if (code != null) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        final m = _pick(data, ['error', 'message']) ?? _pick(data, ['message']);
        if (m is String) msg = m;
      } else if (data is String && data.isNotEmpty && data.length < 300) {
        msg = data;
      }
      return 'HTTP $code${msg != null ? ' — $msg' : ''}';
    }
    return e.message ?? 'Network error';
  }

  /// Lightweight connection test for OpenAI-compatible backends (GET /models).
  /// Returns null on success, or an error string.
  Future<String?> testConnection(AiProvider provider, String apiKey) async {
    if (provider.type != ProviderType.openaiCompatible) {
      return 'Live test is only available for OpenAI-compatible providers — '
          'your key was saved.';
    }
    try {
      final res = await _dio.get(
        '${_trimSlash(provider.baseUrl)}/models',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          ...provider.extraHeaders,
        }),
      );
      return res.statusCode == 200 ? null : 'HTTP ${res.statusCode}';
    } on DioException catch (e) {
      return _dioError(e);
    }
  }
}

class ChatException implements Exception {
  final String message;
  const ChatException(this.message);
  @override
  String toString() => message;
}
