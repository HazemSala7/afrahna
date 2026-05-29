import 'package:flutter/material.dart';

import '../../core/services/task_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/feedback_snack.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _service = TaskService();
  late Future<_TasksData> _future;
  _TasksData? _last;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TasksData> _load() async {
    final results = await Future.wait([
      _service.list(),
      _service.summary(),
    ]);
    return _TasksData(
      tasks: results[0] as List<TaskModel>,
      summary: results[1] as TaskSummary,
    );
  }

  void _reload() => setState(() { _future = _load(); });

  void _applyLocalTasks(List<TaskModel> tasks) {
    final summary = TaskSummary(
      total: tasks.length,
      pending: tasks.where((t) => t.status == 'pending').length,
      inProgress: tasks.where((t) => t.status == 'in_progress').length,
      done: tasks.where((t) => t.status == 'done').length,
      overdue: _last?.summary.overdue ?? 0,
    );
    setState(() => _last = _TasksData(tasks: tasks, summary: summary));
  }

  Future<void> _addOrEdit([TaskModel? existing]) async {
    final result = await showModalBottomSheet<TaskModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskEditorSheet(service: _service, existing: existing),
    );
    if (result == null) return;
    final current = _last?.tasks ?? const <TaskModel>[];
    final updated = existing == null
        ? [result, ...current]
        : current.map((t) => t.id == result.id ? result : t).toList();
    _applyLocalTasks(updated);
    _reload();
  }

  Future<void> _toggle(TaskModel t) async {
    try {
      final updated = await _service.toggle(t.id);
      if (!mounted) return;
      showSuccessSnack(context, 'تم تحديث حالة المهمة');
      final current = _last?.tasks ?? const <TaskModel>[];
      _applyLocalTasks(current.map((x) => x.id == updated.id ? updated : x).toList());
      _reload();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _delete(TaskModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المهمة'),
        content: Text('سيتم حذف "${t.title}" نهائيًا.'),
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
      await _service.delete(t.id);
      if (!mounted) return;
      showSuccessSnack(context, 'تم حذف المهمة');
      final current = _last?.tasks ?? const <TaskModel>[];
      _applyLocalTasks(current.where((x) => x.id != t.id).toList());
      _reload();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _pickTemplate() async {
    try {
      final templates = await _service.templates();
      if (!mounted) return;
      if (templates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد قوالب متاحة حالياً')),
        );
        return;
      }
      final picked = await showModalBottomSheet<TaskTemplateModel>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TemplatePickerSheet(templates: templates),
      );
      if (picked == null || !mounted) return;
      final eventDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 30)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        helpText: 'تاريخ المناسبة',
      );
      if (eventDate == null) return;
      final n = await _service.importTemplate(picked.id, eventDate: eventDate);
      if (!mounted) return;
      showSuccessSnack(context, 'تم استيراد $n مهمة من "${picked.title}"');
      _reload();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('قائمة المهام'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'استيراد قالب',
            onPressed: _pickTemplate,
            icon: const Icon(Icons.library_add_check_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('مهمة جديدة'),
      ),
      body: FutureBuilder<_TasksData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasData) _last = snap.data;
          final data = _last;
          if (data == null) {
            if (snap.hasError) {
              return ErrorState(message: snap.error.toString(), onRetry: _reload);
            }
            return const CenteredLoader();
          }
          if (data.tasks.isEmpty) {
            return _EmptyState(onAdd: () => _addOrEdit(), onTemplate: _pickTemplate);
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
              children: [
                _SummaryCard(summary: data.summary),
                const SizedBox(height: 16),
                ..._buildGrouped(data.tasks),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGrouped(List<TaskModel> all) {
    final pending = all.where((t) => t.status == 'pending').toList();
    final inProgress = all.where((t) => t.status == 'in_progress').toList();
    final done = all.where((t) => t.status == 'done').toList();
    final out = <Widget>[];
    if (pending.isNotEmpty) {
      out.add(_GroupHeader(icon: Icons.radio_button_unchecked, label: 'لم تبدأ بعد', count: pending.length));
      out.addAll(pending.map(_taskTile));
    }
    if (inProgress.isNotEmpty) {
      out.add(_GroupHeader(icon: Icons.autorenew_rounded, label: 'قيد التنفيذ', count: inProgress.length));
      out.addAll(inProgress.map(_taskTile));
    }
    if (done.isNotEmpty) {
      out.add(_GroupHeader(icon: Icons.check_circle, label: 'منتهية', count: done.length));
      out.addAll(done.map(_taskTile));
    }
    return out;
  }

  Widget _taskTile(TaskModel t) => _TaskTile(
        task: t,
        onToggle: () => _toggle(t),
        onEdit: () => _addOrEdit(t),
        onDelete: () => _delete(t),
      );
}

class _TasksData {
  _TasksData({required this.tasks, required this.summary});
  final List<TaskModel> tasks;
  final TaskSummary summary;
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final TaskSummary summary;

  @override
  Widget build(BuildContext context) {
    final pct = (summary.progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFCF6EE), Color(0xFFF3E3CC)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rtl_rounded, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('تقدّم قائمة المهام',
                    style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 15)),
              ),
              Text('$pct%',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: summary.progress,
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Chip(label: 'إجمالي', value: '${summary.total}', color: AppColors.primary),
            _Chip(label: 'منتهية', value: '${summary.done}', color: const Color(0xFF2E7D5B)),
            _Chip(label: 'قيد التنفيذ', value: '${summary.inProgress}', color: const Color(0xFFB8835A)),
            _Chip(label: 'لم تبدأ', value: '${summary.pending}', color: const Color(0xFF7A6450)),
            if (summary.overdue > 0)
              _Chip(label: 'متأخر', value: '${summary.overdue}', color: const Color(0xFFC1452B)),
          ]),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group header + task tile
// ---------------------------------------------------------------------------

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.icon, required this.label, required this.count});
  final IconData icon;
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(99)),
            child: Text('$count',
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onToggle, required this.onEdit, required this.onDelete});
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final done = task.isDone;
    final overdue = task.isOverdue;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overdue ? const Color(0xFFC1452B).withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: done ? AppColors.primary : AppColors.textMuted),
                    color: done ? AppColors.primary : Colors.transparent,
                  ),
                  child: done ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: done ? AppColors.textMuted : AppColors.textDark,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(task.description!,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      _PriorityBadge(priority: task.priority),
                      if (task.category != null && task.category!.isNotEmpty) _Pill(text: task.category!),
                      if (task.dueDate != null)
                        _Pill(
                          icon: Icons.event,
                          text: _fmtDate(task.dueDate!),
                          color: overdue ? const Color(0xFFC1452B) : null,
                        ),
                    ]),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Color(0xFFC1452B)),
                tooltip: 'حذف',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final String priority;
  @override
  Widget build(BuildContext context) {
    final m = {
      'low':    ('منخفض',  const Color(0xFF2E7D5B)),
      'medium': ('متوسط',  const Color(0xFFB8835A)),
      'high':   ('عالي',   const Color(0xFFC1452B)),
    }[priority] ?? ('متوسط', const Color(0xFFB8835A));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: m.$2.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(m.$1, style: TextStyle(color: m.$2, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primaryDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Editor sheet
// ---------------------------------------------------------------------------

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet({required this.service, this.existing});
  final TaskService service;
  final TaskModel? existing;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  String _priority = 'medium';
  String _status = 'pending';
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null) {
      _title.text = t.title;
      _description.text = t.description ?? '';
      _category.text = t.category ?? '';
      _priority = t.priority;
      _status = t.status;
      _dueDate = t.dueDate;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      TaskModel result;
      if (widget.existing == null) {
        result = await widget.service.create(
          title: _title.text.trim(),
          description: _description.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
          category: _category.text.trim(),
        );
      } else {
        result = await widget.service.update(widget.existing!.id, {
          'title': _title.text.trim(),
          'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
          'category': _category.text.trim().isEmpty ? null : _category.text.trim(),
          'priority': _priority,
          'status': _status,
          'due_date': _dueDate,
        });
      }
      if (!mounted) return;
      showSuccessSnack(context, widget.existing == null ? 'تمت إضافة المهمة' : 'تم حفظ التغييرات');
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              Text(isEdit ? 'تعديل المهمة' : 'مهمة جديدة',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 18)),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'العنوان *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _category,
                    decoration: const InputDecoration(labelText: 'الفئة', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(labelText: 'الأولوية', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('منخفض')),
                      DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                      DropdownMenuItem(value: 'high', child: Text('عالي')),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (d != null) setState(() => _dueDate = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'تاريخ الاستحقاق', border: OutlineInputBorder()),
                      child: Text(_dueDate != null ? _fmtDate(_dueDate!) : 'بدون تاريخ',
                          style: const TextStyle(color: AppColors.textDark)),
                    ),
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    onPressed: () => setState(() => _dueDate = null),
                    icon: const Icon(Icons.close),
                    tooltip: 'مسح',
                  ),
              ]),
              if (isEdit) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('لم تبدأ')),
                    DropdownMenuItem(value: 'in_progress', child: Text('قيد التنفيذ')),
                    DropdownMenuItem(value: 'done', child: Text('منتهية')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'pending'),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'حفظ التغييرات' : 'إضافة المهمة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Template picker
