import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/coordinator_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/feedback_snack.dart';

class CoordinatorPage extends StatefulWidget {
  const CoordinatorPage({super.key});
  @override
  State<CoordinatorPage> createState() => _CoordinatorPageState();
}

class _CoordinatorPageState extends State<CoordinatorPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('منسق المناسبة'),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Color(0xFFFAD9A7),
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.account_balance_wallet), text: 'الميزانية'),
              Tab(icon: Icon(Icons.groups), text: 'المدعوون'),
            ],
          ),
        ),
        body: const TabBarView(children: [_BudgetTab(), _GuestsTab()]),
      ),
    );
  }
}

// ===========================================================================
// BUDGET TAB
// ===========================================================================

class _BudgetTab extends StatefulWidget {
  const _BudgetTab();
  @override
  State<_BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<_BudgetTab> {
  final _service = BudgetService();
  late Future<_BudgetData> _future;
  _BudgetData? _last;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BudgetData> _load() async {
    final r = await Future.wait([_service.list(), _service.summary()]);
    return _BudgetData(items: r[0] as List<BudgetItemModel>, summary: r[1] as BudgetSummary);
  }

  void _reload() => setState(() { _future = _load(); });

  void _applyLocalItems(List<BudgetItemModel> items) {
    final est = items.fold<double>(0, (s, x) => s + x.estimatedAmount);
    final act = items.fold<double>(0, (s, x) => s + x.actualAmount);
    final paid = items.where((x) => x.paid).fold<double>(0, (s, x) => s + x.actualAmount);
    setState(() => _last = _BudgetData(
          items: items,
          summary: BudgetSummary(
            count: items.length,
            estimated: est,
            actual: act,
            paid: paid,
            remaining: act - paid,
          ),
        ));
  }

  Future<void> _addOrEdit([BudgetItemModel? item]) async {
    final result = await showModalBottomSheet<BudgetItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BudgetEditorSheet(service: _service, existing: item),
    );
    if (result == null) return;
    final current = _last?.items ?? const <BudgetItemModel>[];
    final updated = item == null
        ? [result, ...current]
        : current.map((x) => x.id == result.id ? result : x).toList();
    _applyLocalItems(updated);
    _reload();
  }

  Future<void> _delete(BudgetItemModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف البند'),
        content: Text('سيتم حذف "${item.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(item.id);
      if (!mounted) return;
      showSuccessSnack(context, 'تم حذف البند');
      final current = _last?.items ?? const <BudgetItemModel>[];
      _applyLocalItems(current.where((x) => x.id != item.id).toList());
      _reload();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      FutureBuilder<_BudgetData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasData) _last = snap.data;
          final data = _last;
          if (data == null) {
            if (snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: _reload);
            return const CenteredLoader();
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
              children: [
                _BudgetSummaryCard(summary: data.summary),
                const SizedBox(height: 14),
                if (data.items.isEmpty)
                  _EmptyTab(
                    icon: Icons.account_balance_wallet,
                    text: 'لم تضف بنودًا للميزانية بعد',
                    actionLabel: 'إضافة بند',
                    onAction: () => _addOrEdit(),
                  )
                else
                  ...data.items.map((it) => _BudgetTile(
                        item: it,
                        onEdit: () => _addOrEdit(it),
                        onDelete: () => _delete(it),
                        onTogglePaid: () async {
                          await _service.update(it.id, {'paid': !it.paid});
                          _reload();
                        },
                      )),
              ],
            ),
          );
        },
      ),
      Positioned(
        bottom: 18, left: 18,
        child: FloatingActionButton.extended(
          heroTag: 'fab-budget',
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => _addOrEdit(),
          icon: const Icon(Icons.add),
          label: const Text('بند جديد'),
        ),
      ),
    ]);
  }
}

