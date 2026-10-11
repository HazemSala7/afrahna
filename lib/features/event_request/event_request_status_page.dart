import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/arabic_counts.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/animations.dart';
import 'event_request_models.dart';
import 'event_request_page.dart';
import 'event_request_storage.dart';

/// What the customer sees after «تقديم الطلب»: the request is with the team,
/// and the map of everything their event still needs.
///
/// The review banner and the map are on one scroll rather than two screens.
/// Hiding the map until the team replies would leave the customer with a
/// spinner and nothing to do; showing it immediately means the request is
/// useful the second it is sent, and the team's call only adds to it.
class EventRequestStatusPage extends StatefulWidget {
  const EventRequestStatusPage({super.key});

  @override
  State<EventRequestStatusPage> createState() => _EventRequestStatusPageState();
}

class _EventRequestStatusPageState extends State<EventRequestStatusPage> {
  EventRequest? _request;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await EventRequestStorage.instance.load();
    if (!mounted) return;
    setState(() {
      _request = r;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final r = _request;
    if (r == null) return;
    setState(() {});
    await EventRequestStorage.instance.save(r);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final r = _request;
    if (r == null) return const _NoRequestView();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PinkAppBar(
        title: 'طلبي',
        actions: [
          IconButton(
            tooltip: 'مشاركة الطلب',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => Share.share(r.shareMessage),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'resend') _resend(r);
              if (v == 'new') _startOver();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'resend', child: Text('إعادة إرسال الطلب')),
              PopupMenuItem(value: 'new', child: Text('بدء طلب جديد')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          if (r.stage == RequestStage.underReview)
            FadeSlideIn(child: _reviewBanner(r)),
          if (r.stage == RequestStage.underReview) const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: _summaryCard(r),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: _progressCard(r),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: _stepsCard(r),
          ),
          const SizedBox(height: 18),
          _shareButton(r),
        ],
      ),
    );
  }

  // ---- banner --------------------------------------------------------------

  Widget _reviewBanner(EventRequest r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.brandDeepGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              PulseScale(
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_top_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جاري متابعة طلبك',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'رح تتم مراجعة طلبك من فريق أفراحنا ونتواصل معك قريباً',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _request!.stage = RequestStage.accepted;
                _persist();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                'تم التواصل معي — ابدأ المتابعة',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- summary -------------------------------------------------------------

  Widget _summaryCard(EventRequest r) {
    final days = r.daysAway;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: kSelectedFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(r.kind.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.kind.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'الرقم المرجعي: ${r.reference}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (days >= 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    days == 0 ? 'اليوم!' : 'باقي ${arabicDays(days)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Fact(icon: Icons.calendar_month_rounded, text: r.dateLabel),
              _Fact(icon: Icons.location_city_rounded, text: r.cityName),
              _Fact(icon: Icons.groups_rounded, text: r.guests.label),
              _Fact(icon: Icons.star_rounded, text: 'مستوى ${r.level.label}'),
              _Fact(
                icon: r.contactTime.icon,
                text: 'التواصل ${r.contactTime.label}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- progress ------------------------------------------------------------

  Widget _progressCard(EventRequest r) {
    final pct = r.progress;
    return _Card(
      child: Row(
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.primaryLight,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primaryDark),
                    ),
                  ),
                  Text(
                    '${(v * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تقدّم إنجاز طلبك',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'خلصت ${r.doneCount} من ${arabicServices(r.steps.length)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'اضغط على أي خدمة تحت لتحدّث حالتها',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- the map -------------------------------------------------------------

  Widget _stepsCard(EventRequest r) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < r.steps.length; i++) ...[
            _StepRow(
              step: r.steps[i],
              onTap: () => _editStep(r.steps[i]),
            ),
            if (i != r.steps.length - 1)
              const Divider(height: 1, indent: 56, endIndent: 14),
          ],
        ],
      ),
    );
  }

  Future<void> _editStep(RequestStep step) async {
    final controller = TextEditingController(text: step.vendorName ?? '');
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _StepEditor(step: step, controller: controller),
      ),
    );
    controller.dispose();
    if (result == true) await _persist();
  }

  // ---- actions -------------------------------------------------------------

  Widget _shareButton(EventRequest r) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: () => Share.share(r.shareMessage),
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.ios_share_rounded, size: 20),
        label: const Text(
          'مشاركة الطلب',
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Future<void> _resend(EventRequest r) async {
    final digits = kEventRequestPhone.replaceAll(RegExp(r'\D'), '');
    await openExternal(Uri.parse(
        'https://wa.me/$digits?text=${Uri.encodeComponent(r.teamMessage)}'));
  }

  Future<void> _startOver() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('بدء طلب جديد؟',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          'رح ينمسح الطلب الحالي وخارطة الإنجاز تبعته من هالجهاز.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.discount),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('امسح وابدأ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await EventRequestStorage.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const EventRequestPage()),
    );
  }
}

