import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/theme.dart';

/// The cosmos: the living night sky every screen of the app sits in, and the
/// handful of pieces — glass, holographic edges, gold foil — that make the
/// screens on top of it read as instruments rather than web pages.
///
/// Performance is the constraint everything here is built around:
///  - the sky paints into its own layer, so a twinkling star never repaints
///    the page above it;
///  - it redraws at 30 frames a second, which slow-moving light cannot be told
///    apart from 60 at, for half the cost;
///  - it stops altogether when the phone asks for reduced motion, and when the
///    screen it belongs to is covered by another.

// ===========================================================================
// THE SKY
// ===========================================================================

/// One clock for every sky on screen. Each page carries its own sky, and two
/// pages are on screen together during a transition; sharing the clock puts
/// every star in the same place in both, so the sky never visibly jumps.
final Stopwatch _clock = Stopwatch()..start();
double get _now => debugCosmicTime ?? _clock.elapsedMicroseconds / 1e6;

/// Holds the sky at one moment, in seconds. The clock above is a real
/// stopwatch — tests run on a fake one — so a render test sets this to draw
/// the same stars on every run.
@visibleForTesting
double? debugCosmicTime;

/// The moment the sky is held at, or null while it is moving. What anything
/// that moves with the sky (the festival on the home page) reads, so a render
/// test that holds the sky holds all of it.
double? get heldSkyTime => debugCosmicTime;

class _Star {
  const _Star(this.x, this.y, this.radius, this.phase, this.speed,
      this.brightness, this.flare, this.color);

  final double x, y, radius, phase, speed, brightness;
  final bool flare;
  final Color color;
}

/// Seeded, so the constellation is the same on every screen and every launch.
final List<_Star> _stars = () {
  final rnd = math.Random(917);
  // Gold leaf, mostly, with the odd rose and lavender fleck. Nothing white:
  // white on ivory is nothing at all.
  const palette = [
    AppColors.primary,
    AppColors.primary,
    Color(0xFFD9AE8A),
    AppColors.accent,
    AppColors.holoLavender,
    AppColors.holoRose,
  ];
  return List<_Star>.generate(170, (_) {
    final bright = rnd.nextDouble() < 0.07;
    return _Star(
      rnd.nextDouble(),
      rnd.nextDouble(),
      bright ? 1.2 + rnd.nextDouble() * 0.9 : 0.35 + rnd.nextDouble() * 0.75,
      rnd.nextDouble() * math.pi * 2,
      0.4 + rnd.nextDouble() * 1.6,
      bright ? 0.95 : 0.22 + rnd.nextDouble() * 0.55,
      bright,
      palette[rnd.nextInt(palette.length)],
    );
  });
}();

/// A speck of light drifting up through the sky: the wedding in the science
/// fiction — gold dust and petals caught in the light.
class _Mote {
  const _Mote(this.x, this.phase, this.speed, this.size, this.drift,
      this.color, this.sparkle);

  final double x, phase, speed, size, drift;
  final Color color;

  /// A third of them are four-point sparks rather than plain motes.
  final bool sparkle;
}