class _BudgetData {
  _BudgetData({required this.items, required this.summary});
  final List<BudgetItemModel> items;
  final BudgetSummary summary;
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({required this.summary});
  final BudgetSummary summary;
  @override
  Widget build(BuildContext context) {
    final pct = summary.actual == 0 ? 0.0 : (summary.paid / summary.actual).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFCF6EE), Color(0xFFF3E3CC)],
          begin: Alignment.topRight, end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.account_balance_wallet, color: AppColors.primaryDark),
            SizedBox(width: 8),
            Text('ملخص الميزانية',
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _StatPill(label: 'تقديري', value: _fmtMoney(summary.estimated), color: const Color(0xFF7A6450)),
            _StatPill(label: 'فعلي',   value: _fmtMoney(summary.actual),    color: AppColors.primaryDark),
            _StatPill(label: 'مدفوع',  value: _fmtMoney(summary.paid),      color: const Color(0xFF2E7D5B)),
            _StatPill(label: 'متبقي',  value: _fmtMoney(summary.remaining), color: const Color(0xFFC1452B)),
          ]),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.item, required this.onEdit, required this.onDelete, required this.onTogglePaid});
  final BudgetItemModel item;
  final VoidCallback onEdit, onDelete, onTogglePaid;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: ListTile(
        onTap: onEdit,
        leading: GestureDetector(
          onTap: onTogglePaid,
          child: CircleAvatar(
            backgroundColor: item.paid ? const Color(0xFF2E7D5B) : AppColors.primaryLight,
            child: Icon(item.paid ? Icons.check : Icons.payments,
                color: item.paid ? Colors.white : AppColors.primaryDark, size: 20),
          ),
        ),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
        subtitle: Text(
          [
            if (item.category != null && item.category!.isNotEmpty) item.category!,
            'تقديري: ${_fmtMoney(item.estimatedAmount)}',
            'فعلي: ${_fmtMoney(item.actualAmount)}',
          ].join(' • '),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: Color(0xFFC1452B)),
        ),
      ),
    );
  }
}

class _BudgetEditorSheet extends StatefulWidget {
  const _BudgetEditorSheet({required this.service, this.existing});
  final BudgetService service;
  final BudgetItemModel? existing;
  @override
  State<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<_BudgetEditorSheet> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _estimated = TextEditingController();
  final _actual = TextEditingController();
  bool _paid = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final it = widget.existing;
    if (it != null) {
      _name.text = it.name;
      _category.text = it.category ?? '';
      _estimated.text = it.estimatedAmount == 0 ? '' : it.estimatedAmount.toStringAsFixed(0);
      _actual.text = it.actualAmount == 0 ? '' : it.actualAmount.toStringAsFixed(0);
      _paid = it.paid;
    }
  }

  @override
  void dispose() {
    _name.dispose(); _category.dispose(); _estimated.dispose(); _actual.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final est = double.tryParse(_estimated.text.trim()) ?? 0;
      final act = double.tryParse(_actual.text.trim()) ?? 0;
      BudgetItemModel result;
      if (widget.existing == null) {
        result = await widget.service.create(
          name: _name.text.trim(),
          category: _category.text.trim(),
          estimated: est,
          actual: act,
          paid: _paid,
        );
      } else {
        result = await widget.service.update(widget.existing!.id, {
          'name': _name.text.trim(),
          'category': _category.text.trim().isEmpty ? null : _category.text.trim(),
          'estimated_amount': est,
          'actual_amount': act,
          'paid': _paid,
        });
      }
      if (!mounted) return;
      showSuccessSnack(context, widget.existing == null ? 'تمت إضافة البند' : 'تم حفظ التغييرات');
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(width: 44, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(99))),
            ),
            Text(widget.existing == null ? 'بند جديد' : 'تعديل بند',
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 18)),
            const SizedBox(height: 14),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم *', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _category, decoration: const InputDecoration(labelText: 'الفئة', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _estimated,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'مبلغ تقديري', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _actual,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'مبلغ فعلي', border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            SwitchListTile(
              value: _paid,
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              title: const Text('تم الدفع', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
              onChanged: (v) => setState(() => _paid = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ===========================================================================
// GUESTS TAB
// ===========================================================================

class _GuestsTab extends StatefulWidget {
  const _GuestsTab();
  @override
  State<_GuestsTab> createState() => _GuestsTabState();
}

class _GuestsTabState extends State<_GuestsTab> {
  final _service = GuestService();
  late Future<_GuestsData> _future;
  _GuestsData? _last;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_GuestsData> _load() async {
    final r = await Future.wait([_service.list(), _service.summary()]);
    return _GuestsData(items: r[0] as List<GuestModel>, summary: r[1] as GuestSummary);
  }

  void _reload() => setState(() { _future = _load(); });

  void _applyLocalGuests(List<GuestModel> items) {
    int invited = 0, confirmed = 0, declined = 0, maybe = 0, heads = 0;
    for (final g in items) {
      switch (g.rsvpStatus) {
        case 'confirmed': confirmed++; heads += 1 + g.plusOnes; break;
        case 'declined': declined++; break;
        case 'maybe': maybe++; break;
        default: invited++;
      }
    }
    setState(() => _last = _GuestsData(
          items: items,
          summary: GuestSummary(
            total: items.length,
            invited: invited,
            confirmed: confirmed,
            declined: declined,
            maybe: maybe,
            expectedHeads: heads,
          ),
        ));
  }

  Future<void> _addOrEdit([GuestModel? g]) async {
    final result = await showModalBottomSheet<GuestModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GuestEditorSheet(service: _service, existing: g),
    );
    if (result == null) return;
    final current = _last?.items ?? const <GuestModel>[];
    final updated = g == null
        ? [result, ...current]
        : current.map((x) => x.id == result.id ? result : x).toList();
    _applyLocalGuests(updated);
    _reload();
  }

  Future<void> _delete(GuestModel g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المدعو'),
        content: Text('سيتم حذف "${g.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(g.id);
      if (!mounted) return;
      showSuccessSnack(context, 'تم حذف المدعو');
      final current = _last?.items ?? const <GuestModel>[];
      _applyLocalGuests(current.where((x) => x.id != g.id).toList());
      _reload();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      FutureBuilder<_GuestsData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasData) _last = snap.data;
          final data = _last;
          if (data == null) {
            if (snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: _reload);
            return const CenteredLoader();
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
              children: [
                _GuestsSummaryCard(summary: data.summary),
                const SizedBox(height: 14),
                if (data.items.isEmpty)
                  _EmptyTab(
                    icon: Icons.groups,
                    text: 'لم تضف مدعوين بعد',
                    actionLabel: 'إضافة مدعو',
                    onAction: () => _addOrEdit(),
                  )
                else
                  ...data.items.map((g) => _GuestTile(
                        guest: g,
                        onEdit: () => _addOrEdit(g),
                        onDelete: () => _delete(g),
                        onCycle: () async {
                          const order = ['invited', 'confirmed', 'maybe', 'declined'];
                          final i = order.indexOf(g.rsvpStatus);
                          final next = order[(i + 1) % order.length];
                          await _service.update(g.id, {'rsvp_status': next});
                          _reload();
                        },
                      )),
              ],
            ),
          );
        },
      ),
      Positioned(
        bottom: 18, left: 18,
        child: FloatingActionButton.extended(
          heroTag: 'fab-guests',
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => _addOrEdit(),
          icon: const Icon(Icons.person_add),
          label: const Text('مدعو جديد'),
        ),
      ),
    ]);
  }
}

