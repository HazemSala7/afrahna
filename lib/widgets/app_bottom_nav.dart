import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import 'cosmos.dart';

/// The app's five-tab dock, shared by the home shell and every screen pushed on
/// top of it, so the same way out is always in the same place.
///
/// A capsule of dark glass floating a hand's width above the bottom of the
/// screen, the sky visible round it. The active tab lights its icon in gold
/// and draws a pill of holographic light under it; the centre «الرئيسية» is a
/// gold orb inside a slowly turning ring of holographic light, which breathes
/// when home is the screen you are on.
///
/// In an RTL Row the first child renders at the visual RIGHT, so the visual
/// order left→right is: المتجر | ريلز | الرئيسية | خطّطي | حسابي.
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
    // Stories moved to a rail at the top of the home tab; this slot now holds
    // the marketplace, which needs a permanent entry point.
    AppNavItem('المتجر', Icons.storefront_outlined, Icons.storefront_rounded),
  ];

  // Index of the highlighted centre tab.
  static const int _centerIndex = 2;

  static const double _barHeight = 64;

  /// How far the home orb rises above the dock's top edge.
  static const double _poke = 18;

  /// Gap between the dock and the bottom of the screen: the dock floats.
  static const double _float = 10;

  /// Diameter of the centre orb, ring included.
  static const double _orbSize = 62;

  /// Vertical space the dock occupies above the system gesture inset. Pages
  /// that use `extendBody: true` reserve this much bottom padding so content
  /// clears the dock (and the raised orb).
  static const double contentHeight = _barHeight + _poke + _float;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return MediaQuery.withClampedTextScaling(
      // Keep the fixed-height dock from overflowing when the device uses a
      // large system font scale.
      maxScaleFactor: 1.15,
      child: SizedBox(
        height: contentHeight + bottomInset,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ---- the glass dock ----
            Positioned(
              left: 14,
              right: 14,
              bottom: _float + bottomInset,
              height: _barHeight,
              child: _GlassDock(
                child: Row(
                  children: [
                    // RTL: first child = visual right.
                    _side(0),
                    _side(1),
                    // Centre slot: just the label — the orb floats above it.
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            items[_centerIndex].label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: current == _centerIndex
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _side(3),
                    _side(4),
                  ],
                ),
              ),
            ),
            // ---- the centre orb, rising out of the dock ----
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _CenterOrb(
                  item: items[_centerIndex],
                  active: current == _centerIndex,
                  size: _orbSize,
                  onTap: () => _tap(_centerIndex),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _tap(int i) {
    HapticFeedback.selectionClick();
    onTap(i);
  }

  Widget _side(int i) => Expanded(
        child: _SideNavButton(
          item: items[i],
          active: current == i,
          onTap: () => _tap(i),
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
// THE DOCK
// ===========================================================================

/// Frosted dark glass with a holographic rim and a line of gold light along
/// its top edge. The blur is paid for once, here — never per list item.
class _GlassDock extends StatelessWidget {
  const _GlassDock({required this.child});
  final Widget child;

  static const _radius = 30.0;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(_radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          const BoxShadow(
            color: Color(0x268E5F4A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.13),
            blurRadius: 30,
            spreadRadius: -8,
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter:
            const HoloBorderPainter(radius: _radius, width: 1.1),
        child: ClipRRect(
          borderRadius: r,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surface.withValues(alpha: 0.92),
                    AppColors.surfaceHigh.withValues(alpha: 0.96),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // The line of light along the top edge.
                  Positioned(
                    top: 0,
                    left: 40,
                    right: 40,
                    height: 1.2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.accent.withValues(alpha: 0),
                          AppColors.accent.withValues(alpha: 0.35),
                          AppColors.accent.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                  Positioned.fill(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      splashColor: AppColors.accent.withValues(alpha: 0.14),
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The active icon lifts, turns gold and glows.
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            transform: Matrix4.translationValues(0, active ? -2 : 0, 0),
            child: Icon(
              active ? item.activeIcon : item.icon,
              color: active ? AppColors.accent : AppColors.textMuted,
              size: 24,
              shadows: active
                  ? [
                      Shadow(
                        color: AppColors.accent.withValues(alpha: 0.8),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? AppColors.textDark : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          // A pill of holographic light under the active tab.
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: active ? 18 : 0,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(colors: AppColors.holoStops),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.holoLavender.withValues(alpha: 0.7),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// CENTRE ORB
// ===========================================================================

/// The raised home orb: gold at its core, held in a ring of holographic light
/// that turns slowly — and breathes, when home is where you are.
class _CenterOrb extends StatefulWidget {
  const _CenterOrb({
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
  State<_CenterOrb> createState() => _CenterOrbState();
}

class _CenterOrbState extends State<_CenterOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        selected: widget.active,
        label: widget.item.label,
        child: SizedBox(
          width: size,
          height: size,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                // Seven breaths a turn when active; still otherwise.
                final breath = widget.active
                    ? 0.5 + 0.5 * math.sin(_c.value * math.pi * 14)
                    : 0.0;
                return CustomPaint(
                  painter: _OrbRingPainter(_c.value, breath),
                  child: Center(
                    child: Container(
                      width: size - 14,
                      height: size - 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.35, -0.45),
                          radius: 1.05,
                          colors: [
                            AppColors.champagne,
                            AppColors.primary,
                            AppColors.goldDeep,
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: 0.45 + 0.25 * breath),
                            blurRadius: 18 + 12 * breath,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.item.activeIcon,
                        color: AppColors.pearl,
                        size: 25,
                        shadows: const [
                          Shadow(color: Color(0x66000000), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbRingPainter extends CustomPainter {
  _OrbRingPainter(this.t, this.breath);
  final double t;
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;

    // A gap between the orb and its ring, so the ring reads as separate. It
    // is the page's own ground, so the ring looks cut out of the bar.
    canvas.drawCircle(c, r - 1.5, Paint()..color = AppColors.background);

    final rect = Rect.fromCircle(center: c, radius: r);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = SweepGradient(
        colors: AppColors.holoStops,
        transform: GradientRotation(t * math.pi * 2),
      ).createShader(rect);
    // Soft outer glow first, then the crisp ring on top of it.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 4 + 3 * breath)
        ..shader = ring.shader,
    );
    canvas.drawCircle(c, r, ring);
  }

  @override
  bool shouldRepaint(_OrbRingPainter old) =>
      old.t != t || old.breath != breath;
}
