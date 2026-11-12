import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../community/auth_service.dart';
import '../community/community_service.dart';
import '../data/links.dart';

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
  String reason = 'Sign in to contribute.',
}) async {
  if (!await ensureSignedIn(context, community, reason: reason)) return false;
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(contributionError(e))));
    }
    return false;
  }
}

/// Short, user-facing text for a failed contribution.
String contributionError(Object e) {
  if (e is SignInRequired) return 'Please sign in first.';
  final text = e.toString();
  if (text.contains('rate limit')) {
    return 'Too many contributions in a short time – please try again later.';
  }
  return 'Could not save – please check your connection.';
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
      reason: 'Browse without an account, or sign in to rate, report and '
          'add photos.');
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
      if (mounted) setState(() => _error = 'Sign-in failed. Please try again.');
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
            Text('Sign in', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.reason ?? 'Sign in to rate, report and add photos.'),
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
                  label: const Text('Sign in with Google'),
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
              child: const Text('Continue without account'),
            ),
            Text(
              'Only your first name is shown with your contributions. '
              'Your location never leaves your device. By signing in you '
              'accept the terms of use.',
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
        link('Privacy policy', kPrivacyUrl),
        link('Terms of use', kTermsUrl),
        link('Imprint', kImprintUrl),
      ],
    );
  }
}
