class MenuCategory {
  final int id;
  final String nameAr;
  final String? nameEn;
  final String? imageUrl;
  final int itemsCount;

  const MenuCategory({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.imageUrl,
    required this.itemsCount,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
        id: j['id'] as int,
        nameAr: j['name_ar'] as String,
        nameEn: j['name_en'] as String?,
        imageUrl: j['image_url'] as String?,
        itemsCount: (j['items_count'] as num?)?.toInt() ?? 0,
      );
}
