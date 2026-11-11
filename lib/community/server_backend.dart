import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image/image.dart' as img;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';
import 'community_backend.dart';
import 'models.dart';
import 'photo_storage.dart';
import 'server_rows.dart';

/// Connection settings, passed at build time (`--dart-define`, from CI
/// secrets). Without them the app uses the local adapters.
class ServerConfig {
  const ServerConfig._();

  static const url = String.fromEnvironment('BACKEND_URL');
  static const anonKey = String.fromEnvironment('BACKEND_ANON_KEY');
  static const googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

const _photoBucket = 'spot-photos';

/// Community data on the server. Reading works without an account; writes
/// are checked by the database (row level security).
class ServerCommunityBackend implements CommunityBackend {
  ServerCommunityBackend(this._client);

  final SupabaseClient _client;

  /// The API returns at most 1000 rows per request.
  static const _page = 1000;

  Future<List<T>> _all<T>(
      String table, T Function(Map<String, dynamic>) parse) async {
    final result = <T>[];
    for (var from = 0;; from += _page) {
      final rows = await _client
          .from(table)
          .select()
          .order('created_at')
          .range(from, from + _page - 1);
      result.addAll(rows.map(parse));
      if (rows.length < _page) return result;
    }
  }

  @override
  Future<List<UserProfile>> users() => _all('profiles', ServerRows.profile);

  @override
  Future<void> saveUser(UserProfile user) => _client
      .from('profiles')
      .update({'display_name': user.displayName}).eq('id', user.id);

  @override
  Future<List<CommunitySpot>> spots() => _all('spots', ServerRows.spot);

  @override
  Future<void> addSpot(CommunitySpot spot) =>
      _client.from('spots').insert(ServerRows.spotInsert(spot));

  @override
  Future<List<SpotReview>> reviews() => _all('reviews', ServerRows.review);

  @override
  Future<void> saveReview(SpotReview review) => _client
      .from('reviews')
      .upsert(ServerRows.reviewUpsert(review), onConflict: 'spot_id,user_id');

  @override
  Future<List<SpotPhoto>> photos() => _all('photos', ServerRows.photo);

  @override
  Future<void> addPhoto(SpotPhoto photo) =>
      _client.from('photos').insert(ServerRows.photoInsert(photo));

  @override
  Future<List<ExistenceVote>> votes() => _all('votes', ServerRows.vote);

  @override
  Future<void> addVote(ExistenceVote vote) =>
      _client.from('votes').insert(ServerRows.voteInsert(vote));

  @override
  Future<List<ClosureReport>> closureReports() =>
      _all('closures', ServerRows.closure);

  @override
  Future<void> addClosureReport(ClosureReport report) =>
      _client.from('closures').insert(ServerRows.closureInsert(report));
}

/// Sign in with Apple (iOS) and Google (iOS + Android). The account's
/// display name lives in the `profiles` table.
class ServerAuthService implements AuthService {
  ServerAuthService(this._client);

  final SupabaseClient _client;
  UserProfile? _profile;
  bool _googleReady = false;

