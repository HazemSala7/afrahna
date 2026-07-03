import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/image_upload_field.dart';

class CreateServicePage extends StatefulWidget {
  const CreateServicePage({super.key, this.vendorId, this.existing});

  final int? vendorId;
  final ServiceModel? existing;

  @override
  State<CreateServicePage> createState() => _CreateServicePageState();
}

class _CreateServicePageState extends State<CreateServicePage> {
  final _form = GlobalKey<FormState>();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _descAr = TextEditingController();
  final _descEn = TextEditingController();
  final _price = TextEditingController();
  final _discount = TextEditingController();
  final _duration = TextEditingController();

  /// Public URL of the chosen service image (uploaded via [ImageUploadField]).
  String? _imageUrl;

  bool _isActive = true;
  bool _submitting = false;

  /// The vendor this service belongs to. Resolved automatically for the
  /// logged-in vendor owner so they never type a numeric id by hand.
  int? _resolvedVendorId;
  bool _loadingVendor = false;

  final _service = ServiceService();

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameAr.text = e.titleAr;
      _nameEn.text = e.titleEn;
      _descAr.text = e.descriptionAr ?? '';
      _descEn.text = e.descriptionEn ?? '';
      _price.text = e.price?.toString() ?? '';
      _discount.text = e.discountPrice?.toString() ?? '';
      _imageUrl = e.image;
    }
    _resolvedVendorId = widget.vendorId ?? e?.vendorId;
    // Logged-in owner creating a service for their own shop: fetch their
    // vendor id from the API instead of asking them to type it.
    if (_resolvedVendorId == null && !_editing) {
      _loadMyVendor();
    }
  }

  Future<void> _loadMyVendor() async {
    setState(() => _loadingVendor = true);
    try {
      final v = await VendorService().mine();
      if (!mounted) return;
      setState(() => _resolvedVendorId = v.id);
    } on ApiException {
      // Leave it null; _submit will surface a clear message if needed.
    } finally {
      if (mounted) setState(() => _loadingVendor = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameAr, _nameEn, _descAr, _descEn,
      _price, _discount, _duration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final vid = _resolvedVendorId;
    if (vid == null && !_editing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تحديد المتجر. تأكد من تسجيل الدخول كصاحب متجر.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_editing) {
        await _service.update(
          widget.existing!.id,
          nameAr: _nameAr.text.trim(),
          nameEn: _nameEn.text.trim(),
          descriptionAr: _descAr.text.trim().isEmpty ? null : _descAr.text.trim(),
          descriptionEn: _descEn.text.trim().isEmpty ? null : _descEn.text.trim(),
          price: double.tryParse(_price.text.trim()),
          discountPrice:
              _discount.text.trim().isEmpty ? null : double.tryParse(_discount.text.trim()),
          duration: _duration.text.trim().isEmpty ? null : _duration.text.trim(),
          image: (_imageUrl != null && _imageUrl!.isNotEmpty) ? _imageUrl : null,
          isActive: _isActive,
        );
      } else {
        await _service.create(
          vendorId: vid!,
          nameAr: _nameAr.text.trim(),
          nameEn: _nameEn.text.trim(),
          price: double.tryParse(_price.text.trim()) ?? 0,
          descriptionAr: _descAr.text.trim().isEmpty ? null : _descAr.text.trim(),
          descriptionEn: _descEn.text.trim().isEmpty ? null : _descEn.text.trim(),
          discountPrice:
              _discount.text.trim().isEmpty ? null : double.tryParse(_discount.text.trim()),
          duration: _duration.text.trim().isEmpty ? null : _duration.text.trim(),
          image: (_imageUrl != null && _imageUrl!.isNotEmpty) ? _imageUrl : null,
          isActive: _isActive,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'تعديل خدمة' : 'إنشاء خدمة جديدة')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loadingVendor) ...[
              const Row(
                children: [
                  SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('جارٍ تحميل بيانات متجرك...'),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nameAr,
              decoration: const InputDecoration(
                labelText: 'اسم الخدمة بالعربية',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameEn,
              decoration: const InputDecoration(
                labelText: 'اسم الخدمة بالإنجليزية',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descAr,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'الوصف بالعربية',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descEn,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'الوصف بالإنجليزية',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || double.tryParse(v.trim()) == null) ? 'سعر صحيح مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _discount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'سعر بعد الخصم (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _duration,
              decoration: const InputDecoration(
                labelText: 'المدة (مثل: ساعتين)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ImageUploadField(
              label: 'صورة الخدمة',
              url: _imageUrl,
              folder: 'services',
              fallbackIcon: Icons.design_services_outlined,
              onChanged: (url) => setState(() => _imageUrl = url),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('مفعّلة'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_editing ? 'حفظ التعديلات' : 'إنشاء الخدمة'),
            ),
          ],
        ),
      ),
    );
  }
}
