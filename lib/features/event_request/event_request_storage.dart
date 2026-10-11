import 'package:shared_preferences/shared_preferences.dart';

import 'event_request_models.dart';

/// Keeps the customer's event request on the device.
///
/// The request is submitted to the team over WhatsApp, which means there is no
/// server record to read back. Without this the customer would tap «تقديم
/// الطلب», close the app, and have nothing to return to — so the progress map
/// lives here and survives restarts.
class EventRequestStorage {
  EventRequestStorage._();
  static final EventRequestStorage instance = EventRequestStorage._();

  static const _key = 'event_request_current';

  EventRequest? _cached;
  bool _loaded = false;

  /// The saved request, or null when none has been submitted.
  Future<EventRequest?> load() async {
    if (_loaded) return _cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      _cached = raw == null ? null : EventRequest.decode(raw);
    } catch (_) {
      // Storage being unavailable must not block the form: the customer can
      // still submit, they just will not see it again after a restart.
      _cached = null;
    }
    _loaded = true;
    return _cached;
  }

  /// The last value returned by [load], without touching disk. Lets a widget
  /// decide synchronously whether to show the "tracked request" state.
  EventRequest? get cached => _cached;

  Future<void> save(EventRequest request) async {
    _cached = request;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, request.encode());
    } catch (_) {
      // Keep the in-memory copy so the current session still works.
    }
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Nothing to recover from; the in-memory copy is already gone.
    }
  }
}
