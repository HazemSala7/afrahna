import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';

/// Granular delegate permission keys (mirrors the backend `User` constants),
/// paired with an Arabic label for the admin toggle list.
const _delegatePermissions = <({String key, String label})>[
  (key: 'edit_vendor', label: 'تعديل بيانات المعلن'),
  (key: 'manage_services', label: 'إدارة الخدمات'),
  (key: 'manage_promotions', label: 'إدارة العروض'),
  (key: 'view_bookings', label: 'عرض الحجوزات'),
  (key: 'toggle_vendor_active', label: 'تفعيل/إيقاف المعلن'),
  (key: 'create_subscription', label: 'إنشاء اشتراك'),
];

/// Admin: edit a single user account (any role). Returns the updated
/// [UserModel] via `Navigator.pop` on success.
class AdminUserEditPage extends StatefulWidget {
  const AdminUserEditPage({super.key, required this.user});
  final UserModel user;

  @override
  State<AdminUserEditPage> createState() => _AdminUserEditPageState();
}

class _AdminUserEditPageState extends State<AdminUserEditPage> {
  final _form = GlobalKey<FormState>();
  final _service = AdminUserService();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _workField;
  late final TextEditingController _notes;
  late final TextEditingController _commission;
  final _password = TextEditingController();

  late bool _isActive;
  late Map<String, bool> _perms;
  bool _saving = false;

  bool get _isDelegate => widget.user.role == 'delegate';

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _name = TextEditingController(text: u.name);
    _phone = TextEditingController(text: u.phone);
    _email = TextEditingController(text: u.email ?? '');
    _workField = TextEditingController(text: u.workField ?? '');
    _notes = TextEditingController(text: '');
    _commission = TextEditingController(
      text: u.commissionPerSubscription?.toString() ?? '',
    );
    _isActive = u.isActive;
    _perms = {
      for (final p in _delegatePermissions)
        p.key: u.permissions[p.key] == true ||
            u.permissions[p.key] == 1 ||
            u.permissions[p.key] == '1',
    };
  }

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _email, _workField, _notes, _commission, _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'is_active': _isActive,
        'work_field':
            _workField.text.trim().isEmpty ? null : _workField.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (_password.text.trim().isNotEmpty) 'password': _password.text.trim(),
      };
      if (_isDelegate) {
        data['commission_per_subscription'] =
            double.tryParse(_commission.text.trim()) ?? 0;
        data['permissions'] = _perms;
      }

      final updated = await _service.update(widget.user.id, data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التعديلات')),
      );
      Navigator.pop(context, updated);
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
      appBar: AppBar(title: Text('تعديل: ${widget.user.name}')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, 'الاسم', required: true),
            _field(_phone, 'رقم الجوال',
                required: true, keyboard: TextInputType.phone),
            _field(_email, 'البريد الإلكتروني (اختياري)',
                keyboard: TextInputType.emailAddress),
            _field(_password, 'كلمة مرور جديدة (اتركها فارغة للإبقاء)'),
            _field(_workField, 'مجال العمل (اختياري)'),
            if (_isDelegate)
              _field(_commission, 'عمولة الاشتراك الافتراضية',
                  keyboard: TextInputType.number),
            _field(_notes, 'ملاحظات (تُضاف)', maxLines: 2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('الحساب مفعّل'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (_isDelegate) ...[
              const SizedBox(height: 8),
              const Text('صلاحيات المندوب',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              for (final p in _delegatePermissions)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.label),
                  value: _perms[p.key] ?? false,
                  onChanged: (v) =>
                      setState(() => _perms[p.key] = v ?? false),
                ),
            ],
            const SizedBox(height: 20),
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
                  : const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (!required) return null;
          return (v == null || v.trim().isEmpty) ? 'حقل مطلوب' : null;
        },
      ),
    );
  }
}
