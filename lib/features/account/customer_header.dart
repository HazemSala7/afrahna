import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

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
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // start (right in RTL) — points
          Expanded(
            flex: 42,
            child: _PointsBlock(
              points: u.pointsBalance,
              onTap: widget.onOpenPoints,
            ),
          ),
          Container(
            width: 1,
            height: 96,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFFEBC9D2),
          ),
          // end (left in RTL) — identity
          Expanded(
            flex: 58,
            child: Row(
              children: [
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
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _TierDot(label: u.tierLabel),
                        ],
                      ),
                      if (since.isNotEmpty) ...[
                        const SizedBox(height: 3),
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
                        const SizedBox(height: 4),
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
                      const SizedBox(height: 10),
                      _PillButton(
                        icon: Icons.person_rounded,
                        label: 'عرض الملف الشخصي',
                        onTap: widget.onEditProfile,
                        filled: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _Avatar(url: u.avatar, name: u.name, onTap: widget.onEditProfile),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsBlock extends StatelessWidget {
  const _PointsBlock({required this.points, required this.onTap});
  final int points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'إجمالي نقاطك',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              NumberFormat.decimalPattern('en').format(points),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFFD9557B),
                height: 1.1,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFFE8B33D),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_rounded,
                  color: Colors.white, size: 17),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          '1 نقطة = 1 شيكل',
          style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        _PillButton(
          icon: Icons.account_balance_wallet_rounded,
          label: 'محفظة النقاط',
          onTap: onTap,
          filled: true,
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
      width: 74,
      height: 74,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 74,
            height: 74,
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
                          fontSize: 26,
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
                  width: 26,
                  height: 26,
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
                      size: 14, color: AppColors.primaryDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierDot extends StatelessWidget {
  const _TierDot({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'تصنيف الحساب: $label',
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFFE8B33D),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.star_rounded, size: 12, color: Colors.white),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    const rose = Color(0xFFD9557B);
    return Material(
      color: filled ? Colors.white : Colors.white,
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
              color: filled ? rose : const Color(0xFFEBC9D2),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: filled ? rose : AppColors.textMuted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: filled ? rose : AppColors.textDark,
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
