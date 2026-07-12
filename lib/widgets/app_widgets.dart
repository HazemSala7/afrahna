import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Pink gradient app background scaffold.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.padding,
    this.extendBody = false,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final EdgeInsets? padding;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: extendBody,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, Color(0xFFF3E5D2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(0),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Unified premium AppBar used across the app:
/// rose-gold gradient, soft shadow, rounded bottom corners,
/// decorative sparkles, glass back button, optional subtitle.
class PinkAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PinkAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;

  static const double _barHeight = 72;

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final hasLeading = showBack && canPop;
    final hasActions = actions != null && actions!.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFFE6B450),
                Color(0xFFB8835A),
                Color(0xFF8B5A3C),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(26),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(26),
            ),
            child: Stack(
              children: [
                // Decorative sparkle pattern
                const Positioned.fill(child: _AppBarSparkles()),
                // Soft top sheen
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 36,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Thin gold underline
                Positioned(
                  bottom: 0,
                  left: 24,
                  right: 24,
                  child: Container(
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0xCCFFE2B0),
                          Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: _barHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          if (hasLeading)
                            _AppBarGlassButton(
                              icon: Icons.arrow_forward_rounded,
                              onTap: onBack ?? () => Navigator.pop(context),
                            )
                          else
                            const SizedBox(width: 44),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 0.3,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x66000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                if (subtitle != null &&
                                    subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                          alpha: 0.85),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11.5,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (hasActions)
                            IconTheme(
                              data: const IconThemeData(
                                color: Colors.white,
                                size: 22,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: actions!,
                              ),
                            )
                          else
                            const SizedBox(width: 44),
                        ],
                      ),
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

/// Translucent circular button used by [PinkAppBar].
class _AppBarGlassButton extends StatelessWidget {
  const _AppBarGlassButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

/// Subtle sparkle dots pattern for the AppBar background.
class _AppBarSparkles extends StatelessWidget {
  const _AppBarSparkles();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AppBarSparklesPainter());
  }
}

class _AppBarSparklesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 22; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.6 + 0.6;
      final alpha = 0.10 + rng.nextDouble() * 0.18;
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Reusable network image with pink fallback.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    this.url,
    this.fallbackIcon = Icons.image_outlined,
    this.fit = BoxFit.cover,
    this.fallbackColor,
  });

  final String? url;
  final IconData fallbackIcon;
  final BoxFit fit;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final color = fallbackColor ?? AppColors.primaryLight;
    if (url == null || url!.isEmpty) {
      return Container(
        color: color,
        alignment: Alignment.center,
        child: Icon(fallbackIcon, color: AppColors.primary, size: 36),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      placeholder: (_, _) => Container(color: color.withValues(alpha: .4)),
      errorWidget: (_, _, _) => Container(
        color: color,
        alignment: Alignment.center,
        child: Icon(fallbackIcon, color: AppColors.primary, size: 36),
      ),
    );
  }
}

/// Full-screen loading state.
class CenteredLoader extends StatelessWidget {
  const CenteredLoader({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(label!,
                style: const TextStyle(color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// Friendly error widget.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('إعادة المحاولة'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty-state widget.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.inbox_outlined,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pink rating row.
class RatingRow extends StatelessWidget {
  const RatingRow({super.key, required this.rating, this.reviewsCount});

  final double rating;
  final int? reviewsCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded,
            color: Color(0xFFFFB400), size: 18),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        if (reviewsCount != null) ...[
          const SizedBox(width: 4),
          Text('(${reviewsCount!})',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12)),
        ],
      ],
    );
  }
}

/// Subscription-tier verification badge shown next to a vendor's name:
///  - VIP      → a glowing GOLD verified check (premium)
///  - featured → the classic BLUE verified check
///  - neither (normal / no subscription) → nothing
///
/// Kept model-agnostic (takes booleans) so it can be dropped in anywhere.
class TierBadge extends StatelessWidget {
  const TierBadge({
    super.key,
    required this.vip,
    required this.featured,
    this.size = 18,
  });

  final bool vip;
  final bool featured;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (vip) {
      return _ShinyVipBadge(size: size * 1.15);
    }
    if (featured) {
      return Icon(Icons.verified_rounded,
          color: const Color(0xFF1D9BF0), size: size);
    }
    return const SizedBox.shrink();
  }
}

/// VIP badge: a lustrous gold crown inside a glossy black disc with a gold rim,
/// a soft pulsing gold glow and an occasional sparkle.
class _ShinyVipBadge extends StatefulWidget {
  const _ShinyVipBadge({required this.size});
  final double size;

  @override
  State<_ShinyVipBadge> createState() => _ShinyVipBadgeState();
}

/// A royal crown silhouette with curved dips between the points (drawn inside
/// [r]). Reads far more premium than sharp triangles.
Path _crownPath(Rect r) {
  double x(double n) => r.left + n * r.width;
  double y(double n) => r.top + n * r.height;
  return Path()
    ..moveTo(x(0.02), y(1.0)) // band bottom-left
    ..lineTo(x(0.0), y(0.56)) // up the left side of the band
    ..lineTo(x(0.13), y(0.14)) // left point
    ..quadraticBezierTo(x(0.31), y(0.62), x(0.5), y(0.04)) // dip → center point
    ..quadraticBezierTo(x(0.69), y(0.62), x(0.87), y(0.14)) // dip → right point
    ..lineTo(x(1.0), y(0.56)) // down the right side
    ..lineTo(x(0.98), y(1.0)) // band bottom-right
    ..close();
}

