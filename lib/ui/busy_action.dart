import 'package:flutter/material.dart';

/// Runs [action] and marks the caller as busy until it finishes.
typedef TrackBusy = Future<void> Function(Future<void> Function() action);

/// Gives a button immediate feedback while its save runs: [builder] gets
/// `busy` (show [BusySpinner], disable the button) and `track`, which wraps
/// only the save itself – sign-in and confirmation dialogs stay outside.
class BusyAction extends StatefulWidget {
  const BusyAction({super.key, required this.builder});

  final Widget Function(BuildContext context, bool busy, TrackBusy track)
      builder;

  @override
  State<BusyAction> createState() => _BusyActionState();
}

class _BusyActionState extends State<BusyAction> {
  bool _busy = false;

  Future<void> _track(Future<void> Function() action) async {
    if (mounted) setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _busy, _track);
}

/// Small progress ring in the size of a button icon.
class BusySpinner extends StatelessWidget {
  const BusySpinner({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
}
