import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/models/models.dart';
import '../../core/theme.dart';

/// What is being followed: a store order or a service booking.
enum TradeKind { order, booking }

/// Who is reading: the customer who asked, or the shop that answers. The same
/// step reads «أكّد المتجر» to one and «أكّدتَ» to the other.
enum TradeViewer { customer, shop }

/// Where an order or a booking stands, drawn as the road it travels: every
/// step reached lit in gold with the time it happened, the next ones waiting,
/// and — when it was turned down or called off — who did it and why.
///
/// A customer used to see a single coloured pill and nothing else. This is
/// what «following up» looks like on their side: they can see the shop moved,
/// and when.
class TradeTimeline extends StatelessWidget {
  const TradeTimeline({
    super.key,
    required this.kind,
    required this.status,
    this.log = const [],
    this.createdAt,
    this.updatedAt,
    this.viewer = TradeViewer.customer,
  });

  final TradeKind kind;
  final String status;
  final List<StatusEvent> log;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final TradeViewer viewer;

  static const _orderSteps = ['pending', 'confirmed', 'preparing', 'ready', 'completed'];
  static const _bookingSteps = ['pending', 'confirmed', 'completed'];

  List<String> get _steps =>
      kind == TradeKind.order ? _orderSteps : _bookingSteps;

  bool get _closedShort => status == 'cancelled' || status == 'rejected';

  String _stepLabel(String step) {
    switch (step) {
      case 'pending':
        return kind == TradeKind.order ? 'أُرسلت' : 'أُرسل';
      case 'confirmed':
        return 'تأكيد';
      case 'preparing':
        return 'تجهيز';
      case 'ready':
        return 'جاهزة';
      case 'completed':
        return kind == TradeKind.order ? 'تسليم' : 'تنفيذ';
    }
    return step;
  }

  /// When [step] was reached: from the history when the API kept one, else
  /// the best the row itself can say.
  DateTime? _reachedAt(String step) {
    for (final e in log.reversed) {
      if (e.status == step) return e.at;
    }
    if (step == 'pending') return createdAt?.toLocal();
    if (step == status) return updatedAt?.toLocal();
    return null;
  }

  /// How far along the road it got. A cancelled or rejected one stops at the
  /// furthest step its history reached.
  int get _reached {
    final steps = _steps;
    if (!_closedShort) {
      final i = steps.indexOf(status);
      return i < 0 ? 0 : i;
    }
    var best = 0;
    for (final e in log) {
      final i = steps.indexOf(e.status);
      if (i > best) best = i;
    }
    return best;
  }

  /// The name the step that never happened takes: «رُفضت» where «تأكيد»
  /// would have been.
  String get _haltLabel {
    final order = kind == TradeKind.order;
    if (status == 'rejected') return order ? 'رُفضت' : 'رُفض';
    return order ? 'أُلغيت' : 'أُلغي';
  }

  StatusEvent? get _closing {
    for (final e in log.reversed) {
      if (e.status == status) return e;
    }
    return null;
  }

  static String _when(DateTime t) {
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay
        ? DateFormat('h:mm a', 'ar').format(t)
        : DateFormat('d MMM', 'ar').format(t);
  }

  /// One line on what happens next, in the reader's own terms.
  String get _hint {
    final order = kind == TradeKind.order;
    if (viewer == TradeViewer.shop) {
      switch (status) {
        case 'pending':
          return 'بانتظار ردّك — الزبون يتابع الطلب';
        case 'confirmed':
          return order ? 'الخطوة التالية: بدء التجهيز' : 'الحجز مؤكّد — سجّل تنفيذه بعد المناسبة';
        case 'preparing':
          return 'الخطوة التالية: الطلبية جاهزة';
        case 'ready':
          return 'الخطوة التالية: تسليم الطلبية';
        case 'completed':
          return order ? 'تم تسليم الطلبية' : 'تم تنفيذ الحجز';
      }
      return '';
    }
    switch (status) {
      case 'pending':
        return 'بانتظار رد المتجر — سنُعلمك فور ردّه';
      case 'confirmed':
        return order
            ? 'أكّد المتجر طلبيتك — سنُعلمك عند بدء التجهيز'
            : 'حجزك مؤكّد — نتمنى لك مناسبة سعيدة';
      case 'preparing':
        return 'المتجر يجهّز طلبيتك الآن';
      case 'ready':
        return 'طلبيتك جاهزة — تواصل مع المتجر للاستلام';
      case 'completed':
        return order ? 'تم تسليم طلبيتك — شكراً لك' : 'تم تنفيذ حجزك — شاركنا تقييمك';
    }
    return '';
  }

