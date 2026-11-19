import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cities.dart';
import '../i18n.dart';
import '../models/city.dart';
import '../models/japan_holidays.dart';
import '../models/smoking_area.dart';
import 'heading_service.dart';
import 'notification_service.dart';
import 'proximity_detector.dart';
import 'smoking_area_repository.dart';
import 'tracking_policy.dart';

enum LocationState { unknown, serviceDisabled, denied, deniedForever, whileInUse, always }

/// Tracks the user's position (also in the background) and sends a local
/// push notification when a smoking area is within the alert radius.
///
/// Battery: precise GPS only while the app is visible or a smoking area is
/// near; otherwise coarse updates, and no tracking at all in the background
/// with alerts off ([TrackingPolicy]).
class ProximityMonitor extends ChangeNotifier with WidgetsBindingObserver {
  ProximityMonitor({
    required this.repository,
    NotificationService? notifications,
    ProximityDetector? detector,
    this.heading,
    this.policy = const TrackingPolicy(),
  })  : notifications = notifications ?? NotificationService.instance,
        detector = detector ?? ProximityDetector();

  final TrackingPolicy policy;
  TrackingMode _mode = TrackingMode.precise;
  bool _foreground = true;
  bool _observing = false;

  /// How the position is tracked right now.
  TrackingMode get trackingMode => _mode;

  static const defaultAlertRadius = 30.0;
  static const minAlertRadius = 10.0;
  static const maxAlertRadius = 150.0;
  static const _prefAlertsEnabled = 'alerts_enabled';
  static const _prefAlertRadius = 'alert_radius_m';

  double _alertRadius = defaultAlertRadius;

  /// Distance (m) at which the user is notified about a smoking area.
  double get alertRadius => _alertRadius;

  final SmokingAreaRepository repository;
  final NotificationService notifications;
  final ProximityDetector detector;

  /// Receives position and GPS course for the direction cone (optional).
  final HeadingService? heading;

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
    _alertRadius = (prefs.getDouble(_prefAlertRadius) ?? defaultAlertRadius)
        .clamp(minAlertRadius, maxAlertRadius)
        .toDouble();
    detector.setRadius(_alertRadius);
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
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

  /// User setting: alert radius in metres (clamped to the allowed range).
  Future<void> setAlertRadius(double meters) async {
    final value = meters.clamp(minAlertRadius, maxAlertRadius).toDouble();
    if (value == _alertRadius) return;
    _alertRadius = value;
    detector.setRadius(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefAlertRadius, value);
    // Restart so the background notification shows the new radius.
    if (_sub != null && _alertsEnabled) await _startStream();
    notifyListeners();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }
    if (foreground == _foreground) return;
    _foreground = foreground;
    _applyMode();
  }

  /// Re-evaluates the tracking mode and restarts the location stream when
  /// it changed (or stops it in the background without alerts).
  void _applyMode() {
    if (_state != LocationState.whileInUse && _state != LocationState.always) {
      return;
    }
    final next = policy.mode(
      foreground: _foreground,
      alertsEnabled: _alertsEnabled,
      current: _mode,
      nearestSmokingMeters: _nearestSmokingMeters(),
    );
    if (next == _mode && (next == TrackingMode.off) == (_sub == null)) return;
    _mode = next;
    if (next == TrackingMode.off) {
      _sub?.cancel();
      _sub = null;
    } else {
      unawaited(_startStream());
    }
  }

  /// Distance to the nearest open smoking area within 2 km (null: none
  /// known nearby yet – counts as "far" only once data is loaded).
  double? _nearestSmokingMeters() {
    final pos = _position;
    if (pos == null) return null;
    final box = GeoBounds.around(pos, 2);
    const distance = Distance();
    double? best;
    var anyData = false;
    final now = japanNow();
    for (final a in repository.allLoaded) {
      anyData = true;
      if (a.category != SpotCategory.smoking ||
          a.isTemporarilyClosed ||
          !box.contains(a.position) ||
          a.closedAt(now)) {
        continue;
      }
      final d = distance(pos, a.position);
      if (best == null || d < best) best = d;
    }
    // Data loaded but nothing within 2 km: far away.
    return best ?? (anyData ? double.infinity : null);
  }

  LocationSettings _settings() {
    final profile = TrackingPolicy.profile(_mode, _alertRadius);
    final distanceFilter = profile.distanceFilterMeters;
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy:
            profile.precise ? LocationAccuracy.high : LocationAccuracy.medium,
        distanceFilter: distanceFilter,
        intervalDuration: profile.interval,
        // A foreground service keeps location updates alive while the app is
        // in the background (required on Android 8+).
        foregroundNotificationConfig: _alertsEnabled
            ? ForegroundNotificationConfig(
                notificationTitle: deviceL10n().fgAlertsOnTitle,
                notificationText:
                    deviceL10n().fgAlertsOnText(_alertRadius.round()),
                notificationChannelName: deviceL10n().fgChannel,
                notificationIcon: const AndroidResource(
                    name: NotificationService.androidIcon),
                color: NotificationService.accent,
                // The foreground service keeps updates coming; a wake lock
                // would keep the CPU awake between them.
                enableWakeLock: false,
                setOngoing: true,
              )
            : null,
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: profile.precise
            ? LocationAccuracy.best
            : LocationAccuracy.medium,
        distanceFilter: distanceFilter,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: _alertsEnabled,
        showBackgroundLocationIndicator: _alertsEnabled,
      );
    }
    return LocationSettings(
      accuracy:
          profile.precise ? LocationAccuracy.high : LocationAccuracy.medium,
      distanceFilter: distanceFilter,
    );
  }

  Future<void> _startStream() async {
    if (_mode == TrackingMode.off) _mode = TrackingMode.precise;
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
    heading?.updatePosition(p.latitude, p.longitude);
    heading?.updateFromGps(course: p.heading, speed: p.speed);
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

    // Precise near smoking areas, coarse far away (background only).
    _applyMode();

    if (!_alertsEnabled) return;
    // Alerts only for smoking areas – toilets are far too dense for that.
    // Only candidates around the position are measured (the loaded data can
    // hold tens of thousands of spots).
    // Smoking areas outside their opening hours are skipped.
    final box = GeoBounds.around(pos, 1);
    final now = japanNow();
    final hit = detector.update(
      pos,
      repository.allLoaded.where((a) =>
          a.category == SpotCategory.smoking &&
          !a.isTemporarilyClosed &&
          box.contains(a.position) &&
          !a.closedAt(now)),
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
    final now = japanNow();
    for (final SmokingArea a in repository.allLoaded) {
      if (a.category != category || a.isTemporarilyClosed) continue;
      if (a.closedAt(now)) continue;
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
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }
}
