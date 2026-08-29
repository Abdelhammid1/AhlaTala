import 'option_group.dart';

/// Two shapes: `ItemSummary` (list rows) and `ItemDetail` (details screen).
class ItemSummary {
  final int id;
  final String nameAr;
  final String? nameEn;
  final String? imageUrl;
  final double basePrice;
  final double? displayPriceFrom;
  final bool priceIsVariable;
  final int? calories;

  const ItemSummary({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.imageUrl,
    required this.basePrice,
    this.displayPriceFrom,
    required this.priceIsVariable,
    this.calories,
  });

  factory ItemSummary.fromJson(Map<String, dynamic> j) => ItemSummary(
        id: j['id'] as int,
        nameAr: j['name_ar'] as String,
        nameEn: j['name_en'] as String?,
        imageUrl: j['image_url'] as String?,
        basePrice: _num(j['base_price']),
        displayPriceFrom:
            j['display_price_from'] == null ? null : _num(j['display_price_from']),
        priceIsVariable: (j['price_is_variable'] as bool?) ?? false,
        calories: (j['calories'] as num?)?.toInt(),
      );
}

class ItemDetail {
  final int id;
  final int categoryId;
  final String nameAr;
  final String? nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? imageUrl;
  final double basePrice;
  final double? displayPriceFrom;
  final bool priceIsVariable;
  final int? calories;
  final List<OptionGroup> optionGroups;

  const ItemDetail({
    required this.id,
    required this.categoryId,
    required this.nameAr,
    this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    this.imageUrl,
    required this.basePrice,
    this.displayPriceFrom,
    required this.priceIsVariable,
    this.calories,
    required this.optionGroups,
  });

  factory ItemDetail.fromJson(Map<String, dynamic> j) => ItemDetail(
        id: j['id'] as int,
        categoryId: j['category_id'] as int,
        nameAr: j['name_ar'] as String,
        nameEn: j['name_en'] as String?,
        descriptionAr: j['description_ar'] as String?,
        descriptionEn: j['description_en'] as String?,
        imageUrl: j['image_url'] as String?,
        basePrice: _num(j['base_price']),
        displayPriceFrom:
            j['display_price_from'] == null ? null : _num(j['display_price_from']),
        priceIsVariable: (j['price_is_variable'] as bool?) ?? false,
        calories: (j['calories'] as num?)?.toInt(),
        optionGroups: ((j['option_groups'] as List?) ?? const [])
            .map((e) => OptionGroup.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}
