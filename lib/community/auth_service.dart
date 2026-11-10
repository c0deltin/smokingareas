import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'community_backend.dart';
import 'models.dart';

/// Adapter for user identity. Locally there is no login: profiles live in
/// the [CommunityBackend] and the active one is remembered on the device.
/// Several local profiles make it possible to try the multi-user rules
/// (e.g. three users reporting a spot as gone) on one phone.
/// A server implementation would sign in with a real account instead.
abstract class AuthService {
  UserProfile get currentUser;
  Future<List<UserProfile>> profiles();
  Future<UserProfile> createProfile(String displayName);
  Future<void> switchTo(String userId);
  Future<UserProfile> rename(String displayName);
}

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
      _current = await createProfile('Ich');
    }
  }

  @override
  UserProfile get currentUser => _current;

  @override
  Future<List<UserProfile>> profiles() => _backend.users();

  @override
  Future<UserProfile> createProfile(String displayName) async {
    final user = UserProfile(
      id: 'local-${_uuid.v4()}',
      displayName: displayName.trim().isEmpty ? 'Nutzer' : displayName.trim(),
      createdAt: DateTime.now(),
    );
    await _backend.saveUser(user);
    _current = user;
    await (await _prefs).setString(_prefKey, user.id);
    return user;
  }

  @override
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
