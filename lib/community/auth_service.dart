import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'community_backend.dart';
import 'models.dart';

/// Ways to sign in with a server backend.
enum SignInProvider { apple, google }

/// Adapter for user identity.
///
/// Reading never needs an account; contributing (report, rate, photo, vote)
/// needs a signed-in [currentUser]. With a server backend users sign in with
/// Apple or Google ([providers]); [LocalAuthService] (no backend configured,
/// development and tests) is always signed in with a local profile.
abstract class AuthService {
  /// Null while the user stays anonymous.
  UserProfile? get currentUser;

  /// Sign-in methods offered on this device (empty: no sign-in needed).
  List<SignInProvider> get providers;

  /// Returns false when the user cancelled.
  Future<bool> signIn(SignInProvider provider);
  Future<void> signOut();

  /// Deletes the account and its contributions on the server.
  Future<void> deleteAccount();
  Future<UserProfile?> rename(String displayName);
}

/// Thrown when a contribution is attempted without a signed-in user.
class SignInRequired implements Exception {
  const SignInRequired();
  @override
  String toString() => 'Sign in to contribute.';
}

/// Local profiles: they live in the [CommunityBackend] and the active one is
/// remembered on the device. Several local profiles make it possible to try
/// the multi-user rules (e.g. three users reporting a spot as gone) on one
/// phone.
class LocalAuthService implements AuthService {
  LocalAuthService(this._backend, {SharedPreferences? prefs})
      : _prefsOverride = prefs;

  final CommunityBackend _backend;
  final SharedPreferences? _prefsOverride;
  static const _prefKey = 'community_current_user';
  static const _uuid = Uuid();

  late UserProfile _current;

  Future<SharedPreferences> get _prefs async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  /// Loads (or creates) the active profile. Must be called once at start.
  Future<void> init() async {
    final users = await _backend.users();
    final id = (await _prefs).getString(_prefKey);
    final match = users.where((u) => u.id == id);
    if (match.isNotEmpty) {
      _current = match.first;
    } else if (users.isNotEmpty) {
      _current = users.first;
      await (await _prefs).setString(_prefKey, _current.id);
    } else {
      _current = await createProfile('Me');
    }
  }

  @override
  UserProfile get currentUser => _current;

  @override
  List<SignInProvider> get providers => const [];

  @override
  Future<bool> signIn(SignInProvider provider) async => true;

  /// Local profiles cannot sign out; switch profiles instead.
  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  Future<List<UserProfile>> profiles() => _backend.users();

  Future<UserProfile> createProfile(String displayName) async {
    final user = UserProfile(
      id: 'local-${_uuid.v4()}',
      displayName: displayName.trim().isEmpty ? 'User' : displayName.trim(),
      createdAt: DateTime.now(),
    );
    await _backend.saveUser(user);
    _current = user;
    await (await _prefs).setString(_prefKey, user.id);
    return user;
  }

  Future<void> switchTo(String userId) async {
    final users = await _backend.users();
    _current = users.firstWhere((u) => u.id == userId);
    await (await _prefs).setString(_prefKey, userId);
  }

  @override
  Future<UserProfile> rename(String displayName) async {
    final name = displayName.trim();
    if (name.isEmpty) return _current;
    _current = _current.copyWith(displayName: name);
    await _backend.saveUser(_current);
    return _current;
  }
}
