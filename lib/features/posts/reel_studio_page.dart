import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/image_upload_field.dart';

/// Reels Studio — lets a vendor record/pick a short video, preview it, add a
/// caption and an optional cover, then upload + publish it as a reel.
///
/// The owning vendor is resolved automatically from the signed-in account
/// (no manual vendor_id entry). Pass [vendorId] when an admin/owner is acting
/// on a specific vendor; otherwise the current user's own vendor is used.
class ReelStudioPage extends StatefulWidget {
  const ReelStudioPage({super.key, this.vendorId});

  final int? vendorId;

  @override
  State<ReelStudioPage> createState() => _ReelStudioPageState();
}

class _ReelStudioPageState extends State<ReelStudioPage> {
  final _picker = ImagePicker();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _postService = PostService();

  // The vendor we publish under (resolved from `mine()` when not provided).
  int? _vendorId;
  bool _resolvingVendor = true;
  String? _vendorError;

  // Selected local video + its preview controller.
  XFile? _video;
  VideoPlayerController? _preview;
  bool _previewReady = false;

  // Optional custom cover image (else the player's first frame is used by the
  // reels feed as a fallback).
  String? _thumbnailUrl;

  bool _submitting = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _resolveVendor();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _resolveVendor() async {
    if (widget.vendorId != null) {
      setState(() {
        _vendorId = widget.vendorId;
        _resolvingVendor = false;
      });
      return;
    }
    try {
      final v = await VendorService().mine();
      if (!mounted) return;
      setState(() {
        _vendorId = v.id;
        _resolvingVendor = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _vendorError = e.message;
        _resolvingVendor = false;
      });
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 90),
      );
      if (picked == null) return;

      // Swap in a fresh preview controller.
      final old = _preview;
      final controller = VideoPlayerController.file(File(picked.path));
      setState(() {
        _video = picked;
        _previewReady = false;
        _preview = controller;
      });
      await old?.dispose();
      await controller.initialize();
      if (!mounted) return;
      controller
        ..setLooping(true)
        ..setVolume(0)
        ..play();
      setState(() => _previewReady = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر اختيار الفيديو')),
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
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('من المعرض'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('تسجيل فيديو'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _togglePlay() {
    final c = _preview;
    if (c == null || !_previewReady) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  Future<void> _publish() async {
    final vid = _vendorId;
    if (vid == null) return;
    if (_video == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر فيديو الريلز أولاً')),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _uploadProgress = 0;
    });
    try {
      final mediaUrl = await UploadService().uploadFile(
        _video!.path,
        folder: 'posts/reels',
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
      await _postService.create(
        vendorId: vid,
        type: PostType.reel,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        body: _body.text.trim().isEmpty ? null : _body.text.trim(),
        mediaUrl: mediaUrl,
        thumbnail: _thumbnailUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نشر الريلز بنجاح')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر نشر الريلز')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استوديو الريلز')),
      body: _resolvingVendor
          ? const Center(child: CircularProgressIndicator())
          : _vendorError != null
              ? _VendorErrorState(message: _vendorError!, onRetry: _resolveVendor)
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return AbsorbPointer(
      absorbing: _submitting,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _VideoPicker(
            video: _video,
            controller: _preview,
            ready: _previewReady,
            onPick: _showSourceSheet,
            onTogglePlay: _togglePlay,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'العنوان (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'الوصف (اختياري)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ImageUploadField(
            label: 'صورة الغلاف (اختياري)',
            url: _thumbnailUrl,
            folder: 'posts/thumbnails',
            fallbackIcon: Icons.image_outlined,
            onChanged: (url) => setState(() => _thumbnailUrl = url),
          ),
          const SizedBox(height: 8),
          if (_submitting) ...[
            LinearProgressIndicator(
              value: _uploadProgress > 0 && _uploadProgress < 1
                  ? _uploadProgress
                  : null,
              backgroundColor: AppColors.primaryLight,
              color: AppColors.primary,
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _uploadProgress >= 1
                    ? 'جاري النشر…'
                    : 'جاري رفع الفيديو ${(_uploadProgress * 100).round()}%',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _submitting ? null : _publish,
            icon: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.upload),
            label: Text(_submitting ? 'جارٍ النشر' : 'نشر الريلز'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VIDEO PICKER / PREVIEW
// ---------------------------------------------------------------------------

class _VideoPicker extends StatelessWidget {
  const _VideoPicker({
    required this.video,
    required this.controller,
    required this.ready,
    required this.onPick,
    required this.onTogglePlay,
  });

  final XFile? video;
  final VideoPlayerController? controller;
  final bool ready;
  final VoidCallback onPick;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    final hasVideo = video != null;
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasVideo && ready && controller != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.size.width,
                    height: controller!.value.size.height,
                    child: VideoPlayer(controller!),
                  ),
                )
              else if (hasVideo)
                const Center(
                    child: CircularProgressIndicator(color: Colors.white))
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.video_call_outlined,
                          color: Colors.white70, size: 56),
                      SizedBox(height: 8),
                      Text('اضغط لاختيار فيديو الريلز',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              // Play/pause overlay when a video is loaded.
              if (hasVideo && ready)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: onTogglePlay,
                    child: AnimatedOpacity(
                      opacity: controller!.value.isPlaying ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        color: Colors.black26,
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 64),
                      ),
                    ),
                  ),
                ),
              // Pick / re-pick button.
              Positioned(
                right: 10,
                bottom: 10,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                  onPressed: onPick,
                  icon: Icon(hasVideo ? Icons.swap_horiz : Icons.add),
                  label: Text(hasVideo ? 'تغيير' : 'اختيار'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorErrorState extends StatelessWidget {
  const _VendorErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined,
                size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
