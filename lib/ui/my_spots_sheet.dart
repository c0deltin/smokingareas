import 'package:flutter/material.dart';

import '../community/community_service.dart';
import '../community/models.dart';
import '../i18n.dart';
import '../models/smoking_area.dart';
import 'report_spot_sheet.dart';
import 'sign_in_sheet.dart';
import 'spot_style.dart';

/// The places the user reported: show on the map, edit, delete.
/// [onShow] moves the map to a place.
Future<void> showMySpotsSheet(BuildContext context, CommunityService community,
    {required void Function(SmokingArea area) onShow}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => MySpotsView(
        community: community,
        onShow: onShow,
        scrollController: controller,
      ),
    ),
  );
}

class MySpotsView extends StatelessWidget {
  const MySpotsView({
    super.key,
    required this.community,
    required this.onShow,
    this.scrollController,
  });

  final CommunityService community;
  final void Function(SmokingArea area) onShow;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: community,
      builder: (context, _) {
        final spots = community.mySpots;
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(context.l10n.mySpots, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (!community.isSignedIn &&
                community.signInProviders.isNotEmpty) ...[
              Text(context.l10n.mySpotsSignIn),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => showSignInSheet(context, community),
                child: Text(context.l10n.signIn),
              ),
            ] else if (spots.isEmpty)
              Text(context.l10n.mySpotsEmpty)
            else
              for (final s in spots)
                _MySpotTile(spot: s, community: community, onShow: onShow),
          ],
        );
      },
    );
  }
}

class _MySpotTile extends StatelessWidget {
  const _MySpotTile(
      {required this.spot, required this.community, required this.onShow});

  final CommunitySpot spot;
  final CommunityService community;
  final void Function(SmokingArea area) onShow;

  @override
  Widget build(BuildContext context) {
    final category =
        SpotCategory.tryParse(spot.category) ?? SpotCategory.smoking;
    final area = community.areaOf(spot);
    final l = context.l10n;
    final details = <String>[
      l.reportedOn(
          formatDay(context, spot.createdAt)),
      if (area != null) ...[
        if (community.ratingFor(area).count > 0)
          '★ ${community.ratingFor(area).average.toStringAsFixed(1)}',
        if (community.photosFor(area).isNotEmpty)
          l.photoCount(community.photosFor(area).length),
        if (community.isHidden(area)) l.removedByCommunity
        else if (community.annotate(area).isTemporarilyClosed)
          l.temporarilyClosedLower,
      ],
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: categoryColor(category, indoor: spot.indoor == true),
        child: Icon(categoryIcon(category), color: Colors.white, size: 20),
      ),
      title: Text(spot.name),
      subtitle: Text(details.join(' · ')),
      onTap: area == null ? null : () => _show(context, area),
      trailing: PopupMenuButton<String>(
        tooltip: l.more,
        onSelected: (v) => switch (v) {
          'show' => area == null ? null : _show(context, area),
          'edit' => _edit(context, category),
          _ => _delete(context),
        },
        itemBuilder: (_) => [
          if (area != null)
            PopupMenuItem(
              value: 'show',
              child: ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(l.showOnMap),
              ),
            ),
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.edit),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.delete),
            ),
          ),
        ],
      ),
    );
  }

  void _show(BuildContext context, SmokingArea area) {
    Navigator.of(context).pop();
    onShow(area);
  }

  Future<void> _edit(BuildContext context, SpotCategory category) async {
    final input = await showReportSpotSheet(
      context,
      category,
      SpotReportInput(
        name: spot.name,
        description: spot.description,
        indoor: spot.indoor,
        covered: spot.covered,
        publicAccess: spot.publicAccess ?? true,
        accessNote: spot.accessNote,
        category: category,
        wheelchair: spot.wheelchair,
        changingTable: spot.changingTable,
        waste: WasteType.parse(spot.waste),
        bin: spot.bin,
      ),
    );
    if (input == null || !context.mounted) return;
    await contribute(
      context,
      community,
      () => withProgress(
        context,
        () => community.updateSpot(
          spot.id,
          name: input.name,
          description: input.description,
          indoor: input.indoor,
          covered: input.covered,
          publicAccess: input.publicAccess,
          accessNote: input.accessNote,
          wheelchair: input.wheelchair,
          changingTable: input.changingTable,
          waste: input.waste,
          bin: input.bin,
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteSpotQuestion(spot.name)),
        content: Text(context.l10n.deleteSpotText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await contribute(context, community,
        () => withProgress(context, () => community.deleteSpot(spot.id)));
  }
}
