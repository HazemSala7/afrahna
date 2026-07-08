import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/image_upload_field.dart';
import '../../widgets/map_picker_page.dart';

/// Lets the vendor owner edit their public profile (the same fields shown
/// in the admin panel vendor form).
class EditVendorPage extends StatefulWidget {
  const EditVendorPage({super.key, required this.vendor});
  final VendorModel vendor;

  @override
  State<EditVendorPage> createState() => _EditVendorPageState();
}

class _EditVendorPageState extends State<EditVendorPage> {
  final _form = GlobalKey<FormState>();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _descAr = TextEditingController();
  final _descEn = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _whatsapp = TextEditingController();
  final _instagram = TextEditingController();
  final _tiktok = TextEditingController();
  final _snapchat = TextEditingController();
  final _facebook = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  final _minPrice = TextEditingController();
  final _maxPrice = TextEditingController();

  String? _logoUrl;
  String? _coverUrl;
  double? _latitude;
  double? _longitude;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vendor;
    _nameAr.text = v.nameAr;
    _nameEn.text = v.nameEn;
    _descAr.text = v.descriptionAr ?? '';
    _descEn.text = v.descriptionEn ?? '';
    _phone.text = v.phone ?? '';
    _whatsapp.text = v.whatsapp ?? '';
    _instagram.text = v.instagram ?? '';
    _tiktok.text = v.tiktok ?? '';
    _snapchat.text = v.snapchat ?? '';
    _facebook.text = v.facebook ?? '';
    _website.text = v.website ?? '';
    _address.text = v.address ?? '';
    _minPrice.text = v.minPrice?.toString() ?? '';
    _maxPrice.text = v.maxPrice?.toString() ?? '';
    _logoUrl = v.logo;
    _coverUrl = v.cover;
    _latitude = v.latitude;
    _longitude = v.longitude;
  }

  @override
  void dispose() {
    for (final c in [
      _nameAr, _nameEn, _descAr, _descEn, _phone, _email,
      _whatsapp, _instagram, _tiktok, _snapchat, _facebook, _website,
      _address, _minPrice, _maxPrice,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _trim(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  /// Admin action: reset the advertiser (owner) account's password.
  Future<void> _changeOwnerPassword() async {
    final ownerId = widget.vendor.ownerId;
    if (ownerId == null) return;
    final newPass = await showDialog<String>(
      context: context,
      builder: (_) => const _OwnerPasswordDialog(),
    );
    if (newPass == null || newPass.isEmpty || !mounted) return;
    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور قصيرة (6 أحرف على الأقل)')),
      );
      return;
    }
    try {
      await AdminUserService().update(ownerId, {'password': newPass});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة مرور المعلن ✓')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'name_ar': _nameAr.text.trim(),
        'name_en': _nameEn.text.trim(),
        if (_trim(_descAr) != null) 'description_ar': _trim(_descAr),
        if (_trim(_descEn) != null) 'description_en': _trim(_descEn),
        if (_trim(_phone) != null) 'phone': _trim(_phone),
        if (_trim(_email) != null) 'email': _trim(_email),
        if (_trim(_whatsapp) != null) 'whatsapp': _trim(_whatsapp),
        if (_trim(_instagram) != null) 'instagram': _trim(_instagram),
        if (_trim(_tiktok) != null) 'tiktok': _trim(_tiktok),
        if (_trim(_snapchat) != null) 'snapchat': _trim(_snapchat),
        if (_trim(_facebook) != null) 'facebook': _trim(_facebook),
        if (_trim(_website) != null) 'website': _trim(_website),
        if (_trim(_address) != null) 'address': _trim(_address),
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
        if (_trim(_minPrice) != null) 'min_price': double.tryParse(_minPrice.text.trim()),
        if (_trim(_maxPrice) != null) 'max_price': double.tryParse(_maxPrice.text.trim()),
        if (_logoUrl != null && _logoUrl!.isNotEmpty) 'logo': _logoUrl,
        if (_coverUrl != null && _coverUrl!.isNotEmpty) 'cover_image': _coverUrl,
      };
      await VendorService().update(widget.vendor.id, data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التعديلات')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickLocation() async {
    final LatLng? result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          initial: (_latitude != null && _longitude != null)
              ? LatLng(_latitude!, _longitude!)
              : null,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
    });
  }

  Widget _locationField() {
    final hasLoc = _latitude != null && _longitude != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الموقع على الخريطة',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            icon: const Icon(Icons.map_outlined),
            label: Text(hasLoc ? 'تغيير الموقع' : 'تحديد الموقع على الخريطة'),
            onPressed: _pickLocation,
          ),
          if (hasLoc)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'الإحداثيات: ${_latitude!.toStringAsFixed(6)}, '
                '${_longitude!.toStringAsFixed(6)}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? type, int maxLines = 1, String? hint, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل بيانات المعلن')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Owner account card — only present for admin-loaded vendors
            // (the owner details are eager-loaded for admins only). Lets the
            // admin see the login username and reset the advertiser's password.
            if (widget.vendor.ownerId != null &&
                (widget.vendor.ownerPhone ?? '').isNotEmpty)
              _OwnerAccountCard(
                name: widget.vendor.ownerName ?? '—',
                phone: widget.vendor.ownerPhone!,
                onChangePassword: _changeOwnerPassword,
              ),
            _field(_nameAr, 'الاسم بالعربية', required: true),
            _field(_nameEn, 'الاسم بالإنجليزية', required: true),
            _field(_descAr, 'الوصف بالعربية', maxLines: 3),
            _field(_descEn, 'الوصف بالإنجليزية', maxLines: 3),
            const Divider(height: 24),
            _field(_phone, 'الهاتف', type: TextInputType.phone),
            _field(_email, 'البريد الإلكتروني', type: TextInputType.emailAddress),
            _field(_whatsapp, 'واتساب (رقم دولي)', type: TextInputType.phone, hint: '+970599...'),
            _field(_instagram, 'إنستغرام (المستخدم أو الرابط)', hint: '@afrahna'),
            _field(_tiktok, 'تيك توك (المستخدم أو الرابط)', hint: '@afrahna'),
            _field(_snapchat, 'سناب شات (المستخدم أو الرابط)', hint: 'afrahna'),
            _field(_facebook, 'فيسبوك (المستخدم أو الرابط)', hint: 'afrahna'),
            _field(_website, 'الموقع الإلكتروني', type: TextInputType.url),
            const Divider(height: 24),
            _field(_address, 'العنوان'),
            _locationField(),
            _field(_minPrice, 'أقل سعر', type: TextInputType.number),
            _field(_maxPrice, 'أعلى سعر', type: TextInputType.number),
            const Divider(height: 24),
            ImageUploadField(
              label: 'الشعار',
              url: _logoUrl,
              folder: 'vendors/logos',
              height: 120,
              fallbackIcon: Icons.storefront_outlined,
              onChanged: (url) => setState(() => _logoUrl = url),
            ),
            ImageUploadField(
              label: 'صورة الغلاف',
              url: _coverUrl,
              folder: 'vendors/covers',
              fallbackIcon: Icons.image_outlined,
              onChanged: (url) => setState(() => _coverUrl = url),
            ),
            const SizedBox(height: 12),
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
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to enter a new password for the owner account. Owns its own
/// controller so it's disposed with the dialog (not synchronously right after
/// pop, which crashes the still-animating TextField).
class _OwnerPasswordDialog extends StatefulWidget {
  const _OwnerPasswordDialog();

