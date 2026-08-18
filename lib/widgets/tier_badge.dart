import 'package:flutter/material.dart';

import '../core/arabic_counts.dart';
import '../core/rewards_ladder.dart';
import '../core/theme.dart';

/// The member's level, drawn as a struck medal rather than a word.
///
/// One widget for every screen that shows a level — the home card, the account
/// card, the account facts row, the rewards page — so برونزي is the same
/// bronze everywhere and only ever means one thing.
class TierMedal extends StatelessWidget {
  const TierMedal({
    super.key,
    required this.rewardsTaken,
    this.size = 34,
    this.showRing = true,
  });

  final int rewardsTaken;
  final double size;

  /// The thin outer ring. Off when the medal sits inside another badge that
  /// already has an outline of its own.
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final rung = RewardsLadder.rungFor(rewardsTaken);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: rung.gradient,
        border: showRing
            ? Border.all(color: Colors.white.withValues(alpha: .75), width: 1.6)
            : null,
        boxShadow: [
          BoxShadow(
            color: rung.metal.withValues(alpha: .45),
            blurRadius: size * .3,
            offset: Offset(0, size * .1),
          ),
        ],
      ),
      child: Icon(
        Icons.emoji_events_rounded,
        size: size * .52,
        color: Colors.white,
      ),
    );
  }
}

/// Medal + «المستوى 2 · فضي» on a tinted pill. The compact form, for sitting
/// beside a name or inside a dense row.
class TierChip extends StatelessWidget {
  const TierChip({
    super.key,
    required this.rewardsTaken,
    this.onLight = true,
    this.showLevel = true,
  });

  final int rewardsTaken;

  /// Whether it sits on a pale card (dark text) or a coloured one (white text).
  final bool onLight;
  final bool showLevel;

  @override
  Widget build(BuildContext context) {
    final rung = RewardsLadder.rungFor(rewardsTaken);
    final fg = onLight ? AppColors.textDark : Colors.white;
    final label = showLevel
        ? 'المستوى ${RewardsLadder.levelFor(rewardsTaken)} · ${rung.name}'
        : rung.name;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 11, 4),
      decoration: BoxDecoration(
        color: onLight
            ? rung.metal.withValues(alpha: .13)
            : Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: onLight
              ? rung.metal.withValues(alpha: .35)
              : Colors.white.withValues(alpha: .32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TierMedal(rewardsTaken: rewardsTaken, size: 22, showRing: false),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The level and how far the balance has climbed inside it — the chip plus the
/// one sentence that makes a level mean something: what is left to the money.
///
/// Deliberately not a copy of the rewards page's hero. This is the glance
/// version: no claim button, no history, one line and one bar.
class TierProgressStrip extends StatelessWidget {
  const TierProgressStrip({
    super.key,
    required this.balance,
    required this.rewardsTaken,
    this.onTap,
  });

  final int balance;
  final int rewardsTaken;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rung = RewardsLadder.rungFor(rewardsTaken);
    final goal = RewardsLadder.goalFor(rewardsTaken);
    final value = RewardsLadder.progress(balance, rewardsTaken);
    final left = (goal - balance).clamp(0, goal);
    final ready = balance >= goal;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .62),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: rung.metal.withValues(alpha: .28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TierMedal(rewardsTaken: rewardsTaken, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'المستوى ${RewardsLadder.levelFor(rewardsTaken)}'
                          ' · ${rung.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            color: AppColors.textDark,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ready
                              ? 'مكافأتك جاهزة — استلم ${RewardsLadder.rewardIls} شيكل'
                              : 'باقي ${arabicPoints(left)} على ${RewardsLadder.rewardIls} شيكل',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: ready ? FontWeight.w800 : FontWeight.w600,
                            color: ready
                                ? const Color(0xFF2E9E5B)
                                : AppColors.textMuted,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$balance من $goal',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: rung.metal.withValues(alpha: .16),
                    valueColor: AlwaysStoppedAnimation(rung.metal),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