class _GuestsData {
  _GuestsData({required this.items, required this.summary});
  final List<GuestModel> items;
  final GuestSummary summary;
}

class _GuestsSummaryCard extends StatelessWidget {
  const _GuestsSummaryCard({required this.summary});
  final GuestSummary summary;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFCF6EE), Color(0xFFF3E3CC)],
          begin: Alignment.topRight, end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.groups, color: AppColors.primaryDark),
            SizedBox(width: 8),
            Text('ملخص المدعوين',
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _StatPill(label: 'إجمالي',  value: '${summary.total}',         color: AppColors.primaryDark),
            _StatPill(label: 'مؤكد',    value: '${summary.confirmed}',     color: const Color(0xFF2E7D5B)),
            _StatPill(label: 'مدعو',    value: '${summary.invited}',       color: const Color(0xFF7A6450)),
            _StatPill(label: 'ربما',    value: '${summary.maybe}',         color: const Color(0xFFB8835A)),
            _StatPill(label: 'اعتذر',   value: '${summary.declined}',      color: const Color(0xFFC1452B)),
            _StatPill(label: 'الحضور',  value: '${summary.expectedHeads}', color: AppColors.primary),
          ]),
        ],
      ),
    );
  }
}

class _GuestTile extends StatelessWidget {
  const _GuestTile({required this.guest, required this.onEdit, required this.onDelete, required this.onCycle});
  final GuestModel guest;
  final VoidCallback onEdit, onDelete, onCycle;
  @override
  Widget build(BuildContext context) {
    final rsvp = _rsvpInfo(guest.rsvpStatus);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: rsvp.$2.withValues(alpha: 0.15),
          child: Text(guest.name.isEmpty ? '?' : guest.name.characters.first,
              style: TextStyle(color: rsvp.$2, fontWeight: FontWeight.w900)),
        ),
        title: Text(guest.name, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
        subtitle: Text(
          [
            if (guest.phone != null && guest.phone!.isNotEmpty) guest.phone!,
            if (guest.group != null && guest.group!.isNotEmpty) guest.group!,
            if (guest.plusOnes > 0) '+${guest.plusOnes} مرافق',
            if (guest.tableNumber != null && guest.tableNumber!.isNotEmpty) 'طاولة ${guest.tableNumber}',
          ].join(' • '),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: onCycle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: rsvp.$2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(rsvp.$1, style: TextStyle(color: rsvp.$2, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Color(0xFFC1452B))),
        ]),
      ),
    );
  }
}

