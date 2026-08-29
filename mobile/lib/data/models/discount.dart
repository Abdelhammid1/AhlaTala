/// Preview result for a discount code (E6). Mirrors backend's PreviewResult shape.
class DiscountPreview {
  final int codeId;
  final String code;
  final String kind; // 'percent' | 'fixed'
  final double value;
  final double discountAmount;

  const DiscountPreview({
    required this.codeId,
    required this.code,
    required this.kind,
    required this.value,
    required this.discountAmount,
  });

  factory DiscountPreview.fromJson(Map<String, dynamic> j) => DiscountPreview(
        codeId: j['code_id'] as int,
        code: j['code'] as String,
        kind: j['kind'] as String,
        value: double.tryParse(j['value']?.toString() ?? '0') ?? 0.0,
        discountAmount: double.tryParse(j['discount_amount']?.toString() ?? '0') ?? 0.0,
      );
}
