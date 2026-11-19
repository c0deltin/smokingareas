import 'package:flutter/material.dart';

import '../community/community_service.dart';
import '../i18n.dart';
import '../services/proximity_monitor.dart';
import 'location_disclosure.dart';
import 'profile_sheet.dart';
import 'sign_in_sheet.dart';

Future<void> showSettingsSheet(BuildContext context, ProximityMonitor monitor,
    [CommunityService? community]) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SettingsView(monitor: monitor, community: community),
  );
}

/// User settings: account, proximity alerts on/off and the alert radius.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.monitor, this.community});
  final ProximityMonitor monitor;
  final CommunityService? community;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  /// Slider value while dragging; saved when the user lets go.
  late double _radius = widget.monitor.alertRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monitor = widget.monitor;
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.settings, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              if (widget.community case final community?)
                ListenableBuilder(
                  listenable: community,
                  builder: (context, _) {
                    final user = community.currentUser;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_circle_outlined),
                      title: Text(user == null
                          ? context.l10n.notSignedIn
                          : context.l10n.signedInAs(user.displayName)),
                      subtitle: Text(user == null
                          ? context.l10n.signInDefaultReason
                          : context.l10n.accountActions),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showProfileSheet(context, community),
                    );
                  },
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.smokingAreaAlerts),
                subtitle: Text(context.l10n.smokingAreaAlertsSub),
                value: monitor.alertsEnabled,
                onChanged: (on) async {
                  if (on && !await confirmLocationUse(context)) return;
                  await monitor.setAlertsEnabled(on);
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(context.l10n.alertRadius)),
                Text(context.l10n.meters(_radius.round()),
                    style: theme.textTheme.titleMedium),
              ]),
              Slider(
                min: ProximityMonitor.minAlertRadius,
                max: ProximityMonitor.maxAlertRadius,
                divisions: ((ProximityMonitor.maxAlertRadius -
                            ProximityMonitor.minAlertRadius) /
                        5)
                    .round(),
                value: _radius,
                label: context.l10n.meters(_radius.round()),
                onChanged: monitor.alertsEnabled
                    ? (v) => setState(() => _radius = v)
                    : null,
                onChangeEnd: monitor.setAlertRadius,
              ),
              Text(
                context.l10n.alertRadiusHelp,
                style: theme.textTheme.bodySmall,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _radius == ProximityMonitor.defaultAlertRadius
                      ? null
                      : () {
                          setState(() =>
                              _radius = ProximityMonitor.defaultAlertRadius);
                          monitor.setAlertRadius(
                              ProximityMonitor.defaultAlertRadius);
                        },
                  child: Text(context.l10n.resetToMeters(
                      ProximityMonitor.defaultAlertRadius.round())),
                ),
              ),
              const Divider(),
              const LegalLinks(),
            ],
          ),
        ),
      ),
    );
  }
}
