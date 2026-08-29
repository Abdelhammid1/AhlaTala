/// One row in the customer's inbox.
class InboxItem {
  final int deliveryId;
  final int notificationId;
  final String title;
  final String body;
  final DateTime? sentAt;
  final DateTime? readAt;

  const InboxItem({
    required this.deliveryId,
    required this.notificationId,
    required this.title,
    required this.body,
    this.sentAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
        deliveryId: j['delivery_id'] as int,
        notificationId: j['notification_id'] as int,
        title: j['title'] as String,
        body: j['body'] as String,
        sentAt: _dt(j['sent_at']),
        readAt: _dt(j['read_at']),
      );
}

DateTime? _dt(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}