  @override
  State<_OwnerPasswordDialog> createState() => _OwnerPasswordDialogState();
}

class _OwnerPasswordDialogState extends State<_OwnerPasswordDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تغيير كلمة مرور المعلن'),
      content: TextField(
        controller: _ctrl,
        obscureText: _obscure,
        autofocus: false,
        decoration: InputDecoration(
          labelText: 'كلمة المرور الجديدة',
          hintText: '6 أحرف على الأقل',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(_obscure
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
            child: const Text('حفظ')),
      ],
    );
  }
}

/// Admin-only card at the top of the shop-edit screen showing the owner
/// (advertiser) account: their name and login username (phone), plus a button
/// to reset their password.
class _OwnerAccountCard extends StatelessWidget {
  const _OwnerAccountCard({
    required this.name,
    required this.phone,
    required this.onChangePassword,
  });
  final String name;
  final String phone;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.manage_accounts_rounded,
                  color: AppColors.primaryDark, size: 20),
              const SizedBox(width: 6),
              const Text('حساب المعلن المالك',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark)),
            ],
          ),
          const SizedBox(height: 8),
          _row('الاسم', name),
          const SizedBox(height: 4),
          _row('اسم المستخدم (الهاتف)', phone),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onChangePassword,
              icon: const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('تغيير كلمة مرور المعلن'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12.5)),
          Expanded(
            child: Text(value,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13.5)),
          ),
        ],
      );
}
