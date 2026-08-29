class Option {
  final int id;
  final String nameAr;
  final String? nameEn;
  final String? imageUrl;
  final double priceDelta;
  final bool isDefault;
  final int sortOrder;

  const Option({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.imageUrl,
    required this.priceDelta,
    required this.isDefault,
    required this.sortOrder,
  });

  factory Option.fromJson(Map<String, dynamic> j) => Option(
        id: j['id'] as int,
        nameAr: j['name_ar'] as String,
        nameEn: j['name_en'] as String?,
        imageUrl: j['image_url'] as String?,
        priceDelta: _num(j['price_delta']),
        isDefault: (j['is_default'] as bool?) ?? false,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}
