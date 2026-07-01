import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';
import '../subscriptions/subscription_plans.dart';

/// Subscription plans (value sent to API, label shown to the delegate).
const _planOptions = <({String value, String label})>[
  (value: 'normal', label: 'عادي'),
  (value: 'featured', label: 'مميز'),
  (value: 'vip', label: 'VIP'),
];

String planLabel(String value) => _planOptions
    .firstWhere((p) => p.value == value, orElse: () => (value: value, label: value))
    .label;

/// Lets a delegate manage a client's subscriptions: see current ones and
/// add / renew / change the plan type and duration smoothly.
class ManageClientSubscriptionPage extends StatefulWidget {
  const ManageClientSubscriptionPage({super.key, required this.client});
  final UserModel client;

  @override
  State<ManageClientSubscriptionPage> createState() =>
      _ManageClientSubscriptionPageState();
}

class _ManageClientSubscriptionPageState
    extends State<ManageClientSubscriptionPage> {
  final _service = DelegateService();
  late Future<List<SubscriptionModel>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _service.clientSubscriptions(widget.client.id);
  }

  Future<void> _addOrEdit({SubscriptionModel? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubscriptionFormSheet(
        clientId: widget.client.id,
        service: _service,
        existing: existing,
      ),
    );
    if (saved == true && mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null
            ? 'تم إنشاء الاشتراك'
            : 'تم تحديث الاشتراك')),
      );
    }
  }

  Future<void> _delete(SubscriptionModel sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الاشتراك'),
        content: Text('هل تريد حذف اشتراك (${planLabel(sub.planName)})؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteSubscription(sub.id);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف الاشتراك')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _addPayment(SubscriptionModel sub) async {
    final result = await showDialog<({double amount, String notes})>(
      context: context,
      builder: (_) => _AddPaymentDialog(remaining: sub.remaining),
    );
    if (result == null || result.amount <= 0) return;
    try {
      await _service.addPayment(sub.id,
          amount: result.amount, notes: result.notes);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تمت إضافة الدفعة')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('اشتراكات: ${widget.client.name}')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('اشتراك / تجديد'),
        onPressed: () => _addOrEdit(),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: FutureBuilder<List<SubscriptionModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              final e = snap.error;
              return ListView(children: [
                const SizedBox(height: 80),
                Center(child: Text(e is ApiException ? e.message : e.toString())),
              ]);
            }
            final subs = snap.data ?? const [];
            if (subs.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Icon(Icons.card_membership_outlined,
                    size: 56, color: AppColors.primary),
                SizedBox(height: 10),
                Center(child: Text('لا توجد اشتراكات بعد')),
                SizedBox(height: 6),
                Center(
                  child: Text('اضغط "اشتراك / تجديد" لإضافة أول اشتراك',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: subs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _SubscriptionCard(
                sub: subs[i],
                onEdit: () => _addOrEdit(existing: subs[i]),
                onDelete: () => _delete(subs[i]),
                onAddPayment: () => _addPayment(subs[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.sub,
    required this.onEdit,
    required this.onDelete,
    required this.onAddPayment,
  });
  final SubscriptionModel sub;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddPayment;

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _active {
    final now = DateTime.now();
    return sub.status == 'active' &&
        !now.isBefore(sub.startDate) &&
        !now.isAfter(sub.endDate.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = sub.endDate.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  planLabel(sub.planName),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _active
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _active ? 'فعّال' : 'منتهٍ',
                  style: TextStyle(
                    color: _active ? Colors.green.shade700 : Colors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit, color: AppColors.primary),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row(Icons.event, 'من ${_fmt(sub.startDate)} إلى ${_fmt(sub.endDate)}'),
          if (_active && daysLeft >= 0)
            _row(Icons.timelapse, 'متبقّي $daysLeft يوم'),
          _row(Icons.sell_outlined,
              'السعر: ${sub.totalAmount.toStringAsFixed(0)} • المدفوع: ${sub.amountPaid.toStringAsFixed(0)} • عمولتك: ${sub.commissionAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sub.remaining > 0
                      ? Colors.red.withValues(alpha: 0.12)
                      : Colors.green.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  sub.remaining > 0
                      ? 'متبقّي: ${sub.remaining.toStringAsFixed(0)} شيكل'
                      : 'مدفوع بالكامل ✓',
                  style: TextStyle(
                    color: sub.remaining > 0
                        ? Colors.red
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const Spacer(),
              if (sub.remaining > 0)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onAddPayment,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة دفعة'),
                ),
            ],
          ),
          if (sub.payments.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            const Text('الدفعات:',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.textMuted)),
            for (final p in sub.payments)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 13, color: Colors.green),
                    const SizedBox(width: 5),
                    Text('${p.amount.toStringAsFixed(0)} شيكل',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                    if (p.paidAt != null) ...[
                      const SizedBox(width: 6),
                      Text(_fmt(p.paidAt!),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                    if ((p.notes ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('• ${p.notes}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppColors.textDark, fontSize: 12.5)),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// ADD / EDIT SUBSCRIPTION FORM
// ---------------------------------------------------------------------------

class _SubscriptionFormSheet extends StatefulWidget {
  const _SubscriptionFormSheet({
    required this.clientId,
    required this.service,
    this.existing,
  });
  final int clientId;
  final DelegateService service;
  final SubscriptionModel? existing;

  @override
  State<_SubscriptionFormSheet> createState() => _SubscriptionFormSheetState();
}

class _SubscriptionFormSheetState extends State<_SubscriptionFormSheet> {
  late String _plan;
  late DateTime _start;
  late DateTime _end;
  late final TextEditingController _total;
  late final TextEditingController _amount;
  late final TextEditingController _commission;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  /// Quick duration presets (label, number of months).
  static const _durations = <({String label, int months})>[
    (label: 'شهر', months: 1),
    (label: '3 أشهر', months: 3),
    (label: '6 أشهر', months: 6),
    (label: 'سنة', months: 12),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _plan = e?.planName ?? 'normal';
    _start = e?.startDate ?? DateTime.now();
    _end = e?.endDate ?? _addMonths(DateTime.now(), 12);
    // New subscription: full price defaults to the selected plan's yearly
    // price, and "paid now" starts empty so the delegate enters the actual
    // first payment (the remaining balance is shown live).
    _total = TextEditingController(
        text: e != null
            ? e.totalAmount.toStringAsFixed(0)
            : '${planByKey(_plan).yearly}');
    _amount = TextEditingController(
        text: e != null ? e.amountPaid.toStringAsFixed(0) : '');
    _commission = TextEditingController(
        text: e != null ? e.commissionAmount.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _total.dispose();
    _amount.dispose();
    _commission.dispose();
    super.dispose();
  }

  static DateTime _addMonths(DateTime d, int months) {
    final y = d.year + ((d.month - 1 + months) ~/ 12);
    final m = (d.month - 1 + months) % 12 + 1;
    final day = d.day;
    final lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, day > lastDay ? lastDay : day);
  }

  void _applyDuration(int months) {
    setState(() => _end = _addMonths(_start, months));
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
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start,
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _end = d);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final total = _total.text.trim().isEmpty
        ? amount
        : (double.tryParse(_total.text.trim()) ?? amount);
    final commission =
        _commission.text.trim().isEmpty ? null : double.tryParse(_commission.text.trim());
    setState(() => _saving = true);
    try {
      if (_editing) {
        await widget.service.updateSubscription(
          widget.existing!.id,
          planName: _plan,
          amountPaid: amount,
          totalAmount: total,
          commissionAmount: commission,
          startDate: _start,
          endDate: _end,
        );
      } else {
        await widget.service.addSubscription(
          userId: widget.clientId,
          planName: _plan,
          amountPaid: amount,
          totalAmount: total,
          commissionAmount: commission,
          startDate: _start,
          endDate: _end,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _editing ? 'تعديل الاشتراك' : 'اشتراك جديد / تجديد',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 16),

              const Text('نوع الاشتراك',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SubscriptionPlansView(
                compact: true,
                selected: _plan,
                onSelected: (k) => setState(() {
                  _plan = k;
                  // Full price = the plan's yearly price (e.g. VIP = 600).
                  // Clear "paid now" so the delegate enters the actual first
                  // payment; the remaining balance is shown live below.
                  _total.text = '${planByKey(k).yearly}';
                  _amount.clear();
                }),
              ),
              const SizedBox(height: 16),

              const Text('المدة',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in _durations)
                    ActionChip(
                      label: Text(d.label),
                      onPressed: () => _applyDuration(d.months),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'من',
                      value: _fmt(_start),
                      onTap: _pickStart,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateField(
                      label: 'إلى',
                      value: _fmt(_end),
                      onTap: _pickEnd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _total,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'السعر الكامل',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'المدفوع الآن',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final t = double.tryParse(_total.text.trim()) ?? 0;
                final p = double.tryParse(_amount.text.trim()) ?? 0;
                final rem = (t - p) > 0 ? (t - p) : 0;
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'المتبقّي: ${rem.toStringAsFixed(0)} شيكل',
                    style: TextStyle(
                      color: rem > 0 ? Colors.red : Colors.green.shade700,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),

              TextField(
                controller: _commission,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'عمولتك (افتراضي = إعدادات حسابك)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
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
                    : Text(_editing ? 'حفظ التعديلات' : 'إنشاء الاشتراك'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog to add a payment to a subscription. Kept as its own StatefulWidget so
/// its controllers/focus live in the dialog's lifecycle (avoids focus-during-
/// build assertions that `autofocus` triggers inside a freshly-shown dialog).
class _AddPaymentDialog extends StatefulWidget {
  const _AddPaymentDialog({required this.remaining});
  final double remaining;

  @override
  State<_AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<_AddPaymentDialog> {
  late final TextEditingController _amount;
  final _notes = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
        text: widget.remaining > 0 ? widget.remaining.toStringAsFixed(0) : '');
    // Focus after the dialog is fully inserted into the tree — not during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة دفعة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
                'المتبقّي حاليًا: ${widget.remaining.toStringAsFixed(0)} شيكل',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'مبلغ الدفعة',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'ملاحظة (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            (
              amount: double.tryParse(_amount.text.trim()) ?? 0,
              notes: _notes.text.trim(),
            ),
          ),
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.event, size: 20),
        ),
        child: Text(value),
      ),
    );
  }
}
