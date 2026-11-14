import 'package:flutter/material.dart';

import '../models/smoking_area.dart';
import 'spot_style.dart';
import 'user_location_marker.dart';

/// One legend row: the real map symbol on the left, one short sentence on
/// the right.
class LegendEntry {
  const LegendEntry(this.symbol, this.text);
  final Widget symbol;
  final String text;
}

/// All map symbols, grouped. Built from the same widgets the map uses, so
/// the legend cannot get out of date.
List<(String, List<LegendEntry>)> legendSections() => [
      (
        'Category (fill colour)',
        const [
          LegendEntry(SpotMarker(category: SpotCategory.smoking),
              'Outdoor smoking area.'),
          LegendEntry(SpotMarker(category: SpotCategory.smoking, indoor: true),
              'Indoor smoking room.'),
          LegendEntry(SpotMarker(category: SpotCategory.toilet),
              'Public toilet.'),
          LegendEntry(
              SpotMarker(
                  category: SpotCategory.bin, origin: SpotOrigin.community),
              'Trash can (reported by users).'),
        ],
      ),
      (
        'Origin (ring)',
        const [
          LegendEntry(SpotMarker(category: SpotCategory.smoking),
              'White: entry from OpenStreetMap.'),
          LegendEntry(
              SpotMarker(
                  category: SpotCategory.smoking, origin: SpotOrigin.official),
              'Gold: from an official list of the city or ward.'),
          LegendEntry(
              SpotMarker(
                  category: SpotCategory.smoking, origin: SpotOrigin.community),
              'Pink: reported by a user.'),
        ],
      ),
      (
        'Status',
        const [
          LegendEntry(SpotMarker(category: SpotCategory.toilet, closed: true),
              'Grey with pause badge: temporarily closed.'),
        ],
      ),
      (
        'Map',
        [
          const LegendEntry(
              ClusterBubble(category: SpotCategory.smoking, count: 12),
              'Several smoking areas – tap to zoom in.'),
          const LegendEntry(
              ClusterBubble(category: SpotCategory.toilet, count: 8),
              'Several toilets – tap to zoom in.'),
          const LegendEntry(
              ClusterBubble(category: SpotCategory.bin, count: 5),
              'Several trash cans – tap to zoom in.'),
          LegendEntry(
            SizedBox(
              width: 44,
              height: 44,
              child: FittedBox(
                child: CustomPaint(
                  size: const Size.square(UserLocationMarker.size),
                  painter: HeadingConePainter(
                      headingDegrees: 30,
                      spreadDegrees: 30,
                      color: Colors.blue),
                  child: const SizedBox.square(
                    dimension: UserLocationMarker.size,
                    child: Center(child: UserLocationMarker(heading: null)),
                  ),
                ),
              ),
            ),
            'Your location – the cone shows the direction you are facing.',
          ),
          LegendEntry(
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.12),
                border: Border.all(color: Colors.blue, width: 1.5),
              ),
            ),
            'Alert radius for nearby smoking areas.',
          ),
        ],
      ),
    ];

Future<void> showLegendSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => LegendView(controller: controller),
    ),
  );
}

class LegendView extends StatelessWidget {
  const LegendView({super.key, this.controller});
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text('Legend', style: theme.textTheme.titleLarge),
        for (final (title, entries) in legendSections()) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 52, child: Center(child: e.symbol)),
                const SizedBox(width: 12),
                Expanded(child: Text(e.text)),
              ]),
            ),
        ],
      ],
    );
  }
}
