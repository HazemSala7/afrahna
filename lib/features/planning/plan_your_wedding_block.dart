import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../widgets/cosmos.dart';
import '../../widgets/section_header.dart';
import '../invitation/invitation_designer_page.dart';
import '../coordinator/coordinator_page.dart';
import 'planning_hub_page.dart';

/// «خطّطي فرحك» — the coordinator, the card designer, and the tools row.
///
/// It used to be assembled inline in the middle of the home page. It lives on
/// the profile now, where the rest of a member's own planning belongs, and as
/// one widget rather than forty lines of layout inside a list.
class PlanYourWeddingBlock extends StatelessWidget {
  const PlanYourWeddingBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SectionHeader(title: 'خطّطي فرحك', emoji: '✨'),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PlanCompactCard(
                  tint: AppColors.accent,
                  depths: const [Color(0xFF8E5F4A), Color(0xFF4A2C24)],
                  icon: Icons.assignment_rounded,
                  title: 'منسق المناسبة',
                  subtitle: 'خطّطي تفاصيل يومك خطوة بخطوة',
                  badge: 'مميّز',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CoordinatorPage()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlanCompactCard(
                  tint: AppColors.holoRose,
                  depths: const [Color(0xFF9C5560), Color(0xFF4E2B33)],
                  icon: Icons.card_giftcard_rounded,
                  title: 'صمّم كرت فرحك',
                  subtitle: 'اختر قالبك واطلبه من أفراحنا',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvitationDesignerPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const PlanningToolsRow(),
      ],
    );
  }
}

/// Deep glass lit from one corner in the card's own colour, with the icon in
/// a glowing orb and a gold pill to act on.
class _PlanCompactCard extends StatelessWidget {
  const _PlanCompactCard({
    required this.tint,
    required this.depths,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final Color tint;

  /// The glass, from the lit corner to the far one.
  final List<Color> depths;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: const HoloBorderPainter(radius: radius),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: depths,
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.14),
                blurRadius: 22,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Stack(
            children: [
              // The light the card is lit by, pooled behind the icon.
              Positioned(
                top: -40,
                right: -40,
                child: IgnorePointer(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          tint.withValues(alpha: 0.22),
                          tint.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tint.withValues(alpha: 0.12),
                            border: Border.all(
                              color: tint.withValues(alpha: 0.55),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tint.withValues(alpha: 0.3),
                                blurRadius: 14,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            color: Color.lerp(tint, Colors.white, 0.2),
                            size: 23,
                            shadows: [Shadow(color: tint, blurRadius: 10)],
                          ),
                        ),
                        const Spacer(),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.holoLavender.withValues(
                                    alpha: 0.22,
                                  ),
                                  AppColors.holoAqua.withValues(alpha: 0.14),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.holoLavender.withValues(
                                  alpha: 0.45,
                                ),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: AppColors.pearl,
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.pearl,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        // The card is a deep panel, so this is type ON a
                        // panel — not the muted grey of type on the page.
                        color: AppColors.champagne,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 12),
                    const GoldPill(label: 'ابدأ الآن', compact: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
