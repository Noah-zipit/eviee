/// USD pricing per 1M tokens (input / output). Approximate public pricing.
class ModelPrice {
  final double per1MIn;
  final double per1MOut;
  const ModelPrice(this.per1MIn, this.per1MOut);
}

/// Known model pricing, matched by substring on the model id (lowercase).
const Map<String, ModelPrice> modelPricing = {
  'gpt-4o-mini': ModelPrice(0.15, 0.60),
  'gpt-4o': ModelPrice(2.50, 10.00),
  'gpt-4.1-mini': ModelPrice(0.40, 1.60),
  'gpt-4.1': ModelPrice(2.00, 8.00),
  'o3-mini': ModelPrice(1.10, 4.40),
  'claude-sonnet-4': ModelPrice(3.00, 15.00),
  'claude-3-5-sonnet': ModelPrice(3.00, 15.00),
  'claude-3-5-haiku': ModelPrice(0.80, 4.00),
  'gemini-2.5-pro': ModelPrice(1.25, 10.00),
  'gemini-2.5-flash': ModelPrice(0.30, 2.50),
  'gemini-1.5-pro': ModelPrice(1.25, 5.00),
  'gemini-1.5-flash': ModelPrice(0.075, 0.30),
  'deepseek-chat': ModelPrice(0.27, 1.10),
  'deepseek-reasoner': ModelPrice(0.55, 2.19),
  'deepseek-v4-flash': ModelPrice(0.44, 1.32), // NVIDIA NIM listing, Sep 2026
  'llama-3.3-70b-versatile': ModelPrice(0.59, 0.79),
  'llama-3.1-8b-instant': ModelPrice(0.05, 0.08),
};

/// Fallback when the model is unknown (editable in Settings).
const ModelPrice defaultPrice = ModelPrice(2.00, 8.00);

ModelPrice priceFor(String modelId) {
  final id = modelId.toLowerCase();
  for (final entry in modelPricing.entries) {
    if (id.contains(entry.key)) return entry.value;
  }
  return defaultPrice;
}

double costUsd(String modelId, int tokensIn, int tokensOut,
    {double? overrideIn, double? overrideOut}) {
  final p = priceFor(modelId);
  final pin = overrideIn ?? p.per1MIn;
  final pout = overrideOut ?? p.per1MOut;
  return (tokensIn * pin + tokensOut * pout) / 1000000.0;
}

String formatCost(double usd) {
  if (usd < 0.01) return '\$${(usd * 1000).toStringAsFixed(2)}m';
  if (usd < 1) return '\$${usd.toStringAsFixed(4)}';
  return '\$${usd.toStringAsFixed(2)}';
}

String formatTokens(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}
