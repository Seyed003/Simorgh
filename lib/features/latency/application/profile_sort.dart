import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../profiles/domain/profile.dart';
import '../domain/latency_result.dart';

enum ProfileSort { defaultOrder, latency }

final profileSortProvider =
    NotifierProvider<ProfileSortController, ProfileSort>(
      ProfileSortController.new,
    );

class ProfileSortController extends Notifier<ProfileSort> {
  static const _key = 'profiles.sort';

  @override
  ProfileSort build() =>
      ProfileSort.values.asNameMap()[ref
          .watch(sharedPreferencesProvider)
          .getString(_key)] ??
      ProfileSort.defaultOrder;

  Future<void> set(ProfileSort sort) async {
    state = sort;
    await ref.read(sharedPreferencesProvider).setString(_key, sort.name);
  }
}

/// Orders [profiles] by [sort]: fastest first, then failed, then untested.
/// The sort is stable so equal entries keep their import order.
List<Profile> sortProfiles(
  List<Profile> profiles,
  ProfileSort sort,
  Map<String, LatencyResult> results,
) {
  if (sort == ProfileSort.defaultOrder) return profiles;
  int rank(Profile p) {
    final result = results[p.id];
    if (result == null) return 1 << 30;
    return result.delay ?? (1 << 29);
  }

  final indexed = profiles.indexed.toList()
    ..sort((a, b) {
      final byLatency = rank(a.$2).compareTo(rank(b.$2));
      return byLatency != 0 ? byLatency : a.$1.compareTo(b.$1);
    });
  return [for (final (_, p) in indexed) p];
}
