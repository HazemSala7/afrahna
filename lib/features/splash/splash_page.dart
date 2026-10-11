import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/notification_router.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/cosmos.dart';
import '../auth/login_page.dart';
import '../home/home_feed_cache.dart';
import '../home/home_page.dart';
import '../reels/reels_cache.dart';

/// The opening: a jump through the stars into the app.
///
/// Drawn in code rather than played from a film, so it is sharp at any screen
/// size, starts on the very first frame (no decoder to wait for), and opens on
/// exactly the colour the operating system has been showing while the process
/// started — [AppColors.space], which the Android launch window and the iOS
/// launch storyboard are painted with too — so there is no flash between them.
///
/// The sequence, in seconds:
///   0.0–1.4  the stars stretch into lines of light, rushing past
///   0.4–1.3  a ring of holographic light draws itself round the centre
///   0.8–1.5  the mark materialises inside it, a scan line passing over it
///   1.3–2.3  «أفراحنا» rises in gold foil, a line of light, then the tagline
/// after which three particles orbit the ring until the app is ready.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  /// A clock, not a tween: every layer reads the same elapsed time.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _clockSeconds),
  );
  static const _clockSeconds = 30;

  final Stopwatch _sinceLaunch = Stopwatch()..start();

  /// The intro is never cut short — below this it flashes by rather than
  /// opens. Whatever is still loading after it, the app waits for as before.
  static const _minHold = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    // Start fetching the home page's data now, in parallel with the intro and
    // session bootstrap, so the home tab shows instantly.
    HomeFeedCache.instance.prefetch();
    // The reels tab is the other screen that used to start from nothing:
    // fetch its first page and pull the first videos onto disk while the
    // intro plays, so it opens on a reel instead of a spinner.
    ReelsCache.instance.prefetch();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = context.read<SessionController>();
      await Future.wait<dynamic>([
        session.bootstrap(),
        _introFinished(),
      ]);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          // Built by hand, so it brings its own living sky: without it the
          // first screen would sit over the painted-once backdrop.
          pageBuilder: (_, a, _) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: CosmicPage(
              child:
                  session.isSignedIn ? const HomePage() : const LoginPage(),
            ),
          ),
        ),
      );
      // Once the shell has been laid out, a link the app was launched with can
      // finally be acted on — before this point the replacement wipes it.
      // (pushReplacement's future resolves when the *new* route pops, so it
      // can't be awaited here.)
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => NotificationRouter.drainPending(),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion: the finished frame, straight away.
      _clock.value = 2.6 / _clockSeconds;
    } else if (!_clock.isAnimating && _clock.value == 0) {
      _clock.forward();
    }
  }

  Future<void> _introFinished() async {
    final left = _minHold - _sinceLaunch.elapsed;
    if (left > Duration.zero) await Future<void>.delayed(left);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final t = _clock.value * _clockSeconds;
          double seg(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
              curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

          final logoIn = seg(0.8, 1.5, Curves.easeOutBack);
          final titleIn = seg(1.3, 2.0);
          final lineIn = seg(1.5, 2.2);
          final tagIn = seg(1.65, 2.3);

          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(painter: _WarpPainter(t)),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 230,
                      height: 230,
                      child: CustomPaint(
                        painter: _RingPainter(t),
                        child: Center(
                          child: Opacity(
                            opacity: logoIn.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.55 + 0.45 * logoIn,
                              child: const _Mark(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: titleIn,
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - titleIn)),
                        child: GoldFoilText(
                          'أفراحنا',
                          style: AppTheme.wordmark(46),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 170 * lineIn,
                      height: 1.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.accent.withValues(alpha: 0),
                          AppColors.accent,
                          AppColors.holoLavender,
                          AppColors.accent.withValues(alpha: 0),
                        ]),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.7),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: tagIn,
                      child: const Text(
                        'كل مناسباتك في مكان واحد',
                        style: TextStyle(
                          // The intro opens on ivory, so the line under the
                          // name is read, not glowed: pearl would be white on
                          // white.
                          color: AppColors.primaryDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The app's mark on a pane of dark glass with a gold rim.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.44),
            blurRadius: 36,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(33),
        child: Image.asset(AppAssets.logo, fit: BoxFit.cover),
      ),
    );
  }
}

/// The jump: stars stretching into lines of light rushing out from the centre,
/// and the glow that is left behind.
class _WarpPainter extends CustomPainter {
  _WarpPainter(this.t);
  final double t;

