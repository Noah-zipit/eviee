import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/app_providers.dart';
import 'orb.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_session.dart';
import '../history/conversations_drawer.dart';
import '../providers/providers_screen.dart';
import '../settings/settings_screen.dart';

/// Home: ambient orb, greeting, suggestion cards, message input.
/// Tapping send starts a new conversation with the active provider.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _sendText(text);
  }

  void _sendSuggestion(String prompt) {
    _input.text = prompt;
    _sendText(prompt);
  }

  void _sendText(String text) {
    ref.read(chatSessionProvider.notifier).newSession();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
    // Send after the route builds so the session attaches to the new screen.
    Future.microtask(() {
      _input.clear();
      ref.read(chatSessionProvider.notifier).send(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeTokensProvider);
    final provider = ref.watch(activeProviderProvider);
    return Scaffold(
      drawer: const ConversationsDrawer(),
      appBar: AppBar(
        title: Text('eviee', style: uiStyle(t, weight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Providers',
            icon: const Icon(Icons.key_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProvidersScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  const OrbWidget(size: 132),
                  const SizedBox(height: 24),
                  Text(
                    'How can I',
                    style: greetingStyle(t),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'help you?',
                    style: greetingStyle(t),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider == null
                        ? 'add a provider to begin'
                        : '${provider.name} · ${effectiveModel(provider, ref.watch(activeModelProvider))}',
                    style: monoStyle(t, size: 11.5),
                  ),
                  const SizedBox(height: 28),
                  _SuggestionGrid(t: t, onTap: _sendSuggestion),
                  const SizedBox(height: 24),
                  _Composer(
                    t: t,
                    controller: _input,
                    onSend: _send,
                    providerReady: provider != null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your keys, your models, your data.',
                    style: uiStyle(t, size: 11.5, color: t.foreground2),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionGrid extends StatelessWidget {
  final EvieeTokens t;
  final void Function(String prompt) onTap;
  const _SuggestionGrid({required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.lightbulb_outline,
        'Brainstorm',
        'ideas that don\'t suck',
        'Give me 5 bold, practical startup ideas in AI tooling — one line each, then expand the best one.'
      ),
      (
        Icons.code_outlined,
        'Write code',
        'ship it faster',
        'Write a clean Python function with a docstring and a quick usage example. Ask me what it should do first if unclear.'
      ),
      (
        Icons.edit_outlined,
        'Draft',
        'an email or a doc',
        'Draft a short, professional email. Ask me who it\'s for and what it\'s about first.'
      ),
      (
        Icons.help_outline,
        'Explain',
        'anything, simply',
        'Explain a complex topic simply, like I\'m smart but new to it. Ask me what topic first.'
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (icon, title, sub, prompt) = items[i];
        return Material(
          color: t.card,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onTap(prompt),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: t.accent),
                  const SizedBox(height: 10),
                  Text(title,
                      style: uiStyle(t, size: 14, weight: FontWeight.w600)),
                  Text(sub,
                      style: uiStyle(t, size: 11.5, color: t.foreground2)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  final EvieeTokens t;
  final TextEditingController controller;
  final void Function() onSend;
  final bool providerReady;
  const _Composer({
    required this.t,
    required this.controller,
    required this.onSend,
    required this.providerReady,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.muted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: uiStyle(t, size: 14.5),
              decoration: InputDecoration(
                hintText: providerReady
                    ? 'Ask anything…'
                    : 'Add a provider first…',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: t.accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSend,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.arrow_upward,
                      size: 20, color: t.onAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
