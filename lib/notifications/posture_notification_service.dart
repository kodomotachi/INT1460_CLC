import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/posture_entry.dart';

class PostureNotificationService {
  PostureNotificationService._();

  static final PostureNotificationService instance =
      PostureNotificationService._();

  static const int _notificationId = 4201;
  static const String _channelId = 'posture_changes';
  static const String _channelName = 'Posture changes';
  static const String _channelDescription =
      'Alerts when your posture changes while the app is in the background.';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _appInForeground = true;
  bool? _lastPostureValue;
  int? _lastPostureTimestampMs;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(settings: settings);

    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  void setAppInForeground(bool value) {
    _appInForeground = value;
  }

  Future<void> handleLatestPosture(PostureEntry? entry) async {
    if (entry == null) {
      return;
    }

    final bool? previousValue = _lastPostureValue;
    final int? previousTimestampMs = _lastPostureTimestampMs;
    _lastPostureValue = entry.isGoodPosture;
    _lastPostureTimestampMs = entry.timestampMs;

    final bool isNewEvent = previousTimestampMs != entry.timestampMs;
    final bool changedGoodToBad =
        previousValue == true && !entry.isGoodPosture;
    if (_appInForeground || !isNewEvent || !changedGoodToBad) {
      return;
    }

    await initialize();
    await _showBadPostureNotification();
  }

  Future<void> _showBadPostureNotification() {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Posture changed',
    );
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    return _notifications.show(
      id: _notificationId,
      title: 'Posture changed',
      body: 'Your posture changed to bad. Sit upright.',
      notificationDetails: details,
    );
  }
}