  static final List<({double angle, double speed, double phase, bool gold})>
      _streaks = () {
    final rnd = math.Random(2026);
    return List.generate(96, (_) {
      return (
        angle: rnd.nextDouble() * math.pi * 2,
        speed: 0.55 + rnd.nextDouble() * 0.9,
        phase: rnd.nextDouble(),
        gold: rnd.nextDouble() < 0.3,
      );
    });
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = size.center(const Offset(0, -70));
    final maxR = size.longestSide * 0.75;

    // The glow at the centre blooms and then settles, and stays.
    final bloom = ((t - 0.3) / 1.1).clamp(0.0, 1.0);
    if (bloom > 0) {
      final r = 80 + 200 * Curves.easeOutCubic.transform(bloom);
      final a = 0.18 + 0.22 * math.sin(bloom * math.pi);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            AppColors.primary.withValues(alpha: a),
            AppColors.holoLavender.withValues(alpha: a * 0.35),
            AppColors.primary.withValues(alpha: 0),
          ], stops: const [0, 0.55, 1])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // Streaks: fastest at 0.5s, gone by 1.4s.
    final fade = t < 0.9 ? 1.0 : (1 - (t - 0.9) / 0.5).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final intensity = math.sin((t / 1.4).clamp(0.0, 1.0) * math.pi);
    for (final s in _streaks) {
      final d = (t * 1.5 * s.speed + s.phase) % 1.0;
      final head = maxR * math.pow(d, 2.1);
      final length = 12 + 240 * d * d * intensity;
      final dir = Offset(math.cos(s.angle), math.sin(s.angle));
      final from = c + dir * math.max(0, head - length);
      final to = c + dir * head;
      final color = s.gold ? AppColors.accent : AppColors.pearl;
      final a = (fade * (0.25 + 0.75 * d)).clamp(0.0, 1.0);
      if (to == from) continue;
      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeWidth = 1 + 1.2 * d
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: a),
          ]).createShader(Rect.fromPoints(from, to)),
      );
    }
  }

  @override
  bool shouldRepaint(_WarpPainter old) => old.t != t;
}

/// The ring round the mark: drawn on as an arc of holographic light, with a
/// fainter dashed ring inside it, a scan line crossing the mark once, and
/// three particles in orbit afterwards.
class _RingPainter extends CustomPainter {
  _RingPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 10;

    double seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

    // ---- the ring drawing itself
    final draw = Curves.easeInOutCubic.transform(seg(0.4, 1.3));
    if (draw > 0) {
      final rect = Rect.fromCircle(center: c, radius: r);
      final shader = SweepGradient(
        colors: AppColors.holoStops,
        transform: GradientRotation(-math.pi / 2 + t * 0.6),
      ).createShader(rect);
      final sweep = math.pi * 2 * draw;
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6)
          ..shader = shader,
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
    }

    // ---- the dashed inner ring, turning the other way
    final inner = seg(1.0, 1.6);
    if (inner > 0) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-t * 0.35);
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.pearl.withValues(alpha: 0.28 * inner);
      final ri = r - 12;
      for (var i = 0; i < 48; i++) {
        final a = i / 48 * math.pi * 2;
        canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: ri), a,
            math.pi * 2 / 48 * 0.45, false, dash);
      }
      canvas.restore();
    }

    // ---- the scan line crossing the mark once
    final scan = seg(1.0, 1.75);
    if (scan > 0 && scan < 1) {
      final y = c.dy - 70 + 140 * Curves.easeInOut.transform(scan);
      final line = Rect.fromLTWH(c.dx - 80, y - 1, 160, 2);
      canvas.drawRect(
        line.inflate(6),
        Paint()
          ..color = AppColors.champagne.withValues(alpha: 0.25)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
      );
      canvas.drawRect(
        line,
        Paint()
          ..shader = LinearGradient(colors: [
            AppColors.champagne.withValues(alpha: 0),
            AppColors.champagne.withValues(alpha: 0.9),
            AppColors.champagne.withValues(alpha: 0),
          ]).createShader(line),
      );
    }

    // ---- particles in orbit once the ring is whole
    final orbit = seg(1.3, 1.9);
    if (orbit > 0) {
      const colors = [AppColors.accent, AppColors.holoLavender, AppColors.holoAqua];
      for (var i = 0; i < colors.length; i++) {
        final a = t * (0.9 + i * 0.35) + i * math.pi * 2 / 3;
        final o = c + Offset(math.cos(a), math.sin(a)) * r;
        canvas.drawCircle(
          o,
          7,
          Paint()
            ..color = colors[i].withValues(alpha: 0.4 * orbit)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5),
        );
        canvas.drawCircle(
            o, 2.4, Paint()..color = colors[i].withValues(alpha: orbit));
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}
