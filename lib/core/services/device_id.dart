import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A stable per-install identifier used to attribute guest actions (e.g. a
/// competition vote) without requiring an account. Persisted locally.
class DeviceId {
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null || id.isEmpty) {
      final r = Random();
      id = 'dev-${DateTime.now().microsecondsSinceEpoch}-${r.nextInt(1 << 31)}';
      await prefs.setString('device_id', id);
    }
    _cached = id;
    return id;
  }

  static String platform() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return 'other';
  }
}
