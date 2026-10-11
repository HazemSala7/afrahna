/// The festival: what the home page adds to the sky to say "a wedding is a
/// celebration" — an aurora breathing behind the header with the odd soft
/// firework, stories on a lit orbit, categories cut as holographic crystals,
/// the hero slider framed as a portal with a bead of light circling it,
/// shops that levitate, constellation lines under the titles, and a burst of
/// light confetti the first time the page opens.
///
/// Built like the sky underneath it: one clock for everything, ticking at 30
/// frames a second only while the page is on screen, held still under
/// reduced motion and in render tests; every moving thing in its own repaint
/// boundary, so a firework never repaints a list of shops.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/theme.dart';
import 'cosmos.dart' show heldSkyTime;

// ===========================================================================
// THE CLOCK
// ===========================================================================

/// One clock for every festive thing on a page. Put it once above them;
/// each reads the time with [FestivalClock.of] and rebuilds through a
/// [ListenableBuilder], so a hundred shimmering tiles cost one ticker.
///
/// The time is seconds since the page was built — or, in a render test,
/// whatever [heldSkyTime] holds, so every frame is the same frame.
class FestivalClock extends StatefulWidget {
  const FestivalClock({super.key, required this.child});

  final Widget child;

  /// The page's clock, in seconds. Reading it outside a [FestivalClock]
  /// gives a clock stopped at the test moment, so a piece used alone still
  /// draws, only without moving.
  static ValueListenable<double> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FestivalScope>();
    return scope?.time ?? _stillClock;
  }

  static final ValueNotifier<double> _stillClock = ValueNotifier<double>(40);

  @override
  State<FestivalClock> createState() => _FestivalClockState();
}

