class Offer {
  final int id;
  final String titleAr;
  final String? descriptionAr;
  final String? imageUrl;
  final DateTime startsAt;
  final DateTime endsAt;
  final int? linkedItemId;
  final int sortOrder;

  const Offer({
    required this.id,
    required this.titleAr,
    this.descriptionAr,
    this.imageUrl,
    required this.startsAt,
    required this.endsAt,
    this.linkedItemId,
    required this.sortOrder,
  });

  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        id: j['id'] as int,
        titleAr: j['title_ar'] as String,
        descriptionAr: j['description_ar'] as String?,
        imageUrl: j['image_url'] as String?,
        startsAt: DateTime.parse(j['starts_at'] as String),
        endsAt: DateTime.parse(j['ends_at'] as String),
        linkedItemId: j['linked_item_id'] as int?,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}
