import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      title: const Text('Use of your location'),
      content: const SingleChildScrollView(
        child: Text(
          'Ippuku uses your location to show nearby smoking areas and '
          'public toilets on the map.\n\n'
          'If you turn on alerts, the app also uses your location in the '
          'background – even when the app is closed or not in use – to '
          'notify you when you are close to a designated smoking area.\n\n'
          'Your location is processed only on your device. It is never sent '
          'to us or shared with anyone. You can turn alerts off at any time.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
