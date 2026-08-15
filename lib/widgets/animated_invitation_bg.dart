import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Living background animations shared by both invitation systems
/// (the card designer and the electronic-invitations templates).
///
/// Every look is drawn procedurally — no video files, no assets — so a theme
/// costs nothing to ship, scales to any screen and never stutters on a slow
/// connection.
enum InvitationAnim {
  none,
  goldDust,
  petals,
  bokeh,
  starfield,
  silk,
  arabesque,
  candles,
  foil,
}

InvitationAnim invitationAnimFromString(String? s) {
  switch ((s ?? '').trim().toLowerCase()) {
    case 'gold':
    case 'gold_dust':
    case 'golddust':
      return InvitationAnim.goldDust;
    case 'petals':
    case 'rose':
      return InvitationAnim.petals;
    case 'bokeh':
    case 'glow':
      return InvitationAnim.bokeh;
    case 'star':
    case 'stars':
    case 'starfield':
      return InvitationAnim.starfield;
    case 'silk':
    case 'waves':
      return InvitationAnim.silk;
    case 'arabesque':
    case 'ornament':
    case 'mandala':
      return InvitationAnim.arabesque;
    case 'candles':
    case 'candle':
      return InvitationAnim.candles;
    case 'foil':
    case 'shimmer':
      return InvitationAnim.foil;
    default:
      return InvitationAnim.none;
  }
}

/// Arabic label for a theme — used by the template picker.
String invitationAnimLabel(InvitationAnim a) => switch (a) {
      InvitationAnim.goldDust => 'غبار ذهبي',
      InvitationAnim.petals => 'بتلات متساقطة',
      InvitationAnim.bokeh => 'أضواء ناعمة',
      InvitationAnim.starfield => 'سماء ماسية',
      InvitationAnim.silk => 'حرير متموّج',
      InvitationAnim.arabesque => 'زخرفة عربية',
      InvitationAnim.candles => 'ضوء الشموع',
      InvitationAnim.foil => 'وميض ذهبي',
      InvitationAnim.none => 'بدون حركة',
    };

/// An animated layer painted behind invitation content. One looping controller
/// drives a [CustomPainter] whose look depends on [anim]. Particle positions are
/// seeded once so the motion stays refined and repeatable.
class AnimatedInvitationBg extends StatefulWidget {
  const AnimatedInvitationBg({
    super.key,
    required this.anim,
    required this.accent,
  });

  final InvitationAnim anim;
  final Color accent;

  @override
  State<AnimatedInvitationBg> createState() => _AnimatedInvitationBgState();
}

class _AnimatedInvitationBgState extends State<AnimatedInvitationBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      // Slower cycles read as "formal"; fast motion reads as a game.
      duration: Duration(seconds: switch (widget.anim) {
        InvitationAnim.silk => 22,
        InvitationAnim.arabesque => 40,
        InvitationAnim.candles => 18,
        _ => 14,
      }),
    )..repeat();
    final rnd = math.Random(_seedFor(widget.anim));
    _particles = List.generate(
      _countFor(widget.anim),
      (_) => _Particle(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        r: rnd.nextDouble(),
        phase: rnd.nextDouble(),
        speed: 0.6 + rnd.nextDouble() * 0.9,
      ),
    );
  }

  int _countFor(InvitationAnim a) => switch (a) {
        InvitationAnim.goldDust => 46,
        InvitationAnim.petals => 16,
        InvitationAnim.bokeh => 14,
        InvitationAnim.starfield => 60,
        InvitationAnim.silk => 5, // ribbons, not motes
        InvitationAnim.arabesque => 0, // fully procedural
        InvitationAnim.candles => 12,
        InvitationAnim.foil => 24,
        InvitationAnim.none => 0,
      };

  int _seedFor(InvitationAnim a) => switch (a) {
        InvitationAnim.goldDust => 7,
        InvitationAnim.petals => 13,
        InvitationAnim.bokeh => 21,
        InvitationAnim.starfield => 42,
        InvitationAnim.silk => 55,
        InvitationAnim.arabesque => 61,
        InvitationAnim.candles => 73,
        InvitationAnim.foil => 89,
        InvitationAnim.none => 0,
      };

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        painter: _InvitationBgPainter(
          anim: widget.anim,
          accent: widget.accent,
          particles: _particles,
          t: _c.value,
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.y,
    required this.r,
    required this.phase,
    required this.speed,
  });
  final double x;
  final double y;
  final double r;
  final double phase;
  final double speed;
}

