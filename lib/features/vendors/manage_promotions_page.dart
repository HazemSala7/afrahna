import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/image_upload_field.dart';

/// Lets a vendor owner manage (view / add / delete) their own promotions —
/// same idea as the admin dashboard's "العروض" page.
class ManagePromotionsPage extends StatefulWidget {
  const ManagePromotionsPage({super.key, required this.vendorId});
  final int vendorId;

  @override
  State<ManagePromotionsPage> createState() => _ManagePromotionsPageState();
}

class _ManagePromotionsPageState extends State<ManagePromotionsPage> {
  final _service = PromotionService();
  late Future<List<PromotionModel>> _future;

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
        builder: (_) => _AddPromotionPage(vendorId: widget.vendorId),
      ),
    );
    if (ok == true && mounted) setState(_reload);
  }

  Future<void> _delete(PromotionModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف العرض'),
        content: Text('هل تريد فعلاً حذف "${p.title}"؟'),
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
      appBar: AppBar(title: const Text('عروضي')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('إضافة عرض'),
        onPressed: _add,
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: FutureBuilder<List<PromotionModel>>(
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
                Icon(Icons.local_offer_outlined,
                    size: 56, color: AppColors.primary),
                SizedBox(height: 10),
                Center(child: Text('لا توجد عروض بعد')),
                SizedBox(height: 6),
                Center(
                  child: Text('اضغط "إضافة عرض" لإنشاء أول عرض',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _PromotionCard(
                promo: items[i],
                onDelete: () => _delete(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({required this.promo, required this.onDelete});
  final PromotionModel promo;
  final VoidCallback onDelete;

  static String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final expired = promo.endDate != null &&
        promo.endDate!.isBefore(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((promo.image ?? '').isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: AppNetworkImage(url: promo.image, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (promo.discountLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'خصم ${promo.discountLabel}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (!promo.isActive || expired)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('غير فعّال',
                            style: TextStyle(
                                color: Colors.red, fontSize: 12)),
                      ),
                    IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                Text(promo.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                if (promo.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(promo.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.event,
                        size: 15, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'من ${_fmt(promo.startDate)} إلى ${_fmt(promo.endDate)}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADD PROMOTION
// ---------------------------------------------------------------------------

class _AddPromotionPage extends StatefulWidget {
  const _AddPromotionPage({required this.vendorId});
  final int vendorId;

  @override
  State<_AddPromotionPage> createState() => _AddPromotionPageState();
}

class _AddPromotionPageState extends State<_AddPromotionPage> {
  final _service = PromotionService();
  final _titleAr = TextEditingController();
  final _titleEn = TextEditingController();
  final _descAr = TextEditingController();
  final _value = TextEditingController();

  String _discountType = 'percent';
  String? _imageUrl;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void dispose() {
    _titleAr.dispose();
    _titleEn.dispose();
    _descAr.dispose();
    _value.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        if (start) {
          _start = d;
          if (_end.isBefore(_start)) _end = _start;
        } else {
          _end = d;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_titleAr.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب عنوان العرض')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.create(
        vendorId: widget.vendorId,
        titleAr: _titleAr.text.trim(),
        titleEn: _titleEn.text.trim(),
        descriptionAr: _descAr.text.trim().isEmpty ? null : _descAr.text.trim(),
        image: _imageUrl,
        discountType: _discountType,
        discountValue: double.tryParse(_value.text.trim()),
        startDate: _start,
        endDate: _end,
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
      appBar: AppBar(title: const Text('إضافة عرض')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ImageUploadField(
            label: 'صورة العرض (اختياري)',
            url: _imageUrl,
            folder: 'promotions',
            height: 180,
            fallbackIcon: Icons.local_offer_outlined,
            onChanged: (url) => setState(() => _imageUrl = url),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleAr,
            decoration: const InputDecoration(
              labelText: 'عنوان العرض',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleEn,
            decoration: const InputDecoration(
              labelText: 'العنوان بالإنجليزية (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descAr,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'وصف العرض (اختياري)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _discountType,
                  decoration: const InputDecoration(
                    labelText: 'نوع الخصم',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'percent', child: Text('نسبة %')),
                    DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت ₪')),
                  ],
                  onChanged: (v) =>
                      setState(() => _discountType = v ?? 'percent'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _value,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'قيمة الخصم',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                    label: 'من', value: _fmt(_start), onTap: () => _pick(true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                    label: 'إلى', value: _fmt(_end), onTap: () => _pick(false)),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
                : const Text('نشر العرض'),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.event, size: 20),
        ),
        child: Text(value),
      ),
    );
  }
}
