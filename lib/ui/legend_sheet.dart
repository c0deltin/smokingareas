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
        'Kategorie (Füllfarbe)',
        const [
          LegendEntry(SpotMarker(category: SpotCategory.smoking),
              'Raucherbereich im Freien.'),
          LegendEntry(SpotMarker(category: SpotCategory.smoking, indoor: true),
              'Raucherraum (innen).'),
          LegendEntry(SpotMarker(category: SpotCategory.toilet),
              'Öffentliche Toilette.'),
        ],
      ),
      (
        'Herkunft (Ring)',
        const [
          LegendEntry(SpotMarker(category: SpotCategory.smoking),
              'Weiß: Eintrag aus OpenStreetMap.'),
          LegendEntry(
              SpotMarker(
                  category: SpotCategory.smoking, origin: SpotOrigin.official),
              'Gold: aus einer offiziellen Liste der Stadt oder des Bezirks.'),
          LegendEntry(
              SpotMarker(
                  category: SpotCategory.smoking, origin: SpotOrigin.community),
              'Pink: von einem Nutzer gemeldet.'),
        ],
      ),
      (
        'Status',
        const [
          LegendEntry(SpotMarker(category: SpotCategory.toilet, closed: true),
              'Grau mit Pause-Zeichen: vorübergehend geschlossen.'),
        ],
      ),
      (
        'Karte',
        [
          const LegendEntry(
              ClusterBubble(category: SpotCategory.smoking, count: 12),
              'Mehrere Raucherbereiche – zum Vergrößern antippen.'),
          const LegendEntry(
              ClusterBubble(category: SpotCategory.toilet, count: 8),
              'Mehrere Toiletten – zum Vergrößern antippen.'),
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
            'Dein Standort – der Kegel zeigt deine Blickrichtung.',
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
            '30-m-Umkreis für den Hinweis auf Raucherbereiche.',
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
        Text('Legende', style: theme.textTheme.titleLarge),
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