// ---------------------------------------------------------------------------

class _TemplatePickerSheet extends StatelessWidget {
  const _TemplatePickerSheet({required this.templates});
  final List<TaskTemplateModel> templates;
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44, height: 4, margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const Text('اختر قالبًا جاهزًا',
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('سيتم استيراد كل عناصر القالب كمهام جديدة، مع حساب تواريخ الاستحقاق نسبيًا لتاريخ المناسبة.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                itemCount: templates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final t = templates[i];
                  return InkWell(
                    onTap: () => Navigator.pop(context, t),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryLight),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            radius: 22,
                            child: Text(t.icon ?? '✅', style: const TextStyle(fontSize: 20)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.title,
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark)),
                                const SizedBox(height: 2),
                                Text(
                                  '${t.items.length} عنصر${t.descriptionAr?.isNotEmpty == true ? ' • ${t.descriptionAr}' : ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_left, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.onTemplate});
  final VoidCallback onAdd;
  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checklist_rtl_rounded, size: 56, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 18),
            const Text('لا توجد مهام بعد',
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('ابدأ بإضافة مهام مخصصة أو استورد قائمة جاهزة لتسريع التخطيط.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('إضافة مهمة'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primary),
                ),
                onPressed: onTemplate,
                icon: const Icon(Icons.library_add_check_rounded),
                label: const Text('استيراد قالب'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'يناير','فبراير','مارس','أبريل','مايو','يونيو',
    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'
  ];
  return '${d.day} ${months[d.month - 1]}';
}
