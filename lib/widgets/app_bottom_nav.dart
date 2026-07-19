import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Reusable bottom navigation bar shared by the home shell and other
/// full-screen pages (e.g. vendor profile) so the same bar is always visible.
///
/// Design: a floating, rounded bar with a real notch carved out of the top
/// edge, and the centre "الرئيسية" tab lifted out into a glowing gradient
/// circle that floats above the bar.
///
/// In an RTL Row the first child renders at the visual RIGHT, so the visual
/// order left→right is: بحث | ريلز | الرئيسية | المفضلة | حسابي.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current, required this.onTap});

  /// Index of the active tab, or -1 when no tab should appear selected.
  final int current;
  final ValueChanged<int> onTap;

  static const items = <AppNavItem>[
    AppNavItem('حسابي', Icons.person_outline_rounded, Icons.person_rounded),
    AppNavItem('خطّطي', Icons.auto_awesome_outlined,
        Icons.auto_awesome_rounded),
    AppNavItem('الرئيسية', Icons.home_rounded, Icons.home_rounded),
    AppNavItem('ريلز', Icons.movie_filter_outlined,
        Icons.movie_filter_rounded),
    AppNavItem('بحث', Icons.search_rounded, Icons.search_rounded),
  ];

  // Index of the centre tab that floats above the bar.
  static const int _centerIndex = 2;

  static const double _fabSize = 64;
  // Slightly smaller than the fab's outer radius so the button fully covers
  // the cut-out — no page content peeks through the ring.
  static const double _notchRadius = 35;
  static const double _barHeight = 66;

  /// Vertical space the bar occupies above the system gesture inset (the bar
  /// itself plus the floating button's overhang). Pages that use
  /// `extendBody: true` must reserve at least this much bottom padding (plus
  /// `MediaQuery.padding.bottom`) so scrolling content isn't hidden behind it.
  static const double contentHeight = _barHeight + _fabSize / 2;

  @override
  Widget build(BuildContext context) {
    // How far the floating circle pokes above the bar's top edge.
    const poke = _fabSize / 2;
    // The bar itself extends under the system gesture inset for a clean edge.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return MediaQuery.withClampedTextScaling(
      // Keep the fixed-height bar from overflowing when the device uses a
      // large system font scale.
      maxScaleFactor: 1.15,
      child: SizedBox(
      height: _barHeight + poke + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ---- The notched bar, anchored full-width to the bottom --------
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PhysicalShape(
              clipper: const _NotchedBarClipper(
                notchRadius: _notchRadius,
                topRadius: 26,
              ),
              color: Colors.white,
              elevation: 14,
              shadowColor: AppColors.primaryDark.withValues(alpha: 0.20),
              child: SizedBox(
                height: _barHeight + bottomInset,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Row(
                    children: [
                      // RTL: first child = visual right.
                      _side(0),
                      _side(1),
                      const SizedBox(width: _notchRadius * 2),
                      _side(3),
                      _side(4),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ---- Centre label, tucked below the notch ----------------------
          Positioned(
            bottom: bottomInset + 8,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                items[_centerIndex].label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: current == _centerIndex
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
              ),
            ),
          ),

          // ---- Centre floating "home" button, poking above the bar -------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _CenterFab(
                item: items[_centerIndex],
                active: current == _centerIndex,
                size: _fabSize,
                onTap: () => onTap(_centerIndex),
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _side(int i) => Expanded(
        child: _SideNavButton(
          item: items[i],
          active: current == i,
          onTap: () => onTap(i),
        ),
      );
}

class AppNavItem {
  const AppNavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

// ===========================================================================
// SIDE TABS
// ===========================================================================

class _SideNavButton extends StatelessWidget {
  const _SideNavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final AppNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active icon lifts slightly and brightens.
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, active ? -2 : 0, 0),
              child: Icon(
                active ? item.activeIcon : item.icon,
                color: active ? AppColors.primary : AppColors.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            // A little glowing dot under the active tab.
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: active ? 6 : 0,
              height: active ? 6 : 0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// CENTRE FLOATING BUTTON
// ===========================================================================

class _CenterFab extends StatelessWidget {
  const _CenterFab({
    required this.item,
    required this.active,
    required this.size,
    required this.onTap,
  });

  final AppNavItem item;
  final bool active;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.accent, AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          // Ring in the page background colour so the notch reads as a clean cut.
          border: Border.all(color: AppColors.background, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: active ? 0.5 : 0.35),
              blurRadius: active ? 18 : 13,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          item.activeIcon,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

// ===========================================================================
// NOTCHED BAR SHAPE
// ===========================================================================

/// Clips the bar into a rounded rectangle with a circular notch carved out of
/// the centre of the top edge (where the floating button nests).
class _NotchedBarClipper extends CustomClipper<Path> {
  const _NotchedBarClipper({
    required this.notchRadius,
    required this.topRadius,
  });

  final double notchRadius;
  final double topRadius;

  @override
  Path getClip(Size size) {
    final host = Offset.zero & size;
    final guest = Rect.fromCircle(
      center: Offset(size.width / 2, 0),
      radius: notchRadius,
    );
    final notched = const CircularNotchedRectangle().getOuterPath(host, guest);
    final rounded = Path()
      ..addRRect(RRect.fromRectAndCorners(
        host,
        topLeft: Radius.circular(topRadius),
        topRight: Radius.circular(topRadius),
      ));
    return Path.combine(PathOperation.intersect, notched, rounded);
  }

  @override
  bool shouldReclip(_NotchedBarClipper oldClipper) =>
      oldClipper.notchRadius != notchRadius ||
      oldClipper.topRadius != topRadius;
}
