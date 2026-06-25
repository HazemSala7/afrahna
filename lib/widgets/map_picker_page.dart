import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/services/location_service.dart';
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
  /// recenters the map. Shows a hint if location is off / permission denied.
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService.instance.current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر تحديد موقعك. فعّل خدمة الموقع وامنح الإذن.'),
        ),
      );
      return;
    }
    final here = LatLng(pos.latitude, pos.longitude);
    _setPoint(here);
    _controller.move(here, 16);
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
