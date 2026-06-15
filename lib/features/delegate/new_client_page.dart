import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_client.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';

/// Subscription plans (نوع الاشتراك) — value sent to the API, label shown in UI.
const _planOptions = <({String value, String label})>[
  (value: 'normal', label: 'عادي'),
  (value: 'slider', label: 'سلايد'),
  (value: 'featured', label: 'شركة مميزة'),
];

class NewClientPage extends StatefulWidget {
  const NewClientPage({super.key});

  @override
  State<NewClientPage> createState() => _NewClientPageState();
}

class _NewClientPageState extends State<NewClientPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _workField = TextEditingController();
  final _amountPaid = TextEditingController(text: '0');
  final _commission = TextEditingController();
  final _paymentMethod = TextEditingController(text: 'cash');
  final _notes = TextEditingController();
  final _shopName = TextEditingController();

  String _plan = 'normal';

  // Shop selection: 'new' (type a name) or 'existing' (pick an unowned shop).
  String _shopMode = 'new';
  AvailableShop? _selectedShop;
  List<AvailableShop> _shops = const [];
  bool _loadingShops = false;
  String? _shopsError;

  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 365));
  bool _submitting = false;

  final _service = DelegateService();

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _email, _password, _workField,
      _amountPaid, _commission, _paymentMethod, _notes, _shopName,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadShops() async {
    setState(() {
      _loadingShops = true;
      _shopsError = null;
    });
    try {
      final shops = await _service.availableShops();
      if (!mounted) return;
      setState(() {
        _shops = shops;
        if (_selectedShop != null &&
            !shops.any((s) => s.id == _selectedShop!.id)) {
          _selectedShop = null;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _shopsError = e.message);
    } finally {
      if (mounted) setState(() => _loadingShops = false);
    }
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _start = d);
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _end = d);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_shopMode == 'existing' && _selectedShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار محل من القائمة')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await _service.registerClient(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        password: _password.text.trim().isEmpty ? null : _password.text.trim(),
        workField: _workField.text.trim().isEmpty ? null : _workField.text.trim(),
        planName: _plan,
        amountPaid: double.tryParse(_amountPaid.text.trim()) ?? 0,
        commissionAmount: _commission.text.trim().isEmpty
            ? null
            : double.tryParse(_commission.text.trim()),
        paymentMethod: _paymentMethod.text.trim().isEmpty
            ? null
            : _paymentMethod.text.trim(),
        startDate: _start,
        endDate: _end,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        shopMode: _shopMode,
        shopName: _shopMode == 'new' ? _shopName.text.trim() : null,
        vendorId: _shopMode == 'existing' ? _selectedShop?.id : null,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم تسجيل المعلن ✅'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الاسم: ${res.client.name}'),
                Text('الهاتف: ${res.client.phone}'),
                const SizedBox(height: 12),
                const Text('بيانات تسجيل الدخول التي يجب تسليمها للمعلن:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: SelectableText('كلمة المرور: ${res.temporaryPassword}')),
                    IconButton(
                      tooltip: 'نسخ',
                      icon: const Icon(Icons.copy),
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: res.temporaryPassword)),
                    ),
                  ],
                ),
                const Divider(),
                Text('نوع الاشتراك: ${_planLabel(res.subscription.planName)}'),
                Text('المبلغ المدفوع: ${res.subscription.amountPaid}'),
                Text('عمولتك: ${res.subscription.commissionAmount}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تم'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _planLabel(String value) =>
      _planOptions.firstWhere((p) => p.value == value,
          orElse: () => (value: value, label: value)).label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة معلن')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('بيانات المعلن'),
            _field(_name, 'اسم المعلن', required: true),
            _field(_phone, 'رقم الجوال', required: true, keyboard: TextInputType.phone),
            _field(_email, 'البريد الإلكتروني (اختياري)', keyboard: TextInputType.emailAddress),
            _field(_password, 'كلمة السر (اختياري — تُولَّد تلقائياً)'),
            _field(_workField, 'مجال العمل (اختياري)'),
            const SizedBox(height: 16),

            _section('المحل'),
            _shopModeSelector(),
            const SizedBox(height: 8),
            if (_shopMode == 'new')
              _field(_shopName, 'اسم المحل', required: true)
            else
              _existingShopPicker(),
            const SizedBox(height: 16),

            _section('بيانات الاشتراك'),
            _planSelector(),
            _field(_amountPaid, 'المبلغ المدفوع', required: true, keyboard: TextInputType.number),
            _field(_commission, 'عمولة المندوب (افتراضي = إعدادات حسابك)', keyboard: TextInputType.number),
            _field(_paymentMethod, 'طريقة الدفع (cash/transfer/...)'),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('تاريخ الاشتراك'),
                    subtitle: Text(_fmt(_start)),
                    trailing: const Icon(Icons.event),
                    onTap: _pickStart,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('تاريخ الانتهاء'),
                    subtitle: Text(_fmt(_end)),
                    trailing: const Icon(Icons.event_available),
                    onTap: _pickEnd,
                  ),
                ),
              ],
            ),
            _field(_notes, 'ملاحظات', maxLines: 3),
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
                  : const Text('إنشاء الحساب والاشتراك'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );

  Widget _planSelector() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          initialValue: _plan,
          decoration: const InputDecoration(
            labelText: 'نوع الاشتراك',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final p in _planOptions)
              DropdownMenuItem(value: p.value, child: Text(p.label)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _plan = v);
          },
        ),
      );

  Widget _shopModeSelector() => SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'new', label: Text('محل جديد'), icon: Icon(Icons.add_business)),
          ButtonSegment(value: 'existing', label: Text('محل موجود'), icon: Icon(Icons.store)),
        ],
        selected: {_shopMode},
        onSelectionChanged: (sel) {
          final mode = sel.first;
          setState(() => _shopMode = mode);
          if (mode == 'existing' && _shops.isEmpty && !_loadingShops) {
            _loadShops();
          }
        },
      );

  Widget _existingShopPicker() {
    if (_loadingShops) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_shopsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(_shopsError!, style: const TextStyle(color: Colors.red))),
            TextButton(onPressed: _loadShops, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    if (_shops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Expanded(child: Text('لا توجد محلات متاحة بدون حساب.')),
            TextButton(onPressed: _loadShops, child: const Text('تحديث')),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<AvailableShop>(
        initialValue: _selectedShop,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'اختر المحل',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final s in _shops)
            DropdownMenuItem(value: s, child: Text(s.name)),
        ],
        onChanged: (v) => setState(() => _selectedShop = v),
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
