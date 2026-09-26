import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/ai_provider.dart';
import '../providers/app_providers.dart';
import '../providers/provider_repository.dart';

/// BYOK provider manager: preset + custom endpoints, key entry (secure
/// storage only), enable toggles, test connection, delete.
class ProvidersScreen extends ConsumerWidget {
  const ProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeTokensProvider);
    final providers = ref.watch(providersListProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Providers', style: uiStyle(t, weight: FontWeight.w600))),
      body: providers.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text('$e', style: uiStyle(t))),
        data: (list) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, i) =>
              _ProviderCard(t: t, provider: list[i]),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        icon: const Icon(Icons.add),
        label: Text('Add provider',
            style: uiStyle(t, weight: FontWeight.w600, color: t.onAccent)),
        onPressed: () => _openEditor(context, ref, null),
      ),
    );
  }

  void _openEditor(
      BuildContext context, WidgetRef ref, AiProvider? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _ProviderEditor(existing: existing),
      ),
    );
  }
}

class _ProviderCard extends ConsumerWidget {
  final EvieeTokens t;
  final AiProvider provider;
  const _ProviderCard({required this.t, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(providerRepositoryProvider);
    final active = ref.watch(activeProviderProvider)?.id == provider.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? t.accent.withValues(alpha: 0.45) : t.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(provider.name,
                          style: uiStyle(t, weight: FontWeight.w600, size: 15)),
                    ),
                    if (active) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.accentDim,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('ACTIVE',
                            style: monoStyle(t, size: 9.5, color: t.accent)),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: provider.enabled,
                onChanged: (v) => repo.setEnabled(provider.id, v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(provider.type.label, style: monoStyle(t, size: 11)),
          const SizedBox(height: 2),
          Text(provider.baseUrl,
              style: monoStyle(t, size: 11), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('model: ${provider.defaultModel.isEmpty ? '—' : provider.defaultModel}',
              style: monoStyle(t, size: 11)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _SmallBtn(
                t: t,
                label: 'API key',
                icon: Icons.key_outlined,
                onTap: () => _editKey(context, ref),
              ),
              _SmallBtn(
                t: t,
                label: 'Test',
                icon: Icons.bolt_outlined,
                onTap: () => _test(context, ref),
              ),
              _SmallBtn(
                t: t,
                label: 'Edit',
                icon: Icons.edit_outlined,
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(ctx).viewInsets.bottom),
                    child: _ProviderEditor(existing: provider),
                  ),
                ),
              ),
              if (!active)
                _SmallBtn(
                  t: t,
                  label: 'Use',
                  icon: Icons.check,
                  onTap: () => ref
                      .read(activeProviderIdProvider.notifier)
                      .set(provider.id),
                ),
              _SmallBtn(
                t: t,
                label: 'Delete',
                icon: Icons.delete_outline,
                destructive: true,
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editKey(BuildContext context, WidgetRef ref) async {
    final t = this.t;
    final repo = ref.read(providerRepositoryProvider);
    final existing = await repo.readKey(provider.id);
    final c = TextEditingController(text: existing ?? '');
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('API key — ${provider.name}', style: uiStyle(t, weight: FontWeight.w600, size: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stored only in secure storage. Never leaves your device.',
                style: uiStyle(t, size: 12, color: t.foreground2)),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              obscureText: true,
              style: monoStyle(t, size: 13, color: t.foreground),
              decoration: const InputDecoration(hintText: 'sk-…'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved == true) {
      await repo.writeKey(provider.id, c.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key saved securely')),
        );
      }
    }
    c.dispose();
  }

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(providerRepositoryProvider);
    final key = await repo.readKey(provider.id);
    if (!context.mounted) return;
    if (key == null || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save an API key first')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection…')),
    );
    final err =
        await ref.read(chatServiceProvider).testConnection(provider, key);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Connected ✓ (${provider.name})')),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${provider.name}?',
            style: uiStyle(t, weight: FontWeight.w600, size: 16)),
        content: Text('Its stored API key is deleted too.',
            style: uiStyle(t, size: 13.5, color: t.foreground2)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(providerRepositoryProvider).delete(provider.id);
    }
  }
}

class _SmallBtn extends StatelessWidget {
  final EvieeTokens t;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  const _SmallBtn({
    required this.t,
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFEF4444) : t.foreground2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: uiStyle(t, size: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Add / edit provider sheet.
class _ProviderEditor extends ConsumerStatefulWidget {
  final AiProvider? existing;
  const _ProviderEditor({this.existing});

  @override
  ConsumerState<_ProviderEditor> createState() => _ProviderEditorState();
}

class _ProviderEditorState extends ConsumerState<_ProviderEditor> {
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _headers;
  late ProviderType _type;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _baseUrl = TextEditingController(text: e?.baseUrl ?? 'https://');
    _model = TextEditingController(text: e?.defaultModel ?? '');
    _headers = TextEditingController(
        text: e == null
            ? ''
            : e.extraHeaders.entries
                .map((x) => '${x.key}: ${x.value}')
                .join('\n'));
    _type = e?.type ?? ProviderType.openaiCompatible;
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _headers.dispose();
    super.dispose();
  }

  Map<String, String> _parseHeaders() {
    final map = <String, String>{};
    for (final line in _headers.text.split('\n')) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        map[line.substring(0, idx).trim()] =
            line.substring(idx + 1).trim();
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeTokensProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Add provider' : 'Edit provider',
                style: uiStyle(t, weight: FontWeight.w700, size: 18)),
            const SizedBox(height: 16),
            _field(t, 'Name', _name, 'My endpoint'),
            const SizedBox(height: 12),
            Text('Type', style: uiStyle(t, size: 12, color: t.foreground2)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ProviderType.values
                  .map((pt) => ChoiceChip(
                        label: Text(pt.label),
                        selected: _type == pt,
                        onSelected: (_) => setState(() => _type = pt),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            _field(t, 'Base URL', _baseUrl, 'https://api.example.com/v1',
                mono: true),
            const SizedBox(height: 12),
            _field(t, 'Default model', _model, 'gpt-4o-mini', mono: true),
            const SizedBox(height: 12),
            _field(t, 'Extra headers (one per line, Key: value)', _headers,
                'HTTP-Referer: https://myapp.com',
                mono: true, maxLines: 3),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Save provider'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _field(EvieeTokens t, String label, TextEditingController c,
      String hint,
      {bool mono = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: uiStyle(t, size: 12, color: t.foreground2)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          maxLines: maxLines,
          style: mono
              ? monoStyle(t, size: 13, color: t.foreground)
              : uiStyle(t, size: 14),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final base = _baseUrl.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (name.isEmpty || base.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and base URL are required')),
      );
      return;
    }
    final repo = ref.read(providerRepositoryProvider);
    final p = AiProvider(
      id: widget.existing?.id ?? ProviderRepository.newId(),
      name: name,
      type: _type,
      baseUrl: base,
      defaultModel: _model.text.trim(),
      extraHeaders: _parseHeaders(),
      enabled: widget.existing?.enabled ?? true,
    );
    await repo.save(p);
    if (mounted) Navigator.pop(context);
  }
}
