import 'models.dart';

/// Outcome of the "does this spot have [SpotFeature]?" answers.
class FeatureStatus {
  const FeatureStatus({required this.yes, required this.no});

  /// Users whose latest answer is "yes" / "no".
  final int yes;
  final int no;

  /// The community's verdict, null when there are no answers or a tie (then
  /// the source data decides).
  bool? get value => yes == no ? null : yes > no;

  static const none = FeatureStatus(yes: 0, no: 0);
}

/// Crowd verdict on a spot feature such as "has a trash can": only the latest
/// answer of each user counts, answers expire after [maxAge] (trash cans come
/// and go), the majority wins over the source data.
class FeaturePolicy {
  const FeaturePolicy({this.maxAge = const Duration(days: 365)});

  final Duration maxAge;

  FeatureStatus evaluate(
    Iterable<FeatureVote> votes,
    SpotFeature feature, {
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final latest = <String, FeatureVote>{};
    for (final v in votes) {
      if (v.feature != feature || t.difference(v.createdAt) > maxAge) continue;
      final prev = latest[v.userId];
      if (prev == null || v.createdAt.isAfter(prev.createdAt)) {
        latest[v.userId] = v;
      }
    }
    var yes = 0;
    for (final v in latest.values) {
      if (v.value) yes++;
    }
    return FeatureStatus(yes: yes, no: latest.length - yes);
  }
}
