import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/attention.dart';
import '../../widgets/tier_badge.dart';

/// Header card at the top of a customer's account: who they are on one side,
/// what their points are worth on the other, with the two actions they reach
/// for most (edit profile / points wallet).
class CustomerHeroCard extends StatefulWidget {
  const CustomerHeroCard({
    super.key,
    required this.user,
    required this.onEditProfile,
    required this.onOpenPoints,
  });

  final UserModel user;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenPoints;

  @override
  State<CustomerHeroCard> createState() => _CustomerHeroCardState();
}

class _CustomerHeroCardState extends State<CustomerHeroCard> {
  /// Resolved from the user's `city_id` — `auth/me` returns the id only, with
  /// no city relation, so the name has to be looked up separately.
  String? _cityName;

  @override
  void initState() {
    super.initState();
    _loadCity();
  }

  Future<void> _loadCity() async {
    final id = widget.user.cityId;
    if (id == null) return;
    try {
      final cities = await CityService().list();
      final match = cities.where((c) => c.id == id).firstOrNull;
      if (mounted && match != null) setState(() => _cityName = match.name);
    } catch (_) {
      // The card reads fine without it.
    }
  }

  static String _memberSince(DateTime? d) {
    if (d == null) return '';
    return 'مستخدم منذ ${DateFormat('MMMM y', 'ar').format(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final since = _memberSince(u.createdAt);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDF0F3), Color(0xFFF8E3E8)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0D2DA)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // Stacked rather than two columns side by side. As columns, the name had
      // about ninety pixels to live in — every real name arrived as «فؤاد -
      // م…» — while the points half had room to spare, and both buttons were
      // squeezed into what was left. Now the identity gets the full width, the
      // points sit beside it as a small readable badge, and the two actions
      // share a row of their own. Same height as before.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(url: u.avatar, name: u.name, onTap: widget.onEditProfile),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            u.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TierMedal(rewardsTaken: u.rewardsTaken, size: 20),
                      ],
                    ),
                    if (since.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        since,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (_cityName != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              size: 13, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              _cityName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _PointsMini(
                points: u.pointsBalance,
                valueLabel: u.pointsValueLabel,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // The level, and the distance left to the next 50 ₪. The card used
          // to show the balance as a bare number: 6 points says nothing on its
          // own, «باقي 94 نقطة على 50 شيكل» says what it is for.
          TierProgressStrip(
            balance: u.pointsBalance,
            rewardsTaken: u.rewardsTaken,
            onTap: widget.onOpenPoints,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  icon: Icons.person_rounded,
                  label: 'الملف الشخصي',
                  onTap: widget.onEditProfile,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WalletPill(
                  onTap: widget.onOpenPoints,
                  ready: u.pointsBalance >= u.tierGoal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The balance, small enough to sit beside the name: the count and what it is
/// worth on this member's rung. The strip below it says what the number is
/// heading towards; the rewards screen this card taps through to has room for
/// the whole ladder.
class _PointsMini extends StatelessWidget {
  const _PointsMini({required this.points, required this.valueLabel});

  final int points;
  final String valueLabel;

  static const _rose = Color(0xFFD9557B);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFFE8B33D),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_rounded,
                  color: Colors.white, size: 14),
            ),
            const SizedBox(width: 5),
            Text(
              NumberFormat.decimalPattern('en').format(points),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _rose,
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _rose.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            valueLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: _rose,
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, required this.onTap});
  final String? url;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first : '؟';
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: (url?.isNotEmpty ?? false)
                  ? AppNetworkImage(url: url, fallbackIcon: Icons.person_rounded)
                  : Container(
                      color: AppColors.primaryLight,
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
            ),
          ),
          PositionedDirectional(
            bottom: -2,
            start: -2,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.photo_camera_rounded,
                      size: 12, color: AppColors.primaryDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// The points wallet, built to be looked at.
///
/// It used to be an outlined pill identical in weight to «الملف الشخصي», and
/// nothing on the card suggested there was money behind it. Now it is the one
/// filled control in the row, a slow band of light crosses it every few
/// seconds, and the moment a reward is actually claimable it turns gold and
/// says so — an animation that only ever means «there is something here» is
/// noise; this one means «you can collect fifty shekels».
class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.onTap, required this.ready});

  final VoidCallback onTap;
  final bool ready;

  static const _rose = [Color(0xFFE0688C), Color(0xFFC33A63)];
  static const _gold = [Color(0xFFF0C34A), Color(0xFFC98A1E)];

  @override
  Widget build(BuildContext context) {
    final colors = ready ? _gold : _rose;

    final pill = Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: ready ? .5 : .32),
            blurRadius: ready ? 14 : 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ready
                ? Icons.card_giftcard_rounded
                : Icons.account_balance_wallet_rounded,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                ready ? 'استلم 50 شيكل' : 'محفظة النقاط',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        // A claimable reward earns a beat as well as a sweep, and a faster
        // one; the everyday state gets the sweep alone.
        child: NudgePulse(
          enabled: ready,
          child: ShimmerSweep(
            period: Duration(milliseconds: ready ? 2200 : 4200),
            strength: ready ? .7 : .5,
            child: pill,
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: const Color(0xFFEBC9D2),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 5),
              // Scale the label down rather than clipping it: this pill sits
              // in the narrower half of the card, where «عرض الملف الشخصي»
              // used to render as «عرض الملف …». Shrinking keeps the word
              // whole at any device width or system font scale.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
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

// ===========================================================================
// QUICK ACTIONS STRIP
// ===========================================================================

class CustomerQuickAction {
  const CustomerQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Unread/pending count drawn as a red bubble; 0 hides it.
  final int badge;
}

/// The row of shortcuts under the header — scrolls sideways so labels stay
/// readable instead of being squeezed to fit.
class CustomerQuickActions extends StatelessWidget {
  const CustomerQuickActions({super.key, required this.actions});
  final List<CustomerQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 42,
                  color: AppColors.primaryLight.withValues(alpha: 0.6),
                ),
              _QuickTile(action: actions[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.action});
  final CustomerQuickAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: action.onTap,
        child: SizedBox(
          width: 78,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(action.icon, size: 26, color: const Color(0xFFD9557B)),
                    if (action.badge > 0)
                      PositionedDirectional(
                        top: -5,
                        start: -7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(
                            color: AppColors.discount,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            action.badge > 99 ? '99+' : '${action.badge}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
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