/// Seeded like the stars, so every screen shows the same drift.
final List<_Mote> _motes = () {
  final rnd = math.Random(613);
  // Champagne is gone: it is lighter than the page it floats on.
  const palette = [
    AppColors.primary,
    AppColors.accent,
    AppColors.holoRose,
    AppColors.holoLavender,
  ];
  return List<_Mote>.generate(
    18,
    (_) => _Mote(
      rnd.nextDouble(),
      rnd.nextDouble(),
      // One full rise takes between 40 and 90 seconds.
      0.011 + rnd.nextDouble() * 0.014,
      0.9 + rnd.nextDouble() * 1.9,
      14 + rnd.nextDouble() * 34,
      palette[rnd.nextInt(palette.length)],
      rnd.nextDouble() < 0.34,
    ),
  );
}();

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.moving, super.repaint});

  final bool moving;

  /// Ivory, warming very slightly towards the bottom of the screen — enough
  /// that the page is not a flat white field, not enough to read as a colour.
  static const _ground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.space, Color(0xFFF7F0EA), Color(0xFFF2E7DE)],
    stops: [0.0, 0.55, 1.0],
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = moving ? _now : 40.0;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = _ground.createShader(rect));

    // Four washes drifting on periods of a couple of minutes: blush across the
    // top, a small gold core on the reading side, lavender low on the other,
    // rose under the bottom bar. Their alpha is a third of what it was on
    // black — a tint laid over ivory darkens the page, and anything stronger
    // reads as a stain rather than light.
    _nebula(canvas, size, 0.30 + 0.06 * math.sin(t * 0.03 + 1),
        0.02 + 0.03 * math.cos(t * 0.04), 0.55, const Color(0x12E0A294));
    _nebula(canvas, size, 0.88 + 0.05 * math.sin(t * 0.05),
        0.07 + 0.04 * math.cos(t * 0.04), 0.34, const Color(0x16C9906B));
    _nebula(canvas, size, 0.08 + 0.05 * math.cos(t * 0.035),
        0.52 + 0.05 * math.sin(t * 0.03), 0.70, const Color(0x0FA68FD8));
    _nebula(canvas, size, 0.62 + 0.06 * math.sin(t * 0.045 + 2),
        1.02 + 0.03 * math.cos(t * 0.05), 0.55, const Color(0x12C08768));

    final dot = Paint();
    final flare = Paint()
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    for (final s in _stars) {
      final twinkle = moving ? 0.55 + 0.45 * math.sin(t * s.speed + s.phase) : 0.8;
      // A third of the strength they had on black. At full alpha a hundred and
      // seventy dark dots on ivory look like dust on a lens, not a sky.
      final a = (s.brightness * twinkle * 0.34).clamp(0.0, 1.0);
      final o = Offset(s.x * size.width, s.y * size.height);
      dot.color = s.color.withValues(alpha: a);
      canvas.drawCircle(o, s.radius, dot);
      if (s.flare) {
        // The few strongest get a four-point glint, like light caught on leaf.
        final len = s.radius * (3 + 3 * twinkle);
        flare.color = s.color.withValues(alpha: a * 0.45);
        canvas.drawLine(o.translate(-len, 0), o.translate(len, 0), flare);
        canvas.drawLine(o.translate(0, -len), o.translate(0, len), flare);
        final halo = Rect.fromCircle(center: o, radius: s.radius * 4.5);
        canvas.drawCircle(
          o,
          s.radius * 4.5,
          Paint()
            ..shader = RadialGradient(colors: [
              s.color.withValues(alpha: a * 0.32),
              s.color.withValues(alpha: 0),
            ]).createShader(halo),
        );
      }
    }

    _veil(canvas, size, t);
    _motesLayer(canvas, size, t);
    _rings(canvas, size, t);
    if (moving) _shootingStar(canvas, size, t);
  }

  /// A slow band crossing the page, like light moving over silk. On black it
  /// was made of white; here it is gold, because a band of white laid on ivory
  /// cannot be seen at all.
  ///
  /// One rectangle and one gradient — the cheapest movement on the screen.
  void _veil(Canvas canvas, Size size, double t) {
    final phase = (t * 0.018) % 1.0;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: const [
            Color(0x00C9906B),
            Color(0x14C9906B),
            Color(0x0DA68FD8),
            Color(0x00C9906B),
          ],
          stops: [
            (phase - 0.35).clamp(0.0, 1.0),
            (phase - 0.12).clamp(0.0, 1.0),
            (phase + 0.12).clamp(0.0, 1.0),
            (phase + 0.35).clamp(0.0, 1.0),
          ],
        ).createShader(rect),
    );
  }

  /// Gold dust rising through the whole page, fading in at the bottom and out
  /// at the top so nothing ever pops.
  void _motesLayer(Canvas canvas, Size size, double t) {
    final dot = Paint();
    final spark = Paint()
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    for (final m in _motes) {
      final cycle = (m.phase + t * m.speed) % 1.0;
      final y = size.height * (1.06 - cycle * 1.12);
      final x = m.x * size.width +
          math.sin(t * 0.45 + m.phase * math.pi * 2) * m.drift;
      // Full strength in the middle of the rise, nothing at either end.
      final fade = math.sin(cycle * math.pi);
      if (fade <= 0.01) continue;
      final a = 0.34 * fade;

      dot.color = m.color.withValues(alpha: a);
      final at = Offset(x, y);
      canvas.drawCircle(at, m.size, dot);

      if (m.sparkle) {
        final len = m.size * 3.4;
        spark.color = m.color.withValues(alpha: a * 0.55);
        canvas.drawLine(at.translate(-len, 0), at.translate(len, 0), spark);
        canvas.drawLine(at.translate(0, -len), at.translate(0, len), spark);
      }
    }
  }

  /// Two interlocking rings drawn in light every thirty-eight seconds: the
  /// sky's toast to the couple. They draw themselves on, hold, and fade.
  void _rings(Canvas canvas, Size size, double t) {
    const period = 38.0, life = 7.0, drawFor = 2.2, fadeFor = 2.0;
    final n = (t / period).floor();
    final local = t - n * period;
    if (local > life) return;

    final rnd = math.Random(n * 104729 + 7);
    final r = size.shortestSide * 0.058;
    // Away from the top, where a screen's title and bar usually sit.
    final c = Offset(
      size.width * (0.2 + rnd.nextDouble() * 0.6),
      size.height * (0.22 + rnd.nextDouble() * 0.42),
    );
    final tilt = (rnd.nextDouble() - 0.5) * 0.5;

    final drawn = Curves.easeOutCubic.transform((local / drawFor).clamp(0.0, 1.0));
    final fade = local > life - fadeFor ? 1 - (local - (life - fadeFor)) / fadeFor : 1.0;
    final a = 0.40 * fade;
    if (a <= 0.01 || drawn <= 0.01) return;

    void ring(Offset at, Color colour) {
      canvas.drawArc(
        Rect.fromCircle(center: at, radius: r),
        -math.pi / 2,
        math.pi * 2 * drawn,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round
          ..color = colour.withValues(alpha: a),
      );
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    canvas.translate(-c.dx, -c.dy);
    ring(c.translate(-r * 0.6, 0), AppColors.accent);
    ring(c.translate(r * 0.6, r * 0.12), AppColors.holoLavender);
    canvas.restore();

    // The point of light that draws them, riding the head of the second ring.
    if (drawn < 1) {
      final angle = -math.pi / 2 + math.pi * 2 * drawn;
      final head = c.translate(r * 0.6, r * 0.12) +
          Offset(math.cos(angle), math.sin(angle)) * r;
      canvas.drawCircle(
          head, 1.8, Paint()..color = AppColors.primaryDark.withValues(alpha: a));
    }
  }

  void _nebula(Canvas canvas, Size size, double fx, double fy, double radius,
      Color color) {
    final c = Offset(fx * size.width, fy * size.height);
    final r = radius * size.longestSide;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  /// One shooting star every nine seconds, each on a path of its own.
  void _shootingStar(Canvas canvas, Size size, double t) {
    const period = 9.0, life = 1.1;
    final n = (t / period).floor();
    final local = t - n * period;
    if (local > life) return;

    final rnd = math.Random(n * 7919 + 13);
    final start = Offset((0.25 + rnd.nextDouble() * 0.75) * size.width,
        rnd.nextDouble() * size.height * 0.45);
    final angle = math.pi * (0.72 + rnd.nextDouble() * 0.12);
    final dir = Offset(math.cos(angle), math.sin(angle));
    final progress = Curves.easeOut.transform(local / life);
    final head = start + dir * (size.shortestSide * 0.7 * progress);
    final tail = head - dir * (90 * (1 - progress * 0.4));
    final fade = 1 - local / life;

    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [
          const Color(0x00C9906B),
          AppColors.primary.withValues(alpha: fade * 0.8),
        ]).createShader(Rect.fromPoints(tail, head)),
    );
    canvas.drawCircle(head, 1.8,
        Paint()..color = AppColors.primaryDark.withValues(alpha: fade));
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.moving != moving;
}