(String, Color) _rsvpInfo(String s) {
  switch (s) {
    case 'confirmed': return ('مؤكد', const Color(0xFF2E7D5B));
    case 'declined':  return ('اعتذر', const Color(0xFFC1452B));
    case 'maybe':     return ('ربما',  const Color(0xFFB8835A));
    default:          return ('مدعو', const Color(0xFF7A6450));
  }
}

class _GuestEditorSheet extends StatefulWidget {
  const _GuestEditorSheet({required this.service, this.existing});
  final GuestService service;
  final GuestModel? existing;
  @override
  State<_GuestEditorSheet> createState() => _GuestEditorSheetState();
}

class _GuestEditorSheetState extends State<_GuestEditorSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _group = TextEditingController();
  final _table = TextEditingController();
  int _plusOnes = 0;
  String _rsvp = 'invited';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    if (g != null) {
      _name.text = g.name;
      _phone.text = g.phone ?? '';
      _group.text = g.group ?? '';
      _table.text = g.tableNumber ?? '';
      _plusOnes = g.plusOnes;
      _rsvp = g.rsvpStatus;
    }
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _group.dispose(); _table.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      GuestModel result;
      if (widget.existing == null) {
        result = await widget.service.create(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          plusOnes: _plusOnes,
          rsvpStatus: _rsvp,
          group: _group.text.trim(),
          tableNumber: _table.text.trim(),
        );
      } else {
        result = await widget.service.update(widget.existing!.id, {
          'name': _name.text.trim(),
          'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          'plus_ones': _plusOnes,
          'rsvp_status': _rsvp,
          'group': _group.text.trim().isEmpty ? null : _group.text.trim(),
          'table_number': _table.text.trim().isEmpty ? null : _table.text.trim(),
        });
      }
      if (!mounted) return;
      showSuccessSnack(context, widget.existing == null ? 'تمت إضافة المدعو' : 'تم حفظ التغييرات');
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(width: 44, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(99))),
            ),
            Text(widget.existing == null ? 'مدعو جديد' : 'تعديل مدعو',
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 18)),
            const SizedBox(height: 14),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم *', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _phone, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'مرافقون', border: OutlineInputBorder()),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    IconButton(
                      onPressed: _plusOnes > 0 ? () => setState(() => _plusOnes--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_plusOnes', style: const TextStyle(fontWeight: FontWeight.w900)),
                    IconButton(
                      onPressed: () => setState(() => _plusOnes++),
                      icon: const Icon(Icons.add),
                    ),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(controller: _group, decoration: const InputDecoration(labelText: 'الفئة (عائلة / أصدقاء…)', border: OutlineInputBorder())),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(controller: _table, decoration: const InputDecoration(labelText: 'الطاولة', border: OutlineInputBorder())),
              ),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _rsvp,
              decoration: const InputDecoration(labelText: 'حالة الدعوة', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'invited',   child: Text('مدعو')),
                DropdownMenuItem(value: 'confirmed', child: Text('مؤكد')),
                DropdownMenuItem(value: 'maybe',     child: Text('ربما')),
                DropdownMenuItem(value: 'declined',  child: Text('اعتذر')),
              ],
              onChanged: (v) => setState(() => _rsvp = v ?? 'invited'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ===========================================================================
// Shared widgets
// ===========================================================================

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ]),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.icon, required this.text, required this.actionLabel, required this.onAction});
  final IconData icon;
  final String text, actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 30),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Icon(icon, size: 56, color: AppColors.primaryDark),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          onPressed: onAction,
          icon: const Icon(Icons.add),
          label: Text(actionLabel),
        ),
      ]),
    );
  }
}

String _fmtMoney(double v) {
  final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
  // Insert thousands separators.
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  final result = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  return '$result د.أ';
}
