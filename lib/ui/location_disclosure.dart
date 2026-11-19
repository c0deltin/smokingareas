import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n.dart';

const _prefKey = 'location_disclosure_accepted';

/// Prominent disclosure shown before the app asks for location access
/// (required by Google Play for background location): what the location is
/// used for, that it is also used in the background, and that it stays on
/// the device. Shown until the user accepts once; returns whether location
/// may be requested.
Future<bool> confirmLocationUse(BuildContext context,
    {SharedPreferences? prefs}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  if (p.getBool(_prefKey) ?? false) return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const LocationDisclosureDialog(),
  );
  if (ok == true) await p.setBool(_prefKey, true);
  return ok == true;
}

class LocationDisclosureDialog extends StatelessWidget {
  const LocationDisclosureDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.location_on_outlined),
      title: Text(context.l10n.locationUseTitle),
      content: SingleChildScrollView(
        child: Text(context.l10n.locationUseText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.continueLabel),
        ),
      ],
    );
  }
}
