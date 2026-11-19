import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../community/community_service.dart';
import '../community/models.dart';
import '../i18n.dart';
import '../models/smoking_area.dart';
import 'community_section.dart';
import 'moderation.dart';
import 'spot_style.dart';

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

Future<void> showAreaDetails(
  BuildContext context,
  SmokingArea area, {
  LatLng? userPosition,
  CommunityService? community,
}) {
  // New photos and ratings of other users show up without a restart.
  community?.refreshIfStale();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => AreaDetailsSheet(
        area: area,
        userPosition: userPosition,
        community: community,
        scrollController: controller,
      ),
    ),
  );
}

class AreaDetailsSheet extends StatelessWidget {
  const AreaDetailsSheet({
    super.key,
    required this.area,
    this.userPosition,
    this.community,
    this.scrollController,
  });

  final SmokingArea area;
  final LatLng? userPosition;
  final CommunityService? community;
  final ScrollController? scrollController;

  Uri get _routeUri {
    final dest = '${area.latitude},${area.longitude}';
    if (Platform.isIOS) {
      return Uri.parse('https://maps.apple.com/?daddr=$dest&dirflg=w');
    }
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=walking',
    );
  }

  Uri? get _officialUri {
    final url = area.officialUrl;
    return url == null ? null : Uri.tryParse(url);
  }

  Uri? get _osmUri {
    final element = area.osmElement;
    if (element != null) {
      return Uri.parse('https://www.openstreetmap.org/$element');
    }
    final website = area.tags['website'] ?? area.tags['url'];
    return website == null ? null : Uri.tryParse(website);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = userPosition == null
        ? null
        : const Distance()(userPosition!, area.position);
    final nameJa = area.tags['name:ja'];
    final nameEn = area.tags['name:en'];

    final l = context.l10n;
    String yesNo(bool? v, [String? yes, String? no]) =>
        v == null ? l.unknown : (v ? (yes ?? l.yes) : (no ?? l.no));

    final rows = <(IconData, String, String)>[
      if (distance != null)
        (Icons.near_me, l.distance, formatDistance(distance)),
      if (area.address != null) (Icons.place_outlined, l.address, area.address!),
      if (area.isApproximate)
        (Icons.gps_not_fixed, l.position, l.positionApprox),
      if (area.isSmoking && area.roomCount > 1)
        (Icons.layers_outlined, l.smokingRooms,
            l.roomsInBuilding(area.roomCount)),
      if (area.isSmoking) ...[
        (Icons.meeting_room_outlined, l.type,
            yesNo(area.isIndoor, l.smokingRoomIndoors, l.outdoors)),
        (Icons.roofing, l.covered, yesNo(area.isCovered)),
      ],
      if (area.isToilet) ...[
        (Icons.accessible, l.wheelchairAccessible, yesNo(area.wheelchair)),
        (Icons.baby_changing_station, l.babyChanging,
            yesNo(area.changingTable)),
      ],
      if (area.category == SpotCategory.bin)
        (
          Icons.recycling,
          l.accepts,
          area.waste.isEmpty
              ? l.unknown
              : [
                  for (final t in WasteType.values)
                    if (area.waste.contains(t)) l.waste(t),
                ].join(', '),
        ),
      if (area.isPublic != null || area.accessNote != null)
        (
          Icons.lock_open_outlined,
          l.access,
          [
            if (area.isPublic != null)
              area.isPublic! ? l.accessPublic : l.accessNotPublic,
            if (area.accessNote != null) area.accessNote!,
          ].join(' – '),
        ),
      if (area.category != SpotCategory.bin)
        (Icons.payments_outlined, l.fee, yesNo(area.requiresFee)),
      if (area.openingHours != null)
        (Icons.schedule, l.openingHours, area.openingHours!),
      if (area.operator != null) (Icons.business, l.operator, area.operator!),
      if (area.description != null)
        (Icons.info_outline, l.note, area.description!),
      if (area.tags['community:by'] != null)
        (Icons.person_outline, l.reportedBy, area.tags['community:by']!),
      (Icons.storage, l.source,
          area.isOfficial ? l.sourceOfficial(area.source) : area.source),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: categoryColor(area.category,
                      indoor: area.isIndoor == true),
                  child: Icon(
                      categoryIcon(area.category),
                      color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.title(area), style: theme.textTheme.titleLarge),
                      if (nameJa != null && nameJa != l.title(area))
                        Text(nameJa, style: theme.textTheme.bodyMedium),
                      if (nameEn != null && nameEn != l.title(area))
                        Text(nameEn, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                // Places reported by users can be reported to moderators.
                if (community != null && area.tags['community'] == 'yes')
                  ContentMenu(
                    community: community!,
                    target: ReportTarget.spot,
                    targetId: area.id,
                    authorId: area.tags['community:by_id'] ?? '',
                    authorName: area.tags['community:by'] ?? l.thisUser,
                    onBlocked: () => Navigator.of(context).maybePop(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (community != null)
              ListenableBuilder(
                listenable: community!,
                builder: (context, _) {
                  final current = community!.annotate(area);
                  return current.isTemporarilyClosed
                      ? ClosedBanner(area: current)
                      : const SizedBox.shrink();
                },
              )
            else if (area.isTemporarilyClosed)
              ClosedBanner(area: area),
            for (final (icon, label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: theme.colorScheme.outline),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    ),
                    Expanded(
                      child: Text(value,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => launchUrl(_routeUri,
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.directions_walk),
                    label: Text(l.route),
                  ),
                ),
                if (_officialUri != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(_officialUri!,
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.account_balance_outlined),
                      label: Text(l.city),
                    ),
                  ),
                ],
                if (_osmUri != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(_osmUri!,
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(l.osm),
                    ),
                  ),
                ],
              ],
            ),
            if (community != null)
              CommunitySection(
                area: area,
                community: community!,
                onRemoved: () {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(context).pop();
                  messenger.showSnackBar(SnackBar(
                    content: Text(l.removedAfterReports),
                  ));
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Red notice for temporarily closed spots.
class ClosedBanner extends StatelessWidget {
  const ClosedBanner({super.key, required this.area});
  final SmokingArea area;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final until = area.closedUntil;
    final note = area.closedNote;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.pause_circle_filled, color: theme.colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.temporarilyClosed,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.onErrorContainer)),
            if (note != null)
              Text(note,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onErrorContainer)),
            if (until != null)
              Text(
                  context.l10n.expectedUntil(formatDay(context, until)),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onErrorContainer)),
          ]),
        ),
      ]),
    );
  }
}