/// The living sky. Fills its parent.
class CosmicBackground extends StatefulWidget {
  const CosmicBackground({super.key});

  @override
  State<CosmicBackground> createState() => _CosmicBackgroundState();
}

class _CosmicBackgroundState extends State<CosmicBackground>
    with SingleTickerProviderStateMixin {
  final _repaint = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  bool _still = false;

  void _tick(Duration elapsed) {
    if (elapsed - _last < const Duration(milliseconds: 33)) return;
    _last = elapsed;
    _repaint.value++;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SkyPainter(moving: !_still, repaint: _repaint),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// The same sky, painted once and never again: what shows behind a route
/// that was not built through the theme (a hand-made [PageRouteBuilder]).
class CosmicBackdrop extends StatelessWidget {
  const CosmicBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SkyPainter(moving: false),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// A page with its own sky behind it, and the scan of light that passes over
/// it as it arrives.
class CosmicPage extends StatelessWidget {
  const CosmicPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CosmicBackground(),
        RepaintBoundary(child: child),
        if (!MediaQuery.disableAnimationsOf(context)) const _ArrivalScan(),
      ],
    );
  }
}

/// A line of light that sweeps down the page once, the moment it opens.
///
/// It is the page saying it has arrived — the same gesture as the intro's
/// scan, at a tenth of the strength, over in under a second. Behind
/// [IgnorePointer] so it never takes a tap meant for the screen underneath.
class _ArrivalScan extends StatefulWidget {
  const _ArrivalScan();

