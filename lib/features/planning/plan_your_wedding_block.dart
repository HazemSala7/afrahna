import 'package:flutter/material.dart';

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
                  colors: const [
                    Color(0xFF57B3A8),
                    Color(0xFF4FA69C),
                    Color(0xFF2F7C74),
                  ],
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
                  colors: const [
                    Color(0xFF8B5A3C),
                    Color(0xFFB8835A),
                    Color(0xFFD4A373),
                  ],
                  icon: Icons.card_giftcard_rounded,
                  title: 'صمّم كرت فرحك',
                  subtitle: 'اختر قالبك واطلبه من أفراحنا',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InvitationDesignerPage()),
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

class _PlanCompactCard extends StatelessWidget {
  const _PlanCompactCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final List<Color> colors; // [light, base, dark]
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final dark = Color.alphaBlend(
        Colors.black.withValues(alpha: 0.35), colors[1]);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors[1].withValues(alpha: 0.42),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.2),
                  ),
                  child: Icon(icon, color: Colors.white, size: 23),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 9.5)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
            const SizedBox(height: 5),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1.35)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ابدأ الآن',
                      style: TextStyle(
                          color: dark,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_back_rounded, color: dark, size: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
