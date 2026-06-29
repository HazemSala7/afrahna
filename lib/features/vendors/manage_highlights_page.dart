import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/image_upload_field.dart';

/// Lets a vendor owner manage (create / edit / delete) their permanent
/// highlights and the media inside each one.
class ManageHighlightsPage extends StatefulWidget {
  const ManageHighlightsPage({super.key, required this.vendorId});
  final int vendorId;

  @override
  State<ManageHighlightsPage> createState() => _ManageHighlightsPageState();
}

class _ManageHighlightsPageState extends State<ManageHighlightsPage> {
  final _service = HighlightService();
  late Future<List<HighlightModel>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _service.listForVendor(widget.vendorId);
  }

  Future<void> _createHighlight() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditHighlightPage(vendorId: widget.vendorId),
      ),
    );
    if (ok == true && mounted) setState(_reload);
  }

  Future<void> _openItems(HighlightModel h) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ManageHighlightItemsPage(highlight: h),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _delete(HighlightModel h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الهايلايت'),
        content: Text('هل تريد فعلاً حذف "${h.title}" وكل محتواه؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(h.id);
      if (!mounted) return;
      setState(_reload);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الهايلايت')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('هايلايت جديد'),
        onPressed: _createHighlight,
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: FutureBuilder<List<HighlightModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              final e = snap.error;
              return ListView(children: [
                const SizedBox(height: 80),
                Center(
                    child:
                        Text(e is ApiException ? e.message : e.toString())),
              ]);
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('لا توجد هايلايت بعد')),
                SizedBox(height: 8),
                Center(
                  child: Text('اضغط "هايلايت جديد" لإنشاء أول واحد',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _HighlightRow(
                highlight: items[i],
                onOpen: () => _openItems(items[i]),
                onDelete: () => _delete(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.highlight,
    required this.onOpen,
    required this.onDelete,
  });
  final HighlightModel highlight;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: [
                    AppColors.primary,
                    AppColors.accent,
                    AppColors.primaryDark,
                    AppColors.primary,
                  ]),
                ),
                child: ClipOval(
                  child: AppNetworkImage(
                    url: highlight.cover,
                    fallbackIcon: Icons.auto_awesome_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(highlight.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${highlight.items.length} عنصر',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_left, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CREATE / EDIT HIGHLIGHT (title + cover)
// ---------------------------------------------------------------------------

class _EditHighlightPage extends StatefulWidget {
  const _EditHighlightPage({required this.vendorId});
  final int vendorId;

  @override
  State<_EditHighlightPage> createState() => _EditHighlightPageState();
}

class _EditHighlightPageState extends State<_EditHighlightPage> {
  final _service = HighlightService();
  final _title = TextEditingController();
  String? _coverUrl;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب عنوان الهايلايت')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.create(
        vendorId: widget.vendorId,
        title: _title.text.trim(),
        coverImage: _coverUrl,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('هايلايت جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ImageUploadField(
            label: 'صورة الغلاف (اختياري)',
            url: _coverUrl,
            folder: 'highlights/covers',
            height: 180,
            fallbackIcon: Icons.add_photo_alternate_outlined,
            onChanged: (url) => setState(() => _coverUrl = url),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'عنوان الهايلايت',
              hintText: 'مثال: أعمالنا، فعالياتنا…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'بعد الإنشاء، افتح الهايلايت لإضافة الصور والفيديوهات بداخله.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('إنشاء'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MANAGE ITEMS INSIDE A HIGHLIGHT (add image/video, delete)
// ---------------------------------------------------------------------------

class ManageHighlightItemsPage extends StatefulWidget {
  const ManageHighlightItemsPage({super.key, required this.highlight});
  final HighlightModel highlight;

  @override
  State<ManageHighlightItemsPage> createState() =>
      _ManageHighlightItemsPageState();
}

class _ManageHighlightItemsPageState extends State<ManageHighlightItemsPage> {
  final _service = HighlightService();
  final _picker = ImagePicker();
  late Future<List<HighlightModel>> _future;
  bool _uploading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    // Re-fetch the vendor's highlights and pick this one to refresh its items.
    _future = _service.listForVendor(widget.highlight.vendorId ?? 0);
  }

  HighlightModel _current(List<HighlightModel> all) {
    return all.firstWhere(
      (h) => h.id == widget.highlight.id,
      orElse: () => widget.highlight,
    );
  }

  Future<void> _addImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    await _upload(picked.path, 'image');
  }

  Future<void> _addVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 90),
    );
    if (picked == null) return;
    await _upload(picked.path, 'video');
  }

  Future<void> _upload(String path, String type) async {
    setState(() {
      _uploading = true;
      _progress = 0;
    });
    try {
      final url = await UploadService().uploadFile(
        path,
        folder: 'highlights/items',
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await _service.addItem(
        highlightId: widget.highlight.id,
        mediaUrl: url,
        type: type,
      );
      if (!mounted) return;
      setState(_reload);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذّر رفع الملف')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('إضافة صورة'),
              onTap: () {
                Navigator.pop(ctx);
                _addImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('إضافة فيديو'),
              onTap: () {
                Navigator.pop(ctx);
                _addVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(HighlightItemModel item) async {
    try {
      await _service.deleteItem(item.id);
      if (!mounted) return;
      setState(_reload);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.highlight.title)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('إضافة محتوى'),
        onPressed: _uploading ? null : _showAddSheet,
      ),
      body: Column(
        children: [
          if (_uploading)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _progress > 0 && _progress < 1 ? _progress : null,
                    backgroundColor: AppColors.primaryLight,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 6),
                  Text('جاري الرفع ${(_progress * 100).round()}%',
                      style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => setState(_reload),
              child: FutureBuilder<List<HighlightModel>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.hasData
                      ? _current(snap.data!).items
                      : widget.highlight.items;
                  if (items.isEmpty) {
                    return ListView(children: const [
                      SizedBox(height: 120),
                      Center(child: Text('لا يوجد محتوى بعد')),
                      SizedBox(height: 8),
                      Center(
                        child: Text('اضغط "إضافة محتوى" لرفع صورة أو فيديو',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ]);
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 9 / 16,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _ItemTile(
                      item: items[i],
                      onDelete: () => _deleteItem(items[i]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onDelete});
  final HighlightItemModel item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.isVideo)
            Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: const Icon(Icons.play_circle_fill,
                  color: Colors.white70, size: 40),
            )
          else
            AppNetworkImage(url: item.mediaUrl, fit: BoxFit.cover),
          if (item.isVideo)
            const Positioned(
              top: 4,
              left: 4,
              child: Icon(Icons.videocam, color: Colors.white, size: 18),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 18),
                onPressed: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
