import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';
import '../../widgets/image_upload_field.dart';

/// Facebook-style post composer for a vendor: free text + multiple images.
class CreateVendorPostPage extends StatefulWidget {
  const CreateVendorPostPage({super.key, required this.vendorId});
  final int vendorId;

  @override
  State<CreateVendorPostPage> createState() => _CreateVendorPostPageState();
}

class _CreateVendorPostPageState extends State<CreateVendorPostPage> {
  final _service = PostService();
  final _body = TextEditingController();
  List<String> _images = const [];
  bool _saving = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final text = _body.text.trim();
    if (text.isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب شيئًا أو أضف صورة')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.create(
        vendorId: widget.vendorId,
        type: PostType.post,
        body: text.isEmpty ? null : text,
        images: _images.isEmpty ? null : _images,
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
      appBar: AppBar(
        title: const Text('منشور جديد'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _saving ? null : _publish,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('نشر'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _body,
            maxLines: 6,
            minLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'بماذا تفكّر؟ اكتب منشورك هنا...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          MultiImageUploadField(
            label: 'صور المنشور (اختياري)',
            urls: _images,
            folder: 'posts',
            fallbackIcon: Icons.image_outlined,
            onChanged: (v) => setState(() => _images = v),
          ),
        ],
      ),
    );
  }
}
