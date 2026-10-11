import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import 'cosmos.dart';
import 'shell_bottom_nav.dart';

/// The page scaffold: no background of its own — the page's sky shows through
/// (see [CosmicPage]).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.padding,
    this.extendBody = false,
    this.showShellNav = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final EdgeInsets? padding;
  final bool extendBody;

  /// Whether the app's five-tab bar is drawn at the bottom.
  ///
  /// On by default: a pushed screen without it is a dead end whose only exit
  /// is the back arrow, and a reader several screens deep has no way to reach
  /// الرئيسية or حسابي without unwinding the whole pile. Screens that already
  /// pass their own [bottomNavigationBar] keep it — theirs wins — and the few
  /// that are meant to be immersive turn this off explicitly.
  final bool showShellNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: extendBody,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar ??
          (showShellNav ? const ShellBottomNav() : null),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: body,
        ),
      ),
    );
  }
}

/// The app's command bar, used across the app.
///
/// Dark glass with a little of the sky caught inside it — two faint nebulae
/// and a scatter of stars — a band of light that passes slowly across it, a
/// line of neon along its lower edge, and the title cast in gold foil. The
/// name is historical (it was a rose-gold gradient); every screen that used
/// it gets the new bar without a change of its own.
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
  static const BorderRadius _radius =
      BorderRadius.vertical(bottom: Radius.circular(28));

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final hasLeading = showBack && canPop;
    final hasActions = actions != null && actions!.isNotEmpty;
    final titleStyle =
        (Theme.of(context).appBarTheme.titleTextStyle ?? const TextStyle())
            .copyWith(fontSize: 19, fontWeight: FontWeight.w700, height: 1.2);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: _radius,
            boxShadow: [
              BoxShadow(
                color: Color(0x1F8E5F4A),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: _radius,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xF5FFFFFF), Color(0xEDF6EFEA)],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: CustomPaint(painter: _BarSkyPainter()),
                ),
                const Positioned.fill(child: _BarSweep()),
                // The line of neon along the lower edge.
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 0,
                  height: 1.4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.accent.withValues(alpha: 0),
                        AppColors.accent.withValues(alpha: 0.55),
                        AppColors.holoLavender.withValues(alpha: 0.45),
                        AppColors.accent.withValues(alpha: 0),
                      ]),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: _barHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                              children: [
                                GoldFoilText(
                                  title,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: titleStyle,
                                ),
                                if (subtitle != null &&
                                    subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
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
                                color: AppColors.accent,
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

/// A glass orb with a gold rim, used by [PinkAppBar].
class _AppBarGlassButton extends StatelessWidget {
  const _AppBarGlassButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AppColors.accent.withValues(alpha: 0.2),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.16),
                blurRadius: 12,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.accent, size: 21),
        ),
      ),
    );
  }
}

/// A way back for screens that have no app bar to put one in.
///
/// The invitation and the reels feed are full-bleed by design, and both can be
/// pushed straight from a notification — which left the reader stranded on
/// them with no exit. Drop this into the screen's [Stack] and it places itself
/// in the top corner.
///
/// It disappears when there is nothing to go back to, so the same screen can
/// still be used as a tab inside the home shell without growing a dead button.
/// The arrow carries its own scrim because what sits behind it is a photograph
/// or a video, light in one frame and dark in the next.
class OverlayBackButton extends StatelessWidget {
  const OverlayBackButton({super.key, this.onTap});

  /// Defaults to popping the route.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null && !Navigator.of(context).canPop()) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 10, top: 6),
          child: Semantics(
            button: true,
            label: 'رجوع',
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .28),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.black.withValues(alpha: .38),
                clipBehavior: Clip.antiAlias,
                shape: CircleBorder(
                  side: BorderSide(
                      color: AppColors.accent.withValues(alpha: .45)),
                ),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (onTap != null) {
                      onTap!();
                    } else {
                      Navigator.maybePop(context);
                    }
                  },
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    // arrow_back_rounded mirrors itself in RTL, so it points
                    // the way an Arabic reader expects.
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 21,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sky caught inside the command bar: two faint nebulae and a scatter of
/// stars, a few of them with the four-point flare. Painted once.
class _BarSkyPainter extends CustomPainter {
  const _BarSkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    void glow(Offset c, double r, Color color) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    glow(Offset(size.width * 0.9, size.height * 0.1), size.width * 0.45,
        AppColors.primary.withValues(alpha: 0.22));
    glow(Offset(size.width * 0.08, size.height * 0.95), size.width * 0.4,
        AppColors.holoLavender.withValues(alpha: 0.12));

    final rng = math.Random(7);
    final dot = Paint();
    for (var i = 0; i < 30; i++) {
      final o = Offset(
          rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      final r = rng.nextDouble() * 1.1 + 0.3;
      final a = 0.15 + rng.nextDouble() * 0.5;
      dot.color = (i % 5 == 0 ? AppColors.accent : AppColors.pearl)
          .withValues(alpha: a);
      canvas.drawCircle(o, r, dot);
      if (i % 11 == 0) {
        final flare = Paint()
          ..color = AppColors.pearl.withValues(alpha: a * 0.6)
          ..strokeWidth = 0.6;
        canvas.drawLine(o.translate(-4, 0), o.translate(4, 0), flare);
        canvas.drawLine(o.translate(0, -4), o.translate(0, 4), flare);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A slow band of light passing across the command bar, like the scan of an
/// instrument panel. Its own layer, so the bar's text never repaints with it.
class _BarSweep extends StatefulWidget {
  const _BarSweep();

  @override
  State<_BarSweep> createState() => _BarSweepState();
}

class _BarSweepState extends State<_BarSweep>
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
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            // Crosses in the first 40% of the cycle, then rests.
            final t = (_c.value / 0.4).clamp(0.0, 1.0);
            if (t >= 1) return const SizedBox.expand();
            return FractionalTranslation(
              translation:
                  Offset(-1.2 + 2.4 * Curves.easeInOut.transform(t), 0),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1, -0.4),
                    end: Alignment(1, 0.4),
                    colors: [
                      Color(0x00F2CC8F),
                      Color(0x14F7E3C3),
                      Color(0x10C6B3F5),
                      Color(0x00F2CC8F),
                    ],
                    stops: [0.3, 0.48, 0.56, 0.72],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Reusable network image with a violet-glass fallback.
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
    Widget fallback() => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [color, AppColors.surface],
            ),
          ),
          child: Center(
            child: Icon(fallbackIcon,
                color: AppColors.primary.withValues(alpha: 0.75), size: 36),
          ),
        );