  /// Loads the profile of a session kept from the last app start.
  Future<void> init() async {
    if (_client.auth.currentUser != null) {
      try {
        await _loadProfile();
      } catch (_) {
        // Offline: keep the session; the name loads on the next refresh.
        final user = _client.auth.currentUser!;
        _profile = UserProfile(
            id: user.id, displayName: 'Me', createdAt: DateTime.now());
      }
    }
  }

  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _profile = null;
      return;
    }
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    _profile = row == null
        ? UserProfile(id: user.id, displayName: 'User', createdAt: DateTime.now())
        : ServerRows.profile(row);
  }

  @override
  UserProfile? get currentUser =>
      _client.auth.currentUser == null ? null : _profile;

  @override
  List<SignInProvider> get providers => [
        if (!kIsWeb && Platform.isIOS) SignInProvider.apple,
        SignInProvider.google,
      ];

  @override
  Future<bool> signIn(SignInProvider provider) async {
    final givenName = switch (provider) {
      SignInProvider.apple => await _signInWithApple(),
      SignInProvider.google => await _signInWithGoogle(),
    };
    if (givenName == null) return false;
    await _loadProfile();
    // Apple only shares the name once and not in the token: store it.
    final name = givenName.trim();
    if (_profile?.displayName == 'User' && name.isNotEmpty) {
      await rename(name);
    }
    return true;
  }

  /// Returns the given name ('' if unknown), null when cancelled.
  Future<String?> _signInWithApple() async {
    final rawNonce = _nonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.fullName],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
    final idToken = credential.identityToken;
    if (idToken == null) throw const AuthException('No identity token');
    await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple, idToken: idToken, nonce: rawNonce);
    return credential.givenName ?? '';
  }

  Future<String?> _signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(
        clientId: Platform.isIOS && ServerConfig.googleIosClientId.isNotEmpty
            ? ServerConfig.googleIosClientId
            : null,
        serverClientId: ServerConfig.googleWebClientId.isEmpty
            ? null
            : ServerConfig.googleWebClientId,
      );
      _googleReady = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AuthException('No identity token');
    await _client.auth
        .signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
    // The profile gets the first name from the Google token already.
    return '';
  }

  static String _nonce() {
    final random = Random.secure();
    return base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _profile = null;
    if (_googleReady) await GoogleSignIn.instance.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    // Photo files first (the database can only delete its own rows).
    final storage = _client.storage.from(_photoBucket);
    final files = await storage.list(path: user.id);
    if (files.isNotEmpty) {
      await storage.remove([for (final f in files) '${user.id}/${f.name}']);
    }
    await _client.rpc('delete_account');
    await signOut();
  }

  @override
  Future<UserProfile?> rename(String displayName) async {
    final profile = _profile;
    final name = displayName.trim();
    if (profile == null || name.isEmpty) return profile;
    final short = name.length > 40 ? name.substring(0, 40) : name;
    await _client
        .from('profiles')
        .update({'display_name': short}).eq('id', profile.id);
    return _profile = profile.copyWith(displayName: short);
  }
}

/// Photos in the server's photo bucket. Uploads are re-encoded as JPEG
/// (max. 1600 px), which also drops all metadata such as GPS positions.
class ServerPhotoStorage implements PhotoStorage {
  ServerPhotoStorage(this._client, this._cacheDirectory);

  final SupabaseClient _client;
  final Future<Directory> Function() _cacheDirectory;
  static const _uuid = Uuid();

  @override
  Future<String> save(File source) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const SignInRequired();
    final bytes = await source.readAsBytes();
    final jpeg = await Isolate.run(() => reencodePhoto(bytes));
    final path = ServerRows.photoPath(user.id, _uuid.v4());
    await _client.storage.from(_photoBucket).uploadBinary(path, jpeg,
        fileOptions: const FileOptions(contentType: 'image/jpeg'));
    await _cacheFile(path).then((f) => f.writeAsBytes(jpeg));
    return path;
  }

  Future<File> _cacheFile(String key) async {
    final dir = Directory('${(await _cacheDirectory()).path}/photo-cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/${key.replaceAll('/', '_')}');
  }

  @override
  Future<File?> resolve(String key) async {
    if (!ServerRows.isPhotoPath(key)) return null;
    final file = await _cacheFile(key);
    if (await file.exists()) return file;
    try {
      final bytes = await _client.storage.from(_photoBucket).download(key);
      await file.writeAsBytes(bytes);
      return file;
    } catch (_) {
      return null;
    }
  }
}

/// Decodes any supported image, scales it to at most [maxSide] pixels and
/// encodes it as JPEG without metadata (EXIF incl. GPS is not copied).
Uint8List reencodePhoto(Uint8List bytes, {int maxSide = 1600}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image');
  var image = img.bakeOrientation(decoded);
  if (image.width > maxSide || image.height > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide)
        : img.copyResize(image, height: maxSide);
  }
  image.exif = img.ExifData();
  return img.encodeJpg(image, quality: 82);
}
