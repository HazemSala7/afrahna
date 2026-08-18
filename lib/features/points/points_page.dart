import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/arabic_counts.dart';
import '../../core/models/models.dart';
import '../../core/rewards_ladder.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/tier_badge.dart';
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
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    if (context.read<SessionController>().isSignedIn) {
      _future = PointsService().summary();
    }
  }

  // A block body, not an arrow: `=> _future = ...` hands setState a closure
  // whose value is a Future, which Flutter asserts against — pull-to-refresh
  // and claiming a reward both went through here and both threw.
  void _reload() {
    setState(() {
      _future = PointsService().summary();
    });
  }

  IconData _catIcon(String key) {
    switch (key) {
      case 'signup':
        return Icons.person_add_alt_1_rounded;
      case 'invite':
        return Icons.group_add_rounded;
      case 'subscription':
        return Icons.workspace_premium_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'story_comment':
        return Icons.auto_stories_rounded;
      case 'service_comment':
        return Icons.design_services_rounded;
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
                _ladderCard(s),
                const SizedBox(height: 16),
                _dailyCard(s),
                const SizedBox(height: 16),
                _progressSection(s),
                const SizedBox(height: 16),
                _inviteCard(s),
                if (s.rewards.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _rewardsSection(s),
                ],
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
    final left = (s.goal - s.balance).clamp(0, s.goal);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
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
          // The level badge leads: it decides both the goal below it and the
          // price of every interaction further down the page.
          TierChip(rewardsTaken: s.rewardsTaken, onLight: false),
          const SizedBox(height: 12),
          Text(
            '${s.balance}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 46,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          const Text('نقطة',
              style:
                  TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          // The one number that matters: how far it is to the money.
          _RedeemMeter(balance: s.balance, cost: s.goal, rewardIls: s.rewardIls),
          const SizedBox(height: 14),
          if (s.canClaim)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _claiming ? null : () => _claim(s),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _claiming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: AppColors.primaryDark),
                      )
                    : const Icon(Icons.card_giftcard_rounded, size: 20),
                label: Text(
                  _claiming ? 'جارٍ الاستلام…' : 'استلم ${s.rewardIls} شيكل الآن',
                  style:
                      const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            )
          else
            Text(
              'باقي ${arabicPoints(left)} لتحصل على ${s.rewardIls} شيكل',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Future<void> _claim(PointsSummary s) async {
    setState(() => _claiming = true);
    try {
      final message = await PointsService().claimReward();
      if (!mounted) return;
      // Refresh the session too — the account card carries the same balance.
      unawaited(context.read<SessionController>().refreshUser());
      _reload();
      await showDialog<void>(
        context: context,
        builder: (_) => _CelebrationDialog(amount: s.rewardIls, message: message),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  // ---- The ladder --------------------------------------------------------

  /// The four rungs, drawn as one climb. A member who can only see their own
  /// level has no reason to want the next one; laying برونزي → بلاتيني out with
  /// their goals on them is the whole point of having a ladder.
  Widget _ladderCard(PointsSummary s) {
    const rungs = RewardsLadder.rungs;
    final beyond = s.rewardsTaken >= rungs.length;
    final at = s.rewardsTaken.clamp(0, rungs.length - 1);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
              icon: Icons.military_tech_rounded, text: 'مستويات المكافآت'),
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 12),
            child: Text(
              'كل مستوى يمنحك 50 شيكل عند بلوغ هدفه، ثم تنتقل إلى المستوى الذي يليه.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < rungs.length; i++) ...[
                Expanded(
                  child: _Rung(
                    rung: rungs[i],
                    done: i < s.rewardsTaken,
                    current: i == at && !beyond,
                  ),
                ),
                if (i < rungs.length - 1)
                  Container(
                    width: 12,
                    height: 2,
                    margin: const EdgeInsets.only(top: 21),
                    color: i < s.rewardsTaken
                        ? AppColors.primary
                        : AppColors.primaryLight,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _Note(
            icon: Icons.all_inclusive_rounded,
            text: beyond
                ? 'أنت فوق البلاتيني — يتضاعف الهدف مع كل مكافأة، وهدفك الحالي'
                    ' ${s.goal} نقطة مقابل ${s.rewardIls} شيكل.'
                : 'بعد البلاتيني تستمر المكافآت ويتضاعف الهدف في كل مرة'
                    ' (1600، 3200 …) مع بقاء 15 تفاعلاً للنقطة.',
          ),
        ],
      ),
    );
  }

  // ---- Today's limits ----------------------------------------------------

  /// The two rules that decide how fast anyone can climb: three counted
  /// interactions a day, and a thirty-day run that pays in one lump.
  Widget _dailyCard(PointsSummary s) {
    final capLeft = (s.dailyCap - s.dailyUsed).clamp(0, s.dailyCap);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(icon: Icons.today_rounded, text: 'يومك'),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('تفاعلات محتسبة اليوم',
                    style: TextStyle(
                        color: AppColors.textDark, fontWeight: FontWeight.w800)),
              ),
              for (var i = 0; i < s.dailyCap; i++)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < s.dailyUsed
                        ? AppColors.primary
                        : AppColors.primaryLight,
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: .45)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 28),
            child: Text(
              capLeft > 0
                  ? 'يتبقّى لك ${arabicInteractions(capLeft)} اليوم من أصل'
                      ' ${s.dailyCap}.'
                  : 'انتهت تفاعلات اليوم — تعود غداً. تفاعلك يبقى كما هو لكنه لا'
                      ' يضيف نقاطاً.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ),
          const Divider(height: 22),
          Row(
            children: [
              _StreakRing(days: s.streakDays, needed: s.streakNeeded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المواظبة اليومية',
                        style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      s.streakDays >= s.streakNeeded
                          ? 'أتممت الشهر كاملاً! ${s.streakAward} نقطة في طريقها إليك.'
                          : 'افتح التطبيق ${s.streakNeeded} يوماً متتالياً لتنال'
                              ' ${s.streakAward} نقطة دفعة واحدة (3 نقاط عن كل يوم).',
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                          height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Cash-outs already taken -------------------------------------------

  Widget _rewardsSection(PointsSummary s) {
    final df = DateFormat('d MMM y', 'ar');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
              icon: Icons.emoji_events_rounded, text: 'مكافآتك المستلمة'),
          const SizedBox(height: 4),
          ...s.rewards.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المستوى ${r.level} · ${r.tier}',
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
                    Text('${r.amountIls} شيكل',
                        style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              )),
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
            'كل صديق يسجّل بكودك = ${arabicPoints(s.invitePoints)} فوراً، بلا حدّ يومي.'
            ' أسرع طريق للمستوى التالي.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Chip(text: '${arabicPoints(s.invitePoints)} لكل صديق'),
              const SizedBox(width: 8),
              if ((s.breakdown['invite'] ?? 0) > 0)
                _Chip(text: 'جمعت ${arabicPoints(s.breakdown['invite']!)}'),
            ],
          ),
          const SizedBox(height: 10),
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
  /// Earning categories the server already prices, but that nothing in the
  /// app can trigger yet — there is no comment box on a story or a service.
  /// They show as «قريباً» rather than as a bar stuck at zero.
  static const _notYetInApp = {'story_comment', 'service_comment'};

  static const _earnable = [
    'reel_like',
    'post_like',
    'reel_comment',
    'post_comment',
    'story_comment',
    'review',
    'service_comment',
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
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text(
              nearest.done > 0
                  ? 'أقرب نقطة لك: ${PointsSummary.categoryLabel(nearest.key)}'
                      ' — باقي ${t - nearest.done}'
                  : 'في مستوى ${s.tier}: كل ${arabicInteractions(t)} = نقطة واحدة',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ),
          // Each category counts on its own, so the same $t applies seven times
          // over — that is worth saying once rather than leaving it to be
          // inferred from seven identical bars.
          _Note(
            icon: Icons.info_outline_rounded,
            text: 'كل نوع تفاعل له عدّاده الخاص، ويُحتسب لك'
                ' ${arabicInteractions(s.dailyCap)} في اليوم على الأكثر.',
          ),
          const SizedBox(height: 6),
          if (signup > 0)
            _EarnRow(
              icon: _catIcon('signup'),
              label: PointsSummary.categoryLabel('signup'),
              done: 1,
              total: 1,
              points: signup,
              completedNote: 'مكافأة لمرة واحدة',
            ),
          if ((s.breakdown['subscription'] ?? 0) > 0)
            _EarnRow(
              icon: _catIcon('subscription'),
              label: PointsSummary.categoryLabel('subscription'),
              done: 1,
              total: 1,
              points: s.breakdown['subscription']!,
              completedNote: 'مكافأة لمرة واحدة',
            ),
          if ((s.breakdown['streak'] ?? 0) > 0)
            _EarnRow(
              icon: _catIcon('streak'),
              label: PointsSummary.categoryLabel('streak'),
              done: 1,
              total: 1,
              points: s.breakdown['streak']!,
              completedNote: 'مواظبة ${s.streakNeeded} يوماً',
            ),
          for (final r in rows)
            _EarnRow(
              icon: _catIcon(r.key),
              label: PointsSummary.categoryLabel(r.key),
              done: r.done,
              total: t,
              points: r.points,
              soon: _notYetInApp.contains(r.key) && r.done == 0 && r.points == 0,
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
              'يمكنك أيضاً استبدال ${s.redeemCost} نقطة لدى أي معلن مقابل خصم '
              '${s.redeemDiscount}% — مرة كل 24 ساعة لكل معلن. تُخصم من الرصيد نفسه، '
              'فتبتعد قليلاً عن مكافأة الـ${s.rewardIls} شيكل.',
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
    required this.rewardIls,
  });

  final int balance;
  final int cost;
  final int rewardIls;

  @override
  Widget build(BuildContext context) {
    final ready = balance >= cost && cost > 0;
    final value = cost <= 0 ? 0.0 : (balance / cost).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ready ? 'مكافأتك جاهزة 🎉' : 'هدفك: $rewardIls شيكل',
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
              backgroundColor: Colors.black.withValues(alpha: .24),
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
    this.soon = false,
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

  /// The category earns points, but the feature it counts has not shipped yet.
  /// Listed anyway so the ladder is the whole ladder, just visibly dimmed.
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final complete = completedNote != null;
    final left = total - done;

    if (soon) return _soonRow();

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
                _Chip(text: arabicPoints(points)),
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
    if (done == 0) return 'لم تبدأ بعد — ${arabicInteractions(total)} تكفي لنقطة';
    if (left == 1) return 'لم تصل للهدف — باقي واحدة فقط!';
    return 'لم تصل للهدف — باقي $left';
  }

  /// One quiet line: the way to earn is real, the place to do it is not
  /// open yet. A meter stuck at «0 من 7» would just look broken.
  Widget _soonRow() => Opacity(
        opacity: .55,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.textMuted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const _Chip(text: 'قريباً'),
            ],
          ),
        ),
      );
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

