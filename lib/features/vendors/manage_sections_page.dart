import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';

/// Standalone page wrapping [SectionsManagerList].
class ManageSectionsPage extends StatelessWidget {
  const ManageSectionsPage({super.key, required this.vendorId});
  final int vendorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أقسام المتجر')),
      body: SectionsManagerList(vendorId: vendorId),
    );
  }
}

/// Reusable sections manager: an "add section" button plus the list with
/// inline edit / delete. Used standalone and as the "الأقسام" vendor tab.
class SectionsManagerList extends StatefulWidget {
  const SectionsManagerList({
    super.key,
    required this.vendorId,
    this.refreshSignal = 0,
  });
  final int vendorId;
  final int refreshSignal;

  @override
  State<SectionsManagerList> createState() => _SectionsManagerListState();
}

class _SectionsManagerListState extends State<SectionsManagerList> {
  final _service = ProductSectionService();
  late Future<List<ProductSectionModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.list(vendorId: widget.vendorId);
  }

  @override
  void didUpdateWidget(SectionsManagerList old) {
    super.didUpdateWidget(old);
    if (old.refreshSignal != widget.refreshSignal) _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.list(vendorId: widget.vendorId);
    });
  }

  Future<void> _edit([ProductSectionModel? section]) async {
    final controller = TextEditingController(text: section?.nameAr ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(section == null ? 'إضافة قسم' : 'تعديل القسم'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم القسم',
            hintText: 'مثال: فساتين، إكسسوارات...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      if (section == null) {
        await _service.create(vendorId: widget.vendorId, nameAr: name);
      } else {
        await _service.update(section.id, nameAr: name);
      }
      if (mounted) _reload();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _delete(ProductSectionModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف القسم'),
        content: Text(
            'سيتم حذف "${s.name}". المنتجات داخله لن تُحذف بل تصبح بدون قسم.'),
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
      if (mounted) _reload();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<ProductSectionModel>>(
        future: _future,
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final items = snap.data ?? const <ProductSectionModel>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
            children: [
              // Add button (always visible).
              InkWell(
                onTap: () => _edit(),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 6),
                      Text('إضافة قسم جديد',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (loading)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(snap.error is ApiException
                        ? (snap.error as ApiException).message
                        : '${snap.error}'),
                  ),
                )
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: Column(
                    children: [
                      Icon(Icons.category_outlined,
                          size: 56, color: AppColors.primary),
                      SizedBox(height: 10),
                      Text('لا توجد أقسام بعد',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text('أنشئ أقسامًا لتنظيم منتجاتك (مثل: فساتين، أحذية)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                )
              else
                ...items.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SectionCard(
                        section: s,
                        onEdit: () => _edit(s),
                        onDelete: () => _delete(s),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.section, required this.onEdit, required this.onDelete});
  final ProductSectionModel section;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.folder_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(section.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text('${section.productsCount} منتج',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