class _InvitationBgPainter extends CustomPainter {
  _InvitationBgPainter({
    required this.anim,
    required this.accent,
    required this.particles,
    required this.t,
  });
  final InvitationAnim anim;
  final Color accent;
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    switch (anim) {
      case InvitationAnim.goldDust:
        _goldDust(canvas, size);
      case InvitationAnim.petals:
        _petals(canvas, size);
      case InvitationAnim.bokeh:
        _bokeh(canvas, size);
      case InvitationAnim.starfield:
        _starfield(canvas, size);
      case InvitationAnim.silk:
        _silk(canvas, size);
      case InvitationAnim.arabesque:
        _arabesque(canvas, size);
      case InvitationAnim.candles:
        _candles(canvas, size);
      case InvitationAnim.foil:
        _foil(canvas, size);
      case InvitationAnim.none:
        break;
    }
  }

  void _goldDust(Canvas canvas, Size size) {
    final sweepX = (t * 1.6 - 0.3) * size.width;
    final shimmer = Paint()
      ..shader = ui.Gradient.linear(
        Offset(sweepX - 60, 0),
        Offset(sweepX + 60, size.height),
        [
          accent.withValues(alpha: 0.0),
          accent.withValues(alpha: 0.10),
          accent.withValues(alpha: 0.0),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Offset.zero & size, shimmer);

    for (final p in particles) {
      final drift = (t * p.speed + p.phase) % 1.0;
      final y = (p.y - drift + 1.0) % 1.0 * size.height;
      final x = (p.x + math.sin((drift + p.phase) * 2 * math.pi) * 0.02) *
          size.width;
      final twinkle =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin((t * p.speed + p.phase) * 6.28));
      canvas.drawCircle(
        Offset(x, y),
        0.6 + p.r * 1.7,
        Paint()..color = accent.withValues(alpha: 0.85 * twinkle),
      );
    }
  }

  void _petals(Canvas canvas, Size size) {
    for (final p in particles) {
      final fall = (t * p.speed * 0.7 + p.phase) % 1.0;
      final y = fall * (size.height + 24) - 12;
      final sway = math.sin((fall + p.phase) * 2 * math.pi) * 14;
      final x = p.x * size.width + sway;
      final s = 5.0 + p.r * 5.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((fall + p.phase) * 2 * math.pi);
      final path = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s, -s * 0.2, 0, s)
        ..quadraticBezierTo(-s, -s * 0.2, 0, -s)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = accent.withValues(alpha: 0.28 + 0.22 * p.r),
      );
      canvas.restore();
    }
  }

  void _bokeh(Canvas canvas, Size size) {
    for (final p in particles) {
      final rise = (t * p.speed * 0.5 + p.phase) % 1.0;
      final y = (1.0 - rise) * size.height;
      final x = (p.x + math.sin((rise + p.phase) * 2 * math.pi) * 0.05) *
          size.width;
      final radius = 8 + p.r * 26;
      final alpha = 0.10 + 0.14 * (0.5 + 0.5 * math.sin(rise * 3.14));
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(x, y),
            radius,
            [
              accent.withValues(alpha: alpha),
              accent.withValues(alpha: 0.0),
            ],
          ),
      );
    }
  }

  void _starfield(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = p.x * size.width;
      final y = p.y * size.height;
      final twinkle =
          0.2 + 0.8 * (0.5 + 0.5 * math.sin((t * p.speed + p.phase) * 6.28));
      canvas.drawCircle(
        Offset(x, y),
        0.5 + p.r * 1.4,
        Paint()..color = accent.withValues(alpha: 0.9 * twinkle),
      );
      if (p.r > 0.82) {
        final len = 3.0 + p.r * 3.0;
        final pl = Paint()
          ..color = accent.withValues(alpha: 0.7 * twinkle)
          ..strokeWidth = 0.8;
        canvas.drawLine(Offset(x - len, y), Offset(x + len, y), pl);
        canvas.drawLine(Offset(x, y - len), Offset(x, y + len), pl);
      }
    }
  }

  // ---- new themes ---------------------------------------------------------

  /// Slow silk ribbons: wide sine bands that glide across the card. The most
  /// "formal" of the set — no particles, just fabric-like movement.
  void _silk(Canvas canvas, Size size) {
    for (var i = 0; i < particles.length; i++) {
      final p = particles[i];
      final phase = t * 2 * math.pi * (0.5 + p.speed * 0.25) + p.phase * 6.28;
      final baseY = size.height * (0.15 + 0.18 * i);
      final amp = size.height * (0.05 + 0.03 * p.r);

      final path = Path()..moveTo(-20, baseY);
      for (double x = -20; x <= size.width + 20; x += 14) {
        final y = baseY +
            math.sin((x / size.width) * 3.4 * math.pi + phase) * amp +
            math.sin((x / size.width) * 1.3 * math.pi - phase * 0.6) * amp * .4;
        path.lineTo(x, y);
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12 + p.r * 18
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(size.width, 0),
            [
              accent.withValues(alpha: 0.0),
              accent.withValues(alpha: 0.10 + 0.06 * p.r),
              accent.withValues(alpha: 0.0),
            ],
            [0.0, 0.5, 1.0],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  /// A slowly rotating eight-fold arabesque, the way an ornate border on a
  /// formal card would look if it breathed.
  void _arabesque(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final baseR = math.min(size.width, size.height) * 0.42;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * 2 * math.pi * 0.25); // one slow quarter-turn per cycle

    // Two rings turning against each other keeps it from looking like a
    // single spinning sticker.
    for (final ring in const [1.0, 0.62]) {
      final r = baseR * ring;
      final petals = ring == 1.0 ? 16 : 12;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring == 1.0 ? 1.1 : 0.9
        ..color = accent.withValues(alpha: ring == 1.0 ? 0.16 : 0.11);

      canvas.save();
      if (ring != 1.0) canvas.rotate(-t * 2 * math.pi * 0.5);

      for (var i = 0; i < petals; i++) {
        final a = i / petals * 2 * math.pi;
        final tip = Offset(math.cos(a) * r, math.sin(a) * r);
        final ctrl = r * 0.38;
        final path = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(
            math.cos(a - 0.30) * ctrl * 1.7,
            math.sin(a - 0.30) * ctrl * 1.7,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            math.cos(a + 0.30) * ctrl * 1.7,
            math.sin(a + 0.30) * ctrl * 1.7,
            0,
            0,
          );
        canvas.drawPath(path, paint);
      }
      canvas.drawCircle(Offset.zero, r * 0.30, paint);
      canvas.restore();
    }
    canvas.restore();
  }

  /// Warm candlelight: soft orbs that rise and flicker, plus a faint bloom at
  /// the base of the card.
  void _candles(Canvas canvas, Size size) {
    // Bloom from below, as if candles stood in front of the card.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, size.height),
          Offset(size.width / 2, size.height * 0.45),
          [accent.withValues(alpha: 0.13), accent.withValues(alpha: 0.0)],
        ),
    );

    for (final p in particles) {
      final rise = (t * p.speed * 0.35 + p.phase) % 1.0;
      final y = size.height * (1.02 - rise * 0.95);
      // Flame-like lateral wobble, faster than the rise.
      final wobble = math.sin((t * 6 + p.phase * 6.28) * p.speed) * 6;
      final x = p.x * size.width + wobble;
      // Flicker: two out-of-phase sines so it never pulses regularly.
      final flicker = 0.55 +
          0.25 * math.sin(t * 18 * p.speed + p.phase * 6.28) +
          0.20 * math.sin(t * 11 * p.speed + p.phase * 3.1);
      final radius = (7 + p.r * 16) * (0.85 + 0.15 * flicker);
      final fade = math.sin(rise * math.pi).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(x, y),
            radius,
            [
              accent.withValues(alpha: 0.30 * fade * flicker),
              accent.withValues(alpha: 0.0),
            ],
          ),
      );
      canvas.drawCircle(
        Offset(x, y),
        1.6 + p.r * 1.4,
        Paint()..color = accent.withValues(alpha: 0.75 * fade * flicker),
      );
    }
  }

  /// A brushed-foil sweep with sparse four-point glints — restrained, the way
  /// hot-foil printing catches the light when you tilt a real card.
  void _foil(Canvas canvas, Size size) {
    final sweep = (t * 1.4 - 0.2);
    final cx = sweep * size.width * 1.4;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - size.width * 0.35, 0),
          Offset(cx + size.width * 0.35, size.height),
          [
            accent.withValues(alpha: 0.0),
            accent.withValues(alpha: 0.05),
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.05),
            accent.withValues(alpha: 0.0),
          ],
          [0.0, 0.35, 0.5, 0.65, 1.0],
        ),
    );

    for (final p in particles) {
      final x = p.x * size.width;
      final y = p.y * size.height;
      // A glint only fires as the sweep passes over it.
      final dist = ((x / size.width) - sweep % 1.0).abs();
      final near = (1 - (dist / 0.22)).clamp(0.0, 1.0);
      if (near <= 0) continue;
      final a = near * (0.5 + 0.5 * math.sin(t * 20 + p.phase * 6.28));
      final len = 2.5 + p.r * 5.0;
      final paint = Paint()
        ..color = accent.withValues(alpha: a)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x - len, y), Offset(x + len, y), paint);
      canvas.drawLine(Offset(x, y - len), Offset(x, y + len), paint);
      canvas.drawCircle(Offset(x, y), 0.9, Paint()..color = accent.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(_InvitationBgPainter old) =>
      old.t != t || old.anim != anim;
}

/// The three steps of making an invitation, shown at the top of each stage so
/// the flow never feels like an open-ended form: choose a design, fill in the
/// details, then preview and share.
class InvitationSteps extends StatelessWidget {
  const InvitationSteps({super.key, required this.current, this.onDark = false});

  /// 1-based index of the active step.
  final int current;

  /// Light-on-dark variant, for use over a themed backdrop.
  final bool onDark;

  static const _labels = ['التصميم', 'البيانات', 'المشاركة'];

  @override
  Widget build(BuildContext context) {
    final idle = onDark ? Colors.white24 : const Color(0xFFE0D2BE);
    final idleText = onDark ? Colors.white60 : const Color(0xFF9C8273);
    const active = Color(0xFFB8835A);

    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: (i + 1) <= current ? active : idle,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (i + 1) <= current ? active : Colors.transparent,
                  border: Border.all(
                    color: (i + 1) <= current ? active : idle,
                    width: 1.6,
                  ),
                ),
                child: (i + 1) < current
                    ? const Icon(Icons.check_rounded,
                        size: 15, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: (i + 1) == current ? Colors.white : idleText,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      (i + 1) == current ? FontWeight.w900 : FontWeight.w600,
                  color: (i + 1) <= current ? active : idleText,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
