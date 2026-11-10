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
/// * Votes older than [maxAge] are ignored – a spot confirmed years ago but
///   reported missing today should go away.
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

  ExistenceStatus evaluate(Iterable<ExistenceVote> votes, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final latest = <String, ExistenceVote>{};
    for (final v in votes) {
      if (t.difference(v.createdAt) > maxAge) continue;
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
}
