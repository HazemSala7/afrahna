import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/image_upload_field.dart';

/// Lets a vendor owner manage (view / add / delete) their own stories.
class ManageStoriesPage extends StatefulWidget {
  const ManageStoriesPage({super.key, required this.vendorId});
  final int vendorId;

  @override
  State<ManageStoriesPage> createState() => _ManageStoriesPageState();
}

class _ManageStoriesPageState extends State<ManageStoriesPage> {
  final _service = StoryService();
  late Future<List<StoryModel>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _service.listForVendor(widget.vendorId);
  }

  Future<void> _add() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddStoryPage(vendorId: widget.vendorId),
      ),
    );
    if (ok == true && mounted) setState(_reload);
  }

  Future<void> _delete(StoryModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الستوري'),
        content: const Text('هل تريد فعلاً حذف هذه الستوري؟'),
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
      await _service.delete(s.id);
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
      appBar: AppBar(title: const Text('إدارة الستوريز')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('إضافة ستوري'),
        onPressed: _add,
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: FutureBuilder<List<StoryModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              final e = snap.error;
              return ListView(children: [
                const SizedBox(height: 80),
                Center(child: Text(e is ApiException ? e.message : e.toString())),
              ]);
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('لا توجد ستوريز بعد')),
                SizedBox(height: 8),
                Center(
                  child: Text('اضغط "إضافة ستوري" لإنشاء أول ستوري',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              ]);
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 9 / 16,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => _StoryTile(
                story: items[i],
                onDelete: () => _delete(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.story, required this.onDelete});
  final StoryModel story;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppNetworkImage(url: story.image, fit: BoxFit.cover),
          // Gradient so caption + delete button stay readable.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black38, Colors.transparent, Colors.black54],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
          if (story.caption.isNotEmpty)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                story.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                onPressed: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADD STORY
// ---------------------------------------------------------------------------

class _AddStoryPage extends StatefulWidget {
  const _AddStoryPage({required this.vendorId});
  final int vendorId;

  @override
  State<_AddStoryPage> createState() => _AddStoryPageState();
}

class _AddStoryPageState extends State<_AddStoryPage> {
  final _service = StoryService();
  final _captionAr = TextEditingController();
  final _captionEn = TextEditingController();
  String? _imageUrl;
  bool _saving = false;

  @override
  void dispose() {
    _captionAr.dispose();
    _captionEn.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر صورة للستوري أولاً')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.create(
        vendorId: widget.vendorId,
        image: _imageUrl!,
        captionAr: _captionAr.text.trim(),
        captionEn: _captionEn.text.trim(),
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
      appBar: AppBar(title: const Text('إضافة ستوري')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ImageUploadField(
            label: 'صورة الستوري',
            url: _imageUrl,
            folder: 'stories',
            height: 260,
            fallbackIcon: Icons.add_photo_alternate_outlined,
            onChanged: (url) => setState(() => _imageUrl = url),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionAr,
            decoration: const InputDecoration(
              labelText: 'تعليق بالعربية (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionEn,
            decoration: const InputDecoration(
              labelText: 'تعليق بالإنجليزية (اختياري)',
              border: OutlineInputBorder(),
            ),
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
                    height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('نشر الستوري'),
          ),
        ],
      ),
    );
  }
}
