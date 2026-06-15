import 'package:geolocator/geolocator.dart';

/// Lightweight wrapper around geolocator for sorting content by proximity.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Position? _cached;

  /// The last known position, if it was fetched during this session.
  Position? get cached => _cached;

  /// Returns the device's current position, or null if location is disabled
  /// or permission was denied. Never throws.
  Future<Position?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _cached;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _cached;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      _cached = pos;
      return pos;
    } catch (_) {
      return _cached;
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
