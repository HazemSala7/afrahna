import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../auth/login_page.dart';

/// "نقاطي" — the user's rewards screen: balance, where the points came from,
/// where they were spent, and an invite section to earn more.
class PointsPage extends StatefulWidget {
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  Future<PointsSummary>? _future;

  @override
  void initState() {
    super.initState();
    if (context.read<SessionController>().isSignedIn) {
      _future = PointsService().summary();
    }
  }

  void _reload() => setState(() => _future = PointsService().summary());

  IconData _catIcon(String key) {
    switch (key) {
      case 'signup':
        return Icons.person_add_alt_1_rounded;
      case 'invite':
        return Icons.group_add_rounded;
      case 'reel_like':
        return Icons.favorite_rounded;
      case 'reel_comment':
        return Icons.mode_comment_rounded;
      case 'post_like':
        return Icons.thumb_up_rounded;
      case 'post_comment':
        return Icons.comment_rounded;
      case 'review':
        return Icons.star_rounded;
      case 'follow':
        return Icons.storefront_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (!session.isSignedIn) {
      return AppScaffold(
        appBar: const PinkAppBar(title: 'نقاطي'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded,
                    size: 72, color: AppColors.primary),
                const SizedBox(height: 14),
                const Text('سجّل الدخول لعرض نقاطك ومكافآتك',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LoginPage())),
                  child: const Text('تسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppScaffold(
      appBar: const PinkAppBar(title: 'نقاطي'),
      body: FutureBuilder<PointsSummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
                message: snap.error.toString(), onRetry: _reload);
          }
          final s = snap.data!;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                _balanceCard(s),
                const SizedBox(height: 16),
                _inviteCard(s),
                const SizedBox(height: 16),
                _progressSection(s),
                const SizedBox(height: 16),
                _spentSection(s),
                const SizedBox(height: 16),
                _howToRedeem(s),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- Balance hero ------------------------------------------------------

  Widget _balanceCard(PointsSummary s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        gradient: AppColors.brandDeepGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.white, size: 34),
          const SizedBox(height: 8),
          Text(
            '${s.balance}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 46,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text('نقطة',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          // The cash value of the balance, and the rate behind it. Both come
          // from the server, so retuning the rate in the dashboard is enough.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white.withValues(alpha: .35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.payments_rounded,
                    color: Colors.white, size: 17),
                const SizedBox(width: 6),
                Text(
                  'تساوي ${s.valueLabel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'كل ${s.pointsPerShekel} نقاط = 1 شيكل',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          // The balance on its own is a number with nothing to reach for. This
          // is the thing it is heading towards: the first redemption.
          _RedeemMeter(
            balance: s.balance,
            cost: s.redeemCost,
            discount: s.redeemDiscount,
          ),
        ],
      ),
    );
  }

  // ---- Invite friends ----------------------------------------------------

  Widget _inviteCard(PointsSummary s) {
    final code = s.referralCode ?? '';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_add_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('ادعُ أصدقاءك',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        fontSize: 16)),
              ),
              if (s.invitesCount > 0)
                Text('${s.invitesCount} صديق',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'كل ${s.threshold} دعوات = نقطة. شارك كودك وليُدخله صديقك عند التسجيل.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          // Where the invites stand right now — the card asked for ten and
          // never said how many had arrived.
          _EarnRow(
            icon: Icons.card_giftcard_rounded,
            // Not the lifetime total — the header already shows that. This is
            // the count that resets every time a point is won.
            label: 'دعوات نحو النقطة القادمة',
            done: (s.progress['invite'] ?? 0).clamp(0, s.threshold),
            total: s.threshold,
            points: s.breakdown['invite'] ?? 0,
            highlight: (s.progress['invite'] ?? 0) > 0,
          ),
          const SizedBox(height: 6),
          if (code.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _copyCode(code),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: .3)),
                      ),
                      child: Row(
                        children: [
                          Text(code,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 2,
                                  color: AppColors.primaryDark)),
                          const Spacer(),
                          const Icon(Icons.copy_rounded,
                              size: 18, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _shareCode(code),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('مشاركة'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ---- Progress toward the next point ------------------------------------

  /// The interaction categories a point can still be earned in. `signup` is
  /// not here — it is a one-time bonus rather than a counter, and is shown as
  /// an already-finished line. Neither is `invite`: the card above owns it,
  /// next to the code you would share to move it.
  static const _earnable = [
    'post_like',
    'reel_like',
    'post_comment',
    'reel_comment',
    'review',
    'follow',
  ];

  /// «كم باقي لنقطة» — the page used to list only the points already banked,
  /// which said nothing about how close the next one was. Every category now
  /// shows its own counter out of the threshold, with the nearest one first:
  /// seven of ten is a reason to do three more, "1 نقطة" is not.
  Widget _progressSection(PointsSummary s) {
    final t = s.threshold;
    final rows = [
      for (final key in _earnable)
        (
          key: key,
          done: (s.progress[key] ?? 0).clamp(0, t),
          points: s.breakdown[key] ?? 0,
        ),
    ]..sort((a, b) {
        // Closest to the next point first — that is the one worth doing today.
        final byProgress = b.done.compareTo(a.done);
        return byProgress != 0 ? byProgress : b.points.compareTo(a.points);
      });

    final signup = s.breakdown['signup'] ?? 0;
    final nearest = rows.first;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
              icon: Icons.trending_up_rounded, text: 'طريقك للنقطة القادمة'),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              nearest.done > 0
                  ? 'أقرب نقطة لك: ${PointsSummary.categoryLabel(nearest.key)}'
                    ' — باقي ${t - nearest.done}'
                  : 'كل $t تفاعلات = نقطة واحدة',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ),
          if (signup > 0)
            _EarnRow(
              icon: _catIcon('signup'),
              label: PointsSummary.categoryLabel('signup'),
              done: 1,
              total: 1,
              points: signup,
              completedNote: 'مكافأة لمرة واحدة',
            ),
          for (final r in rows)
            _EarnRow(
              icon: _catIcon(r.key),
              label: PointsSummary.categoryLabel(r.key),
              done: r.done,
              total: t,
              points: r.points,
              // Nudge only the row that is actually close, so the highlight
              // means something.
              highlight: r.key == nearest.key && r.done > 0,
            ),
        ],
      ),
    );
  }

  // ---- Spend history -----------------------------------------------------

  Widget _spentSection(PointsSummary s) {
    final df = DateFormat('d MMM y', 'ar');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
              icon: Icons.redeem_rounded, text: 'أين أنفقت نقاطك'),
          const SizedBox(height: 4),
          if (s.redemptions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('لم تستبدل أي نقاط بعد.',
                  style: TextStyle(color: AppColors.textMuted)),
            )
          else
            ...s.redemptions.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          size: 20, color: AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.vendorName ?? 'معلن',
                                style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w700)),
                            if (r.createdAt != null)
                              Text(df.format(r.createdAt!),
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('- ${r.points}',
                          style: const TextStyle(
                              color: AppColors.discount,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ---- How to redeem info ------------------------------------------------

  Widget _howToRedeem(PointsSummary s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_rounded, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'استبدل ${s.redeemCost} نقطة لدى أي معلن للحصول على خصم ${s.redeemDiscount}% — مرة واحدة كل 24 ساعة لكل معلن. اذهب إلى صفحة المعلن واضغط «استبدال النقاط».',
              style: const TextStyle(
                  color: AppColors.textDark, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ---- helpers -----------------------------------------------------------

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      );

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ كود الدعوة')),
    );
  }

  void _shareCode(String code) {
    // Share a LINK, not just the code: it opens the app straight to sign-up
    // when installed, and otherwise lands on a page that sends the friend to
    // the right store (Android or iPhone) with the code on their clipboard.
    // The code stays in the text as a fallback for anyone who types it by hand.
    final link = 'https://afrahna.co/r/$code';
    Share.share(
      'انضم إلى تطبيق أفراحنا 🎉\n'
      'سجّل من هذا الرابط ليصلنا كلانا نقاط:\n$link\n\n'
      'أو أدخل كود الدعوة عند التسجيل: $code',
      subject: 'دعوة أفراحنا',
    );
  }
}

/// How close the balance is to being worth something in a shop.
///
/// Sits on the brand gradient, so it is drawn in white rather than reusing
/// [_Meter], which is built for the light cards below.
class _RedeemMeter extends StatelessWidget {
  const _RedeemMeter({
    required this.balance,
    required this.cost,
    required this.discount,
  });

  final int balance;
  final int cost;
  final int discount;

  @override
  Widget build(BuildContext context) {
    final ready = balance >= cost && cost > 0;
    final value = cost <= 0 ? 0.0 : (balance / cost).clamp(0.0, 1.0);
    final left = cost - balance;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ready ? 'جاهزة للاستبدال' : 'باقي $left نقطة على خصم $discount%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
            Text(
              '$balance من $cost',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .22),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// One way of earning, and how far along it is.
///
/// The count is the point of the row: a bar alone reads as decoration, and
/// "١ نقطة" alone hides that the next one is two likes away.
class _EarnRow extends StatelessWidget {
  const _EarnRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.total,
    this.points = 0,
    this.highlight = false,
    this.completedNote,
  });

  final IconData icon;
  final String label;
  final int done;
  final int total;

  /// Points already banked in this category.
  final int points;

  /// The row closest to its next point, given a little more presence.
  final bool highlight;

  /// Shown instead of the remaining count for one-time bonuses.
  final String? completedNote;

  @override
  Widget build(BuildContext context) {
    final complete = completedNote != null;
    final left = total - done;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(
        horizontal: highlight ? 10 : 0,
        vertical: highlight ? 9 : 5,
      ),
      decoration: highlight
          ? BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: .38),
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 19,
                  color: complete ? AppColors.primaryDark : AppColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (points > 0) ...[
                _Chip(text: '$points نقطة'),
                const SizedBox(width: 6),
              ],
              Text(
                complete ? completedNote! : '$done من $total',
                style: TextStyle(
                  color: highlight ? AppColors.primaryDark : AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // The scale itself: ten steps from nothing to the target, so the
          // distance left is something you can count rather than estimate.
          _StepMeter(
            done: complete ? total : done,
            total: total,
            strong: highlight || complete,
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                complete || left <= 0
                    ? Icons.check_circle_rounded
                    : Icons.flag_outlined,
                size: 13,
                color: complete || left <= 0
                    ? const Color(0xFF2E9E5B)
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _status(complete, left),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: complete || left <= 0
                        ? const Color(0xFF2E9E5B)
                        : (highlight
                            ? AppColors.primaryDark
                            : AppColors.textMuted),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Says plainly whether the target has been reached, because that is the
  /// question the row exists to answer.
  String _status(bool complete, int left) {
    if (complete) return 'اكتمل — نقاطها في رصيدك';
    if (left <= 0) return 'وصلت الهدف — النقطة في رصيدك';
    if (done == 0) return 'لم تبدأ بعد — $total تكفي لنقطة';
    if (left == 1) return 'لم تصل للهدف — باقي واحدة فقط!';
    return 'لم تصل للهدف — باقي $left';
  }
}

/// Ten steps rather than one continuous bar: a filled segment is one like, one
/// invite, one review — a countable thing — so "three left" is visible without
/// reading the number. The segments light up one after another on first paint.
class _StepMeter extends StatelessWidget {
  const _StepMeter({
    required this.done,
    required this.total,
    this.strong = false,
  });

  final int done;
  final int total;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final steps = total.clamp(1, 20);
    final filled = done.clamp(0, steps).toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: filled),
      duration: Duration(milliseconds: 260 + 70 * filled.round()),
      curve: Curves.easeOut,
      builder: (context, v, _) => Row(
        children: [
          for (var i = 0; i < steps; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Container(
                height: strong ? 9 : 8,
                decoration: BoxDecoration(
                  color: v > i
                      ? (strong ? AppColors.primaryDark : AppColors.primary)
                      : AppColors.primaryLight.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small rounded label for a points count.
class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                fontSize: 16)),
      ],
    );
  }
}
