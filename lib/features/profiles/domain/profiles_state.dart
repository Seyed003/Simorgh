import 'profile.dart';
import 'subscription.dart';

class ProfilesState {
  const ProfilesState({
    this.profiles = const [],
    this.subscriptions = const [],
    this.selectedId,
  });

  final List<Profile> profiles;
  final List<Subscription> subscriptions;
  final String? selectedId;

  /// [selectedId] value meaning "pick the fastest server automatically".
  static const autoId = 'auto';

  bool get isAuto => selectedId == autoId;

  /// Whether the connect button has something to connect to.
  bool get hasSelection => isAuto ? profiles.isNotEmpty : selected != null;

  Profile? get selected {
    for (final p in profiles) {
      if (p.id == selectedId) return p;
    }
    return null;
  }

  List<Profile> manualProfiles() =>
      profiles.where((p) => p.subscriptionId == null).toList();

  List<Profile> profilesOf(String subscriptionId) =>
      profiles.where((p) => p.subscriptionId == subscriptionId).toList();

  ProfilesState copyWith({
    List<Profile>? profiles,
    List<Subscription>? subscriptions,
    String? Function()? selectedId,
  }) => ProfilesState(
    profiles: profiles ?? this.profiles,
    subscriptions: subscriptions ?? this.subscriptions,
    selectedId: selectedId != null ? selectedId() : this.selectedId,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'profiles': profiles.map((p) => p.toJson()).toList(),
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    'selectedId': selectedId,
  };

  factory ProfilesState.fromJson(Map<String, Object?> json) {
    List<Map<String, Object?>> list(String key) =>
        ((json[key] as List?) ?? const [])
            .whereType<Map<Object?, Object?>>()
            .map((e) => e.cast<String, Object?>())
            .toList();
    final profiles = <Profile>[];
    for (final item in list('profiles')) {
      try {
        profiles.add(Profile.fromJson(item));
      } on Object {
        // Skip entries written by a newer/older schema instead of failing.
      }
    }
    return ProfilesState(
      profiles: profiles,
      subscriptions: list('subscriptions').map(Subscription.fromJson).toList(),
      selectedId: json['selectedId'] as String?,
    );
  }
}

/// Outcome of an import, used for the snackbar summary.
class ImportOutcome {
  const ImportOutcome({
    required this.added,
    required this.skipped,
    this.subscription,
    this.profiles = const [],
    this.skipReason,
  });

  final int added;
  final int skipped;
  final Subscription? subscription;

  /// Why the first skipped entry was left out, e.g. what an OpenVPN file
  /// lacks.
  final String? skipReason;

  /// The profiles added, e.g. to ask for the logins they still need.
  final List<Profile> profiles;
}
