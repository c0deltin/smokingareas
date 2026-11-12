import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../community/community_service.dart';
import '../community/models.dart';
import 'moderation.dart';
import 'sign_in_sheet.dart';
import '../models/smoking_area.dart';

/// Lets the user pick a photo with camera or gallery (null = cancelled).
Future<File?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Take photo'),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Choose from gallery'),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return null;
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  return picked == null ? null : File(picked.path);
}

/// Stars widget (read-only).
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.size = 18});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Colors.amber.shade700;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          value >= i
              ? Icons.star
              : (value >= i - 0.5 ? Icons.star_half : Icons.star_border),
          size: size,
          color: color,
        ),
    ]);
  }
}

/// Community part of the spot details: rating, photos, existence votes.
class CommunitySection extends StatelessWidget {
  const CommunitySection({
    super.key,
    required this.area,
    required this.community,
    this.onRemoved,
  });

  final SmokingArea area;
  final CommunityService community;

  /// Called when the current user's vote removed the spot from the map.
  final VoidCallback? onRemoved;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: community,
      builder: (context, _) {
        final theme = Theme.of(context);
        final rating = community.ratingFor(area);
        final reviews = community.reviewsFor(area);
        final photos = community.photosFor(area);
        final status = community.statusFor(area);
        final myVote = community.myVote(area);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24),
            Row(children: [
              Text('Community', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (community.currentUser case final user?)
                Text('as ${user.displayName}',
                    style: theme.textTheme.bodySmall),
            ]),
            const SizedBox(height: 8),

            // --- rating -------------------------------------------------
            Row(children: [
              StarRating(value: rating.average),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rating.count == 0
                      ? 'No ratings yet'
                      : '${rating.average.toStringAsFixed(1)} '
                          '(${rating.count} rating${rating.count == 1 ? '' : 's'})',
                ),
              ),
              TextButton.icon(
                onPressed: () => _rate(context, rating.mine),
                icon: const Icon(Icons.star_outline),
                label: Text(rating.mine == null ? 'Rate' : 'Change'),
              ),
            ]),
            for (final r in reviews.where((r) => r.comment != null).take(3))
              _ReviewTile(review: r, community: community),

            // --- photos -------------------------------------------------
            const SizedBox(height: 8),
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _AddPhotoButton(onTap: () => _addPhoto(context)),
                  for (final p in photos)
                    _PhotoThumb(photo: p, community: community),
                ],
              ),
            ),

            // --- temporary closure (Waze-like, expires) -----------------
            const SizedBox(height: 12),
            _ClosureControls(area: area, community: community),

            // --- existence votes (Waze-like) ----------------------------
            const SizedBox(height: 12),
            Text(
                area.isToilet
                    ? 'Is this toilet still there?'
                    : 'Is this smoking area still there?',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: _VoteButton(
                  selected: myVote == true,
                  icon: Icons.check_circle_outline,
                  label: 'Yes (${status.confirmations})',
                  color: Colors.green,
                  onPressed: () => contribute(context, community,
                      () => community.vote(area, exists: true),
                      reason: 'Sign in to confirm places.'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VoteButton(
                  selected: myVote == false,
                  icon: Icons.highlight_off,
                  label: 'No (${status.removals})',
                  color: theme.colorScheme.error,
                  onPressed: () => _voteGone(context),
                ),
              ),
            ]),
            if (status.disputed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${status.removals} user${status.removals == 1 ? '' : 's'} '
                  'reported that this '
                  '${area.isToilet ? 'toilet' : 'smoking area'} is gone.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _rate(BuildContext context, int? current) async {
    if (!await ensureSignedIn(context, community,
            reason: 'Sign in to rate places.') ||
        !context.mounted) {
      return;
    }
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _RatingDialog(initial: current ?? 0),
    );
    if (result == null || !context.mounted) return;
    await contribute(context, community,
        () => community.rate(area, result.$1, comment: result.$2));
  }

  Future<void> _addPhoto(BuildContext context) async {
    if (!await ensureSignedIn(context, community,
            reason: 'Sign in to add photos.') ||
        !context.mounted) {
      return;
    }
    final file = await pickPhoto(context);
    if (file == null || !context.mounted) return;
    await contribute(context, community,
        () => withProgress(context, () => community.addPhoto(area, file),
            label: 'Uploading photo …'));
  }

  Future<void> _voteGone(BuildContext context) async {
    if (!await ensureSignedIn(context, community,
            reason: 'Sign in to report places that are gone.') ||
        !context.mounted) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gone?'),
        content: const Text(
          'If enough users report that this place is gone, it is removed '
          'from the map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final saved = await contribute(
        context, community, () => community.vote(area, exists: false));
    if (saved && community.isHidden(area)) onRemoved?.call();
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.community});
  final SpotReview review;
  final CommunityService community;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = community.userName(review.userId);
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StarRating(value: review.stars.toDouble(), size: 12),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: '$author: ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: review.comment),
          ]), style: theme.textTheme.bodySmall),
        ),
        SizedBox(
          height: 24,
          child: ContentMenu(
            community: community,
            target: ReportTarget.review,
            targetId: reviewTargetId(review),
            authorId: review.userId,
            authorName: author,
            iconSize: 16,
          ),
        ),
      ]),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 84,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined,
                  color: theme.colorScheme.primary),
              const SizedBox(height: 4),
              Text('Photo', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.community});
  final SpotPhoto photo;
  final CommunityService community;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: community.photoFile(photo),
      builder: (context, snap) {
        final file = snap.data;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 84,
              height: 84,
              child: file == null
                  ? const ColoredBox(color: Colors.black12)
                  : GestureDetector(
                      onTap: () => _open(context, file),
                      child: Image.file(file, fit: BoxFit.cover,
                          cacheWidth: 252),
                    ),
            ),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, File file) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InteractiveViewer(child: Image.file(file)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(children: [
              Expanded(
                child: Text(
                  'by ${community.userName(photo.userId)} · '
                  '${photo.createdAt.day}.${photo.createdAt.month}.${photo.createdAt.year}',
                ),
              ),
              ContentMenu(
                community: community,
                target: ReportTarget.photo,
                targetId: photo.id,
                authorId: photo.userId,
                authorName: community.userName(photo.userId),
                onBlocked: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: selected ? Colors.white : color,
      backgroundColor: selected ? color : null,
      side: BorderSide(color: color),
    );
    return OutlinedButton.icon(
      style: style,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({required this.initial});
  final int initial;

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  late int _stars = widget.initial;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              iconSize: 36,
              onPressed: () => setState(() => _stars = i),
              icon: Icon(i <= _stars ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade700),
            ),
        ]),
        TextField(
          controller: _comment,
          maxLength: 280,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Comment (optional): clean, crowded, easy to find …',
            border: OutlineInputBorder(),
          ),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _stars == 0
              ? null
              : () => Navigator.pop(context, (_stars, _comment.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// "Temporarily closed" / "open again" reports.
class _ClosureControls extends StatelessWidget {
  const _ClosureControls({required this.area, required this.community});
  final SmokingArea area;
  final CommunityService community;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = community.closureFor(area);
    // Closed by official data or by the community (live state).
    final closed = community.annotate(area).isTemporarilyClosed;
    final info = closed
        ? '${status.closedReports} "closed" '
            'report${status.closedReports == 1 ? '' : 's'}'
            '${status.reopenedReports > 0 ? ', ${status.reopenedReports} "reopened"' : ''}'
        : 'Blocked, construction, out of order? Report it – the report '
            'expires after 14 days or on the date you set.';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: closed
              ? OutlinedButton.icon(
                  onPressed: () => contribute(context, community,
                      () => community.reportClosure(area, closed: false),
                      reason: 'Sign in to report closures.'),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Open again'),
                )
              : OutlinedButton.icon(
                  onPressed: () => _reportClosed(context),
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Temporarily closed'),
                ),
        ),
      ]),
      if (closed && status.closedReports == 0 && area.isOfficial)
        Text('Closed according to the official list.',
            style: theme.textTheme.bodySmall)
      else
        Text(info, style: theme.textTheme.bodySmall),
    ]);
  }

  Future<void> _reportClosed(BuildContext context) async {
    if (!await ensureSignedIn(context, community,
            reason: 'Sign in to report closures.') ||
        !context.mounted) {
      return;
    }
    final result = await showDialog<(String, DateTime?)>(
      context: context,
      builder: (_) => const _ClosureDialog(),
    );
    if (result == null || !context.mounted) return;
    await contribute(
        context,
        community,
        () => community.reportClosure(area,
            closed: true, note: result.$1, until: result.$2));
  }
}

class _ClosureDialog extends StatefulWidget {
  const _ClosureDialog();

  @override
  State<_ClosureDialog> createState() => _ClosureDialogState();
}

class _ClosureDialogState extends State<_ClosureDialog> {
  final _note = TextEditingController();
  DateTime? _until;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Temporarily closed'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _note,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. construction, out of order, blocked',
            border: OutlineInputBorder(),
          ),
        ),
        Row(children: [
          Expanded(
            child: Text(_until == null
                ? 'End unknown (expires after 14 days)'
                : 'expected until ${_until!.day}.${_until!.month}.${_until!.year}'),
          ),
          TextButton(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: now,
                lastDate: now.add(const Duration(days: 180)),
                initialDate: _until ?? now.add(const Duration(days: 7)),
              );
              if (picked != null) setState(() => _until = picked);
            },
            child: const Text('Date'),
          ),
        ]),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_note.text, _until)),
          child: const Text('Report'),
        ),
      ],
    );
  }
}
