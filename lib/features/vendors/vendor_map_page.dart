import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';

/// Read-only in-app map showing a vendor's location with a marker.
/// Always stays inside the app (OpenStreetMap, no external app needed).
///
/// If [initialLocation] is null, the [query] (address / shop name) is geocoded
/// via OpenStreetMap's free Nominatim service so a marker can still be shown
/// without leaving the app.
class VendorMapPage extends StatefulWidget {
  const VendorMapPage({
    super.key,
    required this.title,
    this.initialLocation,
    this.address,
    this.query,
  });

  final String title;
  final LatLng? initialLocation;
  final String? address;
  final String? query;

  @override
  State<VendorMapPage> createState() => _VendorMapPageState();
}

class _VendorMapPageState extends State<VendorMapPage> {
  LatLng? _location;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _location = widget.initialLocation;
    if (_location == null) _geocode();
  }

  Future<void> _geocode() async {
    final q = (widget.query ?? widget.address ?? widget.title).trim();
    if (q.isEmpty) {
      setState(() => _error = 'لا يوجد عنوان لعرضه على الخريطة');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': q, 'format': 'json', 'limit': 1},
        options: Options(
          headers: {'User-Agent': 'afrahna.sala7.neurex'},
          responseType: ResponseType.json,
        ),
      );
      final data = res.data;
      if (data is List && data.isNotEmpty) {
        final first = Map<String, dynamic>.from(data.first as Map);
        final lat = double.tryParse('${first['lat']}');
        final lon = double.tryParse('${first['lon']}');
        if (lat != null && lon != null) {
          if (!mounted) return;
          setState(() {
            _location = LatLng(lat, lon);
            _loading = false;
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحديد موقع هذا المحل على الخريطة';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل الخريطة. تحقق من اتصال الإنترنت.';
      });
    }
  }

  Future<void> _openDirections() async {
    final loc = _location;
    final uri = loc != null
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination='
            '${loc.latitude},${loc.longitude}')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query='
            '${Uri.encodeComponent(widget.query ?? widget.address ?? widget.title)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح تطبيق الخرائط')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.directions),
            label: const Text('الاتجاهات (فتح في الخرائط)'),
            onPressed: _openDirections,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final loc = _location;
    if (loc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined,
                  size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(_error ?? 'لا يوجد موقع متاح',
                  textAlign: TextAlign.center),
              if ((widget.address ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(widget.address!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted)),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _geocode,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: loc, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'afrahna.sala7.neurex',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: loc,
                  width: 48,
                  height: 48,
                  alignment: Alignment.topCenter,
                  child: const Icon(Icons.location_on,
                      color: AppColors.primary, size: 48),
                ),
              ],
            ),
          ],
        ),
        if ((widget.address ?? '').isNotEmpty)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              color: Colors.white,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.address!,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
