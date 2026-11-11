import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/smoking_area.dart';

/// Thin wrapper around flutter_local_notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'smoking_area_nearby';
  static const _channelName = 'Smoking area nearby';

  /// Called with the area id when the user taps a notification.
  void Function(String areaId)? onTap;

  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
      title: 'Smoking area nearby 🚬',
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
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
      ),
      payload: area.id,
    );
  }
}
