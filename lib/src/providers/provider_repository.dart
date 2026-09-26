import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../history/database.dart';
import 'ai_provider.dart';

/// CRUD for providers + presets. API keys are stored ONLY in secure storage,
/// keyed by provider id. Keys are never written to Drift and never logged.
class ProviderRepository {
  final AppDatabase db;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  ProviderRepository(this.db);

  static String keyName(String providerId) => 'eviee_key_$providerId';

  Stream<List<AiProvider>> watchAll() =>
      db.watchProviders().map((rows) => rows.map(AiProvider.fromRow).toList());

  Future<List<AiProvider>> all() async =>
      (await db.allProviders()).map(AiProvider.fromRow).toList();

  Future<List<AiProvider>> enabled() async =>
      (await all()).where((p) => p.enabled).toList();

  Future<AiProvider?> get(String id) async {
    final row = await db.getProvider(id);
    return row == null ? null : AiProvider.fromRow(row);
  }

  Future<void> save(AiProvider p) => db.upsertProvider(p.toCompanion());

  Future<void> delete(String id) async {
    await db.deleteProvider(id);
    await _secure.delete(key: keyName(id));
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final p = await get(id);
    if (p != null) await save(p.copyWith(enabled: enabled));
  }

  Future<String?> readKey(String providerId) =>
      _secure.read(key: keyName(providerId));

  Future<void> writeKey(String providerId, String key) =>
      _secure.write(key: keyName(providerId), value: key);

  Future<bool> hasKey(String providerId) async {
    final k = await readKey(providerId);
    return k != null && k.trim().isNotEmpty;
  }

  /// Seed the built-in presets on first run (no keys). Also backfills any
  /// presets added in later app versions for existing installs.
  Future<void> seedPresetsIfEmpty() async {
    final existing = await db.allProviders();
    if (existing.isEmpty) {
      for (final p in _presets) {
        await db.upsertProvider(p.toCompanion());
      }
      return;
    }
    final ids = existing.map((r) => r.id).toSet();
    for (final p in _presets) {
      if (!ids.contains(p.id)) {
        await db.upsertProvider(p.toCompanion());
      }
    }
    // Migrate installs seeded with a retired model id.
    for (final r in existing) {
      if (r.id == 'preset-nvidia-nim' &&
          r.defaultModel == 'deepseek-ai/deepseek-v4-flash-0731') {
        await db.upsertProvider(
          ProvidersCompanion(
            id: const Value('preset-nvidia-nim'),
            defaultModel: const Value('deepseek-ai/deepseek-v4.1-flash'),
          ),
        );
      }
    }
  }

  static String newId() =>
      'p_${DateTime.now().millisecondsSinceEpoch}';

  static final List<AiProvider> _presets = [
    const AiProvider(
      id: 'preset-openai',
      name: 'OpenAI',
      type: ProviderType.openaiCompatible,
      baseUrl: 'https://api.openai.com/v1',
      defaultModel: 'gpt-4o-mini',
    ),
    const AiProvider(
      id: 'preset-groq',
      name: 'Groq',
      type: ProviderType.openaiCompatible,
      baseUrl: 'https://api.groq.com/openai/v1',
      defaultModel: 'llama-3.3-70b-versatile',
    ),
    const AiProvider(
      id: 'preset-openrouter',
      name: 'OpenRouter',
      type: ProviderType.openaiCompatible,
      baseUrl: 'https://openrouter.ai/api/v1',
      defaultModel: 'openrouter/auto',
    ),
    const AiProvider(
      id: 'preset-deepseek',
      name: 'DeepSeek',
      type: ProviderType.openaiCompatible,
      baseUrl: 'https://api.deepseek.com/v1',
      defaultModel: 'deepseek-chat',
    ),
    const AiProvider(
      id: 'preset-nvidia-nim',
      name: 'NVIDIA NIM',
      type: ProviderType.openaiCompatible,
      baseUrl: 'https://integrate.api.nvidia.com/v1',
      defaultModel: 'deepseek-ai/deepseek-v4.1-flash',
    ),
    const AiProvider(
      id: 'preset-gemini',
      name: 'Gemini',
      type: ProviderType.gemini,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      defaultModel: 'gemini-2.5-flash',
    ),
    const AiProvider(
      id: 'preset-anthropic',
      name: 'Anthropic',
      type: ProviderType.anthropic,
      baseUrl: 'https://api.anthropic.com/v1',
      defaultModel: 'claude-sonnet-4-20250514',
    ),
  ];
}
