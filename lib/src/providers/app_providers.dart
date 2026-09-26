import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../history/database.dart' hide Provider;
import '../providers/ai_provider.dart';
import '../providers/provider_repository.dart';
import '../chat/chat_service.dart';

// ---------- database ----------
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override appDatabaseProvider in main()');
});

// ---------- providers ----------
final providerRepositoryProvider = Provider<ProviderRepository>(
  (ref) => ProviderRepository(ref.watch(appDatabaseProvider)),
);

final providersListProvider = StreamProvider<List<AiProvider>>(
  (ref) => ref.watch(providerRepositoryProvider).watchAll(),
);

final enabledProvidersProvider = Provider<List<AiProvider>>((ref) {
  final list = ref.watch(providersListProvider).valueOrNull ?? const [];
  return list.where((p) => p.enabled).toList();
});

// Active provider id, persisted in the settings table.
const _kActiveProvider = 'active_provider_id';

final activeProviderIdProvider =
    StateNotifierProvider<ActiveProviderIdNotifier, String?>(
  (ref) => ActiveProviderIdNotifier(ref),
);

class ActiveProviderIdNotifier extends StateNotifier<String?> {
  final Ref ref;
  ActiveProviderIdNotifier(this.ref) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    state = await db.getSetting(_kActiveProvider);
  }

  Future<void> set(String? id) async {
    state = id;
    await ref.read(appDatabaseProvider).setSetting(_kActiveProvider, id ?? '');
  }
}

final activeProviderProvider = Provider<AiProvider?>((ref) {
  final enabled = ref.watch(enabledProvidersProvider);
  if (enabled.isEmpty) return null;
  final id = ref.watch(activeProviderIdProvider);
  final match = enabled.where((p) => p.id == id);
  return match.isEmpty ? enabled.first : match.first;
});

// Active model override per session (defaults to provider.defaultModel).
final activeModelProvider = StateProvider<String?>((ref) => null);

String effectiveModel(AiProvider p, String? override) =>
    (override?.trim().isNotEmpty ?? false) ? override!.trim() : p.defaultModel;

// ---------- theme ----------
const _kThemePreset = 'theme_preset';

final themePresetIdProvider =
    StateNotifierProvider<ThemePresetNotifier, String>(
  (ref) => ThemePresetNotifier(ref),
);

class ThemePresetNotifier extends StateNotifier<String> {
  final Ref ref;
  ThemePresetNotifier(this.ref) : super('ember') {
    _load();
  }

  Future<void> _load() async {
    final saved = await ref.read(appDatabaseProvider).getSetting(_kThemePreset);
    if (saved != null && saved.isNotEmpty) state = saved;
  }

  Future<void> set(String id) async {
    state = id;
    await ref.read(appDatabaseProvider).setSetting(_kThemePreset, id);
  }
}

final themeTokensProvider =
    Provider<EvieeTokens>((ref) => tokensFor(ref.watch(themePresetIdProvider)));

// ---------- pricing overrides ----------
const _kPriceIn = 'price_default_in';
const _kPriceOut = 'price_default_out';

final defaultPriceInProvider = FutureProvider<double>((ref) async {
  final v = await ref.watch(appDatabaseProvider).getSetting(_kPriceIn);
  return double.tryParse(v ?? '') ?? 2.0;
});

final defaultPriceOutProvider = FutureProvider<double>((ref) async {
  final v = await ref.watch(appDatabaseProvider).getSetting(_kPriceOut);
  return double.tryParse(v ?? '') ?? 8.0;
});

Future<void> saveDefaultPrices(
    AppDatabase db, double perIn, double perOut) async {
  await db.setSetting(_kPriceIn, perIn.toString());
  await db.setSetting(_kPriceOut, perOut.toString());
  await db.setSetting('price_custom', '1');
}

// ---------- chat service ----------
final chatServiceProvider = Provider<ChatService>((ref) => ChatService(Dio()));