    if (url == null || url!.isEmpty) return fallback();
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
          placeholder: (_, _) => Container(color: color.withValues(alpha: .6)),
          errorWidget: (_, _, _) => fallback(),
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

/// The app's loading mark: two interlocked wedding rings drawn in holographic
/// light, a point of light pulsing where they cross, and three particles
/// orbiting them. Pure Flutter (no packages) so it stays lightweight.
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
      duration: const Duration(milliseconds: 2400),
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
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            painter: _AfrahnaRingsPainter(_c.value),
          ),
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

  static const _clear = Color(0x00F7E3C3);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, size.height / 2);
    final ringR = w * 0.22;
    final stroke = (w * 0.065).clamp(2.0, 8.0);
    final dx = ringR * 0.72;

    // Two overlapping rings → the interlocked wedding-ring silhouette.
    final left = Offset(c.dx - dx, c.dy + ringR * 0.16);
    final right = Offset(c.dx + dx, c.dy - ringR * 0.16);

    final pulse = 1 + 0.035 * math.sin(t * 2 * math.pi);
    final rr = ringR * pulse;

    // Faint base rings: glass, not paint.
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.pearl.withValues(alpha: 0.08);
    canvas.drawCircle(left, rr, base);
    canvas.drawCircle(right, rr, base);

    // A comet of holographic light chasing round each ring: a blurred pass for
    // the glow, a crisp one on top.
    void comet(Offset center, double phase) {
      final rect = Rect.fromCircle(center: center, radius: rr);
      final shader = SweepGradient(
        colors: const [
          _clear,
          _clear,
          AppColors.champagne,
          AppColors.holoRose,
          AppColors.holoLavender,
          AppColors.holoAqua,
          _clear,
        ],
        stops: const [0.0, 0.5, 0.64, 0.76, 0.87, 0.965, 1.0],
        transform: GradientRotation((t + phase) * 2 * math.pi),
      ).createShader(rect);
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.8
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, stroke)
          ..shader = shader,
      );
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
    }

    comet(left, 0.0);
    comet(right, 0.5);

    // The point of light where the rings cross.
    final glint = 0.5 + 0.5 * math.sin(t * 4 * math.pi);
    final gr = w * (0.06 + 0.04 * glint);
    canvas.drawCircle(
      c,
      gr * 2.4,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.pearl.withValues(alpha: 0.55 * glint + 0.2),
          AppColors.champagne.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: gr * 2.4)),
    );

    // Three particles in orbit, each at its own speed.
    const orbit = [AppColors.accent, AppColors.holoLavender, AppColors.holoAqua];
    for (var i = 0; i < orbit.length; i++) {
      final a = (t * (1 + i * 0.35) + i / 3) * 2 * math.pi;
      final o = c + Offset(math.cos(a), math.sin(a) * 0.62) * (ringR * 1.95);
      canvas.drawCircle(
          o, w * 0.022, Paint()..color = orbit[i].withValues(alpha: 0.9));
      canvas.drawCircle(
        o,
        w * 0.05,
        Paint()
          ..color = orbit[i].withValues(alpha: 0.25)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, w * 0.03),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AfrahnaRingsPainter old) => old.t != t;
}

/// A glowing orb for the icon of an empty or error state.
class _StateOrb extends StatelessWidget {
  const _StateOrb({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.26),
            color.withValues(alpha: 0.06),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.6, 1],
        ),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(
        icon,
        size: 48,
        color: color,
        shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 18)],
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
            const _StateOrb(
                icon: Icons.cloud_off_rounded, color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
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
            _StateOrb(
              icon: icon ?? Icons.inbox_outlined,
              color: AppColors.holoLavender,
            ),
            const SizedBox(height: 16),
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

/// Star rating row.
class RatingRow extends StatelessWidget {
  const RatingRow({super.key, required this.rating, this.reviewsCount});

  final double rating;
  final int? reviewsCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.star_rounded,
          color: Color(0xFFFFC23D),
          size: 18,
          shadows: [Shadow(color: Color(0x99FFB400), blurRadius: 8)],
        ),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        if (reviewsCount != null) ...[
          const SizedBox(width: 4),
          Text('(${reviewsCount!})',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ],
    );
  }
}

/// Subscription-tier verification badge shown next to a vendor's name:
///  - VIP      → a blue verified check
///  - featured → a green verified check
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
    // Verification mark: VIP = blue, مميّز/featured = green — each with a glow
    // of its own colour so it reads against the dark.
    if (vip) {
      return Icon(Icons.verified_rounded,
          color: const Color(0xFF3AAEFF),
          size: size,
          shadows: const [Shadow(color: Color(0x993AAEFF), blurRadius: 8)]);
    }
    if (featured) {
      return Icon(Icons.verified_rounded,
          color: const Color(0xFF34D17A),
          size: size,
          shadows: const [Shadow(color: Color(0x9934D17A), blurRadius: 8)]);
    }
    return const SizedBox.shrink();
  }
}
