import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';

const _planOptions = <({String value, String label})>[
  (value: 'normal', label: 'عادي'),
  (value: 'slider', label: 'سلايد'),
  (value: 'featured', label: 'شركة مميزة'),
];

const _statusOptions = <({String value, String label})>[
  (value: 'active', label: 'فعّال'),
  (value: 'pending', label: 'معلّق'),
  (value: 'expired', label: 'منتهٍ'),
  (value: 'cancelled', label: 'ملغى'),
];

String _planLabel(String v) => _planOptions
    .firstWhere((p) => p.value == v, orElse: () => (value: v, label: v))
    .label;
String _statusLabel(String v) => _statusOptions
    .firstWhere((p) => p.value == v, orElse: () => (value: v, label: v))
    .label;

/// Admin: searchable, lazily-paginated subscriptions list with a status
/// filter. Tap a row to edit / extend it or mark the commission as paid.
class AdminSubscriptionsPage extends StatefulWidget {
  const AdminSubscriptionsPage({super.key});

  @override
  State<AdminSubscriptionsPage> createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends State<AdminSubscriptionsPage> {
  final _service = SubscriptionService();
  final _scroll = ScrollController();
  final List<SubscriptionModel> _items = [];

  String? _status; // null = all
  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  bool _initialLoaded = false;
  String? _error;

  bool get _hasMore => _page < _lastPage;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadNext();
  }

  @override
  void dispose() {
    _scroll.dispose();
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
      final res = await _service.listPaged(status: _status, page: _page + 1);
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

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 0;
      _lastPage = 1;
      _initialLoaded = false;
    });
    await _loadNext();
  }

  void _setStatus(String? s) {
    setState(() => _status = s);
    _refresh();
  }

  Future<void> _edit(SubscriptionModel sub) async {
    final updated = await Navigator.push<SubscriptionModel>(
      context,
      MaterialPageRoute(
        builder: (_) => _SubscriptionEditPage(subscription: sub),
      ),
    );
    if (updated != null && mounted) {
      final i = _items.indexWhere((e) => e.id == updated.id);
      if (i >= 0) setState(() => _items[i] = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاشتراكات')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _statusChip('الكل', null),
                for (final s in _statusOptions) _statusChip(s.label, s.value),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String? value) {
    final selected = _status == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _setStatus(value),
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
      return const Center(child: Text('لا توجد اشتراكات'));
    }
    // Group the accumulated subscriptions by store (owner account) so each
    // store shows once with all its subscription cases. Grouping the full
    // accumulated list self-corrects as more pages load on scroll.
    final groups = <int, List<SubscriptionModel>>{};
    final order = <int>[];
    for (final s in _items) {
      final key = s.userId;
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(s);
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        itemCount: order.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= order.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _storeCard(groups[order[i]]!);
        },
      ),
    );
  }

  /// One card per store showing every subscription case it has.
  Widget _storeCard(List<SubscriptionModel> subs) {
    final name = subs.first.clientName.isNotEmpty
        ? subs.first.clientName
        : 'متجر #${subs.first.userId}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                Text('${subs.length} اشتراك',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            const Divider(height: 14),
            for (final s in subs) _caseRow(s),
          ],
        ),
      ),
    );
  }

  Widget _caseRow(SubscriptionModel s) {
    return InkWell(
      onTap: () => _edit(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_planLabel(s.planName)} • ${s.amountPaid.toStringAsFixed(0)}'
                    ' • تنتهي ${_fmt(s.endDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!s.commissionPaid && s.commissionAmount > 0)
                    const Text('عمولة غير مدفوعة',
                        style: TextStyle(color: Colors.orange, fontSize: 10.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_statusLabel(s.status),
                style: TextStyle(
                    color: s.isActive ? Colors.green : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
            const Icon(Icons.chevron_left, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Full-page editor for a single subscription.
class _SubscriptionEditPage extends StatefulWidget {
  const _SubscriptionEditPage({required this.subscription});
  final SubscriptionModel subscription;

  @override
  State<_SubscriptionEditPage> createState() => _SubscriptionEditPageState();
}

class _SubscriptionEditPageState extends State<_SubscriptionEditPage> {
  final _form = GlobalKey<FormState>();
  final _service = SubscriptionService();

  late final TextEditingController _amount;
  late final TextEditingController _commission;
  late String _plan;
  late String _status;
  late DateTime _start;
  late DateTime _end;
  late bool _commissionPaid;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.subscription;
    _amount = TextEditingController(text: s.amountPaid.toStringAsFixed(0));
    _commission =
        TextEditingController(text: s.commissionAmount.toStringAsFixed(0));
    _plan = s.planName;
    _status = s.status;
    _start = s.startDate;
    _end = s.endDate;
    _commissionPaid = s.commissionPaid;
  }

  @override
  void dispose() {
    _amount.dispose();
    _commission.dispose();
    super.dispose();
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _end = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await _service.update(widget.subscription.id, {
        'plan_name': _plan,
        'amount_paid': double.tryParse(_amount.text.trim()) ?? 0,
        'commission_amount': double.tryParse(_commission.text.trim()) ?? 0,
        'status': _status,
        'start_date': _date(_start),
        'end_date': _date(_end),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الاشتراك')),
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

  Future<void> _markPaid() async {
    setState(() => _saving = true);
    try {
      final updated =
          await _service.markCommissionPaid(widget.subscription.id);
      if (!mounted) return;
      setState(() => _commissionPaid = updated.commissionPaid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعليم العمولة كمدفوعة')),
      );
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
    final s = widget.subscription;
    return Scaffold(
      appBar: AppBar(title: Text('اشتراك: ${s.clientName}')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _plan,
              decoration: const InputDecoration(
                  labelText: 'نوع الاشتراك', border: OutlineInputBorder()),
              items: [
                for (final p in _planOptions)
                  DropdownMenuItem(value: p.value, child: Text(p.label)),
              ],
              onChanged: (v) => setState(() => _plan = v ?? _plan),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'المبلغ المدفوع', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _commission,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'عمولة المندوب', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                  labelText: 'الحالة', border: OutlineInputBorder()),
              items: [
                for (final st in _statusOptions)
                  DropdownMenuItem(value: st.value, child: Text(st.label)),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تاريخ الانتهاء (تمديد)'),
              subtitle: Text(_date(_end)),
              trailing: const Icon(Icons.event_available),
              onTap: _pickEnd,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('عمولة المندوب'),
              subtitle: Text(_commissionPaid ? 'مدفوعة' : 'غير مدفوعة',
                  style: TextStyle(
                      color: _commissionPaid ? Colors.green : Colors.orange)),
              trailing: _commissionPaid
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : TextButton(
                      onPressed: _saving ? null : _markPaid,
                      child: const Text('تعليم كمدفوعة'),
                    ),
            ),
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
}
