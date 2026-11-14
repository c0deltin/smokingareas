import 'dart:io';

import 'package:uuid/uuid.dart';

import 'community_backend.dart';
import 'models.dart';
import 'photo_storage.dart';

/// What is worth uploading from the device-only data of earlier versions:
/// every reported place and photo, the latest rating, vote and (still
/// active) closure report per place.
class MigrationPlan {
  MigrationPlan({
    required this.spots,
    required this.reviews,
    required this.votes,
    required this.closures,
    required this.photos,
  });

  factory MigrationPlan.from({
    required List<CommunitySpot> spots,
    required List<SpotReview> reviews,
    required List<ExistenceVote> votes,
    required List<ClosureReport> closures,
    required List<SpotPhoto> photos,
    required DateTime now,
  }) {
    Map<String, T> latest<T>(List<T> rows, String Function(T) spot,
        DateTime Function(T) time) {
      final m = <String, T>{};
      for (final r in rows) {
        final prev = m[spot(r)];
        if (prev == null || time(r).isAfter(time(prev))) m[spot(r)] = r;
      }
      return m;
    }

    bool active(ClosureReport c) =>
        now.difference(c.createdAt) <= const Duration(days: 14) ||
        (c.until != null && c.until!.isAfter(now));

    return MigrationPlan(
      spots: spots,
      reviews: latest(reviews, (r) => r.spotId, (r) => r.createdAt)
          .values
          .toList(),
      votes: latest(votes, (v) => v.spotId, (v) => v.createdAt).values.toList(),
      closures: latest(closures, (c) => c.spotId, (c) => c.createdAt)
          .values
          .where(active)
          .toList(),
      photos: photos,
    );
  }

  final List<CommunitySpot> spots;
  final List<SpotReview> reviews;
  final List<ExistenceVote> votes;
  final List<ClosureReport> closures;
  final List<SpotPhoto> photos;

  int get count =>
      spots.length +
      reviews.length +
      votes.length +
      closures.length +
      photos.length;
}

/// Result of [LocalDataMigration.upload].
class MigrationResult {
  const MigrationResult(this.uploaded, this.remaining, [this.error]);
  final int uploaded;
  final int remaining;

  /// Why the upload stopped early (offline, rate limit …); it can be resumed.
  final Object? error;
  bool get done => remaining == 0;
}

/// Moves community data that earlier versions kept only on the device to
/// the signed-in account. Each uploaded row is removed locally right away,
/// so an interrupted upload (offline, hourly limits) resumes where it
/// stopped.
class LocalDataMigration {
  LocalDataMigration({
    required this.local,
    required this.localPhotos,
    required this.photosDirectory,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final LocalCommunityBackend local;
  final PhotoStorage localPhotos;

  /// Folder of the local photo files, deleted once everything is done.
  final Future<Directory> Function() photosDirectory;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  Future<bool> get hasData => local.hasData;

  Future<MigrationPlan> plan() async => MigrationPlan.from(
        spots: await local.spots(),
        reviews: await local.reviews(),
        votes: await local.votes(),
        closures: await local.closureReports(),
        photos: await local.photos(),
        now: _now(),
      );

  /// Uploads as [userId] to [target]; photo files go to [targetPhotos].
  Future<MigrationResult> upload({
    required CommunityBackend target,
    required PhotoStorage targetPhotos,
    required String userId,
  }) async {
    final p = await plan();
    var uploaded = 0;
    Future<void> step(Future<void> Function() send, Future<void> Function() done)
        async {
      try {
        await send();
      } catch (e) {
        // Already on the server from an earlier, interrupted run.
        if (!e.toString().contains('duplicate key')) rethrow;
      }
      await done();
      uploaded++;
    }

    try {
      for (final s in p.spots) {
        await step(() => target.addSpot(_withAuthor(s, userId)),
            () => local.remove(spot: s));
      }
      for (final r in p.reviews) {
        await step(
            () => target.saveReview(SpotReview(
                spotId: r.spotId,
                userId: userId,
                stars: r.stars,
                comment: r.comment,
                createdAt: r.createdAt)),
            () => local.remove(reviewsOf: r.spotId));
      }
      for (final v in p.votes) {
        await step(
            () => target.addVote(ExistenceVote(
                spotId: v.spotId,
                userId: userId,
                exists: v.exists,
                createdAt: v.createdAt,
                fingerprint: v.fingerprint)),
            () => local.remove(votesOf: v.spotId));
      }
      for (final c in p.closures) {
        await step(
            () => target.addClosureReport(ClosureReport(
                spotId: c.spotId,
                userId: userId,
                closed: c.closed,
                note: c.note,
                until: c.until,
                createdAt: c.createdAt,
                fingerprint: c.fingerprint)),
            () => local.remove(closuresOf: c.spotId));
      }
      for (final photo in p.photos) {
        final file = await localPhotos.resolve(photo.storageKey);
        if (file == null) {
          await local.remove(photo: photo);
          continue;
        }
        await step(() async {
          final key = await targetPhotos.save(file);
          await target.addPhoto(SpotPhoto(
              id: _uuid.v4(),
              spotId: photo.spotId,
              userId: userId,
              storageKey: key,
              createdAt: photo.createdAt));
        }, () => local.remove(photo: photo));
      }
    } catch (e) {
      return MigrationResult(uploaded, p.count - uploaded, e);
    }
    await discard();
    return MigrationResult(uploaded, 0);
  }

  /// Deletes the device-only data and photo files.
  Future<void> discard() async {
    await local.clear();
    final dir = await photosDirectory();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static CommunitySpot _withAuthor(CommunitySpot s, String userId) =>
      CommunitySpot(
        id: s.id,
        position: s.position,
        name: s.name,
        createdBy: userId,
        createdAt: s.createdAt,
        description: s.description,
        indoor: s.indoor,
        covered: s.covered,
        publicAccess: s.publicAccess,
        accessNote: s.accessNote,
        category: s.category,
        wheelchair: s.wheelchair,
        changingTable: s.changingTable,
        waste: s.waste,
        bin: s.bin,
        notSameAs: s.notSameAs,
      );
}
