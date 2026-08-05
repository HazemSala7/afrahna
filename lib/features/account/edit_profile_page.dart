import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/image_upload_field.dart';

/// Lets a signed-in user edit their OWN profile: photo, name, phone, email and
/// social handles. Until this screen existed the only way to change any of it
/// was through the admin panel.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _whatsapp;
  late final TextEditingController _instagram;
  late final TextEditingController _facebook;
  late final TextEditingController _tiktok;
  late final TextEditingController _snapchat;

  String? _avatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<SessionController>().user;
    _name = TextEditingController(text: u?.name ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _whatsapp = TextEditingController(text: u?.whatsapp ?? '');
    _instagram = TextEditingController(text: u?.instagram ?? '');
    _facebook = TextEditingController(text: u?.facebook ?? '');
    _tiktok = TextEditingController(text: u?.tiktok ?? '');
    _snapchat = TextEditingController(text: u?.snapchat ?? '');
    _avatar = u?.avatar;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _email, _whatsapp,
      _instagram, _facebook, _tiktok, _snapchat,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await AuthService().updateProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        // Empty strings clear the optional fields server-side.
        email: _email.text.trim(),
        avatar: _avatar ?? '',
        whatsapp: _whatsapp.text.trim(),
        instagram: _instagram.text.trim(),
        facebook: _facebook.text.trim(),
        tiktok: _tiktok.text.trim(),
        snapchat: _snapchat.text.trim(),
      );
      if (!mounted) return;
      context.read<SessionController>().setUser(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التعديلات ✓')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const PinkAppBar(title: 'تعديل الملف الشخصي'),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
          children: [
            _AvatarPicker(
              url: _avatar,
              onChanged: (v) => setState(() => _avatar = v),
            ),
            const SizedBox(height: 22),

            const _GroupLabel('المعلومات الأساسية'),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                children: [
                  _field(
                    controller: _name,
                    label: 'اسم المستخدم',
                    icon: Icons.person_rounded,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'الاسم قصير جدًا'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _phone,
                    label: 'رقم الجوال',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    ],
                    // The phone is also the login username.
                    helper: 'يُستخدم لتسجيل الدخول',
                    validator: (v) => (v == null || v.trim().length < 6)
                        ? 'أدخل رقم جوال صحيح'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _email,
                    label: 'البريد الإلكتروني (اختياري)',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      return t.contains('@') ? null : 'بريد غير صحيح';
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            const _GroupLabel('وسائل التواصل'),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                children: [
                  _field(
                    controller: _whatsapp,
                    label: 'واتساب',
                    icon: Icons.chat_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _instagram,
                    label: 'إنستغرام',
                    icon: Icons.camera_alt_rounded,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _facebook,
                    label: 'فيسبوك',
                    icon: Icons.facebook_rounded,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _tiktok,
                    label: 'تيك توك',
                    icon: Icons.music_note_rounded,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _snapchat,
                    label: 'سناب شات',
                    icon: Icons.photo_camera_front_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('حفظ التعديلات',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? helper,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.url, required this.onChanged});

  final String? url;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        child: ImageUploadField(
          label: 'صورة البروفايل',
          url: url,
          folder: 'users/avatars',
          fallbackIcon: Icons.person_rounded,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