/// «نقطة / نقطتان / نقاط» — Arabic does not pluralise by adding an s, and a
/// literal '$n نقطة' gets three of the four cases wrong.
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

/// One rung of the ladder: the metal disc, the name, the goal, and what an
/// interaction is worth once you are standing on it.
class _Rung extends StatelessWidget {
  const _Rung({
    required this.rung,
    required this.done,
    required this.current,
  });

  final LadderRung rung;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final lit = done || current;
    final size = current ? 44.0 : 36.0;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: size,
          height: size,
          margin: EdgeInsets.symmetric(vertical: current ? 0 : 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: lit ? rung.gradient : null,
            color: lit ? null : AppColors.primaryLight.withValues(alpha: .55),
            border:
                current ? Border.all(color: AppColors.primary, width: 2.4) : null,
            boxShadow: current
                ? [
                    BoxShadow(
                      color: rung.metal.withValues(alpha: .45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            done ? Icons.check_rounded : Icons.emoji_events_rounded,
            size: current ? 22 : 17,
            color: lit ? Colors.white : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rung.name,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: current ? FontWeight.w900 : FontWeight.w700,
            color: lit ? AppColors.textDark : AppColors.textMuted,
          ),
        ),
        Text(
          '${rung.goal} نقطة',
          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
        ),
        Text(
          'كل ${arabicInteractions(rung.perPoint)}',
          style: TextStyle(
            fontSize: 10,
            color: current ? AppColors.primaryDark : AppColors.textMuted,
            fontWeight: current ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// How far into the thirty-day run the member is. A ring rather than a bar:
/// it reads as a day counter and takes almost no width beside the text.
class _StreakRing extends StatelessWidget {
  const _StreakRing({required this.days, required this.needed});

  final int days;
  final int needed;

  @override
  Widget build(BuildContext context) {
    final value = needed <= 0 ? 0.0 : (days / needed).clamp(0.0, 1.0);
    return SizedBox(
      width: 54,
      height: 54,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 5,
                backgroundColor: AppColors.primaryLight,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$days',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        height: 1,
                        color: AppColors.textDark)),
                Text('من $needed',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textMuted, height: 1.4)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet aside inside a card — a rule that is worth stating but should not
/// compete with the numbers above it.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: AppColors.textDark, fontSize: 11.8, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cashing out is the moment the whole programme is built around, so it gets
/// its own screen-filling moment rather than a snackbar.
class _CelebrationDialog extends StatelessWidget {
  const _CelebrationDialog({required this.amount, required this.message});

  final int amount;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        decoration: BoxDecoration(
          gradient: AppColors.brandDeepGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .6, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .18),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .5), width: 2),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'مبروك! $amount شيكل',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 21),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('تمام',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