/// Positions of the three crown points (for the jewel balls), as fractions.
const List<Offset> _crownPeaks = [
  Offset(0.13, 0.14),
  Offset(0.5, 0.04),
  Offset(0.87, 0.14),
];

class _VipCrownPainter extends CustomPainter {
  _VipCrownPainter(this.glow, this.sweep);
  final double glow; // 0..1 pulsing
  final double sweep; // 0..1 light-sweep position

  static const _gold = LinearGradient(
    colors: [Color(0xFFFFF6C9), Color(0xFFF7C948), Color(0xFFB9791A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // Disc sits in the lower part; a small crown perches on top of it.
    final cc = Offset(w / 2, w * 0.60);
    final r = w * 0.36;

    // Warm gold glow behind the disc — pulses for a lively shine.
    canvas.drawCircle(
      cc,
      r * (1.08 + 0.10 * glow),
      Paint()
        ..color = const Color(0xFFF3B63C).withValues(alpha: 0.40 + 0.55 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * (0.12 + 0.06 * glow)),
    );

    // Glossy black disc.
    canvas.drawCircle(
      cc,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFF3C3C3C), Color(0xFF0A0A0A)],
          center: const Alignment(-0.3, -0.4),
        ).createShader(Rect.fromCircle(center: cc, radius: r)),
    );

    // Gold rim.
    canvas.drawCircle(
      cc,
      r - w * 0.018,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.038
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFF3B8),
            Color(0xFFF7C948),
            Color(0xFFB9791A),
            Color(0xFFFFF3B8),
          ],
        ).createShader(Rect.fromCircle(center: cc, radius: r)),
    );

    // Light sweep gliding across the disc.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: cc, radius: r)));
    final sweepX = cc.dx + (sweep * 2 - 1) * r * 1.7;
    canvas.translate(sweepX, cc.dy);
    canvas.rotate(-0.5);
    final band = Rect.fromCenter(
        center: Offset.zero, width: r * 0.55, height: r * 3);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.38),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.3, 0.5, 0.7],
        ).createShader(band),
    );
    canvas.restore();

    // Royal gold crown perched on top of the disc.
    final cr = Rect.fromLTWH(w * 0.28, w * 0.02, w * 0.44, w * 0.30);
    final crown = _crownPath(cr);
    // Dark outline for definition.
    canvas.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF2A1A02),
    );
    // Gold fill.
    canvas.drawPath(crown, Paint()..shader = _gold.createShader(cr));
    // Glossy top highlight across the band.
    canvas.drawPath(
      crown,
      Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.02)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5],
        ).createShader(cr),
    );

    // Rounded jewel balls on the three points.
    final rj = w * 0.036;
    for (final peak in _crownPeaks) {
      final c = Offset(cr.left + peak.dx * cr.width, cr.top + peak.dy * cr.height);
      canvas.drawCircle(
        c,
        rj,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFFFFDF5), Color(0xFFF3C969)],
            center: Alignment(-0.3, -0.3),
          ).createShader(Rect.fromCircle(center: c, radius: rj)),
      );
      canvas.drawCircle(
        c,
        rj,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.012
          ..color = const Color(0xFF2A1A02),
      );
    }

    // Center gem on the band.
    final gem = Offset(cr.center.dx, cr.top + cr.height * 0.72);
    canvas.drawCircle(
      gem,
      w * 0.03,
      Paint()..color = const Color(0xFFE0353B),
    );
    canvas.drawCircle(
      gem,
      w * 0.03,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.01
        ..color = const Color(0xFF2A1A02),
    );
  }

  @override
  bool shouldRepaint(_VipCrownPainter old) =>
      old.glow != glow || old.sweep != sweep;
}

class _ShinyVipBadgeState extends State<_ShinyVipBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size * 1.35; // room for the small crown above the disc
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final glow = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
        // Light sweep during the first ~40% of each cycle.
        final sweep = Curves.easeInOut.transform((t / 0.4).clamp(0.0, 1.0));
        // Gentle breathing scale.
        final scale = 1.0 + 0.05 * math.sin(t * 2 * math.pi);
        final twinklePhase = (t - 0.55).clamp(0.0, 0.25) / 0.25;
        final twinkle = math.sin(twinklePhase * math.pi);

        return Transform.scale(
          scale: scale,
          child: SizedBox(
          width: d,
          height: d,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                  size: Size(d, d), painter: _VipCrownPainter(glow, sweep)),
              // White check inside the black disc (at y ≈ 0.60d).
              Align(
                alignment: const Alignment(0, 0.22),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: d * 0.32,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 1.5,
                    ),
                  ],
                ),
              ),
              if (twinkle > 0.02)
                Positioned(
                  top: d * 0.0,
                  right: d * 0.08,
                  child: Opacity(
                    opacity: twinkle.clamp(0.0, 1.0),
                    child: Icon(Icons.auto_awesome,
                        color: const Color(0xFFFFF6D6), size: d * 0.2),
                  ),
                ),
            ],
          ),
          ),
        );
      },
    );
  }
}
