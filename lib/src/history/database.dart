import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant('New chat'))();
  TextColumn get providerId => text().nullable()();
  TextColumn get model => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // user | assistant
  TextColumn get content => text()();
  IntColumn get tokensIn => integer().withDefault(const Constant(0))();
  IntColumn get tokensOut => integer().withDefault(const Constant(0))();
  RealColumn get costUsd => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class Providers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // openai_compatible | gemini | anthropic
  TextColumn get baseUrl => text()();
  TextColumn get defaultModel => text().withDefault(const Constant(''))();
  TextColumn get modelOverride =>
      text().nullable()(); // user-picked model, null = use defaultModel
  TextColumn get extraHeaders =>
      text().withDefault(const Constant('{}'))(); // JSON map
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {key};
}

/// Opens the lazy SQLite executor used by the app's Drift database.
LazyDatabase lazySqliteExecutor() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'eviee.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [Conversations, Messages, Providers, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(providers, providers.modelOverride);
          }
        },
      );

  // ---------- conversations ----------
  Stream<List<Conversation>> watchConversations() =>
      (select(conversations)
            ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
          .watch();

  Future<List<Conversation>> searchConversations(String query) async {
    if (query.trim().isEmpty) {
      return (select(conversations)
            ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
          .get();
    }
    final q = '%${query.trim()}%';
    final msgMatch = selectOnly(messages)
      ..addColumns([messages.conversationId])
      ..where(messages.content.like(q));
    final ids = (await msgMatch.get())
        .map((r) => r.read(messages.conversationId))
        .whereType<String>()
        .toList();
    return (select(conversations)
          ..where((c) =>
              c.title.like(q) | c.id.isIn(ids.isEmpty ? ['__none__'] : ids))
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .get();
  }

  Future<void> upsertConversation(ConversationsCompanion c) =>
      into(conversations).insertOnConflictUpdate(c);

  Future<void> deleteConversation(String id) =>
      (delete(conversations)..where((c) => c.id.equals(id))).go();

  Future<void> touchConversation(String id) =>
      (update(conversations)..where((c) => c.id.equals(id))).write(
        ConversationsCompanion(updatedAt: Value(DateTime.now())),
      );

  // ---------- messages ----------
  Stream<List<Message>> watchMessages(String conversationId) =>
      (select(messages)
            ..where((m) => m.conversationId.equals(conversationId))
            ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
          .watch();

  Future<void> insertMessage(MessagesCompanion m) =>
      into(messages).insert(m);

  Future<void> updateMessage(String id, MessagesCompanion m) =>
      (update(messages)..where((x) => x.id.equals(id))).write(m);

  Future<void> deleteMessage(String id) =>
      (delete(messages)..where((m) => m.id.equals(id))).go();

  Future<double> conversationCost(String conversationId) async {
    final row = await (selectOnly(messages)
          ..addColumns([messages.costUsd.sum()])
          ..where(messages.conversationId.equals(conversationId)))
        .getSingle();
    return row.read(messages.costUsd.sum()) ?? 0.0;
  }

  // ---------- providers ----------
  Stream<List<Provider>> watchProviders() =>
      (select(providers)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<List<Provider>> allProviders() => select(providers).get();

  Future<Provider?> getProvider(String id) =>
      (select(providers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertProvider(ProvidersCompanion pr) =>
      into(providers).insertOnConflictUpdate(pr);

  Future<void> deleteProvider(String id) =>
      (delete(providers)..where((t) => t.id.equals(id))).go();

  // ---------- settings ----------
  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(
        SettingsCompanion(key: Value(key), value: Value(value)),
      );
}

/// Decode the JSON extra-headers column into a plain map.
Map<String, String> decodeHeaders(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
  } catch (_) {}
  return {};
}
