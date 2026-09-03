// Sem code gen (freezed) de propósito -- é só um cache local simples,
// mesmo padrão manual já usado pro cache de UserModel em auth_service.dart.
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type; // warning | danger | success | info
  final String? route;
  final DateTime receivedAt;
  final bool read;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.route,
    required this.receivedAt,
    required this.read,
  });

  NotificationItem copyWith({bool? read}) => NotificationItem(
        id: id,
        title: title,
        body: body,
        type: type,
        route: route,
        receivedAt: receivedAt,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'route': route,
        'received_at': receivedAt.toIso8601String(),
        'read': read,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        type: json['type'] as String? ?? 'info',
        route: json['route'] as String?,
        receivedAt: DateTime.parse(json['received_at'] as String),
        read: json['read'] as bool? ?? false,
      );
}
