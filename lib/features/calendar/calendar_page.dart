import 'package:flutter/material.dart';

import '../../core/services/event_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/feedback_snack.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _service = EventService();
  late DateTime _visibleMonth;
  DateTime? _selectedDay;
  late Future<_CalData> _future;
  _CalData? _last;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _future = _load();
  }

  Future<_CalData> _load() async {
    final start = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    final end = DateTime(_visibleMonth.year, _visibleMonth.month + 2, 0);
    final results = await Future.wait([
      _service.list(from: start, to: end),
      _service.upcoming(limit: 8),
      _service.main(),
    ]);
    return _CalData(
      events: results[0] as List<EventModel>,
      upcoming: results[1] as List<EventModel>,
      main: results[2] as EventModel?,
    );
  }

  void _reload() => setState(() { _future = _load(); });

  void _applyLocalEvents(List<EventModel> events) {
    final upcoming = [...events]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final main = events.where((e) => e.isMain).isNotEmpty
        ? events.firstWhere((e) => e.isMain)
        : _last?.main;
    setState(() => _last = _CalData(
          events: events,
          upcoming: upcoming.where((e) => e.startsAt.isAfter(DateTime.now())).take(8).toList(),
          main: main,
        ));
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _future = _load();
    });
  }

  Future<void> _addOrEdit([EventModel? e]) async {
    final initial = e?.startsAt ?? _selectedDay ?? DateTime.now();
    final result = await showModalBottomSheet<EventModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventEditorSheet(service: _service, existing: e, defaultDate: initial),
    );
    if (result == null) return;
    final current = _last?.events ?? const <EventModel>[];
    final updated = e == null
        ? [...current, result]
        : current.map((x) => x.id == result.id ? result : x).toList();
    _applyLocalEvents(updated);
    _reload();
  }

  Future<void> _delete(EventModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحدث'),
        content: Text('سيتم حذف "${e.title}" نهائيًا.'),
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
      await _service.delete(e.id);
      if (!mounted) return;
      showSuccessSnack(context, 'تم حذف المناسبة');
      final current = _last?.events ?? const <EventModel>[];
      _applyLocalEvents(current.where((x) => x.id != e.id).toList());
      _reload();
    } catch (err) {
      if (!mounted) return;
      showErrorSnack(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('التقويم الذكي'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('حدث جديد'),
      ),
      body: FutureBuilder<_CalData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasData) _last = snap.data;
          final data = _last;
          if (data == null) {
            if (snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: _reload);
            return const CenteredLoader();
          }
          final daysWithEvents = <DateTime>{
            for (final e in data.events) DateTime(e.startsAt.year, e.startsAt.month, e.startsAt.day),
          };
          final selectedEvents = _selectedDay == null
              ? <EventModel>[]
              : data.events.where((e) {
                  final d = e.startsAt;
                  return d.year == _selectedDay!.year && d.month == _selectedDay!.month && d.day == _selectedDay!.day;
                }).toList();

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
              children: [
                if (data.main != null) _CountdownCard(event: data.main!),
                if (data.main != null) const SizedBox(height: 14),
                _MonthCard(
                  month: _visibleMonth,
                  selected: _selectedDay,
                  daysWithEvents: daysWithEvents,
                  onPrev: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                  onPick: (d) => setState(() => _selectedDay = d),
                ),
                const SizedBox(height: 14),
                if (_selectedDay != null) ...[
                  _SectionTitle(text: 'أحداث ${_arMonth(_selectedDay!.month)} ${_selectedDay!.day}'),
                  if (selectedEvents.isEmpty)
                    const _EmptyMini(text: 'لا توجد أحداث في هذا اليوم')
                  else
                    ...selectedEvents.map((e) => _EventTile(event: e, onEdit: () => _addOrEdit(e), onDelete: () => _delete(e))),
                  const SizedBox(height: 14),
                ],
                _SectionTitle(text: 'الأحداث القادمة'),
                if (data.upcoming.isEmpty)
                  const _EmptyMini(text: 'لا توجد أحداث قادمة')
                else
                  ...data.upcoming.map((e) => _EventTile(event: e, onEdit: () => _addOrEdit(e), onDelete: () => _delete(e))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CalData {
  _CalData({required this.events, required this.upcoming, required this.main});
  final List<EventModel> events;
  final List<EventModel> upcoming;
  final EventModel? main;
}

// ---------------------------------------------------------------------------
// Countdown hero
// ---------------------------------------------------------------------------

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.event});
  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final diff = event.startsAt.difference(DateTime.now());
    final days = diff.inDays;
    final isPast = diff.isNegative;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandDeepGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.favorite, color: Color(0xFFFAD9A7), size: 18),
            const SizedBox(width: 6),
            const Text('مناسبتي الرئيسية',
                style: TextStyle(color: Color(0xFFFAD9A7), fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_fmtDateTime(event.startsAt),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Text(event.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
          if (event.location != null && event.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.place, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Expanded(child: Text(event.location!,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12))),
            ]),
          ],
          const SizedBox(height: 14),
          if (isPast)
            const Text('تمت',
                style: TextStyle(color: Color(0xFFFAD9A7), fontSize: 28, fontWeight: FontWeight.w900))
          else
            Row(
              children: [
                _CountBox(value: days.toString(), label: 'يوم'),
                const SizedBox(width: 8),
                _CountBox(value: diff.inHours.remainder(24).toString().padLeft(2, '0'), label: 'ساعة'),
                const SizedBox(width: 8),
                _CountBox(value: diff.inMinutes.remainder(60).toString().padLeft(2, '0'), label: 'دقيقة'),
              ],
            ),
        ],
      ),
    );
  }
}

