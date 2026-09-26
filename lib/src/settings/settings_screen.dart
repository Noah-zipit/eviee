import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/app_providers.dart';

/// Settings: Appearance (theme presets), pricing defaults, About.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeTokensProvider);
    return Scaffold(
      appBar: AppBar(
          title: Text('Settings',
              style: uiStyle(t, weight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionLabel(t: t, text: 'Appearance'),
          const SizedBox(height: 12),
          _ThemePicker(t: t),
          const SizedBox(height: 28),
          _SectionLabel(t: t, text: 'Pricing'),
          const SizedBox(height: 12),
          _PricingEditor(t: t),
          const SizedBox(height: 28),
          _SectionLabel(t: t, text: 'About'),
          const SizedBox(height: 12),
          _AboutCard(t: t),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final EvieeTokens t;
  final String text;
  const _SectionLabel({required this.t, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: uiStyle(t,
          size: 11, weight: FontWeight.w600, color: t.foreground2),
    );
  }
}

/// Theme preset picker with live mini-previews.
class _ThemePicker extends ConsumerWidget {
  final EvieeTokens t;
  const _ThemePicker({required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(themePresetIdProvider);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemCount: evieePresets.length,
      itemBuilder: (context, i) {
        final p = evieePresets[i];
        final active = p.id == activeId;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () =>
                ref.read(themePresetIdProvider.notifier).set(p.id),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active ? p.accent : t.border,
                  width: active ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(17)),
                      child: Container(
                        color: p.background,
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 30,
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: p.border),
                            ),
                            child: Center(
                              child: Container(
                                width: 22,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: p.accent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.label,
                            style: uiStyle(t, size: 11.5,
                                weight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                        if (active) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.check,
                              size: 13, color: t.accent),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Editable fallback prices (USD per 1M tokens) for unknown models.
class _PricingEditor extends ConsumerStatefulWidget {
  final EvieeTokens t;
  const _PricingEditor({required this.t});

  @override
  ConsumerState<_PricingEditor> createState() => _PricingEditorState();
}

class _PricingEditorState extends ConsumerState<_PricingEditor> {
  final _in = TextEditingController();
  final _out = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final inAsync = ref.watch(defaultPriceInProvider);
    final outAsync = ref.watch(defaultPriceOutProvider);
    return inAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (pin) => outAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (pout) {
          if (!_loaded) {
            _in.text = pin.toString();
            _out.text = pout.toString();
            _loaded = true;
          }
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fallback price · USD / 1M tokens',
                    style: uiStyle(t, size: 13, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Used when a model isn\'t in the built-in table.',
                    style: uiStyle(t, size: 12, color: t.foreground2)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _in,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        style: monoStyle(t, size: 13, color: t.foreground),
                        decoration:
                            const InputDecoration(labelText: 'Input'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _out,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        style: monoStyle(t, size: 13, color: t.foreground),
                        decoration:
                            const InputDecoration(labelText: 'Output'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final pinV = double.tryParse(_in.text.trim());
                        final poutV =
                            double.tryParse(_out.text.trim());
                        if (pinV == null || poutV == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Enter valid numbers')),
                          );
                          return;
                        }
                        await saveDefaultPrices(
                            ref.read(appDatabaseProvider), pinV, poutV);
                        ref.invalidate(defaultPriceInProvider);
                        ref.invalidate(defaultPriceOutProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Prices saved')),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
            ),
          ],
        ),
      );
        },
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final EvieeTokens t;
  const _AboutCard({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/logo/eviee-mark.webp',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('eviee',
                      style: uiStyle(t,
                          size: 20, weight: FontWeight.w700)),
                  Text('v1.0.0', style: monoStyle(t, size: 11.5)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Your keys, your models, your data.\nNo subscription, no account, no ads.',
            style: aiBodyStyle(t).copyWith(fontSize: 14.5),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: t.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: t.foreground2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Made by Ashar Qaisar — founder of Elevate Mavens',
                  style: uiStyle(t, size: 13, color: t.foreground2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
