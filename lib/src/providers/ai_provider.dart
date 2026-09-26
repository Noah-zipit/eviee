import 'package:drift/drift.dart' show Value;

import '../history/database.dart';

/// Provider backend type.
enum ProviderType {
  openaiCompatible('openai_compatible', 'OpenAI-compatible'),
  gemini('gemini', 'Gemini'),
  anthropic('anthropic', 'Anthropic');

  final String id;
  final String label;
  const ProviderType(this.id, this.label);

  static ProviderType fromId(String id) => ProviderType.values.firstWhere(
        (t) => t.id == id,
        orElse: () => ProviderType.openaiCompatible,
      );
}

/// Domain model for a BYOK provider. API keys live ONLY in secure storage.
class AiProvider {
  final String id;
  final String name;
  final ProviderType type;
  final String baseUrl;
  final String defaultModel;
  final String? modelOverride; // user-picked model; null/empty = defaultModel
  final Map<String, String> extraHeaders;
  final bool enabled;

  const AiProvider({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.defaultModel,
    this.modelOverride,
    this.extraHeaders = const {},
    this.enabled = true,
  });

  /// The model id actually sent on requests.
  String get resolvedModel =>
      (modelOverride?.trim().isNotEmpty ?? false)
          ? modelOverride!.trim()
          : defaultModel;

  factory AiProvider.fromRow(Provider row) => AiProvider(
        id: row.id,
        name: row.name,
        type: ProviderType.fromId(row.type),
        baseUrl: row.baseUrl,
        defaultModel: row.defaultModel,
        modelOverride: row.modelOverride,
        extraHeaders: decodeHeaders(row.extraHeaders),
        enabled: row.enabled,
      );

  ProvidersCompanion toCompanion() => ProvidersCompanion(
        id: Value(id),
        name: Value(name),
        type: Value(type.id),
        baseUrl: Value(baseUrl),
        defaultModel: Value(defaultModel),
        modelOverride: Value(modelOverride),
        extraHeaders: Value(_encodeHeaders(extraHeaders)),
        enabled: Value(enabled),
      );

  AiProvider copyWith({
    String? name,
    ProviderType? type,
    String? baseUrl,
    String? defaultModel,
    String? Function()? modelOverride,
    Map<String, String>? extraHeaders,
    bool? enabled,
  }) =>
      AiProvider(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        baseUrl: baseUrl ?? this.baseUrl,
        defaultModel: defaultModel ?? this.defaultModel,
        modelOverride:
            modelOverride != null ? modelOverride() : this.modelOverride,
        extraHeaders: extraHeaders ?? this.extraHeaders,
        enabled: enabled ?? this.enabled,
      );
}

String _encodeHeaders(Map<String, String> h) {
  final buf = StringBuffer('{');
  var first = true;
  for (final e in h.entries) {
    if (!first) buf.write(',');
    first = false;
    buf.write('"${_esc(e.key)}":"${_esc(e.value)}"');
  }
  buf.write('}');
  return buf.toString();
}

String _esc(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
