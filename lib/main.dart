import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/theme.dart';
import 'src/history/database.dart';
import 'src/home/splash_screen.dart';
import 'src/providers/app_providers.dart';
import 'src/providers/provider_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lazy SQLite: on Android this is the device's database; on desktop/mobile
  // the override in main_dev/main_test can swap it.
  final db = openDatabase();

  // Seed built-in providers on first run.
  await ProviderRepository(db).seedPresetsIfEmpty();

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const EvieeApp(),
    ),
  );
}

class EvieeApp extends ConsumerWidget {
  const EvieeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return MaterialApp(
      title: 'eviee',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(tokens),
      home: const SplashScreen(),
    );
  }
}

/// Opens a Drift database on the platform's app-data directory.
///
/// On Android / iOS this uses the device filesystem; keys themselves are
/// stored in FlutterSecureStorage, never in this database.
AppDatabase openDatabase() {
  return AppDatabase(lazySqliteExecutor());
}
