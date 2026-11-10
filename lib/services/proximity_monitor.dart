import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cities.dart';
import '../models/smoking_area.dart';
import 'notification_service.dart';
import 'proximity_detector.dart';
import 'smoking_area_repository.dart';

enum LocationState { unknown, serviceDisabled, denied, deniedForever, whileInUse, always }

/// Tracks the user's position (also in the background) and sends a local
/// push notification when a smoking area is within 30 m.
class ProximityMonitor extends ChangeNotifier {
  ProximityMonitor({
    required this.repository,
    NotificationService? notifications,
    ProximityDetector? detector,
  })  : notifications = notifications ?? NotificationService.instance,
        detector = detector ?? ProximityDetector();

  static const alertRadiusMeters = 30.0;
  static const _prefAlertsEnabled = 'alerts_enabled';

  final SmokingAreaRepository repository;
  final NotificationService notifications;
  final ProximityDetector detector;

  StreamSubscription<Position>? _sub;
  LatLng? _position;
  double? _accuracy;
  bool _alertsEnabled = true;
  LocationState _state = LocationState.unknown;
  String? _loadedForCity;
  ProximityHit? _lastHit;

  LatLng? get position => _position;
  double? get accuracy => _accuracy;
  bool get alertsEnabled => _alertsEnabled;
  LocationState get locationState => _state;
  ProximityHit? get lastHit => _lastHit;
  bool get isTracking => _sub != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _alertsEnabled = prefs.getBool(_prefAlertsEnabled) ?? true;
    await notifications.init();
    await _refreshPermissionState();
    if (_state == LocationState.whileInUse || _state == LocationState.always) {
      await _startStream();
    }
    notifyListeners();
  }

  /// Requests location (and notification) permission and starts tracking.
  /// For background alerts the user has to grant "always" access; on both
  /// platforms this needs a second, separate prompt.
  Future<LocationState> requestPermissions({bool background = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _state = LocationState.serviceDisabled;
      notifyListeners();
      return _state;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (background && permission == LocationPermission.whileInUse) {
      // Second request upgrades to "always" (iOS shows the upgrade prompt,
      // Android 11+ redirects to the settings page).
      permission = await Geolocator.requestPermission();
    }
    await notifications.requestPermission();
    await _refreshPermissionState();
    if (_state == LocationState.whileInUse || _state == LocationState.always) {
      await _startStream();
    }
    notifyListeners();
    return _state;
  }

  Future<void> setAlertsEnabled(bool enabled) async {
    _alertsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAlertsEnabled, enabled);
    if (enabled) {
      detector.reset();
      await requestPermissions();
    }
    // Restart so that the Android foreground service is only shown while
    // alerts are on.
    if (_sub != null) await _startStream();
    notifyListeners();
  }

  Future<void> _refreshPermissionState() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _state = LocationState.serviceDisabled;
      return;
    }
    switch (await Geolocator.checkPermission()) {
      case LocationPermission.always:
        _state = LocationState.always;
      case LocationPermission.whileInUse:
        _state = LocationState.whileInUse;
      case LocationPermission.deniedForever:
        _state = LocationState.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        _state = LocationState.denied;
    }
  }

  LocationSettings _settings() {
    const distanceFilter = 5;
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        intervalDuration: const Duration(seconds: 5),
        // A foreground service keeps location updates alive while the app is
        // in the background (required on Android 8+).
        foregroundNotificationConfig: _alertsEnabled
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Raucherbereich-Alarm aktiv',
                notificationText:
                    'Du wirst benachrichtigt, wenn ein Raucherbereich in 30 m Nähe ist.',
                notificationChannelName: 'Standortüberwachung',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilter,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: _alertsEnabled,
        showBackgroundLocationIndicator: _alertsEnabled,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
  }

  Future<void> _startStream() async {
    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(
      _onPosition,
      onError: (Object e) {
        debugPrint('Location stream error: $e');
      },
    );
  }

  Future<void> _onPosition(Position p) async {
    final pos = LatLng(p.latitude, p.longitude);
    _position = pos;
    _accuracy = p.accuracy;
    notifyListeners();

    // Make sure the data of the city we are in is loaded (from cache or
    // network) – also when the app was never opened on that city's map.
    final city = cityForPosition(pos);
    if (city != null && _loadedForCity != city.id) {
      _loadedForCity = city.id;
      try {
        await repository.loadAround(pos);
      } catch (_) {
        _loadedForCity = null;
      }
    }

    if (!_alertsEnabled) return;
    // Alerts only for smoking areas – toilets are far too dense for that.
    final hit = detector.update(
      pos,
      repository.allLoaded.where((a) => a.category == SpotCategory.smoking),
      accuracyMeters: p.accuracy,
    );
    if (hit != null) {
      _lastHit = hit;
      notifyListeners();
      await notifications.showNearby(hit.area, hit.distanceMeters);
    }
  }

  /// Nearest known spot of [category] to the current position.
  ProximityHit? nearest([SpotCategory category = SpotCategory.smoking]) {
    final pos = _position;
    if (pos == null) return null;
    const distance = Distance();
    ProximityHit? best;
    for (final SmokingArea a in repository.allLoaded) {
      if (a.category != category) continue;
      final d = distance(pos, a.position);
      if (best == null || d < best.distanceMeters) best = ProximityHit(a, d);
    }
    return best;
  }

  Future<void> openSettings() async {
    if (_state == LocationState.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
