import 'package:flutter/material.dart';

import '../core/arabic_counts.dart';
import '../core/rewards_ladder.dart';
import '../core/theme.dart';
import 'tier_badge.dart';

/// «مزايا المستويات» — what each rung of the ladder asks for and what it gives.
///
/// A level the member cannot see is a level they cannot want. This lays all
/// four out at once: the one they are standing on opens by default, the ones
/// behind are marked as taken, and the ones ahead show what is waiting there.
///
/// Everything shown is a real rule, not a promise: the goal, the price of a
/// point at that level, the 50 ₪ it pays, and the running total a member has
/// been paid by the time they finish it.
class TierBenefitsCard extends StatefulWidget {
  const TierBenefitsCard({super.key, required this.rewardsTaken});

  final int rewardsTaken;

  @override
  State<TierBenefitsCard> createState() => _TierBenefitsCardState();
}

class _TierBenefitsCardState extends State<TierBenefitsCard> {
  late int _open = widget.rewardsTaken.clamp(0, RewardsLadder.rungs.length - 1);

  @override
  Widget build(BuildContext context) {
    final rungs = RewardsLadder.rungs;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'مزايا المستويات',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                'المستوى ${RewardsLadder.levelFor(widget.rewardsTaken)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 10),
            child: Text(
              'تصعد مستوى في كل مرة تستلم فيها مكافأتك. اضغط أي مستوى لترى ما فيه.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          for (var i = 0; i < rungs.length; i++)
            _TierRow(
              rung: rungs[i],
              index: i,
              rewardsTaken: widget.rewardsTaken,
              open: _open == i,
              onTap: () => setState(() => _open = i),
            ),
          const SizedBox(height: 4),
          _Footnote(rewardsTaken: widget.rewardsTaken),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.rung,
    required this.index,
    required this.rewardsTaken,
    required this.open,
    required this.onTap,
  });

  final LadderRung rung;
  final int index;
  final int rewardsTaken;
  final bool open;
  final VoidCallback onTap;

  bool get _done => index < rewardsTaken;
  bool get _current => index == rewardsTaken;

  /// Shekels in hand once this level is finished — the reason to climb stated
  /// as a running total rather than the same «50 ₪» four times.
  int get _cumulative => RewardsLadder.rewardIls * (index + 1);

  String get _status {
    if (_done) return 'مكتمل';
    if (_current) return 'مستواك الآن';
    return 'قادم';
  }

  Color get _statusColor {
    if (_done) return const Color(0xFF2E9E5B);
    if (_current) return AppColors.primaryDark;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _current
            ? rung.metal.withValues(alpha: .09)
            : AppColors.background.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _current
              ? rung.metal.withValues(alpha: .45)
              : AppColors.primaryLight.withValues(alpha: .8),
          width: _current ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            child: Column(
              children: [
                Row(
                  children: [
                    // Past levels wear a check; the rest wear their metal.
                    Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        TierMedal(rewardsTaken: index, size: 32),
                        if (_done)
                          Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E9E5B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 10, color: Colors.white),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'المستوى ${index + 1} · ${rung.name}',
                            style: TextStyle(
                              fontWeight:
                                  _current ? FontWeight.w900 : FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${rung.goal} نقطة ← ${RewardsLadder.rewardIls} شيكل',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _status,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: _statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: open ? .5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20, color: AppColors.textMuted),
                    ),
                  ],
                ),
                // AnimatedSize over a conditional child, not AnimatedCrossFade:
                // the latter builds both sides always, so a collapsed level
                // would still put its perks in the tree — invisible, but
                // findable, and paid for four times over.
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !open
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        Divider(
                          height: 1,
                          color: rung.metal.withValues(alpha: .25),
                        ),
                        const SizedBox(height: 9),
                        _Perk(
                          icon: Icons.payments_rounded,
                          tint: rung.metal,
                          text: 'اجمع ${arabicPoints(rung.goal)} واستلم'
                              ' ${RewardsLadder.rewardIls} شيكل نقداً.',
                        ),
                        _Perk(
                          icon: Icons.bolt_rounded,
                          tint: rung.metal,
                          text: 'كل ${arabicInteractions(rung.perPoint)} تمنحك نقطة'
                              '${index == 0 ? ' — أسرع معدل في البرنامج' : ''}.',
                        ),
                        _Perk(
                          icon: Icons.savings_rounded,
                          tint: rung.metal,
                          text: 'بإنهاء هذا المستوى تكون قد جمعت'
                              ' $_cumulative شيكل من أفراحنا.',
                        ),
                        _Perk(
                          icon: Icons.group_add_rounded,
                          tint: rung.metal,
                          text: 'دعوة الأصدقاء والمواظبة والاشتراك السنوي'
                              ' تُحتسب كاملة في كل المستويات.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.tint, required this.text});

  final IconData icon;
  final Color tint;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.8,
                height: 1.45,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What happens after the top rung, said once at the bottom rather than
/// pretending بلاتيني is the end of the road.
class _Footnote extends StatelessWidget {
  const _Footnote({required this.rewardsTaken});

  final int rewardsTaken;

  @override
  Widget build(BuildContext context) {
    final beyond = rewardsTaken >= RewardsLadder.rungs.length;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.all_inclusive_rounded,
              size: 15, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              beyond
                  ? 'أنت فوق البلاتيني — المكافآت مستمرة، وهدفك الحالي'
                      ' ${RewardsLadder.goalFor(rewardsTaken)} نقطة.'
                  : 'بعد البلاتيني لا تتوقف المكافآت: يتضاعف الهدف في كل مرة'
                      ' (1600، 3200 …) وتبقى 50 شيكل عن كل مكافأة.',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
