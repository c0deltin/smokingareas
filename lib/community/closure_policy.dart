import 'models.dart';

/// Result of evaluating the closure reports of one spot.
class ClosureStatus {
  const ClosureStatus({
    required this.closed,
    this.since,
    this.until,
    this.note,
    this.closedReports = 0,
    this.reopenedReports = 0,
  });

  final bool closed;

  /// Oldest active "closed" report.
  final DateTime? since;

  /// Expected reopening (latest `until` of the active reports).
  final DateTime? until;

  /// Reason of the newest active "closed" report.
  final String? note;
  final int closedReports;
  final int reopenedReports;

  static const open = ClosureStatus(closed: false);
}

/// Waze-like handling of temporary closures:
///
/// * a report is active for [defaultDuration] after it was made, or until
///   its `until` date (capped at [maxDuration]) – closures end on their own,
/// * only the latest report of each user counts,
/// * the spot is closed when more users report "closed" than "reopened"; on
///   a tie the newest report decides.
class ClosurePolicy {
  const ClosurePolicy({
    this.defaultDuration = const Duration(days: 14),
    this.maxDuration = const Duration(days: 180),
  });

  final Duration defaultDuration;
  final Duration maxDuration;

  DateTime _expiry(ClosureReport r) {
    final cap = r.createdAt.add(maxDuration);
    final until = r.until;
    if (until == null) return r.createdAt.add(defaultDuration);
    return until.isAfter(cap) ? cap : until;
  }

  ClosureStatus evaluate(Iterable<ClosureReport> reports, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final latest = <String, ClosureReport>{};
    for (final r in reports) {
      if (!_expiry(r).isAfter(t)) continue;
      final prev = latest[r.userId];
      if (prev == null || r.createdAt.isAfter(prev.createdAt)) {
        latest[r.userId] = r;
      }
    }
    final closed = latest.values.where((r) => r.closed).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final reopened = latest.values.where((r) => !r.closed).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (closed.isEmpty) {
      return ClosureStatus(
          closed: false, reopenedReports: reopened.length);
    }
    var isClosed = closed.length > reopened.length;
    if (closed.length == reopened.length) {
      isClosed = closed.last.createdAt.isAfter(reopened.last.createdAt);
    }
    DateTime? until;
    for (final r in closed) {
      if (r.until != null && (until == null || r.until!.isAfter(until))) {
        until = r.until;
      }
    }
    String? note;
    for (final r in closed.reversed) {
      if (r.note != null) {
        note = r.note;
        break;
      }
    }
    return ClosureStatus(
      closed: isClosed,
      since: closed.first.createdAt,
      until: until,
      note: note,
      closedReports: closed.length,
      reopenedReports: reopened.length,
    );
  }
}
