import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../community/community_service.dart';
import '../community/models.dart';
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
          title: const Text('Foto aufnehmen'),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Aus Galerie wählen'),
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
              Text('als ${community.currentUser.displayName}',
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
                      ? 'Noch keine Bewertung'
                      : '${rating.average.toStringAsFixed(1)} '
                          '(${rating.count} Bewertung${rating.count == 1 ? '' : 'en'})',
                ),
              ),
              TextButton.icon(
                onPressed: () => _rate(context, rating.mine),
                icon: const Icon(Icons.star_outline),
                label: Text(rating.mine == null ? 'Bewerten' : 'Ändern'),
              ),
            ]),
            for (final r in reviews.where((r) => r.comment != null).take(3))
              _ReviewTile(review: r, author: community.userName(r.userId)),

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

            // --- existence votes (Waze-like) ----------------------------
            const SizedBox(height: 12),
            Text(
                area.isToilet
                    ? 'Gibt es diese Toilette noch?'
                    : 'Gibt es diesen Raucherbereich noch?',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: _VoteButton(
                  selected: myVote == true,
                  icon: Icons.check_circle_outline,
                  label: 'Ja (${status.confirmations})',
                  color: Colors.green,
                  onPressed: () => community.vote(area, exists: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VoteButton(
                  selected: myVote == false,
                  icon: Icons.highlight_off,
                  label: 'Nein (${status.removals})',
                  color: theme.colorScheme.error,
                  onPressed: () => _voteGone(context),
                ),
              ),
            ]),
            if (status.disputed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${status.removals} Nutzer melden, dass es '
                  '${area.isToilet ? 'diese Toilette' : 'diesen Raucherbereich'} '
                  'nicht mehr gibt.',
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
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _RatingDialog(initial: current ?? 0),
    );
    if (result == null) return;
    await community.rate(area, result.$1, comment: result.$2);
  }

  Future<void> _addPhoto(BuildContext context) async {
    final file = await pickPhoto(context);
    if (file == null) return;
    await community.addPhoto(area, file);
  }

  Future<void> _voteGone(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gibt es nicht mehr?'),
        content: const Text(
          'Wenn genug Nutzer melden, dass es diesen Ort nicht mehr gibt, '
          'wird er von der Karte entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Melden'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await community.vote(area, exists: false);
    if (community.isHidden(area)) onRemoved?.call();
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.author});
  final SpotReview review;
  final String author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Text('Foto', style: theme.textTheme.bodySmall),
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
            padding: const EdgeInsets.all(8),
            child: Text(
              'von ${community.userName(photo.userId)} · '
              '${photo.createdAt.day}.${photo.createdAt.month}.${photo.createdAt.year}',
            ),
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
      title: const Text('Bewerten'),
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
            hintText: 'Kommentar (optional): sauber, voll, gut zu finden …',
            border: OutlineInputBorder(),
          ),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _stars == 0
              ? null
              : () => Navigator.pop(context, (_stars, _comment.text)),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
