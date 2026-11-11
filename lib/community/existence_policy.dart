import 'models.dart';

/// Outcome of evaluating the "does this spot still exist?" votes.
class ExistenceStatus {
  const ExistenceStatus({
    required this.confirmations,
    required this.removals,
    required this.hidden,
  });

  /// Users whose latest vote says "gibt es noch".
  final int confirmations;

  /// Users whose latest vote says "gibt es nicht mehr".
  final int removals;

  /// The spot is removed from the map and no longer triggers alerts.
  final bool hidden;

  /// At least one user reported it missing, but it is still shown.
  bool get disputed => !hidden && removals > 0;

  static const none =
      ExistenceStatus(confirmations: 0, removals: 0, hidden: false);
}

/// Waze-like crowd moderation: when enough users report that a spot does not
/// exist (any more), it disappears from the map.
///
/// * Only the latest vote of each user counts (users can change their mind).
/// * The community has the upper hand over the data sets: a vote cast for the
///   current version of the source entry (same fingerprint) does not expire –
///   a spot reported gone stays hidden even if new data still lists it.
///   When the source entry changes (new fingerprint), older votes no longer
///   count and the evaluation starts afresh.
/// * Votes without fingerprint (user-reported spots, older app versions)
///   expire after [maxAge].
/// * A spot is hidden when at least [minRemovals] users say it is gone **and**
///   removals outweigh confirmations by [ratio]. A few people who still find
///   it keep it alive.
class ExistencePolicy {
  const ExistencePolicy({
    this.minRemovals = 3,
    this.ratio = 2.0,
    this.maxAge = const Duration(days: 180),
  });

  final int minRemovals;
  final double ratio;
  final Duration maxAge;

  ExistenceStatus evaluate(
    Iterable<ExistenceVote> votes, {
    DateTime? now,
    String? currentFingerprint,
  }) {
    final t = now ?? DateTime.now();
    final latest = <String, ExistenceVote>{};
    for (final v in votes) {
      if (!isValid(v, t, currentFingerprint)) continue;
      final prev = latest[v.userId];
      if (prev == null || v.createdAt.isAfter(prev.createdAt)) {
        latest[v.userId] = v;
      }
    }
    var yes = 0;
    var no = 0;
    for (final v in latest.values) {
      v.exists ? yes++ : no++;
    }
    final hidden = no >= minRemovals && no >= yes * ratio;
    return ExistenceStatus(confirmations: yes, removals: no, hidden: hidden);
  }

  /// Whether [v] still counts at [now] for an entry whose source data has
  /// [currentFingerprint].
  bool isValid(ExistenceVote v, DateTime now, String? currentFingerprint) {
    if (currentFingerprint != null && v.fingerprint != null) {
      return v.fingerprint == currentFingerprint;
    }
    return now.difference(v.createdAt) <= maxAge;
  }
}
