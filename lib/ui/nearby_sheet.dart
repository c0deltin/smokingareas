import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../i18n.dart';
import '../models/japan_holidays.dart';
import '../models/smoking_area.dart';
import '../services/heading_service.dart';
import '../services/nearby.dart';
import 'area_details_sheet.dart';
import 'hours_text.dart';
import 'spot_style.dart';

/// The closest spots around the user as a list, nearest first.
/// [onShow] moves the map to a spot and opens it.
Future<void> showNearbySheet(
  BuildContext context, {
  required Iterable<SmokingArea> Function() areas,
  required LatLng? Function() position,
  required Set<SpotCategory> categories,
  required bool openOnly,
  required void Function(SmokingArea area) onShow,
  HeadingService? heading,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => NearbyView(
        areas: areas,
        position: position,
        categories: categories,
        openOnly: openOnly,
        heading: heading,
        scrollController: controller,
        onShow: (a) {
          Navigator.of(context).pop();
          onShow(a);
        },
      ),
    ),
  );
}

class NearbyView extends StatefulWidget {
  const NearbyView({
    super.key,
    required this.areas,
    required this.position,
    required this.categories,
    required this.openOnly,
    required this.onShow,
    this.heading,
    this.scrollController,
    this.now,
  });

  final Iterable<SmokingArea> Function() areas;
  final LatLng? Function() position;
  final Set<SpotCategory> categories;
  final bool openOnly;
  final void Function(SmokingArea area) onShow;
  final HeadingService? heading;
  final ScrollController? scrollController;

  /// Wall-clock time in Japan (tests).
  final DateTime? now;

  @override
  State<NearbyView> createState() => _NearbyViewState();
}

class _NearbyViewState extends State<NearbyView> {
  late final Set<SpotCategory> _categories = {
    ...(widget.categories.isEmpty ? SpotCategory.values : widget.categories),
  };
  late bool _openOnly = widget.openOnly;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final pos = widget.position();
    final now = widget.now ?? japanNow();
    final spots = pos == null
        ? const <NearbySpot>[]
        : nearbySpots(
            widget.areas(),
            pos,
            categories: _categories,
            openAt: _openOnly ? now : null,
          );

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        Text(l.nearby, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final c in SpotCategory.values)
              FilterChip(
                avatar: Icon(
                  categoryIcon(c),
                  size: 18,
                  color: categoryColor(c),
                ),
                label: Text(l.categories(c)),
                selected: _categories.contains(c),
                showCheckmark: false,
                onSelected: (on) => setState(
                  () => on ? _categories.add(c) : _categories.remove(c),
                ),
              ),
            FilterChip(
              avatar: const Icon(Icons.schedule, size: 18),
              label: Text(l.openNow),
              selected: _openOnly,
              onSelected: (on) => setState(() => _openOnly = on),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (pos == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(l.nearbyNoLocation, textAlign: TextAlign.center),
          )
        else if (spots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(l.nearbyEmpty, textAlign: TextAlign.center),
          ),
        for (final s in spots) _tile(s, now, l, lang, theme),
      ],
    );
  }

  Widget _tile(
    NearbySpot s,
    DateTime now,
    AppLocalizations l,
    String lang,
    ThemeData theme,
  ) {
    final status = s.area.isTemporarilyClosed
        ? l.closedNow
        : switch (s.area.hours) {
            final h? => openStatus(h, now, l, lang)?.$2,
            null => null,
          };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: categoryColor(
          s.area.category,
          indoor: s.area.isIndoor == true,
        ),
        child: Icon(
          categoryIcon(s.area.category),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        l.title(s.area),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: status == null
          ? null
          : Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatDistance(s.distanceMeters),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          _DirectionArrow(bearing: s.bearing, heading: widget.heading),
        ],
      ),
      onTap: () => widget.onShow(s.area),
    );
  }
}

/// Arrow towards the spot: relative to where the phone points when the
/// compass is known, else relative to north.
class _DirectionArrow extends StatelessWidget {
  const _DirectionArrow({required this.bearing, this.heading});

  final double bearing;
  final HeadingService? heading;

  @override
  Widget build(BuildContext context) {
    Widget arrow(double? h) => Transform.rotate(
      angle: (bearing - (h ?? 0)) * math.pi / 180,
      child: Icon(
        Icons.navigation,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    final service = heading;
    if (service == null) return arrow(null);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => arrow(service.heading),
    );
  }
}