  String _closedBy(StatusEvent? e) {
    final noun = kind == TradeKind.order ? 'الطلبية' : 'الحجز';
    final verb = status == 'rejected' ? 'رفض' : 'ألغى';
    switch (e?.by) {
      case 'customer':
        return viewer == TradeViewer.customer
            ? (status == 'rejected' ? 'رُفض $noun' : 'ألغيتَ $noun')
            : '$verb الزبون $noun';
      case 'vendor':
        return viewer == TradeViewer.shop
            ? (status == 'rejected' ? 'رفضتَ $noun' : 'ألغيتَ $noun')
            : '$verb المتجر $noun';
      case 'admin':
        return '$verb فريق أفراحنا $noun';
    }
    return status == 'rejected' ? 'رُفض $noun' : 'أُلغي $noun';
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final reached = _reached;
    final closing = _closing;

    DateTime? last;
    for (final e in log) {
      if (e.at != null && (last == null || e.at!.isAfter(last))) last = e.at;
    }
    last ??= (status == 'pending' ? createdAt : updatedAt)?.toLocal();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceHigh.withValues(alpha: 0.9),
            AppColors.surfaceHigh.withValues(alpha: 0.5),
          ],
        ),
        border: Border.all(color: AppColors.hairline, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: _StepNode(
                    label: _closedShort && i == reached + 1
                        ? _haltLabel
                        : _stepLabel(steps[i]),
                    time: i <= reached
                        ? _reachedAt(steps[i])
                        : (_closedShort && i == reached + 1
                            ? (closing?.at ?? updatedAt?.toLocal())
                            : null),
                    done: _closedShort
                        ? i <= reached
                        : i < reached || (i == reached && status == 'completed'),
                    current: i == reached && !_closedShort && status != 'completed',
                    halted: _closedShort && i == reached + 1,
                    index: i + 1,
                    leftLit: i > 0 && i <= reached,
                    rightLit: i < steps.length - 1 && i < reached,
                    first: i == 0,
                    last: i == steps.length - 1,
                    when: _when,
                  ),
                ),
              ],
            ],
          ),
          if (_closedShort)
            _ClosedBanner(
              title: _closedBy(closing),
              time: closing?.at ?? updatedAt?.toLocal(),
              note: closing?.note,
              rejected: status == 'rejected',
            )
          else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  status == 'completed'
                      ? Icons.verified_rounded
                      : Icons.radar_rounded,
                  size: 15,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _hint,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      height: 1.3,
                    ),
                  ),
                ),
                if (last != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'آخر تحديث ${_when(last)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.label,
    required this.time,
    required this.done,
    required this.current,
    required this.halted,
    required this.index,
    required this.leftLit,
    required this.rightLit,
    required this.first,
    required this.last,
    required this.when,
  });

  final String label;
  final DateTime? time;
  final bool done;
  final bool current;
  final bool halted;
  final int index;

  /// Whether the road into / out of this step has been travelled. «Left» and
  /// «right» are the reading order's before and after, so they flip with RTL
  /// on their own.
  final bool leftLit;
  final bool rightLit;
  final bool first;
  final bool last;
  final String Function(DateTime) when;

  @override
  Widget build(BuildContext context) {
    const size = 24.0;
    final lit = done || current;

    Widget line(bool on, bool hidden) => Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: hidden
                  ? null
                  : LinearGradient(
                      colors: on
                          ? [AppColors.primary, AppColors.accent]
                          : [AppColors.hairline, AppColors.hairline],
                    ),
              boxShadow: on && !hidden
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
        );

    final Widget dot;
    if (halted) {
      dot = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.discount.withValues(alpha: 0.16),
          border: Border.all(color: AppColors.discount, width: 1.4),
        ),
        child: const Icon(Icons.close_rounded,
            size: 14, color: AppColors.discount),
      );
    } else if (done) {
      dot = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.goldGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.45),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, size: 15, color: AppColors.ink),
      );
    } else if (current) {
      dot = Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.5),
              blurRadius: 12,
            ),
          ],
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent,
          ),
        ),
      );
    } else {
      dot = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline, width: 1.2),
        ),
        child: Text(
          '$index',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            line(leftLit, first),
            dot,
            line(rightLit, last),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: lit || halted ? FontWeight.w800 : FontWeight.w600,
            color: halted
                ? AppColors.discount
                : lit
                    ? AppColors.textDark
                    : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 13,
          child: time == null
              ? null
              : Text(
                  when(time!),
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textMuted,
                  ),
                ),
        ),
      ],
    );
  }
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({
    required this.title,
    required this.time,
    required this.note,
    required this.rejected,
  });

  final String title;
  final DateTime? time;
  final String? note;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final reason = (note ?? '').trim();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.discount.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.discount.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                rejected ? Icons.cancel_rounded : Icons.block_rounded,
                size: 16,
                color: AppColors.discount,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.discount,
                  ),
                ),
              ),
              if (time != null)
                Text(
                  DateFormat('d MMM · h:mm a', 'ar').format(time!),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '«$reason»',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
