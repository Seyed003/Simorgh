import '../../../core/singbox/proxy_config.dart';

/// A stored proxy server the user can connect to.
class Profile {
  const Profile({
    required this.id,
    required this.config,
    required this.createdAt,
    this.subscriptionId,
  });

  final String id;
  final ProxyConfig config;
  final DateTime createdAt;

  /// Owning subscription, `null` for manually imported configs.
  final String? subscriptionId;

  String get name => config.name;

  Profile copyWith({ProxyConfig? config}) => Profile(
    id: id,
    config: config ?? this.config,
    createdAt: createdAt,
    subscriptionId: subscriptionId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'config': config.toJson(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    if (subscriptionId != null) 'subscriptionId': subscriptionId,
  };

  factory Profile.fromJson(Map<String, Object?> json) => Profile(
    id: json['id']! as String,
    config: ProxyConfig.fromJson(
      (json['config']! as Map).cast<String, Object?>(),
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']! as int),
    subscriptionId: json['subscriptionId'] as String?,
  );
}
