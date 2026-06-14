import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';

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
  final _image = TextEditingController();
  final _vendorIdCtrl = TextEditingController();

  bool _isActive = true;
  bool _submitting = false;

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
      _image.text = e.image ?? '';
    }
    if (widget.vendorId != null) {
      _vendorIdCtrl.text = '${widget.vendorId}';
    } else if (e?.vendorId != null) {
      _vendorIdCtrl.text = '${e!.vendorId}';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameAr, _nameEn, _descAr, _descEn,
      _price, _discount, _duration, _image, _vendorIdCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final vid = widget.vendorId ??
        widget.existing?.vendorId ??
        int.tryParse(_vendorIdCtrl.text.trim());
    if (vid == null && !_editing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('معرّف المعلِن مطلوب')),
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
          image: _image.text.trim().isEmpty ? null : _image.text.trim(),
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
          image: _image.text.trim().isEmpty ? null : _image.text.trim(),
          isActive: _isActive,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
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
            if (widget.vendorId == null && !_editing) ...[
              TextFormField(
                controller: _vendorIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'معرّف المعلِن (vendor_id)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || int.tryParse(v.trim()) == null) ? 'مطلوب' : null,
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
            TextFormField(
              controller: _image,
              decoration: const InputDecoration(
                labelText: 'رابط الصورة',
                border: OutlineInputBorder(),
              ),
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
