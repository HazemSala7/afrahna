import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key, this.vendorId});
  final int? vendorId;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _mediaUrl = TextEditingController();
  final _thumbnail = TextEditingController();
  final _price = TextEditingController();
  final _duration = TextEditingController();
  final _vendorIdCtrl = TextEditingController();

  PostType _type = PostType.post;
  bool _submitting = false;

  final _service = PostService();

  @override
  void initState() {
    super.initState();
    if (widget.vendorId != null) _vendorIdCtrl.text = '${widget.vendorId}';
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _mediaUrl, _thumbnail, _price, _duration, _vendorIdCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final vid = widget.vendorId ?? int.tryParse(_vendorIdCtrl.text.trim());
    if (vid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('معرّف المعلِن مطلوب')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.create(
        vendorId: vid,
        type: _type,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        body: _body.text.trim().isEmpty ? null : _body.text.trim(),
        mediaUrl: _mediaUrl.text.trim().isEmpty ? null : _mediaUrl.text.trim(),
        thumbnail: _thumbnail.text.trim().isEmpty ? null : _thumbnail.text.trim(),
        price: _type == PostType.course ? double.tryParse(_price.text.trim()) : null,
        duration: _type == PostType.course
            ? (_duration.text.trim().isEmpty ? null : _duration.text.trim())
            : null,
      );
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
      appBar: AppBar(title: const Text('إنشاء محتوى جديد')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<PostType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'النوع',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: PostType.post,   child: Text('منشور')),
                DropdownMenuItem(value: PostType.reel,   child: Text('ريلز (فيديو قصير)')),
                DropdownMenuItem(value: PostType.course, child: Text('دورة')),
              ],
              onChanged: (v) => setState(() => _type = v ?? PostType.post),
            ),
            if (widget.vendorId == null) ...[
              const SizedBox(height: 12),
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
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _body,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'المحتوى / الوصف',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mediaUrl,
              decoration: const InputDecoration(
                labelText: 'رابط الوسائط (صورة/فيديو)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _thumbnail,
              decoration: const InputDecoration(
                labelText: 'رابط الصورة المصغّرة',
                border: OutlineInputBorder(),
              ),
            ),
            if (_type == PostType.course) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'سعر الدورة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _duration,
                decoration: const InputDecoration(
                  labelText: 'مدة الدورة (مثل: 3 ساعات)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
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
                  : const Text('نشر'),
            ),
          ],
        ),
      ),
    );
  }
}
