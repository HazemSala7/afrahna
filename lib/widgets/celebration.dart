import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// The moment something good happens: a burst of gold and holographic light
/// across the screen, with a ring of energy opening out of it.
///
/// Used where the app has news worth marking — a request sent, a shop's
/// answer, an order delivered — and nowhere else. A celebration that fires on
/// every tap stops meaning anything.
///
/// It draws itself in the overlay, above the whole app, ignores pointers, and
/// takes itself down when it is over. It does nothing at all when the phone
/// asks for reduced motion.
class CelebrationBurst {
  const CelebrationBurst._();

  static void show(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Burst(onDone: () => entry.remove()),
    );
    overlay.insert(entry);
    HapticFeedback.mediumImpact();
  }
}

class _Spark {
  _Spark(math.Random rnd)
      : angle = rnd.nextDouble() * math.pi * 2,
        speed = 0.35 + rnd.nextDouble() * 0.75,
        size = 2.2 + rnd.nextDouble() * 4.6,
        spin = (rnd.nextBool() ? 1 : -1) * (2 + rnd.nextDouble() * 6),
        ribbon = rnd.nextDouble() < 0.45,
        colour = _palette[rnd.nextInt(_palette.length)],
        delay = rnd.nextDouble() * 0.12;

  static const _palette = [
    AppColors.champagne,
    AppColors.accent,
    AppColors.holoRose,
    AppColors.holoLavender,
    AppColors.holoAqua,
    AppColors.pearl,
  ];

  final double angle, speed, size, spin, delay;

  /// Half are little ribbons that tumble; the rest are round sparks.
  final bool ribbon;
  final Color colour;
}

class _Burst extends StatefulWidget {
  const _Burst({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  late final List<_Spark> _sparks = () {
    final rnd = math.Random(DateTime.now().microsecondsSinceEpoch);
    return List<_Spark>.generate(56, (_) => _Spark(rnd));
  }();

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
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
        child: CustomPaint(
          painter: _BurstPainter(_c, _sparks),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.sparks) : super(repaint: t);

  final Animation<double> t;
  final List<_Spark> sparks;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    if (v <= 0) return;
    final origin = Offset(size.width / 2, size.height * 0.42);
    final reach = size.shortestSide * 0.95;

    // The ring of light opening out of the burst.
    final ringT = Curves.easeOutCubic.transform((v / 0.55).clamp(0.0, 1.0));
    final ringFade = (1 - ringT).clamp(0.0, 1.0);
    if (ringFade > 0.01) {
      canvas.drawCircle(
        origin,
        reach * 0.62 * ringT,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * ringFade
          ..color = AppColors.champagne.withValues(alpha: 0.5 * ringFade),
      );
      canvas.drawCircle(
        origin,
        reach * 0.44 * ringT,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * ringFade
          ..color = AppColors.holoLavender.withValues(alpha: 0.4 * ringFade),
      );
    }

    for (final s in sparks) {
      final local = ((v - s.delay) / (1 - s.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final out = Curves.easeOutCubic.transform(local);
      // Thrown out, then pulled down: confetti, not fireworks.
      final drift = Offset(
        math.cos(s.angle) * reach * s.speed * out,
        math.sin(s.angle) * reach * s.speed * out +
            reach * 0.55 * local * local,
      );
      final at = origin + drift;
      if (at.dy > size.height + 20) continue;

      final fade = local < 0.75 ? 1.0 : 1 - (local - 0.75) / 0.25;
      final paint = Paint()..color = s.colour.withValues(alpha: fade);

      if (s.ribbon) {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(s.spin * local);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: s.size, height: s.size * 2.4),
            const Radius.circular(1.2),
          ),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(at, s.size * 0.55, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => false;
}
