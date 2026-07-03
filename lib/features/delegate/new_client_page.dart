import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_client.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';
import '../subscriptions/subscription_plans.dart';

/// Subscription plans (نوع الاشتراك) — value sent to the API, label shown in UI.
const _planOptions = <({String value, String label})>[
  (value: 'normal', label: 'عادي'),
  (value: 'featured', label: 'مميز'),
  (value: 'vip', label: 'VIP'),
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
  final _total = TextEditingController(text: '${planByKey('normal').yearly}');
  final _amountPaid = TextEditingController();
  final _commission = TextEditingController();
  final _paymentMethod = TextEditingController(text: 'cash');
  final _notes = TextEditingController();
  final _shopName = TextEditingController();

  String _plan = 'normal';

  // Shop selection: 'new' (type a name) or 'existing' (pick an unowned shop).
  String _shopMode = 'new';
  AvailableShop? _selectedShop;

  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 365));
  bool _submitting = false;

  final _service = DelegateService();

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _email, _password, _workField,
      _total, _amountPaid, _commission, _paymentMethod, _notes, _shopName,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openShopPicker() async {
    final picked = await showModalBottomSheet<AvailableShop>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ShopPickerSheet(service: _service),
    );
    if (picked != null) setState(() => _selectedShop = picked);
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
        totalAmount: double.tryParse(_total.text.trim()),
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
                Text('السعر الكامل: ${res.subscription.totalAmount.toStringAsFixed(0)} شيكل'),
                Text('المدفوع: ${res.subscription.amountPaid.toStringAsFixed(0)} شيكل'),
                if (res.subscription.remaining > 0)
                  Text('المتبقّي: ${res.subscription.remaining.toStringAsFixed(0)} شيكل',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.red.shade700)),
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
      if (!mounted) return;
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

            _section('اختر الباقة'),
            SubscriptionPlansView(
              compact: true,
              selected: _plan,
              onSelected: (k) {
                setState(() {
                  _plan = k;
                  // Full price = the plan's yearly price (e.g. VIP = 600).
                  // Clear "paid now" so the delegate enters the actual first
                  // payment; the remaining balance is shown live below.
                  _total.text = '${planByKey(k).yearly}';
                  _amountPaid.clear();
                });
              },
            ),
            const SizedBox(height: 14),
            _section('بيانات الاشتراك'),
            Row(
              children: [
                Expanded(
                  child: _field(_total, 'السعر الكامل', required: true,
                      keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(_amountPaid, 'المدفوع الآن', required: true,
                      keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
                ),
              ],
            ),
            Builder(builder: (_) {
              final total = double.tryParse(_total.text.trim()) ?? 0;
              final paid = double.tryParse(_amountPaid.text.trim()) ?? 0;
              final rem = (total - paid) > 0 ? (total - paid) : 0;
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  rem > 0
                      ? 'المتبقّي: ${rem.toStringAsFixed(0)} شيكل'
                      : 'مدفوع بالكامل ✓',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: rem > 0 ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
              );
            }),
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

  Widget _shopModeSelector() => SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'new', label: Text('محل جديد'), icon: Icon(Icons.add_business)),
          ButtonSegment(value: 'existing', label: Text('محل موجود'), icon: Icon(Icons.store)),
        ],
        selected: {_shopMode},
        onSelectionChanged: (sel) {
          setState(() => _shopMode = sel.first);
        },
      );

  Widget _existingShopPicker() {
    final hasSelection = _selectedShop != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _openShopPicker,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'اختر المحل',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.search),
          ),
          child: Text(
            hasSelection ? _selectedShop!.name : 'اضغط للبحث واختيار محل',
            style: hasSelection
                ? null
                : TextStyle(color: Theme.of(context).hintColor),
          ),
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
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        onChanged: onChanged,
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

/// Searchable, lazily-paginated picker for unowned shops. Opens as a bottom
/// sheet: type to search (debounced) and scroll to load the next page.
class _ShopPickerSheet extends StatefulWidget {
  const _ShopPickerSheet({required this.service});
  final DelegateService service;

  @override
  State<_ShopPickerSheet> createState() => _ShopPickerSheetState();
}

class _ShopPickerSheetState extends State<_ShopPickerSheet> {
  final _scroll = ScrollController();
  final _searchCtl = TextEditingController();
  final List<AvailableShop> _items = [];

  String _search = '';
  int _page = 0; // last successfully loaded page (0 = none yet)
  int _lastPage = 1;
  bool _loading = false;
  bool _initialLoaded = false;
  String? _error;
  Timer? _debounce;

  bool get _hasMore => _page < _lastPage;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadNext();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    if (_loading || (_initialLoaded && !_hasMore)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.service.availableShops(
        search: _search,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _page = res.currentPage;
        _lastPage = res.lastPage;
        _initialLoaded = true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _search = v.trim();
        _items.clear();
        _page = 0;
        _lastPage = 1;
        _initialLoaded = false;
      });
      _loadNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: h * 0.85,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchCtl,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث عن محل بالاسم',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchCtl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtl.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _loadNext, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    if (!_initialLoaded && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('لا توجد محلات متاحة'));
    }
    return ListView.separated(
      controller: _scroll,
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final s = _items[i];
        return ListTile(
          leading: const Icon(Icons.store),
          title: Text(s.name),
          onTap: () => Navigator.pop(context, s),
        );
      },
    );
  }
}
