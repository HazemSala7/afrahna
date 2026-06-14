import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api/api_client.dart';
import '../core/services/services.dart';
import '../core/theme.dart';
import 'app_widgets.dart';

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
