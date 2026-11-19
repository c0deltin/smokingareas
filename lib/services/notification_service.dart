import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:latlong2/latlong.dart';

import '../models/smoking_area.dart';

/// What a proximity alert points to: the spot id and its position (so the
/// map can load the data there even when the app was not running).
class NotificationTarget {
  const NotificationTarget(this.id, [this.position]);

  final String id;
  final LatLng? position;

  String encode() => jsonEncode({
        'id': id,
        if (position != null) 'lat': position!.latitude,
        if (position != null) 'lon': position!.longitude,
      });

  /// Also reads the plain-id payloads of earlier app versions.
  static NotificationTarget? parse(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final j = jsonDecode(payload);
      if (j is Map<String, dynamic> && j['id'] is String) {
        final lat = (j['lat'] as num?)?.toDouble();
        final lon = (j['lon'] as num?)?.toDouble();
        return NotificationTarget(
            j['id'] as String,
            lat == null || lon == null ? null : LatLng(lat, lon));
      }
    } catch (_) {
      // Not JSON: an id.
    }
    return NotificationTarget(payload);
  }
}

/// Thin wrapper around flutter_local_notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'smoking_area_nearby';
  static const _channelName = 'Smoking area nearby';

  /// Monochrome status bar icon (`res/drawable/ic_stat_ippuku.xml`) and the
  /// app's blue as accent; the launcher icon is a full-colour square and
  /// shows up as a blank blob in the status bar.
  static const androidIcon = 'ic_stat_ippuku';
  static const accent = Color(0xFF2563EB);

  /// Title of the proximity alert (the app name is shown by the system).
  static const nearbyTitle = 'Smoking area nearby';

  /// Called with the payload ([NotificationTarget]) when the user taps a
  /// notification while the app is running.
  void Function(String payload)? onTap;

  /// Payload of the notification that started the app (tapped while the app
  /// was not running), or null.
  Future<String?> launchPayload() async {
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings(androidIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onTap?.call(payload);
      },
    );
    _initialized = true;
  }

  /// Asks for the permission to show notifications (Android 13+, iOS).
  Future<bool> requestPermission() async {
    await init();
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true,
            sound: true,
            badge: false,
          ) ??
          false;
    }
    return true;
  }

  Future<void> showNearby(SmokingArea area, double distanceMeters) async {
    await init();
    final meters = distanceMeters.round();
    await _plugin.show(
      id: area.id.hashCode & 0x7fffffff,
      title: nearbyTitle,
      body: '${area.title} – about $meters m away. Tap to open the map.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Notifies you when you come close to a smoking area.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.navigation,
          icon: androidIcon,
          color: accent,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
      ),
      payload: NotificationTarget(area.id, area.position).encode(),
    );
  }
}
