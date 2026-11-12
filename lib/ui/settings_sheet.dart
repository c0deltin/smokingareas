import 'package:flutter/material.dart';

import '../community/community_service.dart';
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
              Text('Settings', style: theme.textTheme.titleLarge),
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
                          ? 'Not signed in'
                          : 'Signed in as ${user.displayName}'),
                      subtitle: Text(user == null
                          ? 'Sign in to rate, report and add photos.'
                          : 'Account, sign out, delete account'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showProfileSheet(context, community),
                    );
                  },
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Smoking area alerts'),
                subtitle: const Text(
                    'Notify me when I come close to a smoking area.'),
                value: monitor.alertsEnabled,
                onChanged: (on) async {
                  if (on && !await confirmLocationUse(context)) return;
                  await monitor.setAlertsEnabled(on);
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(child: Text('Alert radius')),
                Text('${_radius.round()} m',
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
                label: '${_radius.round()} m',
                onChanged: monitor.alertsEnabled
                    ? (v) => setState(() => _radius = v)
                    : null,
                onChangeEnd: monitor.setAlertRadius,
              ),
              Text(
                'Small radius: alerts only right next to a smoking area. '
                'Large radius: earlier alerts, but more of them in dense '
                'areas. The blue circle around your location shows the '
                'radius.',
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
                  child: Text(
                      'Reset to ${ProximityMonitor.defaultAlertRadius.round()} m'),
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
