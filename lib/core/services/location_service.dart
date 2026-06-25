import 'package:geolocator/geolocator.dart';

/// Lightweight wrapper around geolocator for sorting content by proximity.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Position? _cached;

  /// The last known position, if it was fetched during this session.
  Position? get cached => _cached;

  /// Returns the device's current position, or null if location is disabled
  /// or permission was denied. Never throws and never hangs: [timeout] caps
  /// how long we wait for a GPS fix before falling back to the last known
  /// position (important on emulators / indoors where a fix can take forever).
  Future<Position?> current({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _cached ?? await _lastKnown();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _cached;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
      _cached = pos;
      return pos;
    } catch (_) {
      // Timed out or failed — return the best position we already have.
      return _cached ?? await _lastKnown();
    }
  }

  /// Best-effort cached fix from the OS; null if unavailable. Never throws.
  Future<Position?> _lastKnown() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) _cached = pos;
      return pos;
    } catch (_) {
      return null;
    }
  }

  /// Distance in meters between a position and a lat/lng, or null if either
  /// coordinate is missing.
  static double? distanceMeters(
    Position? from,
    double? lat,
    double? lng,
  ) {
    if (from == null || lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
        from.latitude, from.longitude, lat, lng);
  }
}
