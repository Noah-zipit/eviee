import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/github.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import '../core/pricing.dart';
import '../core/theme.dart';
import '../history/conversations_drawer.dart';
import '../providers/ai_provider.dart';
import '../providers/app_providers.dart';
import 'chat_service.dart';
import 'chat_session.dart';

/// Chat thread: streaming messages, markdown + code highlighting,
/// provider/model picker pill + per-response cost pill.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    ref.read(chatSessionProvider.notifier).send(text);
    _jumpToBottom();
  }

  void _jumpToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeTokensProvider);
    final session = ref.watch(chatSessionProvider);

    // Auto-scroll while streaming.
    ref.listen(chatSessionProvider, (prev, next) {
      final prevLen = prev?.messages.isNotEmpty == true
          ? prev!.messages.last.content.length
          : 0;
      final nextLen = next.messages.isNotEmpty
          ? next.messages.last.content.length
          : 0;
      if (nextLen != prevLen && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });

    return Scaffold(
      drawer: const ConversationsDrawer(),
      appBar: AppBar(
        title: _ProviderPill(t: t),
        actions: [
          _CostPill(t: t, cost: session.sessionCost),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: session.messages.isEmpty
                  ? _EmptyThread(t: t)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: session.messages.length,
                      itemBuilder: (context, i) => _MessageBubble(
                        t: t,
                        msg: session.messages[i],
                        isLast: i == session.messages.length - 1,
                      ),
                    ),
            ),
            if (session.error != null)
              _ErrorBar(
                  t: t,
                  message: session.error!,
                  onDismiss: () =>
                      ref.read(chatSessionProvider.notifier).clearError()),
            _Composer(
              t: t,
              controller: _input,
              busy: session.busy,
              liveTokens: session.liveTokensOut,
              liveCost: session.liveCostUsd,
              onSend: _send,
              onStop: () => ref.read(chatSessionProvider.notifier).stop(),
              onRegenerate: session.busy || session.messages.isEmpty
                  ? null
                  : () => ref.read(chatSessionProvider.notifier).regenerate(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Provider/model picker pill in the app bar.
class _ProviderPill extends ConsumerWidget {
  final EvieeTokens t;
  const _ProviderPill({required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(activeProviderProvider);
    final model = provider == null ? '—' : provider.resolvedModel;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showPicker(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: t.muted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: provider == null ? t.foreground2 : t.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                provider == null ? 'no provider' : '${provider.name} · $model',
                style: monoStyle(t, size: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: t.foreground2),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    final enabled = ref.read(enabledProvidersProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Provider', style: uiStyle(t, weight: FontWeight.w600)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final p in enabled)
                        Builder(builder: (_) {
                          final active =
                              ref.watch(activeProviderProvider)?.id == p.id;
                          final custom =
                              (p.modelOverride?.trim().isNotEmpty ?? false);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(p.name,
                                style: uiStyle(t, size: 14.5)),
                            subtitle: Text(
                              custom
                                  ? '${p.resolvedModel}  ·  custom'
                                  : p.resolvedModel,
                              style: monoStyle(t, size: 11),
                            ),
                            trailing: active
                                ? Icon(Icons.check, color: t.accent)
                                : null,
                            onTap: () {
                              ref
                                  .read(activeProviderIdProvider.notifier)
                                  .set(p.id);
                            },
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Model', style: uiStyle(t, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              _ModelSection(t: t),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Model picker for the active provider: live catalogue list + manual entry.
/// The pick is saved per provider and survives restarts.
class _ModelSection extends ConsumerWidget {
  final EvieeTokens t;
  const _ModelSection({required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(activeProviderProvider);
    if (provider == null) return const SizedBox.shrink();
    final custom = provider.modelOverride?.trim().isNotEmpty ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openModelList(context, ref, provider),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.muted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.resolvedModel,
                        style: monoStyle(t, size: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        custom
                            ? 'custom pick — tap to change'
                            : 'provider default — tap to choose from list',
                        style: uiStyle(t, size: 11, color: t.foreground2),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.list, size: 18, color: t.foreground2),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ModelField(key: ValueKey(provider.id), t: t, provider: provider),
      ],
    );
  }

  void _openModelList(
      BuildContext context, WidgetRef ref, AiProvider provider) {
    showDialog(
      context: context,
      builder: (dctx) => _ModelListDialog(t: t, provider: provider),
    );
  }
}

/// Live model catalogue for one provider, fetched with its saved API key.
class _ModelListDialog extends ConsumerStatefulWidget {
  final EvieeTokens t;
  final AiProvider provider;
  const _ModelListDialog({required this.t, required this.provider});

  @override
  ConsumerState<_ModelListDialog> createState() => _ModelListDialogState();
}

class _ModelListDialogState extends ConsumerState<_ModelListDialog> {
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<String>> _load() async {
    final repo = ref.read(providerRepositoryProvider);
    final key = await repo.readKey(widget.provider.id);
    if (key == null || key.trim().isEmpty) {
      throw ChatException(
          'Save an API key for ${widget.provider.name} first.');
    }
    return ref
        .read(chatServiceProvider)
        .listModels(provider: widget.provider, apiKey: key);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final provider = widget.provider;
    return AlertDialog(
      title: Text('${provider.name} models', style: uiStyle(t, size: 16)),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: FutureBuilder<List<String>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snap.error.toString(),
                      style: uiStyle(t, size: 13, color: t.foreground2),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final models = snap.data ?? const <String>[];
            if (models.isEmpty) {
              return Center(
                child: Text('No models returned.',
                    style: uiStyle(t, size: 13, color: t.foreground2)),
              );
            }
            final current = provider.resolvedModel;
            return ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Use provider default',
                      style: uiStyle(t, size: 13.5)),
                  subtitle: Text(provider.defaultModel,
                      style: monoStyle(t, size: 11)),
                  trailing:
                      (provider.modelOverride?.trim().isNotEmpty ?? false)
                          ? null
                          : Icon(Icons.check, color: t.accent),
                  onTap: () async {
                    await ref
                        .read(providerRepositoryProvider)
                        .setModelOverride(provider.id, null);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                const Divider(height: 8),
                for (final m in models)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m, style: monoStyle(t, size: 12.5)),
                    trailing: current == m
                        ? Icon(Icons.check, color: t.accent)
                        : null,
                    onTap: () async {
                      await ref
                          .read(providerRepositoryProvider)
                          .setModelOverride(provider.id, m);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ModelField extends ConsumerStatefulWidget {
  final EvieeTokens t;
  final AiProvider provider;
  const _ModelField({super.key, required this.t, required this.provider});

  @override
  ConsumerState<_ModelField> createState() => _ModelFieldState();
}

class _ModelFieldState extends ConsumerState<_ModelField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.provider.modelOverride ?? '');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      style: monoStyle(widget.t, size: 13, color: widget.t.foreground),
      decoration: const InputDecoration(
          hintText: 'or type a model id manually, Enter to save'),
      onSubmitted: (v) async {
        await ref
            .read(providerRepositoryProvider)
            .setModelOverride(widget.provider.id, v);
      },
    );
  }
}

/// Session cost pill in the app bar.
class _CostPill extends StatelessWidget {
  final EvieeTokens t;
  final double cost;
  const _CostPill({required this.t, required this.cost});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: t.accentDim,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(formatCost(cost),
          style: monoStyle(t, size: 11.5, color: t.accent)),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  final EvieeTokens t;
  const _EmptyThread({required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Say the word.',
        style: greetingStyle(t, size: 26),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final EvieeTokens t;
  final SessionMessage msg;
  final bool isLast;
  const _MessageBubble(
      {required this.t, required this.msg, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48, top: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: t.accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(msg.content,
              style: uiStyle(t, size: 15, color: t.onAccent)),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(6),
        ),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MarkdownBody(t: t, text: msg.content),
          if (msg.streaming && msg.content.isEmpty)
            _TypingDots(t: t)
          else if (msg.streaming)
            _StreamCursor(t: t),
          if (!msg.streaming && msg.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${formatTokens(msg.tokensIn + msg.tokensOut)} tokens · ${formatCost(msg.costUsd)}',
                  style: monoStyle(t, size: 10.5),
                ),
                const Spacer(),
                _IconBtn(
                  t: t,
                  icon: Icons.copy_outlined,
                  tooltip: 'Copy',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final EvieeTokens t;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.t,
      required this.icon,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 15, color: t.foreground2),
      ),
    );
  }
}

class _MarkdownBody extends StatelessWidget {
  final EvieeTokens t;
  final String text;
  const _MarkdownBody({required this.t, required this.text});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: aiBodyStyle(t),
        h1: uiStyle(t, size: 20, weight: FontWeight.w700),
        h2: uiStyle(t, size: 18, weight: FontWeight.w700),
        h3: uiStyle(t, size: 16, weight: FontWeight.w700),
        listBullet: aiBodyStyle(t),
        code: monoStyle(t, size: 13, color: t.foreground),
        codeblockDecoration: BoxDecoration(
          color: t.isLight ? t.muted : const Color(0xFF0A0B0D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        blockquote: aiBodyStyle(t).copyWith(color: t.foreground2),
        a: uiStyle(t, size: 15, color: t.accent),
        tableBody: aiBodyStyle(t),
      ),
      builders: {'code': _CodeBuilder(t: t)},
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
    );
  }
}

/// Code block with syntax highlighting, language label and copy button.
class _CodeBuilder extends MarkdownElementBuilder {
  final EvieeTokens t;
  _CodeBuilder({required this.t});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // flutter_markdown may hand us the inner <code> element directly,
    // or the <pre> wrapper around it — handle both.
    var codeEl = element;
    if (element.tag == 'pre' && (element.children?.isNotEmpty ?? false)) {
      final first = element.children!.first;
      if (first is md.Element && first.tag == 'code') codeEl = first;
    }
    final language =
        codeEl.attributes['class']?.replaceFirst('language-', '') ?? '';
    final code = codeEl.textContent;
    return _CodeBlock(t: t, language: language, code: code);
  }
}

class _CodeBlock extends StatelessWidget {
  final EvieeTokens t;
  final String language;
  final String code;
  const _CodeBlock(
      {required this.t, required this.language, required this.code});

  @override
  Widget build(BuildContext context) {
    final highlighted = HighlightView(
      code,
      language: language.isEmpty ? 'plaintext' : language,
      theme: githubTheme,
      padding: const EdgeInsets.all(12),
      textStyle: monoStyle(t, size: 12.5, color: t.foreground),
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: t.isLight ? t.muted : const Color(0xFF0A0B0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text(language.isEmpty ? 'code' : language,
                    style: monoStyle(t, size: 10.5)),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.copy_outlined,
                        size: 14, color: t.foreground2),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: t.border),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: highlighted,
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  final EvieeTokens t;
  const _TypingDots({required this.t});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = ((_c.value * 3 + i) % 3) / 3;
          return Container(
            margin: const EdgeInsets.only(right: 5, top: 6),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.t.foreground2
                  .withValues(alpha: 0.35 + 0.65 * (1 - phase)),
            ),
          );
        }),
      ),
    );
  }
}

class _StreamCursor extends StatefulWidget {
  final EvieeTokens t;
  const _StreamCursor({required this.t});

  @override
  State<_StreamCursor> createState() => _StreamCursorState();
}

class _StreamCursorState extends State<_StreamCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 530))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
          width: 9, height: 17, margin: const EdgeInsets.only(top: 4),
          color: widget.t.accent),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  final EvieeTokens t;
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBar(
      {required this.t, required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(message,
                  style: uiStyle(t, size: 12.5, color: t.foreground))),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onDismiss,
            color: t.foreground2,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final EvieeTokens t;
  final TextEditingController controller;
  final bool busy;
  final int liveTokens;
  final double liveCost;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback? onRegenerate;
  const _Composer({
    required this.t,
    required this.controller,
    required this.busy,
    required this.liveTokens,
    required this.liveCost,
    required this.onSend,
    required this.onStop,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${formatTokens(liveTokens)} tokens · ${formatCost(liveCost)}',
                style: monoStyle(t, size: 10.5),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: t.muted,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                if (onRegenerate != null)
                  IconButton(
                    tooltip: 'Regenerate',
                    icon: const Icon(Icons.refresh_outlined, size: 20),
                    color: t.foreground2,
                    onPressed: onRegenerate,
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: uiStyle(t, size: 14.5),
                    maxLines: 5,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Message…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(
                    color: busy ? t.foreground2 : t.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: busy ? onStop : onSend,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          busy ? Icons.stop : Icons.arrow_upward,
                          size: 20,
                          color: busy ? t.background : t.onAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
