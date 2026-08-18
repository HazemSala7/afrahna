import 'package:flutter/material.dart';

/// The rewards ladder, mirroring `PointsRules` on the server.
///
/// It lives on the client too because the home screen and the account card
/// show the member's level the moment they open the app — before, and without,
/// a call to `/points/summary`. Everything here is derived from one number the
/// user payload already carries: how many rewards have been cashed out.
///
/// The server stays the authority. Nothing here awards or spends anything; if
/// the two ever disagree, the points screen shows the server's answer.
class RewardsLadder {
  const RewardsLadder._();

  /// What one cash-out pays, in shekels.
  static const int rewardIls = 50;

  /// name, points the level asks for, interactions per point, and the metal
  /// the badge is drawn in.
  static const List<LadderRung> rungs = [
    LadderRung('برونزي', 100, 5, Color(0xFFC17C48), Color(0xFFE0A272)),
    LadderRung('فضي', 200, 7, Color(0xFF9AA5B1), Color(0xFFE3E7EB)),
    LadderRung('ذهبي', 400, 10, Color(0xFFD9A521), Color(0xFFF3D06A)),
    LadderRung('بلاتيني', 800, 15, Color(0xFF6C8EBF), Color(0xFFBBD3EC)),
  ];

  /// The rung a member stands on, decided by cash-outs taken — not by the
  /// balance, which drops back to near zero every time a reward is claimed.
  static LadderRung rungFor(int rewardsTaken) =>
      rungs[rewardsTaken.clamp(0, rungs.length - 1)];

  /// Points needed for the next [rewardIls]. Past the top rung the same level
  /// repeats with the goal doubling each time: 800 → 1600 → 3200 …
  static int goalFor(int rewardsTaken) {
    final last = rungs.length - 1;
    if (rewardsTaken <= last) return rungs[rewardsTaken].goal;
    return rungs[last].goal * (1 << (rewardsTaken - last));
  }

  /// Levels keep counting past بلاتيني, so «المستوى 6 · بلاتيني» stays true.
  static int levelFor(int rewardsTaken) => rewardsTaken + 1;

  /// How far along the current level a balance is, from 0 to 1.
  static double progress(int balance, int rewardsTaken) {
    final goal = goalFor(rewardsTaken);
    return goal <= 0 ? 0 : (balance / goal).clamp(0.0, 1.0);
  }
}

@immutable
class LadderRung {
  const LadderRung(this.name, this.goal, this.perPoint, this.metal, this.sheen);

  final String name;
  final int goal;
  final int perPoint;

  /// The badge's base colour and its highlight, so a bronze medal reads as
  /// bronze rather than as «the brand colour again».
  final Color metal;
  final Color sheen;

  LinearGradient get gradient => LinearGradient(
        colors: [sheen, metal],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      );
}
