import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/image_upload_field.dart';
import 'manage_sections_page.dart';

String _money(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Standalone page wrapping [StoreProductsList] with an "add" button.
class ManageProductsPage extends StatefulWidget {
  const ManageProductsPage({super.key, required this.vendorId});
  final int vendorId;

  @override
  State<ManageProductsPage> createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  int _reload = 0;

  Future<void> _add() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProductPage(vendorId: widget.vendorId),
      ),
    );
    if (ok == true && mounted) setState(() => _reload++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('منتجاتي')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('إضافة منتج'),
        onPressed: _add,
      ),
      body: StoreProductsList(
        vendorId: widget.vendorId,
        canManage: true,
        refreshSignal: _reload,
      ),
    );
  }
}

/// Reusable list of a vendor's products. When [canManage] is true, tapping a
/// row edits it and a delete button is shown. Bump [refreshSignal] to reload.
class StoreProductsList extends StatefulWidget {
  const StoreProductsList({
    super.key,
    required this.vendorId,
    this.canManage = false,
    this.refreshSignal = 0,
  });

  final int vendorId;
  final bool canManage;
  final int refreshSignal;

  @override
  State<StoreProductsList> createState() => _StoreProductsListState();
}

class _StoreProductsListState extends State<StoreProductsList> {
  final _service = ProductService();
  late Future<List<ProductModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.list(vendorId: widget.vendorId);
  }

  @override
  void didUpdateWidget(StoreProductsList old) {
    super.didUpdateWidget(old);
    if (old.refreshSignal != widget.refreshSignal ||
        old.vendorId != widget.vendorId) {
      setState(() {
        _future = _service.list(vendorId: widget.vendorId);
      });
    }
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.list(vendorId: widget.vendorId);
    });
  }

  Future<void> _editRow(ProductModel p) async {
    if (!widget.canManage) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProductPage(vendorId: widget.vendorId, product: p),
      ),
    );
    if (ok == true) _reload();
  }

  Future<void> _delete(ProductModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف "${p.name}"؟'),
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
      await _service.delete(p.id);
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<ProductModel>>(
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
                  child: Text(e is ApiException ? e.message : e.toString())),
            ]);
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 100),
              const Icon(Icons.inventory_2_outlined,
                  size: 56, color: AppColors.primary),
              const SizedBox(height: 10),
              const Center(child: Text('لا توجد منتجات بعد')),
              const SizedBox(height: 6),
              Center(
                child: Text(
                    widget.canManage
                        ? 'اضغط "إضافة منتج" لإضافة أول منتج'
                        : 'لا توجد منتجات معروضة حالياً',
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            ]);
          }
          final available = items.where((p) => p.isAvailable).length;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('${items.length} منتج',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppColors.textDark)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E9E5A).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$available متوفر',
                            style: const TextStyle(
                                color: Color(0xFF1E9E5A),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                );
              }
              final p = items[i - 1];
              return _ProductRow(
                product: p,
                canManage: widget.canManage,
                onEdit: () => _editRow(p),
                onDelete: () => _delete(p),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });
  final ProductModel product;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final off = product.hasDiscount
        ? ((product.price - product.discountPrice!) / product.price * 100).round()
        : 0;

    return InkWell(
      onTap: canManage ? onEdit : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // ---- Image + badges ----
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 92,
                    height: 92,
                    color: const Color(0xFFF3EDE6),
                    child: AppNetworkImage(
                      url: product.image,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.inventory_2_outlined,
                    ),
                  ),
                ),
                if (off > 0)
                  PositionedDirectional(
                    top: 6,
                    start: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5A5F), Color(0xFFE0353B)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('-$off%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                if (!product.isAvailable)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.55),
                        alignment: Alignment.center,
                        child: const Icon(Icons.block,
                            color: Colors.black45, size: 26),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // ---- Info ----
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                          color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(_money(product.effectivePrice),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                      const SizedBox(width: 2),
                      const Text('₪',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 8),
                        Text('${_money(product.price)} ₪',
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StatusChip(available: product.isAvailable),
                ],
              ),
            ),
            // ---- Actions ----
            if (canManage) ...[
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundIconBtn(
                    icon: Icons.edit_outlined,
                    color: AppColors.primary,
                    onTap: onEdit,
                  ),
                  const SizedBox(height: 8),
                  _RoundIconBtn(
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.available});
  final bool available;

  @override
  Widget build(BuildContext context) {
    final c = available ? const Color(0xFF1E9E5A) : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(available ? Icons.check_circle : Icons.remove_circle,
              size: 12, color: c),
          const SizedBox(width: 4),
          Text(available ? 'متوفر' : 'غير متوفر',
              style: TextStyle(
                  color: c, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn(
      {required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADD / EDIT PRODUCT
// ---------------------------------------------------------------------------

class EditProductPage extends StatefulWidget {
  const EditProductPage({super.key, required this.vendorId, this.product});
  final int vendorId;
  final ProductModel? product;

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _service = ProductService();
  final _sectionService = ProductSectionService();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _discount;
  late final TextEditingController _desc;

  late List<String> _images;
  late bool _available;
  int? _sectionId;
  List<ProductSectionModel> _sections = const [];
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.nameAr ?? '');
    _price = TextEditingController(text: p == null ? '' : _money(p.price));
    _discount = TextEditingController(
        text: (p?.discountPrice != null && p!.discountPrice! > 0)
            ? _money(p.discountPrice!)
            : '');
    _desc = TextEditingController(text: p?.descriptionAr ?? '');
    _images = List<String>.from(p?.gallery ?? const <String>[]);
    _available = p?.isAvailable ?? true;
    _sectionId = p?.sectionId;
    _loadSections();
  }

  Future<void> _loadSections() async {
    try {
      final s = await _sectionService.list(vendorId: widget.vendorId);
      if (!mounted) return;
      setState(() {
        _sections = s;
        // Drop a stale selection if the section no longer exists.
        if (_sectionId != null && !s.any((e) => e.id == _sectionId)) {
          _sectionId = null;
        }
      });
    } catch (_) {
      // Sections are optional; ignore load failures.
    }
  }

  Future<void> _openSections() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManageSectionsPage(vendorId: widget.vendorId),
      ),
    );
    await _loadSections();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _discount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    if (name.isEmpty) {
      _snack('اكتب اسم المنتج');
      return;
    }
    if (price == null || price < 0) {
      _snack('اكتب سعرًا صحيحًا');
      return;
    }
    final discount = double.tryParse(_discount.text.trim());
    setState(() => _saving = true);
    try {
      final cover = _images.isNotEmpty ? _images.first : null;
      if (_isEdit) {
        await _service.update(
          widget.product!.id,
          nameAr: name,
          price: price,
          discountPrice: discount,
          descriptionAr: _desc.text.trim(),
          image: cover,
          images: _images,
          sectionId: _sectionId,
          clearSection: _sectionId == null,
          isAvailable: _available,
        );
      } else {
        await _service.create(
          vendorId: widget.vendorId,
          nameAr: name,
          price: price,
          discountPrice: discount,
          descriptionAr: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          image: cover,
          images: _images,
          sectionId: _sectionId,
          isAvailable: _available,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل المنتج' : 'إضافة منتج')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MultiImageUploadField(
            label: 'صور المنتج (أول صورة هي الغلاف)',
            urls: _images,
            folder: 'products',
            fallbackIcon: Icons.inventory_2_outlined,
            onChanged: (v) => setState(() => _images = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'اسم المنتج',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'السعر (₪)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _discount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'سعر بعد الخصم (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'الوصف (اختياري)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _sectionId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'القسم',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('بدون قسم')),
                    ..._sections.map((s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(s.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _sectionId = v),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'إدارة الأقسام',
                icon: const Icon(Icons.tune),
                onPressed: _openSections,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('متوفر للبيع'),
            value: _available,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _available = v),
          ),
          const SizedBox(height: 10),
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
                : Text(_isEdit ? 'حفظ التعديلات' : 'إضافة المنتج'),
          ),
        ],
      ),
    );
  }
}
