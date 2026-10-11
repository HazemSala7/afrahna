import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/animations.dart';
import 'event_request_models.dart';
import 'event_request_status_page.dart';
import 'event_request_storage.dart';

/// The number the completed brief is sent to.
const String kEventRequestPhone = '+972599252493';

/// Fill for a chosen option.
///
/// Not AppColors.brandGradient: that one is cream to soft gold, and the white
/// text these chips use all but vanished on it — the selected option ended up
/// the least readable thing on the screen. This is the deep fill the home cards
/// already use, which white sits on properly.
const LinearGradient kSelectedFill = LinearGradient(
  colors: [AppColors.goldDeep, AppColors.primary],
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
);

/// «نظّم مناسبتك» — the six-step brief a customer fills before the team calls.
///
/// Laid out as numbered cards rather than a wizard with next/back buttons: the
/// whole request is six short questions, and showing them on one scroll lets
/// someone see how much is left and jump back to change an answer. A wizard
/// would hide that and add five taps for no gain.
class EventRequestPage extends StatefulWidget {
  const EventRequestPage({super.key});

  @override
  State<EventRequestPage> createState() => _EventRequestPageState();
}

class _EventRequestPageState extends State<EventRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();

  EventKind? _kind;
  BudgetLevel? _level;
  CityModel? _city;
  DateTime? _date;
  GuestRange? _guests;
  ContactTime _contactTime = ContactTime.evening;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  List<CityModel> _cities = const [];
  bool _citiesFailed = false;
  bool _submitting = false;

  /// Set once the customer has tried to submit, so the red "required" hints on
  /// the choice sections only appear after a failed attempt rather than
  /// scolding someone who has simply not scrolled there yet.
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final list = await CityService().list();
      if (!mounted) return;
      setState(() => _cities = list);
    } catch (_) {
      // The city list is a convenience, not a gate: if it cannot load the
      // customer types their city instead of being blocked from asking.
      if (!mounted) return;
      setState(() => _citiesFailed = true);
    }
  }

  // -------------------------------------------------------------------------
  // COMPLETENESS
  // -------------------------------------------------------------------------

  /// How many of the six steps are answered — drives the header's progress bar.
  int get _answered {
    var n = 0;
    if (_kind != null) n++;
    if (_level != null) n++;
    if (_city != null || _address.text.trim().isNotEmpty) n++;
    if (_date != null) n++;
    if (_guests != null) n++;
    if (_name.text.trim().length >= 2 &&
        _phone.text.replaceAll(RegExp(r'\D'), '').length >= 7) {
      n++;
    }
    return n;
  }

  // -------------------------------------------------------------------------
  // SUBMIT
  // -------------------------------------------------------------------------

  Future<void> _submit() async {
    setState(() => _showErrors = true);

    final formOk = _formKey.currentState?.validate() ?? false;
    final choicesOk =
        _kind != null && _level != null && _date != null && _guests != null;

    if (!formOk || !choicesOk) {
      // Send the customer to the first thing that is missing instead of leaving
      // them to hunt for the red text.
      await _scroll.animateTo(
        choicesOk ? _scroll.position.maxScrollExtent : 0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('في خانات ناقصة — كمّلها عشان نبعت طلبك'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _submitting = true);

    final request = EventRequest(
      kind: _kind!,
      level: _level!,
      cityId: _city?.id,
      cityName: _city?.name ?? _address.text.trim(),
      date: _date!,
      guests: _guests!,
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      contactTime: _contactTime,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: DateTime.now(),
    );

    // Saved before the hand-off: if WhatsApp fails to open, or the customer
    // backs out of it, the request still exists and can be re-sent from the
    // status screen.
    await EventRequestStorage.instance.save(request);

    final digits = kEventRequestPhone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse(
        'https://wa.me/$digits?text=${Uri.encodeComponent(request.teamMessage)}');
    await openExternal(uri);

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const EventRequestStatusPage()),
    );
  }

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            _header(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 140),
              sliver: SliverList.list(children: [
                FadeSlideIn(delay: const Duration(milliseconds: 40), child: _stepKind()),
                const SizedBox(height: 14),
                FadeSlideIn(delay: const Duration(milliseconds: 90), child: _stepLevel()),
                const SizedBox(height: 14),
                FadeSlideIn(delay: const Duration(milliseconds: 140), child: _stepCity()),
                const SizedBox(height: 14),
                FadeSlideIn(delay: const Duration(milliseconds: 190), child: _stepDate()),
                const SizedBox(height: 14),
                FadeSlideIn(delay: const Duration(milliseconds: 240), child: _stepGuests()),
                const SizedBox(height: 14),
                FadeSlideIn(delay: const Duration(milliseconds: 290), child: _stepContact()),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _submitBar(),
    );
  }

  // ---- header --------------------------------------------------------------

  Widget _header() {
    final done = _answered;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 208,
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      title: const Text(
        'تنظيم مناسبتك',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.brandDeepGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.celebration_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'تقديم طلب تنظيم مناسبة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'جاوب ٦ أسئلة قصيرة، وفريق أفراحنا بيرتّبلك كل إشي',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: done / 6),
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 7,
                              backgroundColor: Colors.white24,
                              valueColor:
                                  const AlwaysStoppedAnimation(Color(0xFFFFD9A0)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$done من 6',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- 1. event kind -------------------------------------------------------

  Widget _stepKind() {
    return _Section(
      number: 1,
      title: 'اختر نوع المناسبة',
      subtitle: 'شو المناسبة اللي بدك تنظّمها؟',
      error: _showErrors && _kind == null ? 'لازم تختار نوع المناسبة' : null,
      child: LayoutBuilder(builder: (context, c) {
        // Three across on a phone, more on a wide screen, instead of a fixed
        // count that squeezes the labels on small devices.
        final columns = c.maxWidth > 460 ? 4 : 3;
        const gap = 10.0;
        final tile = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final k in EventKind.values)
              SizedBox(
                width: tile,
                child: _KindTile(
                  kind: k,
                  selected: _kind == k,
                  onTap: () => setState(() => _kind = k),
                ),
              ),
          ],
        );
      }),
    );
  }

  // ---- 2. budget level -----------------------------------------------------

  Widget _stepLevel() {
    return _Section(
      number: 2,
      title: 'تحديد المستوى',
      subtitle: 'اختر المستوى اللي بناسب ميزانيتك',
      error: _showErrors && _level == null ? 'لازم تختار المستوى' : null,
      child: Column(
        children: [
          for (final l in BudgetLevel.values) ...[
            _LevelRow(
              level: l,
              selected: _level == l,
              onTap: () => setState(() => _level = l),
            ),
            if (l != BudgetLevel.values.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ---- 3. city -------------------------------------------------------------

  Widget _stepCity() {
    return _Section(
      number: 3,
      title: 'تحديد المدينة',
      subtitle: 'وين رح تكون المناسبة؟',
      child: _citiesFailed
          ? AuthLikeField(
              controller: _address,
              label: 'اكتب المدينة',
              icon: Icons.location_city_rounded,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'المدينة مطلوبة'
                  : null,
            )
          : _PickerField(
              icon: Icons.location_city_rounded,
              label: 'اختر المدينة',
              value: _city?.name,
              loading: _cities.isEmpty,
              onTap: _cities.isEmpty ? null : _pickCity,
            ),
    );
  }

  Future<void> _pickCity() async {
    final picked = await showModalBottomSheet<CityModel>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SheetList<CityModel>(
        title: 'اختر المدينة',
        items: _cities,
        labelOf: (c) => c.name,
        selected: _city,
      ),
    );
    if (picked != null && mounted) setState(() => _city = picked);
  }

  // ---- 4. date -------------------------------------------------------------

  Widget _stepDate() {
    return _Section(
      number: 4,
      title: 'تحديد تاريخ المناسبة',
      subtitle: 'لو التاريخ لسا مش نهائي اختر التقريبي',
      error: _showErrors && _date == null ? 'لازم تختار التاريخ' : null,
      child: _PickerField(
        icon: Icons.calendar_month_rounded,
        label: 'اختر التاريخ',
        value: _date == null
            ? null
            : '${_date!.year}/${_date!.month.toString().padLeft(2, '0')}/${_date!.day.toString().padLeft(2, '0')}',
        onTap: _pickDate,
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 60)),
      // A wedding is planned forward, never backward: offering past dates only
      // invites a typo nobody notices until the team calls.
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 4),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryDark,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  // ---- 5. guests -----------------------------------------------------------

  Widget _stepGuests() {
    return _Section(
      number: 5,
      title: 'تحديد عدد المدعوين',
      subtitle: 'بيحدّد حجم القاعة والضيافة',
      error: _showErrors && _guests == null ? 'لازم تختار عدد المدعوين' : null,
      child: _PickerField(
        icon: Icons.groups_rounded,
        label: 'اختر عدد المدعوين',
        value: _guests?.label,
        onTap: () async {
          final picked = await showModalBottomSheet<GuestRange>(
            context: context,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => _SheetList<GuestRange>(
              title: 'عدد المدعوين',
              items: GuestRange.values,
              labelOf: (g) => g.label,
              selected: _guests,
            ),
          );
          if (picked != null && mounted) setState(() => _guests = picked);
        },
      ),
    );
  }

  // ---- 6. contact details --------------------------------------------------

  Widget _stepContact() {
    return _Section(
      number: 6,
      title: 'بيانات التواصل',
      subtitle: 'عشان فريقنا يقدر يرجعلك',
      child: Column(
        children: [
          AuthLikeField(
            controller: _name,
            label: 'الاسم الكامل',
            icon: Icons.person_outline_rounded,
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                (v == null || v.trim().length < 2) ? 'الاسم مطلوب' : null,
          ),
          const SizedBox(height: 10),
          AuthLikeField(
            controller: _phone,
            label: 'رقم الجوال',
            icon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            onChanged: (_) => setState(() {}),
            validator: (v) {
              final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
              return s.length < 7 ? 'رقم الجوال غير صحيح' : null;
            },
          ),
          if (!_citiesFailed) ...[
            const SizedBox(height: 10),
            AuthLikeField(
              controller: _address,
              label: 'مكان السكن',
              icon: Icons.home_outlined,
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'مكان السكن مطلوب' : null,
            ),
          ],
          const SizedBox(height: 10),
          AuthLikeField(
            controller: _notes,
            label: 'ملاحظات إضافية (اختياري)',
            icon: Icons.notes_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'وقت التواصل المفضّل',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final t in ContactTime.values) ...[
                Expanded(
                  child: _TimeChip(
                    time: t,
                    selected: _contactTime == t,
                    onTap: () => setState(() => _contactTime = t),
                  ),
                ),
                if (t != ContactTime.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---- submit bar ----------------------------------------------------------

  Widget _submitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: AppColors.primaryDark.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 20),
            label: Text(
              _submitting ? 'جاري الإرسال…' : 'تقديم الطلب',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PIECES
// ---------------------------------------------------------------------------

/// A numbered card. The number is what makes a long form feel finite.
class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.child,
    this.subtitle,
    this.error,
  });

  final int number;
  final String title;
  final String? subtitle;
  final String? error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bad = error != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: bad
              ? AppColors.discount.withValues(alpha: 0.55)
              : AppColors.primaryLight,
          width: bad ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: kSelectedFill,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
          if (bad) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 15, color: AppColors.discount),
                const SizedBox(width: 5),
                Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.discount,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final EventKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected ? kSelectedFill : null,
          color: selected ? null : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.primaryLight,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  kind.icon,
                  size: 26,
                  color: selected ? Colors.white : AppColors.primaryDark,
                ),
                if (selected)
                  const PositionedDirectional(
                    top: -4,
                    end: -8,
                    child: Icon(Icons.check_circle_rounded,
                        size: 14, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              kind.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
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

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final BudgetLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      scale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? kSelectedFill : null,
          color: selected ? null : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.primaryLight,
          ),
        ),
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Icon(
                    i < level.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 17,
                    color: selected
                        ? Colors.white
                        : AppColors.primary.withValues(alpha: 0.85),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  Text(
                    level.hint,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: selected ? 1 : 0,
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.time,
    required this.selected,
    required this.onTap,
  });

  final ContactTime time;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: selected ? kSelectedFill : null,
          color: selected ? null : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.primaryLight,
          ),
        ),
        child: Column(
          children: [
            Icon(time.icon,
                size: 18, color: selected ? Colors.white : AppColors.primaryDark),
            const SizedBox(height: 4),
            Text(
              time.label,
              style: TextStyle(
                fontSize: 11.5,
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

/// A read-only field that opens a picker. Looks like an input so the form reads
/// as one thing, but never shows a keyboard.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? AppColors.primary : AppColors.primaryLight,
            width: filled ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.surface, AppColors.surface],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                filled ? value! : label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: filled ? FontWeight.w800 : FontWeight.w600,
                  color: filled ? AppColors.textDark : AppColors.textMuted,
                ),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet list used by the city and guest-count pickers.
class _SheetList<T> extends StatelessWidget {
  const _SheetList({
    required this.title,
    required this.items,
    required this.labelOf,
    this.selected,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final T? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final isSelected = item == selected;
                  return ListTile(
                    title: Text(
                      labelOf(item),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected ? AppColors.primaryDark : AppColors.textDark,
                        fontSize: 14,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primaryDark, size: 20)
                        : null,
                    onTap: () => Navigator.of(context).pop(item),
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

/// A text field styled like the app's auth inputs.
///
/// The auth [AuthField] is single-line and has no change callback, and this
/// form needs both a notes box and live progress as the customer types — so
/// this mirrors its look rather than bending that widget out of shape.
class AuthLikeField extends StatelessWidget {
  const AuthLikeField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textDirection,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: textDirection,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      style: const TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w600,
        fontSize: 14.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: maxLines > 1,
        labelStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.surface, AppColors.surface],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryDark),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: border(AppColors.primaryLight),
        focusedBorder: border(AppColors.primary, 1.4),
        errorBorder: border(AppColors.discount),
        focusedErrorBorder: border(AppColors.discount, 1.4),
      ),
    );
  }
}
