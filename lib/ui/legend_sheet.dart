import 'package:flutter/material.dart';

import '../i18n.dart';
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
List<(String, List<LegendEntry>)> legendSections(AppLocalizations l) => [
      (
        l.legCategory,
        [
          LegendEntry(const SpotMarker(category: SpotCategory.smoking),
              l.legOutdoorSmoking),
          LegendEntry(
              const SpotMarker(category: SpotCategory.smoking, indoor: true),
              l.legIndoorSmoking),
          LegendEntry(
              const SpotMarker(category: SpotCategory.toilet), l.legToilet),
          LegendEntry(
              const SpotMarker(
                  category: SpotCategory.bin, origin: SpotOrigin.community),
              l.legBin),
        ],
      ),
      (
        l.legOrigin,
        [
          LegendEntry(
              const SpotMarker(category: SpotCategory.smoking), l.legWhite),
          LegendEntry(
              const SpotMarker(
                  category: SpotCategory.smoking, origin: SpotOrigin.official),
              l.legGold),
          LegendEntry(
              const SpotMarker(
                  category: SpotCategory.smoking, origin: SpotOrigin.community),
              l.legPink),
        ],
      ),
      (
        l.legStatus,
        [
          LegendEntry(
              const SpotMarker(category: SpotCategory.toilet, closed: true),
              l.legClosed),
          LegendEntry(
              const SpotMarker(category: SpotCategory.smoking, bin: true),
              l.legBinBadge),
        ],
      ),
      (
        l.legMap,
        [
          LegendEntry(
              const ClusterBubble(category: SpotCategory.smoking, count: 12),
              l.legClusterSmoking),
          LegendEntry(
              const ClusterBubble(category: SpotCategory.toilet, count: 8),
              l.legClusterToilet),
          LegendEntry(
              const ClusterBubble(category: SpotCategory.bin, count: 5),
              l.legClusterBin),
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
            l.legYourLocation,
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
            l.legAlertRadius,
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
        Text(context.l10n.legend, style: theme.textTheme.titleLarge),
        for (final (title, entries) in legendSections(context.l10n)) ...[
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
