import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/invitation_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/feedback_snack.dart';

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key});
  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  final _service = InvitationService();
  late Future<List<InvitationModel>> _future;
  List<InvitationModel>? _last;

  @override
  void initState() {
    super.initState();
    _future = _service.list();
  }

  void _reload() => setState(() { _future = _service.list(); });

  void _applyLocal(List<InvitationModel> items) {
    setState(() => _last = items);
  }

  Future<void> _createNew() async {
    final templates = await _safe(() => _service.templates());
    if (templates == null || !mounted) return;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد قوالب متاحة حالياً')),
      );
      return;
    }
    final pickedTemplate = await showModalBottomSheet<InvitationTemplateModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplatePicker(templates: templates),
    );
    if (pickedTemplate == null || !mounted) return;
    final created = await Navigator.push<InvitationModel>(
      context,
      MaterialPageRoute(builder: (_) => _InvitationEditor(service: _service, template: pickedTemplate)),
    );
    if (created == null) return;
    final current = _last ?? const <InvitationModel>[];
    _applyLocal([created, ...current]);
    _reload();
  }

  Future<void> _edit(InvitationModel inv) async {
    final updated = await Navigator.push<InvitationModel>(
      context,
      MaterialPageRoute(builder: (_) => _InvitationEditor(service: _service, existing: inv)),
    );
    if (updated == null) return;
    final current = _last ?? const <InvitationModel>[];
    _applyLocal(current.map((x) => x.id == updated.id ? updated : x).toList());
    _reload();
  }

  Future<void> _delete(InvitationModel inv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الدعوة'),
        content: const Text('سيتم حذف الدعوة نهائيًا.'),
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
      await _service.delete(inv.id);
      if (!mounted) return;
      showSuccessSnack(context, 'تم حذف الدعوة');
      final current = _last ?? const <InvitationModel>[];
      _applyLocal(current.where((x) => x.id != inv.id).toList());
      _reload();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<T?> _safe<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('دعوات إلكترونية'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _createNew,
        icon: const Icon(Icons.add),
        label: const Text('دعوة جديدة'),
      ),
      body: FutureBuilder<List<InvitationModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasData) _last = snap.data;
          final items = _last;
          if (items == null) {
            if (snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: _reload);
            return const CenteredLoader();
          }
          if (items.isEmpty) return _Empty(onCreate: _createNew);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
              itemCount: items.length,
              itemBuilder: (_, i) => _InvitationCard(
                invitation: items[i],
                onEdit: () => _edit(items[i]),
                onDelete: () => _delete(items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invitation card
// ---------------------------------------------------------------------------

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.invitation, required this.onEdit, required this.onDelete});
  final InvitationModel invitation;
  final VoidCallback onEdit, onDelete;

  Color _parseColor(String hex, Color fallback) {
    try {
      var h = hex.replaceFirst('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tpl = invitation.template;
    final bg = _parseColor(tpl?.bgColor ?? '#FAF3EC', AppColors.background);
    final tc = _parseColor(tpl?.textColor ?? '#3D2817', AppColors.textDark);
    final ac = _parseColor(tpl?.accentColor ?? '#B8835A', AppColors.primary);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ac.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: ac.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: ac.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                  child: Text(tpl?.name ?? 'كلاسيكي',
                      style: TextStyle(color: ac, fontWeight: FontWeight.w800, fontSize: 11)),
                ),
                const Spacer(),
                Row(children: [
                  Icon(Icons.visibility_outlined, size: 14, color: tc.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text('${invitation.viewsCount}',
                      style: TextStyle(color: tc.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w800)),
                ]),
              ]),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  '${invitation.brideName}  &  ${invitation.groomName}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tc, fontWeight: FontWeight.w900, fontSize: 22),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Container(width: 60, height: 2, color: ac)),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.event, color: ac, size: 16),
                const SizedBox(width: 6),
                Text(_fmtDateTime(invitation.eventDate),
                    style: TextStyle(color: tc, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              if (invitation.venue != null && invitation.venue!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.place, color: ac, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(invitation.venue!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tc, fontSize: 13)),
                  ),
                ]),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ac, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _share(context, invitation),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('مشاركة'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'فتح',
                  onPressed: () => _openLink(invitation.shareUrl),
                  icon: Icon(Icons.open_in_new, color: ac),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFC1452B)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _share(BuildContext context, InvitationModel inv) async {
    final text = 'دعوة زفاف ${inv.brideName} & ${inv.groomName}\n${inv.shareUrl}';
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 44, height: 4, margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(99))),
            const Text('مشاركة الدعوة',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textDark)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryLight),
              ),
              child: SelectableText(inv.shareUrl,
                  style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: inv.shareUrl));
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ الرابط')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('نسخ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
                    if (ctx.mounted) Navigator.pop(ctx);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('واتساب'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

class _InvitationEditor extends StatefulWidget {
  const _InvitationEditor({required this.service, this.existing, this.template});
  final InvitationService service;
  final InvitationModel? existing;
  final InvitationTemplateModel? template;
  @override
  State<_InvitationEditor> createState() => _InvitationEditorState();
}

class _InvitationEditorState extends State<_InvitationEditor> {
  final _bride = TextEditingController();
  final _groom = TextEditingController();
  final _venue = TextEditingController();
  final _mapUrl = TextEditingController();
  final _message = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _bride.text = e.brideName;
      _groom.text = e.groomName;
      _venue.text = e.venue ?? '';
      _mapUrl.text = e.mapUrl ?? '';
      _message.text = e.customMessage ?? '';
      _date = DateTime(e.eventDate.year, e.eventDate.month, e.eventDate.day);
      _time = TimeOfDay(hour: e.eventDate.hour, minute: e.eventDate.minute);
    } else {
      final d = DateTime.now().add(const Duration(days: 60));
      _date = DateTime(d.year, d.month, d.day);
      _time = const TimeOfDay(hour: 19, minute: 0);
    }
  }

  @override
  void dispose() {
    _bride.dispose(); _groom.dispose(); _venue.dispose(); _mapUrl.dispose(); _message.dispose();
    super.dispose();
  }

  DateTime get _combined => DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _save() async {
    if (_bride.text.trim().isEmpty || _groom.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم العروسين')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      InvitationModel result;
      if (widget.existing == null) {
        result = await widget.service.create(
          brideName: _bride.text.trim(),
          groomName: _groom.text.trim(),
          eventDate: _combined,
          venue: _venue.text.trim(),
          mapUrl: _mapUrl.text.trim(),
          customMessage: _message.text.trim(),
          templateId: widget.template?.id,
        );
      } else {
        result = await widget.service.update(widget.existing!.id, {
          'bride_name': _bride.text.trim(),
          'groom_name': _groom.text.trim(),
          'event_date': _combined,
          'venue': _venue.text.trim().isEmpty ? null : _venue.text.trim(),
          'map_url': _mapUrl.text.trim().isEmpty ? null : _mapUrl.text.trim(),
          'custom_message': _message.text.trim().isEmpty ? null : _message.text.trim(),
        });
      }
      if (!mounted) return;
      showSuccessSnack(context, widget.existing == null ? 'تم إنشاء الدعوة' : 'تم حفظ التغييرات');
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'دعوة جديدة' : 'تعديل الدعوة'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('حفظ الدعوة'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _bride, decoration: const InputDecoration(labelText: 'اسم العروس *', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _groom, decoration: const InputDecoration(labelText: 'اسم العريس *', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context, initialDate: _date,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
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
          const SizedBox(height: 10),
          TextField(controller: _venue, decoration: const InputDecoration(labelText: 'مكان الحفل', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
            controller: _mapUrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'رابط الموقع على الخريطة',
              hintText: 'https://maps.google.com/...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _message,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'رسالة مخصصة (اختياري)',
              hintText: 'يسرنا دعوتكم لمشاركتنا أجمل لحظات حياتنا...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Template picker + empty state
// ---------------------------------------------------------------------------

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({required this.templates});
  final List<InvitationTemplateModel> templates;

  Color _parseColor(String hex, Color fallback) {
    try {
      var h = hex.replaceFirst('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
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
              child: Container(width: 44, height: 4, margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(99))),
            ),
            const Text('اختر تصميم الدعوة',
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 18)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                controller: scroll,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78,
                ),
                itemCount: templates.length,
                itemBuilder: (_, i) {
                  final t = templates[i];
                  final bg = _parseColor(t.bgColor, AppColors.background);
                  final tc = _parseColor(t.textColor, AppColors.textDark);
                  final ac = _parseColor(t.accentColor, AppColors.primary);
                  return InkWell(
                    onTap: () => Navigator.pop(context, t),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ac.withValues(alpha: 0.3)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 30, height: 2, color: ac),
                          const SizedBox(height: 14),
                          Text('اسم العروس',
                              style: TextStyle(color: tc, fontWeight: FontWeight.w800, fontSize: 13)),
                          Text('&', style: TextStyle(color: ac, fontWeight: FontWeight.w900, fontSize: 20)),
                          Text('اسم العريس',
                              style: TextStyle(color: tc, fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 14),
                          Container(width: 30, height: 2, color: ac),
                          const SizedBox(height: 14),
                          Text(t.name,
                              style: TextStyle(color: tc.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w700)),
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

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 110, height: 110,
            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.mail_rounded, size: 56, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 18),
          const Text('لم تنشئ دعوات بعد',
              style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 18)),
          const SizedBox(height: 6),
          const Text('صمّم دعوة إلكترونية أنيقة وشاركها بنقرة واحدة',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('إنشاء دعوة'),
          ),
        ]),
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
String _fmtDateTime(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '${_fmtDate(d)} • $h:$mi';
}
