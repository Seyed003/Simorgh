import '../../../core/singbox/subscription_info.dart';

class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.info,
    this.lastUpdated,
  });

  final String id;
  final String name;
  final String url;
  final SubscriptionInfo? info;
  final DateTime? lastUpdated;

  Subscription copyWith({
    String? name,
    SubscriptionInfo? info,
    DateTime? lastUpdated,
  }) => Subscription(
    id: id,
    name: name ?? this.name,
    url: url,
    info: info ?? this.info,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    if (info != null) 'info': info!.toJson(),
    if (lastUpdated != null) 'lastUpdated': lastUpdated!.millisecondsSinceEpoch,
  };

  factory Subscription.fromJson(Map<String, Object?> json) {
    final info = json['info'];
    final updated = json['lastUpdated'] as int?;
    return Subscription(
      id: json['id']! as String,
      name: json['name']! as String,
      url: json['url']! as String,
      info: info is Map
          ? SubscriptionInfo.fromJson(info.cast<String, Object?>())
          : null,
      lastUpdated: updated == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updated),
    );
  }
}
