import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../community/auth_service.dart';
import '../community/community_service.dart';
import '../community/outbox.dart';
import '../data/links.dart';
import '../i18n.dart';

/// Offers Sign in with Apple (iOS) / Google. Returns true when the user is
/// signed in afterwards, false when they continue without an account.
Future<bool> showSignInSheet(
  BuildContext context,
  CommunityService community, {
  String? reason,
}) async {
  if (community.isSignedIn) return true;
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SignInView(community: community, reason: reason),
  );
  return result ?? false;
}

/// Makes sure a contribution can be made: true when signed in (or no
/// sign-in is needed), otherwise asks the user to sign in.
Future<bool> ensureSignedIn(
  BuildContext context,
  CommunityService community, {
  required String reason,
}) async {
  if (community.isSignedIn || community.signInProviders.isEmpty) return true;
  return showSignInSheet(context, community, reason: reason);
}

/// Runs a contribution (rate, vote, photo, report): asks to sign in first
/// when needed and shows a short message when saving fails.
Future<bool> contribute(
  BuildContext context,
  CommunityService community,
  Future<void> Function() action, {
  String? reason,
}) async {
  if (!await ensureSignedIn(context, community,
      reason: reason ?? context.l10n.signInToContribute)) {
    return false;
  }
  try {
    await action();
    return true;
  } on SavedOffline {
    // Kept on the device and shown already; sent when online again.
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.savedOffline)));
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(
              content: Text(contributionError(e, context.l10n))));
    }
    return false;
  }
}

/// Short, user-facing text for a failed contribution ([l] defaults to
/// English).
String contributionError(Object e, [AppLocalizations? l]) {
  final t = l ?? lookupAppLocalizations(const Locale('en'));
  if (e is SignInRequired) return t.errSignInFirst;
  final text = e.toString();
  if (text.contains('rate limit')) return t.errRateLimit;
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('TimeoutException')) {
    return t.errConnection;
  }
  // Anything else: show the server's reason, shortened.
  final reason = text.length > 120 ? '${text.substring(0, 120)}…' : text;
  return t.errCouldNotSave(reason);
}

/// Shows a small "Saving …" dialog while [action] runs (uploads can take a
/// few seconds on mobile networks).
Future<T> withProgress<T>(BuildContext context, Future<T> Function() action,
    {String? label}) async {
  final text = label ?? context.l10n.saving;
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(text)),
        ]),
      ),
    ),
  );
  try {
    return await action();
  } finally {
    navigator.pop();
  }
}

/// Shows the sign-in sheet once after installation (users can stay
/// anonymous and sign in later in Settings or when they contribute).
Future<void> maybeShowInitialSignIn(
  BuildContext context,
  CommunityService community, {
  SharedPreferences? prefs,
}) async {
  if (community.isSignedIn || community.signInProviders.isEmpty) return;
  final p = prefs ?? await SharedPreferences.getInstance();
  const key = 'sign_in_prompted';
  if (p.getBool(key) ?? false) return;
  await p.setBool(key, true);
  if (!context.mounted) return;
  await showSignInSheet(context, community,
      reason: context.l10n.initialSignInReason);
}

class SignInView extends StatefulWidget {
  const SignInView({super.key, required this.community, this.reason});

  final CommunityService community;
  final String? reason;

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn(SignInProvider provider) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await widget.community.signIn(provider);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
        return;
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.signInFailed);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providers = widget.community.signInProviders;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.signIn, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.reason ?? context.l10n.signInDefaultReason),
            const SizedBox(height: 16),
            if (providers.contains(SignInProvider.apple)) ...[
              SizedBox(
                height: 48,
                child: SignInWithAppleButton(
                  onPressed: () {
                    if (!_busy) _signIn(SignInProvider.apple);
                  },
                  style: theme.brightness == Brightness.dark
                      ? SignInWithAppleButtonStyle.white
                      : SignInWithAppleButtonStyle.black,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (providers.contains(SignInProvider.google))
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed:
                      _busy ? null : () => _signIn(SignInProvider.google),
                  icon: const Text('G',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  label: Text(context.l10n.signInWithGoogle),
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: Text(context.l10n.continueWithoutAccount),
            ),
            Text(
              context.l10n.signInPrivacyNote,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const LegalLinks(),
          ],
        ),
      ),
    );
  }
}

/// Links to the privacy policy, terms of use and imprint.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    Widget link(String label, Uri url) => TextButton(
          style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: Theme.of(context).textTheme.bodySmall),
          onPressed: () =>
              launchUrl(url, mode: LaunchMode.externalApplication),
          child: Text(label),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        link(context.l10n.privacyPolicy, kPrivacyUrl),
        link(context.l10n.termsOfUse, kTermsUrl),
        link(context.l10n.imprint, kImprintUrl),
      ],
    );
  }
}
