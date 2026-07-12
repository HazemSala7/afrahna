import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api/api_client.dart';
import '../core/services/services.dart';
import '../core/theme.dart';
import 'app_widgets.dart';

/// A form field that lets the user pick MANY images (gallery multi-select or
/// camera), uploads each, and reports back the ordered list of public URLs.
/// The first image is treated as the cover.
class MultiImageUploadField extends StatefulWidget {
  const MultiImageUploadField({
    super.key,
    required this.label,
    required this.urls,
    required this.folder,
    required this.onChanged,
    this.fallbackIcon = Icons.image_outlined,
  });

  final String label;
  final List<String> urls;
  final String folder;
  final ValueChanged<List<String>> onChanged;
  final IconData fallbackIcon;

  @override
  State<MultiImageUploadField> createState() => _MultiImageUploadFieldState();
}

class _MultiImageUploadFieldState extends State<MultiImageUploadField> {
  final _picker = ImagePicker();
  int _uploading = 0;

  Future<void> _addFromGallery() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 88);
      if (picked.isEmpty) return;
      await _uploadAll(picked.map((e) => e.path).toList());
    } catch (_) {
      _err();
    }
  }

  Future<void> _addFromCamera() async {
    try {
      final picked =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 88);
      if (picked == null) return;
      await _uploadAll([picked.path]);
    } catch (_) {
      _err();
    }
  }

  Future<void> _uploadAll(List<String> paths) async {
    setState(() => _uploading += paths.length);
    final added = <String>[];
    for (final path in paths) {
      try {
        final url = await UploadService().uploadFile(path, folder: widget.folder);
        added.add(url);
      } on ApiException {
        // skip the failed one, keep going
      } catch (_) {
        // skip
      } finally {
        if (mounted) setState(() => _uploading -= 1);
      }
    }
    if (added.isNotEmpty) {
      widget.onChanged([...widget.urls, ...added]);
    }
  }

  void _err() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر رفع الصور')),
      );
    }
  }

  void _removeAt(int i) {
    final next = [...widget.urls]..removeAt(i);
    widget.onChanged(next);
  }

  void _showSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار عدة صور من المعرض'),
              onTap: () {
                Navigator.pop(ctx);
                _addFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () {
                Navigator.pop(ctx);
                _addFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tile = 92.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < widget.urls.length; i++)
                SizedBox(
                  width: tile,
                  height: tile,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: tile,
                          height: tile,
                          child: AppNetworkImage(
                            url: widget.urls[i],
                            fit: BoxFit.cover,
                            fallbackIcon: widget.fallbackIcon,
                          ),
                        ),
                      ),
                      if (i == 0)
                        PositionedDirectional(
                          bottom: 4,
                          start: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('الغلاف',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      PositionedDirectional(
                        top: -6,
                        end: -6,
                        child: GestureDetector(
                          onTap: () => _removeAt(i),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Uploading placeholders.
              for (int i = 0; i < _uploading; i++)
                Container(
                  width: tile,
                  height: tile,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              // Add tile.
              GestureDetector(
                onTap: _showSourceSheet,
                child: Container(
                  width: tile,
                  height: tile,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primaryLight,
                        style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          color: AppColors.primary, size: 26),
                      SizedBox(height: 4),
                      Text('إضافة صور',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A form field that lets the user pick an image from the gallery or camera,
/// uploads it to the server, and reports back the resulting public URL.
class ImageUploadField extends StatefulWidget {
  const ImageUploadField({
    super.key,
    required this.label,
    required this.url,
    required this.folder,
    required this.onChanged,
    this.height = 140,
    this.fallbackIcon = Icons.image_outlined,
  });

  final String label;

  /// Current stored image URL (may be null/empty).
  final String? url;

  /// Server folder to upload into, e.g. "vendors/logos".
  final String folder;

  /// Called with the new public URL after a successful upload.
  final ValueChanged<String> onChanged;

  final double height;
  final IconData fallbackIcon;

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  final _picker = ImagePicker();
  bool _uploading = false;
  String? _localPath; // preview of just-picked file before/while uploading

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        _localPath = picked.path;
        _uploading = true;
      });
      final url = await UploadService().uploadFile(picked.path, folder: widget.folder);
      if (!mounted) return;
      widget.onChanged(url);
      setState(() {
        _uploading = false;
        _localPath = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _localPath = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _localPath = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر رفع الصورة')),
      );
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('من المعرض'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('من الكاميرا'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = (_localPath != null) ||
        (widget.url != null && widget.url!.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _uploading ? null : _showSourceSheet,
            child: Container(
              height: widget.height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryLight),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_localPath != null)
                    Image.file(File(_localPath!), fit: BoxFit.cover)
                  else if (hasImage)
                    AppNetworkImage(
                      url: widget.url,
                      fit: BoxFit.cover,
                      fallbackIcon: widget.fallbackIcon,
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.fallbackIcon,
                              color: AppColors.primary, size: 36),
                          const SizedBox(height: 6),
                          const Text('اضغط لاختيار صورة',
                              style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  if (_uploading)
                    Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                          color: Colors.white),
                    ),
                  if (hasImage && !_uploading)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                          onPressed: _showSourceSheet,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