// ---------------------------------------------------------------------------
// PIECES
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primaryLight),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryDark),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.onTap});

  final RequestStep step;
  final VoidCallback onTap;

  Color get _tint => switch (step.status) {
        StepStatus.done => const Color(0xFF1B9C5A),
        StepStatus.inProgress => AppColors.primary,
        StepStatus.pending => AppColors.textMuted,
      };

  IconData get _mark => switch (step.status) {
        StepStatus.done => Icons.check_circle_rounded,
        StepStatus.inProgress => Icons.autorenew_rounded,
        StepStatus.pending => Icons.radio_button_unchecked_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final muted = step.status == StepStatus.pending;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(_mark, size: 20, color: _tint),
            const SizedBox(width: 12),
            Icon(
              step.icon,
              size: 18,
              color: muted
                  ? AppColors.textMuted.withValues(alpha: 0.7)
                  : AppColors.primaryDark,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: muted ? FontWeight.w600 : FontWeight.w800,
                      color: muted ? AppColors.textMuted : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.vendorName == null
                        ? step.status.label
                        : '${step.vendorName} · ${step.status.label}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _tint,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded,
                size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// The «تفاصيل» sheet for one line of the map.
class _StepEditor extends StatefulWidget {
  const _StepEditor({required this.step, required this.controller});

  final RequestStep step;
  final TextEditingController controller;

  @override
  State<_StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends State<_StepEditor> {
  late StepStatus _status = widget.step.status;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(widget.step.icon, color: AppColors.primaryDark, size: 22),
                const SizedBox(width: 8),
                Text(
                  widget.step.label,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'الحالة',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                for (final s in StepStatus.values) ...[
                  _StatusOption(
                    status: s,
                    selected: _status == s,
                    onTap: () => setState(() => _status = s),
                  ),
                  if (s != StepStatus.values.last) const SizedBox(height: 7),
                ],
              ],
            ),
            const SizedBox(height: 16),
            AuthLikeField(
              controller: widget.controller,
              label: 'اسم المحل (اختياري)',
              icon: Icons.storefront_rounded,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  widget.step.status = _status;
                  final v = widget.controller.text.trim();
                  widget.step.vendorName = v.isEmpty ? null : v;
                  Navigator.of(context).pop(true);
                },
                child: const Text(
                  'حفظ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final StepStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? kSelectedFill : null,
          color: selected ? null : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.primaryLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              switch (status) {
                StepStatus.done => Icons.check_circle_rounded,
                StepStatus.inProgress => Icons.autorenew_rounded,
                StepStatus.pending => Icons.radio_button_unchecked_rounded,
              },
              size: 19,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Text(
              status.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the page is opened with nothing saved — for instance after
/// «بدء طلب جديد» on another device, or if storage was cleared.
class _NoRequestView extends StatelessWidget {
  const _NoRequestView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const PinkAppBar(title: 'طلبي'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.celebration_outlined,
                  size: 64, color: AppColors.primary.withValues(alpha: 0.45)),
              const SizedBox(height: 14),
              const Text(
                'ما في طلب محفوظ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ابدأ طلب تنظيم مناسبتك وخلّي فريق أفراحنا يرتّبلك كل إشي',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const EventRequestPage()),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('ابدأ الطلب',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