class _CountBox extends StatelessWidget {
  const _CountBox({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month grid
// ---------------------------------------------------------------------------

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.selected,
    required this.daysWithEvents,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  final DateTime month;
  final DateTime? selected;
  final Set<DateTime> daysWithEvents;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // We start the week on Saturday (RTL Arabic convention).
    // Dart's weekday: Mon=1..Sun=7. Saturday=6 → offset 0.
    int leading = (firstDay.weekday - DateTime.saturday) % 7;
    if (leading < 0) leading += 7;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_right, color: AppColors.primaryDark)),
          Expanded(
            child: Center(
              child: Text('${_arMonth(month.month)} ${month.year}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 16)),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_left, color: AppColors.primaryDark)),
        ]),
        const SizedBox(height: 4),
        Row(
          children: const ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج']
              .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)))))
              .toList(),
        ),
        const SizedBox(height: 4),
        for (int r = 0; r < rows; r++)
          Row(
            children: List.generate(7, (c) {
              final idx = r * 7 + c;
              final dayNum = idx - leading + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 42));
              }
              final date = DateTime(month.year, month.month, dayNum);
              final isToday = date == todayKey;
              final isSelected = selected != null && date == DateTime(selected!.year, selected!.month, selected!.day);
              final hasEvent = daysWithEvents.contains(date);
              return Expanded(
                child: GestureDetector(
                  onTap: () => onPick(date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isToday ? AppColors.primaryLight : Colors.transparent),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      Text('$dayNum',
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textDark,
                            fontWeight: isToday || isSelected ? FontWeight.w900 : FontWeight.w600,
                          )),
                      if (hasEvent)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              );
            }),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Event tile & editor sheet
// ---------------------------------------------------------------------------

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onEdit, required this.onDelete});
  final EventModel event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
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
        leading: CircleAvatar(
          backgroundColor: event.isMain ? AppColors.primary : AppColors.primaryLight,
          child: Icon(event.isMain ? Icons.favorite : Icons.event,
              color: event.isMain ? Colors.white : AppColors.primaryDark, size: 18),
        ),
        title: Text(event.title,
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
        subtitle: Text(
          [_fmtDateTime(event.startsAt), if (event.location != null && event.location!.isNotEmpty) event.location!].join(' • '),
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

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({required this.service, this.existing, required this.defaultDate});
  final EventService service;
  final EventModel? existing;
  final DateTime defaultDate;
  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  bool _isMain = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _description.text = e.description ?? '';
      _location.text = e.location ?? '';
      _date = DateTime(e.startsAt.year, e.startsAt.month, e.startsAt.day);
      _time = TimeOfDay(hour: e.startsAt.hour, minute: e.startsAt.minute);
      _isMain = e.isMain;
    } else {
      _date = DateTime(widget.defaultDate.year, widget.defaultDate.month, widget.defaultDate.day);
      _time = const TimeOfDay(hour: 19, minute: 0);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  DateTime get _combined => DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      EventModel result;
      if (widget.existing == null) {
        result = await widget.service.create(
          title: _title.text.trim(),
          description: _description.text.trim(),
          startsAt: _combined,
          location: _location.text.trim(),
          isMain: _isMain,
        );
      } else {
        result = await widget.service.update(widget.existing!.id, {
          'title': _title.text.trim(),
          'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
          'starts_at': _combined,
          'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
          'is_main': _isMain,
        });
      }
      if (!mounted) return;
      showSuccessSnack(context, widget.existing == null ? 'تمت إضافة المناسبة' : 'تم حفظ التغييرات');
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
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                width: 44, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            Text(isEdit ? 'تعديل حدث' : 'حدث جديد',
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 18)),
            const SizedBox(height: 14),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'العنوان *', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _location, decoration: const InputDecoration(labelText: 'الموقع', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'التاريخ', border: OutlineInputBorder()),
                    child: Text(_fmtDate(_date)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: _time);
                    if (t != null) setState(() => _time = t);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'الوقت', border: OutlineInputBorder()),
                    child: Text(_time.format(context)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _isMain,
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              title: const Text('اجعلها مناسبتي الرئيسية',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
              subtitle: const Text('سيتم عرض العد التنازلي لها في الصفحة الرئيسية للتقويم',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              onChanged: (v) => setState(() => _isMain = v),
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
                  : Text(isEdit ? 'حفظ التغييرات' : 'إضافة الحدث'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15)),
      );
}

class _EmptyMini extends StatelessWidget {
  const _EmptyMini({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Text(text, style: const TextStyle(color: AppColors.textMuted))),
      );
}

String _arMonth(int m) => const [
      'يناير','فبراير','مارس','أبريل','مايو','يونيو',
      'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'
    ][m - 1];

String _fmtDate(DateTime d) => '${d.day} ${_arMonth(d.month)} ${d.year}';
String _fmtDateTime(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '${_fmtDate(d)} • $h:$mi';
}