  @override
  State<_ArrivalScan> createState() => _ArrivalScanState();
}

class _ArrivalScanState extends State<_ArrivalScan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ScanPainter(_c),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    if (v <= 0 || v >= 1) return;
    final y = Curves.easeInOutCubic.transform(v) * size.height;
    // Brightest halfway down, gone by the bottom.
    final a = math.sin(v * math.pi) * 0.5;

    final band = Rect.fromLTRB(0, y - 110, size.width, y + 40);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accent.withValues(alpha: 0),
            AppColors.accent.withValues(alpha: 0.11 * a),
            AppColors.accent.withValues(alpha: 0),
          ],
          stops: const [0, 0.73, 1],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..strokeWidth = 1.2
        ..shader = LinearGradient(colors: [
          AppColors.accent.withValues(alpha: 0),
          AppColors.champagne.withValues(alpha: 0.7 * a),
          AppColors.holoLavender.withValues(alpha: 0.5 * a),
          AppColors.accent.withValues(alpha: 0),
        ]).createShader(Rect.fromLTWH(0, y - 1, size.width, 2)),
    );
  }

  @override
  bool shouldRepaint(_ScanPainter old) => false;
}

// ===========================================================================
// MOVING BETWEEN SCREENS
// ===========================================================================

/// Every [MaterialPageRoute] in the app goes through here (via the theme).
///
/// Each page brings its own sky, so a page is opaque and moves as one piece.
/// That is what lets iOS keep its native slide — and with it the swipe from
/// the edge to go back, which a custom transition would take away. Everywhere
/// else the app "warps": the new screen arrives from slightly in front of the
/// glass while the old one recedes into the dark.
class CosmicPageTransitionsBuilder extends PageTransitionsBuilder {
  const CosmicPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final page = CosmicPage(child: child);
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return const CupertinoPageTransitionsBuilder().buildTransitions(
          route, context, animation, secondaryAnimation, page);
    }
    return _Warp(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: page,
    );
  }
}

class _Warp extends StatelessWidget {
  const _Warp({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final arrive = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final leave = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInOutCubic,
    );
    return FadeTransition(
      opacity: arrive,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.07, end: 1).animate(arrive),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(leave),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 0.93).animate(leave),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// GLASS, EDGES, FOIL
// ===========================================================================

/// The hairline round a glass panel: gold at one corner, fading through clear
/// glass and a breath of lavender to gold again at the other — the way light
/// catches the edge of a lens.
class HoloBorderPainter extends CustomPainter {
  const HoloBorderPainter({this.radius = 22, this.width = 1, this.strength = 1});

  final double radius;
  final double width;

  /// 0..1 — how bright the edge is.
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
        rect.deflate(width / 2), Radius.circular(radius));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.55 * strength),
            AppColors.holoRose.withValues(alpha: 0.38 * strength),
            AppColors.holoLavender.withValues(alpha: 0.30 * strength),
            AppColors.primary.withValues(alpha: 0.50 * strength),
          ],
          stops: const [0, 0.35, 0.7, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(HoloBorderPainter old) =>
      old.radius != radius || old.width != width || old.strength != strength;
}