class _FestivalClockState extends State<FestivalClock>
    with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(heldSkyTime ?? 0);
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  void _tick(Duration elapsed) {
    // 30 a second: slow light cannot be told apart from 60, at half the cost.
    if (elapsed - _last < const Duration(milliseconds: 33)) return;
    _last = elapsed;
    _time.value = elapsed.inMicroseconds / 1e6;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        heldSkyTime != null || MediaQuery.disableAnimationsOf(context);
    if (still) {
      if (_ticker.isActive) _ticker.stop();
      _time.value = heldSkyTime ?? 40;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _FestivalScope(time: _time, child: widget.child);
}

class _FestivalScope extends InheritedWidget {
  const _FestivalScope({required this.time, required super.child});

  final ValueListenable<double> time;

  @override
  bool updateShouldNotify(_FestivalScope old) => old.time != time;
}

/// Rebuilds [builder] on every tick of the page's clock.
class _OnClock extends StatelessWidget {
  const _OnClock({required this.builder});

  final Widget Function(BuildContext context, double t) builder;

  @override
  Widget build(BuildContext context) {
    final clock = FestivalClock.of(context);
    return ListenableBuilder(
      listenable: clock,
      builder: (context, _) => builder(context, clock.value),
    );
  }
}

/// The festival's light. Rose gold, pearl, a breath of lavender: the sky's
/// own palette, so the festival belongs to the page it is on.
const List<Color> _lights = [
  AppColors.primary,
  AppColors.holoRose,
  AppColors.accent,
  AppColors.holoLavender,
  AppColors.champagne,
];

/// A stable number in [0, 1) from an integer, for anything that must look
/// random yet be the same on every frame and every launch.
double _hash(int n) {
  var x = (n * 2654435761) & 0x7fffffff;
  x ^= x >> 13;
  x = (x * 1274126177) & 0x7fffffff;
  return (x & 0xffffff) / 0x1000000;
}

/// A four-point spark: two thin lozenges crossed.
void _spark(Canvas canvas, Offset c, double r, Paint paint) {
  final path = Path()
    ..moveTo(c.dx, c.dy - r)
    ..lineTo(c.dx + r * 0.22, c.dy)
    ..lineTo(c.dx, c.dy + r)
    ..lineTo(c.dx - r * 0.22, c.dy)
    ..close()
    ..moveTo(c.dx - r, c.dy)
    ..lineTo(c.dx, c.dy - r * 0.22)
    ..lineTo(c.dx + r, c.dy)
    ..lineTo(c.dx, c.dy + r * 0.22)
    ..close();
  canvas.drawPath(path, paint);
}

// ===========================================================================
// THE AURORA CROWN
// ===========================================================================

/// The light behind the top of the page: three ribbons of aurora drifting
/// slowly across, a glow breathing behind the mark, and every few seconds a
/// soft firework somewhere in the field — the joy, said in light.
///
/// Fills its parent. Put it at the back of a Stack, under the header.
class AuroraCrown extends StatelessWidget {
  const AuroraCrown({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: _OnClock(
          builder: (_, t) => CustomPaint(
            painter: _AuroraPainter(t),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter(this.t);

  final double t;

  /// A firework every so often, each one lasting [_burstLife].
  static const double _burstEvery = 4.4;
  static const double _burstLife = 2.1;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _ribbons(canvas, size);
    _glowBehindTheMark(canvas, size);
    _fireworks(canvas, size);
    // Fade the whole field out towards its bottom edge, so the aurora ends
    // in the page rather than at a line.
    final fade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.space.withValues(alpha: 0),
          AppColors.space.withValues(alpha: 0),
          AppColors.space,
        ],
        stops: const [0, 0.72, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fade);
  }

  void _ribbons(Canvas canvas, Size size) {
    // Three bands at different heights, speeds and wavelengths; each a path
    // whose top edge is a sine wave and whose fill fades out below it, so
    // the band is soft without a blur.
    const bands = [
      (base: 0.30, amp: 0.10, k: 1.6, speed: 0.11, phase: 0.0, color: 0),
      (base: 0.46, amp: 0.08, k: 2.3, speed: -0.08, phase: 2.1, color: 1),
      (base: 0.62, amp: 0.07, k: 1.1, speed: 0.06, phase: 4.0, color: 3),
    ];
    for (final b in bands) {
      final path = Path()..moveTo(0, size.height);
      const steps = 28;
      for (var i = 0; i <= steps; i++) {
        final x = size.width * i / steps;
        final u = i / steps;
        final y = size.height *
            (b.base +
                b.amp * math.sin(u * b.k * math.pi * 2 + t * b.speed * 2 + b.phase) +
                b.amp * 0.4 * math.sin(u * b.k * 5.3 - t * b.speed * 3.1));
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      final colour = _lights[b.color];
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colour.withValues(alpha: 0.46),
              colour.withValues(alpha: 0.16),
              colour.withValues(alpha: 0),
            ],
            stops: const [0, 0.4, 1],
          ).createShader(
            Rect.fromLTWH(0, size.height * (b.base - b.amp), size.width,
                size.height * (1 - b.base + b.amp)),
          ),
      );
    }
  }

  void _glowBehindTheMark(Canvas canvas, Size size) {
    // The wordmark sits at the top centre; a halo breathes behind it.
    final c = Offset(size.width / 2, size.height * 0.16);
    final breath = 0.5 + 0.5 * math.sin(t * 1.1);
    final r = size.width * (0.22 + 0.03 * breath);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.champagne.withValues(alpha: 0.42 + 0.12 * breath),
            AppColors.holoRose.withValues(alpha: 0.14),
            AppColors.holoRose.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _fireworks(Canvas canvas, Size size) {
    // Which burst is current, and how far into its life it is. Each burst
    // has its own place and tint, drawn from its number.
    final n = (t / _burstEvery).floor();
    final age = t - n * _burstEvery;
    if (age > _burstLife) return;
    final p = age / _burstLife;
    final c = Offset(
      size.width * (0.14 + 0.72 * _hash(n * 3 + 1)),
      size.height * (0.18 + 0.42 * _hash(n * 3 + 2)),
    );
    final colour = _lights[(n + 1) % _lights.length];
    final second = _lights[(n + 3) % _lights.length];

    // The ring of light that leads, then the rays of sparks behind it.
    final eased = 1 - math.pow(1 - p, 3).toDouble();
    final reach = size.width * 0.24 * eased;
    final fade = (1 - p).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      reach,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = colour.withValues(alpha: 0.5 * fade),
    );
    const rays = 14;
    for (var i = 0; i < rays; i++) {
      final a = i / rays * math.pi * 2 + _hash(n * 7 + i) * 0.3;
      final len = reach * (0.75 + 0.25 * _hash(n * 11 + i));
      final tip = c + Offset(math.cos(a), math.sin(a)) * len;
      final tint = i.isEven ? colour : second;
      // The tip of the ray, and one spark trailing it.
      canvas.drawCircle(tip, 2.8 * (1 - 0.4 * p),
          Paint()..color = tint.withValues(alpha: 0.95 * fade));
      final trail = c + Offset(math.cos(a), math.sin(a)) * (len * 0.62);
      canvas.drawCircle(trail, 1.3,
          Paint()..color = tint.withValues(alpha: 0.55 * fade));
    }
    // A spark at the heart that outlives the rays.
    if (p < 0.6) {
      _spark(canvas, c, 7 * (1 - p),
          Paint()..color = AppColors.champagne.withValues(alpha: 0.9 * (1 - p / 0.6)));
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

// ===========================================================================
// THE GLINT
// ===========================================================================

/// A narrow band of light that crosses its child every few seconds — the
/// glint on a lens, the scan of an instrument. For the search capsule.
class GlintSweep extends StatelessWidget {
  const GlintSweep({
    super.key,
    required this.child,
    this.radius = 26,
    this.period = 4.2,
  });

  final Widget child;
  final double radius;

  /// Seconds between one crossing and the next.
  final double period;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: RepaintBoundary(
                child: _OnClock(
                  builder: (_, t) => CustomPaint(
                    painter: _GlintPainter(t, period),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlintPainter extends CustomPainter {
  const _GlintPainter(this.t, this.period);

  final double t;
  final double period;

  @override
  void paint(Canvas canvas, Size size) {
    // The band crosses in the first third of the period and rests the rest.
    final u = (t % period) / period;
    if (u > 0.34) return;
    final p = u / 0.34;
    final x = size.width * (p * 1.5 - 0.25);
    final band = Rect.fromLTWH(x - size.height, 0, size.height * 2, size.height);
    canvas.save();
    canvas.skew(-0.5, 0);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(band),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlintPainter old) => old.t != t;
}

// ===========================================================================
// THE ORBIT
// ===========================================================================

/// A rail of circles on an orbit: a faint elliptical path drawn behind them
/// with a few sparks travelling along it. The stories sit on it.
class OrbitPath extends StatelessWidget {
  const OrbitPath({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: _OnClock(
                builder: (_, t) => CustomPaint(painter: _OrbitPainter(t)),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // The orbit: a wide ellipse whose upper arc runs behind the circles.
    final rect = Rect.fromLTWH(
        -size.width * 0.1, size.height * 0.08, size.width * 1.2, size.height * 0.84);
    final path = Path()..addOval(rect);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0),
            AppColors.accent.withValues(alpha: 0.38),
            AppColors.holoLavender.withValues(alpha: 0.38),
            AppColors.accent.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    // Three sparks on their way round.
    final metric = path.computeMetrics().first;
    for (var i = 0; i < 3; i++) {
      final d = ((t * 0.035 + i / 3) % 1) * metric.length;
      final tangent = metric.getTangentForOffset(d);
      if (tangent == null) continue;
      _spark(canvas, tangent.position, 4,
          Paint()..color = _lights[(i * 2) % _lights.length].withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}

// ===========================================================================
// THE CRYSTAL
// ===========================================================================

/// A tile cut from holographic crystal: the tint it is given, with a sheen
/// that turns slowly through it and an edge of light turning the other way.
/// Each tile has its own phase so a row shimmers rather than blinks.
class CrystalTile extends StatelessWidget {
  const CrystalTile({
    super.key,
    required this.tint,
    required this.phase,
    required this.child,
    this.size = 50,
    this.radius = 16,
  });

  final Color tint;
  final double phase;
  final Widget child;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _OnClock(
        builder: (_, t) {
          final a = t * 0.35 + phase;
          final dir = Offset(math.cos(a), math.sin(a));
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment(-dir.dx, -dir.dy),
                end: Alignment(dir.dx, dir.dy),
                colors: [
                  Color.alphaBlend(tint.withValues(alpha: 0.30), AppColors.surface),
                  Color.alphaBlend(tint.withValues(alpha: 0.08), AppColors.pearl),
                  Color.alphaBlend(tint.withValues(alpha: 0.24), AppColors.surfaceHigh),
                ],
                stops: const [0, 0.5, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: tint.withValues(alpha: 0.22),
                  blurRadius: 12,
                  spreadRadius: -3,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            foregroundDecoration: _CrystalEdge(tint: tint, angle: -a * 1.4, radius: radius),
            child: child,
          );
        },
      ),
    );
  }
}

/// The edge of the crystal: a hairline whose light turns round it.
class _CrystalEdge extends Decoration {
  const _CrystalEdge({required this.tint, required this.angle, required this.radius});

  final Color tint;
  final double angle;
  final double radius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _CrystalEdgePainter(this);
}

class _CrystalEdgePainter extends BoxPainter {
  _CrystalEdgePainter(this.edge);

  final _CrystalEdge edge;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size ?? Size.zero;
    if (size.isEmpty) return;
    final rect = (offset & size).deflate(0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(edge.radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = SweepGradient(
          transform: GradientRotation(edge.angle),
          colors: [
            edge.tint.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.95),
            edge.tint.withValues(alpha: 0.55),
            AppColors.holoLavender.withValues(alpha: 0.5),
            edge.tint.withValues(alpha: 0.25),
          ],
        ).createShader(rect),
    );
  }
}

// ===========================================================================
// THE PORTAL
// ===========================================================================

/// A frame with a bead of light travelling round it, a comet's tail behind
/// the bead. Put round the hero slider: the slider becomes a portal.
class PortalFrame extends StatelessWidget {
  const PortalFrame({
    super.key,
    required this.child,
    this.radius = 22,
    this.period = 6.5,
  });

  final Widget child;
  final double radius;

  /// Seconds for one lap of the frame.
  final double period;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: _OnClock(
                builder: (_, t) =>
                    CustomPaint(painter: _PortalPainter(t, radius, period)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PortalPainter extends CustomPainter {
  const _PortalPainter(this.t, this.radius, this.period);

  final double t;
  final double radius;
  final double period;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(1);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final metric = path.computeMetrics().first;
    final head = ((t / period) % 1) * metric.length;

    // The tail: a run of fading dots behind the head.
    const tail = 26;
    const spacing = 5.0;
    for (var i = tail; i >= 1; i--) {
      final d = (head - i * spacing) % metric.length;
      final pos = metric.getTangentForOffset(d < 0 ? d + metric.length : d)?.position;
      if (pos == null) continue;
      final k = 1 - i / tail;
      canvas.drawCircle(
        pos,
        1.1 + 1.6 * k,
        Paint()..color = AppColors.accent.withValues(alpha: 0.75 * k * k),
      );
    }
    // The head: a bright core in a soft halo.
    final tip = metric.getTangentForOffset(head)?.position;
    if (tip == null) return;
    canvas.drawCircle(
      tip,
      9,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.champagne.withValues(alpha: 0.7),
          AppColors.accent.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: tip, radius: 9)),
    );
    canvas.drawCircle(tip, 2.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PortalPainter old) => old.t != t;
}

// ===========================================================================
// THE CONSTELLATION
// ===========================================================================

/// A hairline of light with three small stars on it: what sits under a
/// section's title instead of a rule. Still — a title does not twinkle.
class Starline extends StatelessWidget {
  const Starline({super.key, this.width = 96});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 10,
      child: const CustomPaint(painter: _StarlinePainter()),
    );
  }
}

class _StarlinePainter extends CustomPainter {
  const _StarlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..strokeWidth = 1
        ..shader = LinearGradient(colors: [
          AppColors.accent.withValues(alpha: 0.9),
          AppColors.holoLavender.withValues(alpha: 0.6),
          AppColors.accent.withValues(alpha: 0),
        ]).createShader(Offset.zero & size),
    );
    for (final (x, r) in [(0.06, 3.4), (0.34, 2.4), (0.62, 1.8)]) {
      _spark(canvas, Offset(size.width * x, y), r,
          Paint()..color = AppColors.accent);
    }
  }

  @override
  bool shouldRepaint(_StarlinePainter old) => false;
}

// ===========================================================================
// LEVITATION
// ===========================================================================

/// Lifts its child a few pixels and lets it down again, slowly, each child
/// on its own phase — a row of them floats rather than bobs in step.
class Levitate extends StatelessWidget {
  const Levitate({
    super.key,
    required this.index,
    required this.child,
    this.amplitude = 3,
  });

  final int index;
  final Widget child;
  final double amplitude;

  @override
  Widget build(BuildContext context) {
    return _OnClock(
      // The child paints into its own layer once; the float only moves it.
      builder: (_, t) => Transform.translate(
        offset: Offset(0, math.sin(t * 1.15 + index * 0.9) * amplitude),
        child: RepaintBoundary(child: child),
      ),
    );
  }
}

// ===========================================================================
// THE BURST
// ===========================================================================

/// Light confetti thrown up from the top of the page the first time it is
/// seen in a launch: gold, rose and lavender petals that fly out, slow, and
/// fade in under two seconds. Behind [IgnorePointer]; never in a render
/// test, never under reduced motion, never twice.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  /// Whether the burst has already been thrown this launch.
  static bool thrown = false;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final skip = ConfettiBurst.thrown ||
        heldSkyTime != null ||
        MediaQuery.disableAnimationsOf(context);
    if (skip) return;
    ConfettiBurst.thrown = true;
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))
      ..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: c,
        builder: (_, _) => c.isCompleted
            ? const SizedBox.shrink()
            : CustomPaint(
                painter: _ConfettiPainter(c.value),
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.p);

  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final origin = Offset(size.width / 2, size.height * 0.08);
    const count = 30;
    final eased = 1 - math.pow(1 - p, 2.2).toDouble();
    final fade = p < 0.55 ? 1.0 : (1 - (p - 0.55) / 0.45).clamp(0.0, 1.0);
    for (var i = 0; i < count; i++) {
      // Up and out, more up than out, then gravity.
      final a = -math.pi / 2 + (_hash(i * 5 + 1) - 0.5) * math.pi * 1.1;
      final speed = size.width * (0.28 + 0.42 * _hash(i * 5 + 2));
      final pos = origin +
          Offset(math.cos(a), math.sin(a)) * speed * eased +
          Offset(0, size.height * 0.22 * p * p);
      final colour = _lights[i % _lights.length];
      final spin = p * math.pi * 2 * (1 + _hash(i * 5 + 3));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(spin);
      // Petals and sparks, by turns.
      if (i % 3 == 0) {
        _spark(canvas, Offset.zero, 5, Paint()..color = colour.withValues(alpha: fade));
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-4, -2.2, 8, 4.4), const Radius.circular(2.2)),
          Paint()..color = colour.withValues(alpha: 0.95 * fade),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.p != p;
}
