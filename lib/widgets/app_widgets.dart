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
                              // Directional "back": auto-mirrors to point right
                              // (→) in the app's RTL layout.
                              icon: Icons.arrow_back_rounded,
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
    this.maxDecodeWidth = 1440,
  });

  final String? url;
  final IconData fallbackIcon;
  final BoxFit fit;
  final Color? fallbackColor;

  /// Hard ceiling (in device pixels) for how wide the image is decoded into
  /// memory. Even a full-screen image never needs more than this, so an
  /// oversized (e.g. 4K) source can't blow the image cache and OOM the app.
  final int maxDecodeWidth;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decode at (roughly) the on-screen size rather than the image's full
        // native resolution — a 2160×3840 photo otherwise needs ~33 MB of RAM
        // just to draw, which OOMs low-memory devices.
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final logicalW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        var memWidth = (logicalW * dpr).round();
        if (memWidth > maxDecodeWidth) memWidth = maxDecodeWidth;
        if (memWidth < 1) memWidth = maxDecodeWidth;

        return CachedNetworkImage(
          imageUrl: url!,
          fit: fit,
          memCacheWidth: memWidth,
          placeholder: (_, _) => Container(color: color.withValues(alpha: .4)),
          errorWidget: (_, _, _) => Container(
            color: color,
            alignment: Alignment.center,
            child: Icon(fallbackIcon, color: AppColors.primary, size: 36),
          ),
        );
      },
    );
  }
}

/// Full-screen loading state — uses the branded [AfrahnaLoader].
class CenteredLoader extends StatelessWidget {
  const CenteredLoader({super.key, this.label, this.size = 62});
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(child: AfrahnaLoader(size: size, label: label));
  }
}

/// Professional wedding-themed loading animation used across the whole app:
/// two interlocking rose-gold "wedding rings" with a sweeping shimmer comet
/// and twinkling sparkles. Pure Flutter (no packages) so it stays lightweight.
class AfrahnaLoader extends StatefulWidget {
  const AfrahnaLoader({super.key, this.size = 62, this.label});

  final double size;
  final String? label;

  @override
  State<AfrahnaLoader> createState() => _AfrahnaLoaderState();
}

class _AfrahnaLoaderState extends State<AfrahnaLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loader = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _AfrahnaRingsPainter(_c.value),
        ),
      ),
    );
    if (widget.label == null) return loader;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        loader,
        const SizedBox(height: 14),
        Text(
          widget.label!,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AfrahnaRingsPainter extends CustomPainter {
  _AfrahnaRingsPainter(this.t);

  /// Animation position, 0..1.
  final double t;

  static const _clear = Color(0x00B8835A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, size.height / 2);
    final ringR = w * 0.23;
    final stroke = (w * 0.075).clamp(2.0, 9.0);
    final dx = ringR * 0.72;

    // Two overlapping rings → the classic interlocked wedding-ring silhouette.
    final left = Offset(c.dx - dx, c.dy + ringR * 0.16);
    final right = Offset(c.dx + dx, c.dy - ringR * 0.16);

    // Gentle breathing pulse.
    final pulse = 1 + 0.035 * math.sin(t * 2 * math.pi);
    final rr = ringR * pulse;

    // Faint base rings.
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.primaryLight.withValues(alpha: 0.6);
    canvas.drawCircle(left, rr, base);
    canvas.drawCircle(right, rr, base);

    // Sweeping shimmer "comet" that chases around each ring.
    void comet(Offset center, double phase) {
      final rot = (t + phase) * 2 * math.pi;
      final rect = Rect.fromCircle(center: center, radius: rr);
      final shader = SweepGradient(
        colors: const [
          _clear,
          _clear,
          AppColors.accent,
          AppColors.primary,
          AppColors.primaryDark,
          _clear,
        ],
        stops: const [0.0, 0.55, 0.72, 0.86, 0.965, 1.0],
        transform: GradientRotation(rot),
      ).createShader(rect);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader;
      canvas.drawArc(rect, 0, 2 * math.pi, false, p);
    }

    comet(left, 0.0);
    comet(right, 0.5);

    // Twinkling sparkles around the rings.
    final sparkles = <Offset>[
      Offset(c.dx, c.dy - ringR * 1.85),
      Offset(c.dx + ringR * 2.0, c.dy + ringR * 0.95),
      Offset(c.dx - ringR * 2.0, c.dy + ringR * 1.05),
    ];
    for (var i = 0; i < sparkles.length; i++) {
      final tw = math.sin((t * 2 + i / sparkles.length) * 2 * math.pi) * .5 + .5;
      _sparkle(
        canvas,
        sparkles[i],
        (w * 0.055) * (0.45 + tw * 0.9),
        AppColors.accent.withValues(alpha: 0.25 + tw * 0.65),
      );
    }
  }

  void _sparkle(Canvas canvas, Offset o, double r, Color color) {
    final p = Paint()..color = color;
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _AfrahnaRingsPainter old) => old.t != t;
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
    // Verification mark: VIP = blue, مميّز/featured = green.
    if (vip) {
      return Icon(Icons.verified_rounded,
          color: const Color(0xFF1D9BF0), size: size);
    }
    if (featured) {
      return Icon(Icons.verified_rounded,
          color: const Color(0xFF16A34A), size: size);
    }
    return const SizedBox.shrink();
  }
}
