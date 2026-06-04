import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidBackgroundPostureService {
  const AndroidBackgroundPostureService._();

  static const MethodChannel _channel = MethodChannel(
    'posturer/background_monitor',
  );

  static Future<void> start() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('start');
    } on PlatformException catch (error) {
      debugPrint('Failed to start Android posture monitor: $error');
    }
  }

  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException catch (error) {
      debugPrint('Failed to stop Android posture monitor: $error');
    }
  }
}
