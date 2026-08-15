import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

// ===========================================================================
// FADE + SLIDE IN — staggered entrance for list/section children.
// ===========================================================================

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 550),
    this.offset = const Offset(0, 0.18),
    this.id,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  /// Identifies this spot on the page so its entrance plays once and not
  /// every time it is scrolled back to.
  ///
  /// A long list disposes whatever is far off-screen and mounts it again on
  /// the way back, which starts this animation over: the section fades up
  /// from nothing under the finger, and the page feels like it is snagging
  /// rather than scrolling. With an [id] the arrival is remembered, so
  /// returning to a section shows it already in place.
  ///
  /// Leave null for one-off entrances (a splash, a page that is not scrolled),
  /// where replaying cannot happen.
  final String? id;

  /// Ids whose entrance has already been played this run.
  static final Set<String> _played = <String>{};

  @visibleForTesting
  static void debugResetPlayed() => _played.clear();

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.offset,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final id = widget.id;
    if (id != null && FadeSlideIn._played.contains(id)) {
      // Been here before: show it as it was left, not as an arrival.
      _c.value = 1;
      return;
    }
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      if (id != null) FadeSlideIn._played.add(id);
      _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ===========================================================================
// PULSE — gentle scale loop (for FABs, highlights).
// ===========================================================================

class PulseScale extends StatefulWidget {
  const PulseScale({
    super.key,
    required this.child,
    this.min = 0.95,
    this.max = 1.05,
    this.duration = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final double min;
  final double max;
  final Duration duration;

  @override
  State<PulseScale> createState() => _PulseScaleState();
}

class _PulseScaleState extends State<PulseScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        final scale = widget.min + (widget.max - widget.min) * t;
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

// ===========================================================================
// BOUNCY TAP — scale-down on press.
// ===========================================================================

class BouncyTap extends StatefulWidget {
  const BouncyTap({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.94,
  });
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    await _c.forward();
    await _c.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final s = 1 - _c.value * (1 - widget.scale);
          return Transform.scale(scale: s, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

// ===========================================================================
// SPARKLE OVERLAY — drifting golden sparkles for splash / hero.
// ===========================================================================

class SparkleOverlay extends StatefulWidget {
  const SparkleOverlay({
    super.key,
    this.count = 24,
    this.color = AppColors.accent,
  });
  final int count;
  final Color color;

  @override
  State<SparkleOverlay> createState() => _SparkleOverlayState();
}

class _SparkleOverlayState extends State<SparkleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();
  late final List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    _sparkles = List.generate(widget.count, (_) => _Sparkle.random(rnd));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _SparklePainter(
              sparkles: _sparkles, t: _c.value, color: widget.color),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Sparkle {
  _Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
  });

  factory _Sparkle.random(math.Random r) => _Sparkle(
        x: r.nextDouble(),
        y: r.nextDouble(),
        size: 1.5 + r.nextDouble() * 3.5,
        speed: 0.4 + r.nextDouble() * 1.2,
        phase: r.nextDouble(),
      );

  final double x;
  final double y;
  final double size;
  final double speed;
  final double phase;
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({
    required this.sparkles,
    required this.t,
    required this.color,
  });

  final List<_Sparkle> sparkles;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in sparkles) {
      final localT = (t * s.speed + s.phase) % 1.0;
      final y = (s.y - localT) % 1.0;
      final twinkle = (math.sin((localT + s.phase) * math.pi * 2) + 1) / 2;
      final opacity = (0.25 + twinkle * 0.65).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: opacity);
      final cx = s.x * size.width;
      final cy = y * size.height;
      final r = s.size * (0.7 + twinkle * 0.6);

      // 4-point star: small cross of lines
      canvas.drawCircle(Offset(cx, cy), r * 0.5, paint);
      final stroke = Paint()
        ..color = color.withValues(alpha: opacity * 0.8)
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          Offset(cx - r, cy), Offset(cx + r, cy), stroke);
      canvas.drawLine(
          Offset(cx, cy - r), Offset(cx, cy + r), stroke);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => true;
}

// ===========================================================================
// COUNTDOWN CARD — animated days/hours/min/sec until a target date.
// ===========================================================================

class CountdownCard extends StatefulWidget {
  const CountdownCard({
    super.key,
    required this.target,
    required this.title,
  });

  final DateTime target;
  final String title;

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = widget.target.difference(DateTime.now());
    _ticker = Ticker((_) {
      final next = widget.target.difference(DateTime.now());
      if (next.inSeconds != _remaining.inSeconds && mounted) {
        setState(() => _remaining = next);
      }
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _remaining.inDays.clamp(0, 9999);
    final h = (_remaining.inHours % 24).clamp(0, 23);
    final m = (_remaining.inMinutes % 60).clamp(0, 59);
    final s = (_remaining.inSeconds % 60).clamp(0, 59);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.brandDeepGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // sparkle/celebration icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Color(0xFFFFE8C8), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TimeChunk(value: d, label: 'يوم'),
                    _TimeSeparator(),
                    _TimeChunk(value: h, label: 'ساعة'),
                    _TimeSeparator(),
                    _TimeChunk(value: m, label: 'دقيقة'),
                    _TimeSeparator(),
                    _TimeChunk(value: s, label: 'ثانية', animate: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChunk extends StatelessWidget {
  const _TimeChunk({
    required this.value,
    required this.label,
    this.animate = false,
  });
  final int value;
  final String label;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final text = value.toString().padLeft(2, '0');
    final number = AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        text,
        key: ValueKey(text),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        animate ? PulseScale(min: 0.97, max: 1.04, child: number) : number,
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TimeSeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// Minimal Ticker without flutter scheduler import.
class Ticker {
  Ticker(this._onTick);
  final void Function(Duration) _onTick;
  bool _running = false;

  void start() {
    _running = true;
    _loop();
  }

  Future<void> _loop() async {
    while (_running) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _onTick(Duration.zero);
    }
  }

  void dispose() => _running = false;
}

// ===========================================================================
// AI COMPANION FAB — pulsing gradient floating button.
// ===========================================================================

class AiCompanionFab extends StatelessWidget {
  const AiCompanionFab({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PulseScale(
      min: 0.96,
      max: 1.08,
      duration: const Duration(milliseconds: 1600),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.auto_awesome,
              color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

// ===========================================================================
// SHIMMER (lightweight) — for loading skeletons.
// ===========================================================================

class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 12,
  });
  final double width;
  final double height;
  final double borderRadius;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + 2 * _c.value, -0.5),
                end: Alignment(1 + 2 * _c.value, 0.5),
                colors: [
                  AppColors.primaryLight,
                  AppColors.background,
                  AppColors.primaryLight,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}
