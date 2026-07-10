import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme.dart';

/// Full-screen OpenStreetMap that lets the user pick a location by tapping the
/// map. Returns the selected [LatLng] via `Navigator.pop`, or null if
/// cancelled. Requires no API key.
class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key, this.initial});

  /// Initial location to center the map on. Defaults to Ramallah, Palestine.
  final LatLng? initial;

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  static const LatLng _fallback = LatLng(31.9522, 35.2332); // Ramallah

  late LatLng _picked;
  final _controller = MapController();
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial ?? _fallback;
  }

  void _setPoint(LatLng p) => setState(() => _picked = p);

  /// Fetches the device's current location, moves the marker there and
  /// recenters the map. Explicitly walks the permission flow: prompts the
  /// system "allow location" dialog when needed, and offers to open settings
  /// if the service is off or the permission was permanently denied.
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      // 1) Location services (GPS) must be on.
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        final open = await _confirm(
          'خدمة الموقع مُعطّلة',
          'فعّل خدمة الموقع (GPS) لتحديد موقعك الحالي على الخريطة.',
          'فتح الإعدادات',
        );
        if (open) await Geolocator.openLocationSettings();
        return;
      }

      // 2) Permission — request it (shows the system "allow location" dialog).
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        final open = await _confirm(
          'إذن الموقع مرفوض',
          'تم رفض إذن الوصول للموقع نهائيًا. افتح إعدادات التطبيق وامنح إذن الموقع لاستخدام هذه الميزة.',
          'فتح إعدادات التطبيق',
        );
        if (open) await Geolocator.openAppSettings();
        return;
      }
      if (perm == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يلزم السماح بالوصول للموقع لاستخدام هذه الميزة.')),
        );
        return;
      }

      // 3) Fetch the position (capped so it never hangs).
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      _setPoint(here);
      _controller.move(here, 16);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تحديد موقعك، حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Small confirm dialog offering to open a settings screen. Returns true if
  /// the user chose to open settings.
  Future<bool> _confirm(String title, String message, String confirmLabel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختيار الموقع')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _picked,
              initialZoom: 14,
              onTap: (_, point) => _setPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'afrahna.sala7.neurex',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 44,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton.extended(
              heroTag: 'mapMyLocation',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              icon: _locating
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.my_location),
              label: const Text('موقعي الحالي'),
              onPressed: _locating ? null : _useCurrentLocation,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'الإحداثيات: ${_picked.latitude.toStringAsFixed(6)}, '
                  '${_picked.longitude.toStringAsFixed(6)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.check),
            label: const Text('تأكيد الموقع'),
            onPressed: () => Navigator.pop(context, _picked),
          ),
        ),
      ),
    );
  }
}