/// A pane of dark glass with a holographic edge.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 22,
    this.glow = false,
    this.tint,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// A gold bloom behind the panel, for the one thing on a screen that matters.
  final bool glow;

  /// Colours the glass, faintly.
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          splashColor: AppColors.primary.withValues(alpha: 0.18),
          highlightColor: AppColors.primary.withValues(alpha: 0.06),
          child: content,
        ),
      );
    }
    return CustomPaint(
      foregroundPainter: HoloBorderPainter(radius: radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              Color.alphaBlend(
                  (tint ?? AppColors.primary).withValues(alpha: 0.06),
                  AppColors.surfaceHigh),
            ],
          ),
          boxShadow: [
            if (glow)
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.18),
                blurRadius: 28,
                spreadRadius: -6,
              ),
            const BoxShadow(
              color: Color(0x1F8E5F4A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: r, child: content),
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.fraction);
  final double fraction;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}

/// Text cast in gold foil, with a slow band of light crossing it.
class GoldFoilText extends StatefulWidget {
  const GoldFoilText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.shimmer = true,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool shimmer;

  @override
  State<GoldFoilText> createState() => _GoldFoilTextState();
}

class _GoldFoilTextState extends State<GoldFoilText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context) || !widget.shimmer;
    if (still) {
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
    final text = Text(
      widget.text,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
      style: (widget.style ?? const TextStyle()).copyWith(color: Colors.white),
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          // The foil has to read on two very different grounds: the ivory
          // page (the wordmark) and a deep warm panel (a card's title). So the
          // sweep never reaches either end of the range — its darkest stop is
          // still lighter than a panel, its lightest still darker than paper.
          colors: const [
            AppColors.primaryDark,
            AppColors.primary,
            Color(0xFFE8BE94),
            Color(0xFFF7DCB8),
            Color(0xFFE8BE94),
            AppColors.primary,
            AppColors.primaryDark,
          ],
          stops: const [0, 0.22, 0.4, 0.5, 0.6, 0.78, 1],
          transform: _SlideGradient(_c.value * 2 - 1),
          tileMode: TileMode.mirror,
        ).createShader(bounds),
        child: child,
      ),
      child: text,
    );
  }
}

/// A ring of holographic light turning slowly round its child: for the avatar
/// or the control that is "live".
class HoloRing extends StatefulWidget {
  const HoloRing({
    super.key,
    required this.child,
    this.size = 64,
    this.stroke = 2.4,
    this.gap = 3,
    this.period = const Duration(seconds: 6),
  });

  final Widget child;
  final double size;
  final double stroke;
  final double gap;
  final Duration period;

  @override
  State<HoloRing> createState() => _HoloRingState();
}

class _HoloRingState extends State<HoloRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period);

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
    final inner = widget.size - 2 * (widget.stroke + widget.gap);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(
                size: Size.square(widget.size),
                painter: _HoloRingPainter(_c.value, widget.stroke),
              ),
            ),
          ),
          SizedBox(
            width: inner,
            height: inner,
            child: ClipOval(child: widget.child),
          ),
        ],
      ),
    );
  }
}

class _HoloRingPainter extends CustomPainter {
  _HoloRingPainter(this.t, this.stroke);
  final double t;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..shader = SweepGradient(
          colors: AppColors.holoStops,
          transform: GradientRotation(t * math.pi * 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HoloRingPainter old) => old.t != t || old.stroke != stroke;
}

/// A thin line of light: gold in the middle, fading out at both ends.
class NeonDivider extends StatelessWidget {
  const NeonDivider({super.key, this.height = 1, this.margin = EdgeInsets.zero});

  final double height;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.primary.withValues(alpha: 0),
            AppColors.accent.withValues(alpha: 0.85),
            AppColors.primary.withValues(alpha: 0),
          ]),
          // No glow: a halo needs a ground darker than the line to spread
          // into, and on ivory it only muddies the line it surrounds.
          boxShadow: const [],
        ),
      ),
    );
  }
}

/// A small call to act inside a card: liquid gold, ink type, a soft glow.
/// Not a button itself — the card around it takes the tap.
class GoldPill extends StatelessWidget {
  const GoldPill({
    super.key,
    required this.label,
    this.icon = Icons.arrow_back_rounded,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 11.5 : 12.5;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16, vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 14,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: size,
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 4),
            Icon(icon, color: AppColors.ink, size: size + 3.5),
          ],
        ],
      ),
    );
  }
}
