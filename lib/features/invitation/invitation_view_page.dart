import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/api/api_client.dart';
import '../../core/services/invitation_service.dart';
import '../../core/theme.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/animated_invitation_bg.dart';
import '../../widgets/app_widgets.dart';

/// Palette for the invitation. Deliberately its own thing rather than the
/// app's warm browns: an invitation should feel like stationery, not like a
/// screen in a marketplace.
class _Ink {
  static const night = Color(0xFF11131C);
  static const deep = Color(0xFF1B1E2B);
  static const ivory = Color(0xFFF6EFE3);

  /// The ground everything below the hero stands on. It is a *glass*, not a
  /// fill: the sky keeps drifting behind the whole invitation instead of
  /// being covered by a sheet of paper after the first screen.
  static const glass = Color(0x1AFFFFFF);

  /// A panel one step brighter than the glass, for a surface that has to hold
  /// a form.
  static const glassHigh = Color(0x26FFFFFF);

  /// Kept under its old name because a hundred call sites say `paper`: it is
  /// the colour of a surface on the dark, and surfaces here are glass.
  static const paper = glass;

  static const heading = Color(0xFFF7F1E6);
  static const body = Color(0xFFB9AFC4);

  /// Gold on the dark can be foil again — bright, and brighter still where the
  /// light catches it. On cream it had to be darkened to a printed gold; that
  /// is no longer the ground.
  static const goldInk = Color(0xFFE6C78C);

  static const goldInkSweep = LinearGradient(
    colors: [
      Color(0xFFB08A46),
      goldInk,
      Color(0xFFFFF0CB),
      goldInk,
      Color(0xFFB08A46),
    ],
    stops: [0.0, 0.28, 0.5, 0.72, 1.0],
  );
  static const gold = Color(0xFFD9B36C);
  static const goldLight = Color(0xFFF0DCA8);
  static const goldDeep = Color(0xFF9A7635);

  static const goldSweep = LinearGradient(
    colors: [goldDeep, goldLight, gold, goldLight, goldDeep],
    stops: [0.0, 0.28, 0.5, 0.72, 1.0],
  );
}

/// Holds the invitation's idle motion still — the envelope's float and the
/// ring leaving its seal. A render test cannot measure where the seal sits
/// while it is breathing; with this set, the envelope rests exactly where it
/// was designed to rest.
@visibleForTesting
bool debugInvitationStill = false;

/// Display face for the invitation currently on screen. Set from the theme's
/// `font_family` so two themes can differ by more than colour — typography is
/// most of what separates one invitation design from another.
String? _themeFont;

TextStyle _display(double size, {Color color = _Ink.heading, double h = 1.25}) {
  const base = TextStyle(fontWeight: FontWeight.w700);
  final style = base.copyWith(fontSize: size, color: color, height: h);
  // An unknown family must never break a live invitation, so fall back.
  try {
    return _themeFont == null
        ? GoogleFonts.arefRuqaa(textStyle: style)
        : GoogleFonts.getFont(_themeFont!, textStyle: style);
  } catch (_) {
    return GoogleFonts.arefRuqaa(textStyle: style);
  }
}

TextStyle _body(
  double size, {
  Color color = _Ink.body,
  double h = 1.9,
  FontWeight w = FontWeight.w400,
}) => GoogleFonts.amiri(fontSize: size, color: color, height: h, fontWeight: w);

/// The invitation as the guest experiences it: a sealed envelope that opens,
/// then a cinematic card with the couple's details, a live countdown, the
/// venue, photos, and the attendance reply.
class InvitationViewPage extends StatefulWidget {
  const InvitationViewPage({super.key, required this.code});

  final String code;

  @override
  State<InvitationViewPage> createState() => _InvitationViewPageState();
}

class _InvitationViewPageState extends State<InvitationViewPage> {
  final _service = InvitationService();

  InvitationView? _data;
  Object? _error;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await _service.viewByCode(widget.code);
      // Apply the theme's typeface before the first paint.
      final f = v.invitation.template?.fontFamily?.trim();
      _themeFont = (f == null || f.isEmpty) ? null : f;
      if (mounted) setState(() => _data = v);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _refreshWith(InvitationView v) => setState(() => _data = v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Ink.night,
      body: Stack(
        children: [
          SizedBox.expand(
            child: _error != null
                ? _ErrorPane(
                    error: _error!,
                    onRetry: () {
                      setState(() => _error = null);
                      _load();
                    },
                  )
                : _data == null
                ? const Center(
                    child: CircularProgressIndicator(color: _Ink.gold),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    child: _opened
                        ? _InvitationScroll(
                            key: const ValueKey('open'),
                            code: widget.code,
                            data: _data!,
                            onChanged: _refreshWith,
                          )
                        : _EnvelopeStage(
                            key: const ValueKey('sealed'),
                            data: _data!,
                            onOpened: () => setState(() => _opened = true),
                          ),
                  ),
          ),
          const Positioned.fill(child: OverlayBackButton()),
        ],
      ),
    );
  }
}

// ===========================================================================
// SCENE 1 — the sealed envelope
// ===========================================================================

/// An ivory envelope with a gold wax seal. Tapping breaks the seal, the flap
/// swings open in 3D and the card rises out of it.
class _EnvelopeStage extends StatefulWidget {
  const _EnvelopeStage({super.key, required this.data, required this.onOpened});

  final InvitationView data;
  final VoidCallback onOpened;

  @override
  State<_EnvelopeStage> createState() => _EnvelopeStageState();
}

class _EnvelopeStageState extends State<_EnvelopeStage>
    with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  bool _breaking = false;

  // Staged so the motion reads as a sequence rather than one blur:
  // seal lifts → flap swings → card rises → everything fades to the next scene.
  late final Animation<double> _seal = CurvedAnimation(
    parent: _open,
    curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
  );
  late final Animation<double> _flap = CurvedAnimation(
    parent: _open,
    curve: const Interval(0.16, 0.55, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _card = CurvedAnimation(
    parent: _open,
    curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _out = CurvedAnimation(
    parent: _open,
    curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
  );

  @override
  void dispose() {
    _open.dispose();
    _idle.dispose();
    super.dispose();
  }

  Future<void> _break() async {
    if (_breaking) return;
    setState(() => _breaking = true);
    HapticFeedback.mediumImpact();
    _idle.stop();
    await _open.forward();
    if (mounted) widget.onOpened();
  }

  /// First letter of each name, struck into the wax like a signet ring.
  static String _initials(InvitationModel inv) {
    String first(String s) {
      final t = s.trim();
      return t.isEmpty ? '' : t.characters.first;
    }

    final g = first(inv.groomName);
    final b = first(inv.brideName);
    if (g.isEmpty && b.isEmpty) return '';
    return [g, b].where((e) => e.isNotEmpty).join('·');
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.data.invitation;
    final accent = _ThemedBackdrop._hex(inv.template?.accentColor, _Ink.gold);

    return GestureDetector(
      onTap: _break,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ThemedBackdrop(template: widget.data.invitation.template),
          // Night over whatever the couple chose for a background, so the
          // envelope and the invitation inside it are the same place. Without
          // it the scene changes worlds the moment the flap opens.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.15),
                  radius: 1.1,
                  colors: [Color(0xD91A1726), Color(0xF2080810)],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: _NightField(offset: 0)),
          const Positioned.fill(child: _Particles(count: 16)),
          // The envelope is an OBJECT now, not the ground: a little smaller
          // than the screen, tilted, and with air around it.
          LayoutBuilder(
            builder: (context, box) {
              final screenH = box.maxHeight;
              final w = math.min(box.maxWidth * 0.84, 460.0);
              final h = math.min(w * 1.42, screenH * 0.74);
              // The pocket is the lower part; the flap covers exactly the
              // rest, so its point lands on the pocket's edge and the two
              // together are one closed envelope. The flap used to be shorter
              // than the space above the pocket, which left the envelope's own
              // corners transparent — the backdrop showed through them and the
              // flap read as a triangle floating in the air.
              // The seam — the mouth of the envelope, and the point the wax
              // seal is centred on — sits on the exact middle of the screen.
              // It was at 0.44 of the height, which put the seal noticeably
              // high: the one thing the eye lands on first was off-centre.
              // Halving it also makes the flap and the pocket the same depth,
              // so the fold lines read as one symmetrical X.
              final seamY = h / 2; // the mouth: where the card comes out
              final bodyH = h - seamY;
              final flapH = seamY;
              final sealSize = w * 0.24;
              final cardH = h * 0.42;

              return AnimatedBuilder(
                animation: Listenable.merge([_open, _idle]),
                builder: (context, _) {
                  // A still invitation for tests; see [debugInvitationStill].
                  final idle = debugInvitationStill ? 0.5 : _idle.value;
                  // Breathing, not bouncing: six pixels and three hundredths
                  // of a radian. Enough that the light moves across the paper,
                  // little enough that nothing looks loose.
                  final sway = (idle - 0.5) * 2;

                  return Opacity(
                    opacity: 1 - _out.value,
                    child: Center(
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0009)
                          ..translateByDouble(0.0, sway * 6.0, 0.0, 1.0)
                          ..rotateY(sway * 0.035)
                          ..rotateX(-0.045 + sway * 0.015),
                        child: SizedBox(
                          width: w,
                          height: h,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // The shadow it casts on the night, so it is floating
                              // above something rather than pasted onto it.
                              Positioned(
                                bottom: -h * 0.10,
                                child: IgnorePointer(
                                  child: Container(
                                    width: w * (0.72 + 0.02 * sway),
                                    height: h * 0.10,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                        Radius.elliptical(w * 0.36, h * 0.05),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x66000000),
                                          blurRadius: 42,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Back panel: the sheet the flap is folded onto. Plain
                              // paper, no folds — without it the envelope has holes.
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _EnvelopeBodyPainter(
                                    accent: accent,
                                    folds: false,
                                  ),
                                ),
                              ),
                              // The inside of the envelope: paper in shadow, deeper
                              // towards the mouth. It sits under the flap, so it is
                              // only seen once the flap lifts — and it is what makes
                              // the card look like it is coming out of something.
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: seamY,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        const Color(
                                          0xFF6B5836,
                                        ).withValues(alpha: .05),
                                        const Color(
                                          0xFF4A3A20,
                                        ).withValues(alpha: .30),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // The card, sliding up out of the mouth. It starts
                              // below the seam — hidden behind the pocket — and ends
                              // standing above it.
                              Positioned(
                                // Ends with its foot still inside the envelope
                                // rather than clear of it — a card resting in the
                                // mouth reads as having come out of this envelope;
                                // one floating above it reads as a separate object.
                                top:
                                    seamY +
                                    12 -
                                    (cardH * .82 + 12) * _card.value,
                                child: _MiniCard(
                                  bride: inv.brideName,
                                  groom: inv.groomName,
                                  width: w * 0.66,
                                  height: cardH,
                                ),
                              ),
                              // Envelope body — edge to edge, no margins.
                              Positioned(
                                bottom: 0,
                                child: CustomPaint(
                                  size: Size(w, bodyH),
                                  painter: _EnvelopeBodyPainter(accent: accent),
                                ),
                              ),
                              // The flap, hinged along the envelope's top edge and
                              // long enough for its point to meet the pocket.
                              Positioned(
                                top: 0,
                                child: Transform(
                                  alignment: Alignment.topCenter,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.0012)
                                    ..rotateX(-math.pi * _flap.value),
                                  child: CustomPaint(
                                    size: Size(w, flapH),
                                    painter: _FlapPainter(
                                      open: _flap.value,
                                      accent: accent,
                                    ),
                                  ),
                                ),
                              ),
                              // The invitation inside is already lit, so light escapes
                              // along the mouth. Drawn OVER the flap on purpose:
                              // under it, the paper hides the very thing that
                              // makes a closed envelope read as full. It goes out
                              // as the flap lifts, because by then the light has
                              // somewhere else to be.
                              Positioned(
                                top: seamY - 9,
                                left: w * 0.06,
                                right: w * 0.06,
                                height: 18,
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity:
                                        ((0.5 + 0.35 * sway) *
                                                (1 - _flap.value))
                                            .clamp(0.0, 1.0),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            accent.withValues(alpha: 0),
                                            accent.withValues(alpha: .85),
                                            accent.withValues(alpha: 0),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accent.withValues(
                                              alpha: .35,
                                            ),
                                            blurRadius: 26,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // The ring that leaves the seal every few seconds.
                              if (!_breaking)
                                Positioned(
                                  top: seamY - sealSize * 1.6,
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      size: Size.square(sealSize * 3.2),
                                      painter: _SealPulsePainter(
                                        t: idle,
                                        accent: accent,
                                      ),
                                    ),
                                  ),
                                ),
                              // Wax seal, sized to the screen and sitting on the
                              // seam where the flap meets the body — which is the
                              // exact middle of the screen. The key is what
                              // `invitation_seal_test.dart` measures.
                              Positioned(
                                key: const ValueKey('wax-seal'),
                                top: seamY - sealSize / 2,
                                child: Transform.scale(
                                  scale:
                                      (1 + 0.04 * _idle.value) *
                                      (1 + 0.5 * _seal.value),
                                  child: Opacity(
                                    opacity: 1 - _seal.value,
                                    child: CustomPaint(
                                      size: Size(sealSize, sealSize),
                                      painter: _WaxSealPainter(
                                        initials: _initials(inv),
                                        accent: accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Gold shards bursting out of the broken seal.
                              if (_seal.value > 0)
                                Positioned(
                                  bottom: bodyH - sealSize / 2,
                                  child: SizedBox(
                                    width: sealSize * 4,
                                    height: sealSize * 4,
                                    child: CustomPaint(
                                      painter: _SealBurstPainter(
                                        t: _seal.value,
                                        accent: accent,
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
                },
              );
            },
          ),
          // Who it is for, set above the envelope the way a card is addressed.
          if (!_breaking)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: MediaQuery.sizeOf(context).height * 0.13,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'دعوة خاصة',
                      style: _body(
                        10.5,
                        color: _Ink.gold.withValues(alpha: .7),
                      ).copyWith(letterSpacing: 6),
                    ),
                    const SizedBox(height: 10),
                    _GoldText(
                      [
                        inv.groomName,
                        inv.brideName,
                      ].where((e) => e.trim().isNotEmpty).join('  &  '),
                      size: 19,
                      onDark: true,
                    ),
                  ],
                ),
              ),
            ),
          // Not an icon and a sentence: a ring leaving the seal, the way a
          // thing that wants pressing announces itself.
          if (!_breaking)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.sizeOf(context).height * 0.11,
              child: Center(
                child: FadeTransition(
                  opacity: Tween<double>(begin: .45, end: 1).animate(_idle),
                  child: Text(
                    'المسي الختم لفتح الدعوة',
                    style: _body(
                      11.5,
                      color: _Ink.gold.withValues(alpha: .85),
                    ).copyWith(letterSpacing: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Two rings leaving the seal, one behind the other, fading as they go.
///
/// It replaces a touch icon and a sentence. A control that wants pressing is
/// better shown than labelled, and a ring that keeps arriving draws the eye
/// back to the one place on the screen that does anything.
class _SealPulsePainter extends CustomPainter {
  const _SealPulsePainter({required this.t, required this.accent});

  /// The idle cycle, 0..1 and back.
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;

    void ring(double phase) {
      // Each ring runs its own lap of the cycle, half a lap apart.
      final p = (t + phase) % 1.0;
      final r = maxR * (0.34 + 0.66 * p);
      final fade = (1 - p) * 0.5;
      if (fade <= 0.01) return;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = accent.withValues(alpha: fade),
      );
    }

    ring(0.0);
    ring(0.5);
  }

  @override
  bool shouldRepaint(_SealPulsePainter old) => old.t != t;
}

/// An arch drawn in a gold hairline: two uprights that rise and a crown that
/// closes over them.
///
/// It is drawn in one stroke from the foot of one side, up and over, and down
/// the other, so at any moment it looks like a line being traced rather than a
/// shape being faded in. The feet are left open — the arch stands on the page
/// instead of sitting in a box.
class _ArchPainter extends CustomPainter {
  const _ArchPainter({required this.t, required this.accent});

  /// 0 — nothing drawn; 1 — the whole arch.
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0.001 || size.isEmpty) return;

    final w = size.width;
    final h = size.height;
    // The crown is a half-ellipse as wide as the arch and a little under a
    // third of its height; the uprights carry the rest.
    final crown = math.min(w / 2, h * 0.42);
    final foot = h - 4;

    final path = Path()
      ..moveTo(0, foot)
      ..lineTo(0, crown)
      ..arcToPoint(
        Offset(w, crown),
        radius: Radius.elliptical(w / 2, crown),
        clockwise: true,
      )
      ..lineTo(w, foot);

    // Trace it: one metric, cut to the fraction drawn so far.
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * t);

    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.75 * t),
    );

    // A bead of light at the head of the stroke while it is still being
    // drawn — the point the line is coming from.
    if (t < 0.995) {
      final tan = metric.getTangentForOffset(metric.length * t);
      if (tan != null) {
        canvas.drawCircle(
          tan.position,
          2.2,
          Paint()..color = accent.withValues(alpha: 0.9),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ArchPainter old) => old.t != t;
}

/// A hairline border that cuts itself into the hero as the title arrives:
/// four corners growing along the edges until they almost meet, the way an
/// engraver works a plate inwards from its corners.
///
/// It never closes completely — a gap is left at the middle of each side, so
/// the frame reads as drawn rather than as a box around a screen.
class _HeroFramePainter extends CustomPainter {
  const _HeroFramePainter({required this.t, required this.accent});

  /// 0 — nothing; 1 — fully cut.
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0.001) return;
    const inset = 18.0;
    final r = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );

    // Each arm reaches at most 38% of its side, leaving the middle open.
    final hx = r.width * 0.38 * t;
    final hy = r.height * 0.30 * t;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.55 * t);

    void corner(Offset at, double dx, double dy) {
      canvas.drawLine(at, at.translate(dx, 0), line);
      canvas.drawLine(at, at.translate(0, dy), line);
    }

    corner(r.topLeft, hx, hy);
    corner(r.topRight, -hx, hy);
    corner(r.bottomLeft, hx, -hy);
    corner(r.bottomRight, -hx, -hy);
  }

  @override
  bool shouldRepaint(_HeroFramePainter old) => old.t != t;
}

/// The small card that rises out of the envelope.
class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.bride,
    required this.groom,
    required this.width,
    required this.height,
  });

  final String bride;
  final String groom;

  /// Sized against the envelope rather than fixed, so the card always looks
  /// like it came out of *this* envelope on every screen size.
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _Ink.ivory,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .5),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: CustomPaint(
          painter: _ThinFramePainter(progress: 1),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'دعوة زفاف',
                  style: _body(13, color: _Ink.goldDeep, w: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Text(groom, style: _display(24, color: _Ink.night)),
                Text('&', style: _display(16, color: _Ink.gold)),
                Text(bride, style: _display(24, color: _Ink.night)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// SCENE 2 — the invitation itself
// ===========================================================================

class _InvitationScroll extends StatefulWidget {
  const _InvitationScroll({
    super.key,
    required this.code,
    required this.data,
    required this.onChanged,
  });

  final String code;
  final InvitationView data;
  final ValueChanged<InvitationView> onChanged;

  @override
  State<_InvitationScroll> createState() => _InvitationScrollState();
}

class _InvitationScrollState extends State<_InvitationScroll>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  /// The slow swell of the scene behind the hero. Twenty-six seconds there
  /// and back, which is slow enough that you notice the picture has moved
  /// without ever catching it moving.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat(reverse: true);

  final _scroll = ScrollController();
  double _offset = 0;

  Timer? _autoStart;

  /// True once the reader has touched the screen. The page then stays where
  /// they put it for good.
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();
    // Drives the background parallax — the scene drifts slower than the
    // content, which is what gives the page depth.
    _scroll.addListener(() {
      if (mounted) setState(() => _offset = _scroll.offset);
    });
    // Let the entrance finish and the first screen be looked at before the
    // page starts moving.
    _autoStart = Timer(const Duration(milliseconds: 3400), _autoScroll);
  }

  /// Carries the page from wherever it is to the end, at a reading pace.
  ///
  /// The duration is set by distance, not fixed, so a short invitation does
  /// not crawl and a long one does not race: about seventy pixels a second,
  /// held between half a minute and two.
  void _autoScroll() {
    if (!mounted || _handedOver || !_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    final togo = end - _scroll.offset;
    if (togo <= 8) return;
    final seconds = (togo / 70).clamp(30.0, 120.0);
    _scroll.animateTo(
      end,
      duration: Duration(milliseconds: (seconds * 1000).round()),
      curve: Curves.linear,
    );
  }

  /// The reader took over. Stop where we are and do not start again.
  void _handOver() {
    if (_handedOver) return;
    _handedOver = true;
    _autoStart?.cancel();
    if (_scroll.hasClients) {
      // Cancels the running animation by replacing it with a no-op jump.
      _scroll.jumpTo(_scroll.offset);
    }
  }

  @override
  void dispose() {
    _autoStart?.cancel();
    _drift.dispose();
    _enter.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// A staggered reveal slot: each element appears a beat after the last.
  Animation<double> _step(double start, double end) => CurvedAnimation(
    parent: _enter,
    curve: Interval(start, end, curve: Curves.easeOut),
  );

  @override
  Widget build(BuildContext context) {
    final inv = widget.data.invitation;

    final screen = MediaQuery.sizeOf(context);
    final base = _ThemedBackdrop._hex(inv.template?.bgColor, _Ink.night);
    final accent = _ThemedBackdrop._hex(inv.template?.accentColor, _Ink.gold);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Stars first, and they never end: the scene below covers only the
        // first screen, and without this the invitation fell off the sky the
        // moment you scrolled past the hero.
        Positioned.fill(child: _NightField(offset: _offset)),
        // The painted scene sits behind everything and drifts at a third of
        // the scroll speed, so the hero reads as a place you move through
        // rather than a picture behind a card.
        Positioned(
          // The scene drifts at a third of the scroll, then parks. Left
          // unclamped it slid off the top of a long invitation and the page
          // fell onto flat night with a hard horizontal edge across it; the
          // parallax is only read in the first screen or two anyway.
          top: -math.min(_offset * 0.32, screen.height * 0.095),
          left: 0,
          right: 0,
          height: screen.height * 1.1,
          // A very slow swell and sideways drift. A hero that is a still
          // photograph reads as a screenshot; the same picture moving a few
          // per cent reads as a place.
          child: AnimatedBuilder(
            animation: _drift,
            builder: (context, child) {
              final k = Curves.easeInOut.transform(_drift.value);
              return Transform.scale(
                scale: 1.0 + 0.055 * k,
                alignment: Alignment(-0.25 + 0.5 * k, -0.1),
                child: child,
              );
            },
            child: _SceneLayer(
              base: base,
              accent: accent,
              template: inv.template,
            ),
          ),
        ),
        // Any touch at all — a drag, a tap, a press on a button — ends the
        // automatic descent. Listener rather than a scroll notification so it
        // stops on contact, not after the page has already been pulled.
        Listener(
          onPointerDown: (_) => _handOver(),
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            children: [
              // ---- HERO: full bleed, type straight onto the scene ----
              _SceneHero(
                invitation: inv,
                enter: _enter,
                height: screen.height,
                accent: accent,
              ),
              // The hero settles into the night rather than dissolving into a
              // sheet: a band of deeper sky, so the eye knows the reading part
              // has begun while the stars carry straight on through it.
              Container(
                // Was 140, which sat on top of the hero's own full screen and
                // opened the reading part on a void. Enough to mark the change
                // of register, not enough to be a gap.
                height: 56,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00060711), Color(0x99060711)],
                  ),
                ),
              ),
              Container(
                // Transparent on purpose: see [_Ink.glass]. The scene behind is
                // the invitation's ground from the first screen to the last.
                color: const Color(0x99060711),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    _Reveal(
                      anim: _step(0.45, 0.7),
                      child: _Countdown(target: inv.eventDate),
                    ),

                    // The couple's words sit on the page itself, framed by quote
                    // flourishes — boxing them would make them look like a form
                    // field rather than a sentiment.
                    if ((inv.customMessage ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _Reveal(
                        anim: _step(0.55, 0.8),
                        child: _Quote(text: inv.customMessage!.trim()),
                      ),
                    ],

                    if ((inv.venue ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _Reveal(anim: _step(0.6, 0.85), child: const _Flourish()),
                      const SizedBox(height: 22),
                      _Reveal(
                        anim: _step(0.62, 0.88),
                        child: _VenueBlock(
                          venue: inv.venue!,
                          mapUrl: inv.mapUrl,
                        ),
                      ),
                    ],

                    if (inv.gallery.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _Reveal(anim: _step(0.65, 0.9), child: const _Flourish()),
                      const SizedBox(height: 18),
                      _Reveal(
                        anim: _step(0.66, 0.92),
                        child: const _SectionHeading(
                          title: 'لحظاتنا الجميلة',
                          sub: 'معرض الصور',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Reveal(
                        anim: _step(0.68, 0.94),
                        child: _GalleryStrip(images: inv.gallery),
                      ),
                    ],

                    const SizedBox(height: 42),
                    _Reveal(anim: _step(0.7, 0.95), child: const _Flourish()),
                    const SizedBox(height: 18),
                    _Reveal(
                      anim: _step(0.71, 0.96),
                      child: const _SectionHeading(
                        title: 'تأكيد الحضور',
                        sub: 'يسعدنا وجودكم',
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Reveal(
                      anim: _step(0.72, 0.97),
                      child: _RsvpPanel(
                        code: widget.code,
                        data: widget.data,
                        onChanged: widget.onChanged,
                      ),
                    ),

                    const SizedBox(height: 42),
                    _Reveal(anim: _step(0.75, 1.0), child: const _Flourish()),
                    const SizedBox(height: 18),
                    _Reveal(
                      anim: _step(0.76, 1.0),
                      child: const _SectionHeading(
                        title: 'سجل التهاني',
                        sub: 'شاركونا فرحتنا',
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Reveal(
                      anim: _step(0.78, 1.0),
                      child: _WishesPanel(
                        code: widget.code,
                        data: widget.data,
                        onChanged: widget.onChanged,
                      ),
                    ),

                    if ((inv.giftNote ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _Reveal(anim: _step(0.8, 1.0), child: const _Flourish()),
                      const SizedBox(height: 18),
                      _Reveal(
                        anim: _step(0.82, 1.0),
                        child: _GiftPanel(note: inv.giftNote!.trim()),
                      ),
                    ],

                    const SizedBox(height: 30),
                    _Reveal(anim: _step(0.85, 1.0), child: const _Flourish()),
                    const SizedBox(height: 18),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'بكل الحب',
                            style: _body(
                              12.5,
                              color: _Ink.body.withValues(alpha: .65),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _GoldText('أفراحنا', size: 17),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Floating section bar, the way the reference keeps navigation within
        // reach without ever covering the invitation itself.
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: _SectionBar(onJump: _jumpTo),
        ),
      ],
    );
  }

  /// Scrolls to a named block. Offsets are proportional to the hero so this
  /// stays right on any screen size.
  void _jumpTo(int index) {
    final h = MediaQuery.sizeOf(context).height;
    final targets = [h * 1.05, h * 1.5, h * 1.95, h * 2.4, h * 2.8];
    _scroll.animateTo(
      targets[index.clamp(0, targets.length - 1)],
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }
}

/// Fades and lifts its child in on [anim].
class _Reveal extends StatelessWidget {
  const _Reveal({required this.anim, required this.child});

  final Animation<double> anim;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - anim.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

/// The main card: ornate gold frame that draws itself, then the names.
class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.invitation, required this.enter});

  final InvitationModel invitation;
  final AnimationController enter;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  /// Never stops. The card breathes and the foil keeps catching light, so the
  /// invitation stays alive instead of freezing the moment it has loaded.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  InvitationModel get invitation => widget.invitation;
  AnimationController get enter => widget.enter;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE d MMMM y', 'ar');
    final tf = DateFormat('HH:mm');

    return AnimatedBuilder(
      animation: _ambient,
      builder: (context, inner) {
        // A slow figure-of-eight tilt with a matching rise. Small enough to
        // feel like the card is held rather than animated.
        final a = _ambient.value * 2 * math.pi;
        final lift = math.sin(a) * 5;
        final tiltX = math.sin(a) * 0.012;
        final tiltY = math.cos(a * .7) * 0.016;
        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0011)
              ..rotateX(tiltX)
              ..rotateY(tiltY),
            child: inner,
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: 3 / 4.2,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_Ink.deep, Color(0xFF23283A), _Ink.deep],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .55),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: Listenable.merge([enter, _ambient]),
              builder: (context, child) => Stack(
                fit: StackFit.expand,
                children: [
                  // Woven paper texture, then a vignette: without these the card
                  // is a flat swatch of colour.
                  const CustomPaint(painter: _CardTexturePainter()),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: .95,
                        colors: [Color(0x00000000), Color(0x66000000)],
                        stops: [.55, 1.0],
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: _GoldFramePainter(
                      progress: Curves.easeInOut.transform(
                        (enter.value / 0.5).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                  child!,
                  // A single slow pass of light across the foil, once the card
                  // has settled — the moment that sells it as metal.
                  // The foil keeps catching light: one pass per ambient cycle,
                  // spending most of the cycle dark so it reads as an occasional
                  // glint rather than a strobe.
                  CustomPaint(
                    painter: _SheenPainter(
                      t: enter.value < .55
                          ? 0
                          : ((_ambient.value % 1.0) / .38).clamp(0.0, 1.0),
                    ),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 38,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'بسم الله الرحمن الرحيم',
                      style: _body(
                        11.5,
                        color: _Ink.gold.withValues(alpha: .75),
                      ),
                    ),
                    const Spacer(),
                    _OrbitRings(
                      // The medallion is 74; the rings need room to swing
                      // clear of it on both sides.
                      size: 128,
                      accent: _ThemedBackdrop._hex(
                        invitation.template?.accentColor,
                        _Ink.gold,
                      ),
                      child: _Monogram(
                        groom: invitation.groomName,
                        bride: invitation.brideName,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _GoldText('دعوة زفاف', size: 27, onDark: true),
                    const SizedBox(height: 12),
                    const _Ornament(),
                    const SizedBox(height: 16),
                    Text(
                      invitation.groomName,
                      textAlign: TextAlign.center,
                      style: _display(29),
                    ),
                    const SizedBox(height: 2),
                    _GoldText('&', size: 19, onDark: true),
                    const SizedBox(height: 2),
                    Text(
                      invitation.brideName,
                      textAlign: TextAlign.center,
                      style: _display(29),
                    ),
                    const SizedBox(height: 16),
                    const _Ornament(),
                    const Spacer(),
                    Text(
                      df.format(invitation.eventDate),
                      textAlign: TextAlign.center,
                      style: _body(13.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tf.format(invitation.eventDate),
                      style: _body(13.5, color: _Ink.gold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text painted with the gold gradient rather than a flat colour — the single
/// biggest difference between "yellow text" and something that reads as foil.
class _GoldText extends StatelessWidget {
  const _GoldText(this.text, {required this.size, this.onDark = false});

  final String text;
  final double size;

  /// Foil gold over the scene; the darker printed gold on the paper ground,
  /// where pale foil just reads as washed-out yellow.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) =>
          (onDark ? _Ink.goldSweep : _Ink.goldInkSweep).createShader(r),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: _display(size, color: Colors.white),
      ),
    );
  }
}

/// Small centred flourish used as a divider.
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      width: 150,
      child: CustomPaint(painter: _OrnamentPainter()),
    );
  }
}

// ---- countdown -------------------------------------------------------------

class _Countdown extends StatefulWidget {
  const _Countdown({required this.target});

  final DateTime target;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;
  late Duration _left = _remaining();

  Duration _remaining() {
    final d = widget.target.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _left = _remaining());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_left == Duration.zero) {
      return _Panel(
        child: Text(
          'اليوم الموعود 🤍',
          textAlign: TextAlign.center,
          style: _body(16, color: _Ink.gold),
        ),
      );
    }
    final d = _left.inDays;
    final h = _left.inHours % 24;
    final m = _left.inMinutes % 60;
    final s = _left.inSeconds % 60;

    // One plate, four figures, hairlines between them. No panel around it:
    // the numbers are the object, and a border would make them a widget.
    return Column(
      children: [
        Text(
          'العدّ التنازلي',
          style: _body(
            10,
            color: _Ink.goldInk.withValues(alpha: .85),
          ).copyWith(letterSpacing: 6, height: 1.2),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _Ink.glass,
            border: Border(
              top: BorderSide(color: _Ink.goldInk.withValues(alpha: .35)),
              bottom: BorderSide(color: _Ink.goldInk.withValues(alpha: .35)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Unit(value: d, label: 'يوم'),
                const _UnitRule(),
                _Unit(value: h, label: 'ساعة'),
                const _UnitRule(),
                _Unit(value: m, label: 'دقيقة'),
                const _UnitRule(),
                _Unit(value: s, label: 'ثانية'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The hairline standing between two figures of the countdown. Short, and
/// well inside the plate, so it divides without boxing anything.
class _UnitRule extends StatelessWidget {
  const _UnitRule();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 34,
    color: _Ink.goldInk.withValues(alpha: .22),
  );
}

class _Unit extends StatelessWidget {
  const _Unit({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          // No box: the figure IS the element. Each digit still rolls up as
          // it changes, which is the only motion this block needs.
          SizedBox(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => ClipRect(
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .6),
                    end: Offset.zero,
                  ).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.center,
                children: [...previous, ?current],
              ),
              child: Text(
                value.toString().padLeft(2, '0'),
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 26,
                  color: _Ink.goldInk,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: _body(10.5, color: _Ink.body.withValues(alpha: .8)),
          ),
        ],
      ),
    );
  }
}

// ---- panels ----------------------------------------------------------------

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.title, this.icon});

  final Widget child;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Glass over the living background, not a flat grey box.
        color: _Ink.glass,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _Ink.goldInk.withValues(alpha: .28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: CustomPaint(
        // Engraved corner brackets on every panel — the detail that makes a
        // surface look designed rather than defaulted.
        painter: const _PanelCornersPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Expanded(child: _HairRule(fromLeft: true)),
                    const SizedBox(width: 10),
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: _Ink.gold),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      title!,
                      style: _body(
                        13.5,
                        color: _Ink.goldLight,
                        w: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: _HairRule(fromLeft: false)),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A rule that fades out toward the edge, flanking a panel title.
class _HairRule extends StatelessWidget {
  const _HairRule({required this.fromLeft});

  final bool fromLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: fromLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            _Ink.goldInk.withValues(alpha: 0),
            _Ink.goldInk.withValues(alpha: .45),
          ],
        ),
      ),
    );
  }
}

/// Short gold brackets inset at each corner of a panel.
class _PanelCornersPainter extends CustomPainter {
  const _PanelCornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = _Ink.goldInk.withValues(alpha: .40);

    const pad = 9.0;
    const len = 16.0;
    for (final (o, sx, sy) in [
      (const Offset(pad, pad), 1.0, 1.0),
      (Offset(size.width - pad, pad), -1.0, 1.0),
      (Offset(size.width - pad, size.height - pad), -1.0, -1.0),
      (Offset(pad, size.height - pad), 1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(o.dx + sx * len, o.dy)
          ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + sy * len),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _GiftPanel extends StatelessWidget {
  const _GiftPanel({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'الهدايا والحصالة',
      icon: Icons.card_giftcard_rounded,
      child: Column(
        children: [
          SelectableText(
            note,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 17,
              color: _Ink.goldInk,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _GoldButton(
            icon: Icons.copy_rounded,
            label: 'نسخ المعلومات',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: note));
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
    );
  }
}

// ---- RSVP ------------------------------------------------------------------

class _RsvpPanel extends StatefulWidget {
  const _RsvpPanel({
    required this.code,
    required this.data,
    required this.onChanged,
  });

  final String code;
  final InvitationView data;
  final ValueChanged<InvitationView> onChanged;

  @override
  State<_RsvpPanel> createState() => _RsvpPanelState();
}

class _RsvpPanelState extends State<_RsvpPanel> {
  late final _name = TextEditingController(
    text: widget.data.myRsvp?.name ?? '',
  );
  late final _notes = TextEditingController(
    text: widget.data.myRsvp?.notes ?? '',
  );
  late bool? _attending = widget.data.myRsvp?.attending;
  late int _plusOnes = widget.data.myRsvp?.plusOnes ?? 0;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _attending == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اكتب اسمك واختر الحضور')));
      return;
    }
    setState(() => _busy = true);
    try {
      final v = await InvitationService().rsvp(
        widget.code,
        name: _name.text.trim(),
        attending: _attending!,
        plusOnes: _attending! ? _plusOnes : 0,
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      widget.onChanged(v);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_attending! ? 'تم تأكيد حضورك 🎉' : 'تم تسجيل اعتذارك'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'تعذّر الإرسال'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.data.invitation.rsvpOpen;

    // No panel title: the section heading above already names this block.
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              '${widget.data.confirmedCount} تأكيد حضور',
              style: _body(
                12,
                color: _Ink.goldInk.withValues(alpha: .9),
                w: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!open)
            Text(
              'أُغلق تأكيد الحضور لهذه الدعوة.',
              textAlign: TextAlign.center,
              style: _body(13),
            )
          else ...[
            _Field(controller: _name, hint: 'الاسم الكامل'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Choice(
                    label: 'سأحضر',
                    selected: _attending == true,
                    onTap: () => setState(() => _attending = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Choice(
                    label: 'أعتذر',
                    selected: _attending == false,
                    onTap: () => setState(() => _attending = false),
                  ),
                ),
              ],
            ),
            if (_attending == true) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('عدد المرافقين', style: _body(13, color: _Ink.body)),
                  const Spacer(),
                  _Stepper(
                    value: _plusOnes,
                    onChanged: (v) => setState(() => _plusOnes = v),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            _Field(controller: _notes, hint: 'ملاحظة (اختياري)'),
            const SizedBox(height: 14),
            _GoldButton(
              icon: _busy ? null : Icons.check_rounded,
              label: _busy ? 'جارٍ الإرسال…' : 'إرسال',
              onTap: _busy ? null : _submit,
            ),
          ],
        ],
      ),
    );
  }
}

class _WishesPanel extends StatefulWidget {
  const _WishesPanel({
    required this.code,
    required this.data,
    required this.onChanged,
  });

  final String code;
  final InvitationView data;
  final ValueChanged<InvitationView> onChanged;

  @override
  State<_WishesPanel> createState() => _WishesPanelState();
}

class _WishesPanelState extends State<_WishesPanel> {
  final _name = TextEditingController();
  // Not `_body`: that would shadow the `_body()` text-style helper above.
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_name.text.trim().isEmpty || _message.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final v = await InvitationService().wish(
        widget.code,
        name: _name.text.trim(),
        body: _message.text.trim(),
      );
      if (!mounted) return;
      _message.clear();
      widget.onChanged(v);
    } catch (_) {
      // A failed wish is not worth interrupting the invitation for.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Titled by the section heading above.
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(controller: _name, hint: 'الاسم'),
          const SizedBox(height: 8),
          _Field(controller: _message, hint: 'اكتب تهنئتك…', maxLines: 2),
          const SizedBox(height: 10),
          _GoldButton(
            icon: Icons.send_rounded,
            label: _busy ? 'جارٍ النشر…' : 'نشر',
            onTap: _busy ? null : _send,
          ),
          if (widget.data.wishes.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final w in widget.data.wishes.take(12))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _Ink.paper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _Ink.goldInk.withValues(alpha: .16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.name,
                      style: _body(
                        12.5,
                        color: _Ink.goldInk,
                        w: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('“${w.body}”', style: _body(13)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---- small controls --------------------------------------------------------

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: _body(14, color: _Ink.heading),
      cursorColor: _Ink.goldInk,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _body(13, color: _Ink.body.withValues(alpha: .55)),
        filled: true,
        fillColor: _Ink.glassHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _Ink.goldInk.withValues(alpha: .22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _Ink.goldInk, width: 1.4),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _Ink.goldInk : _Ink.glassHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? _Ink.goldInk
                : _Ink.goldInk.withValues(alpha: .22),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _Ink.goldInk.withValues(alpha: .35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: _body(
            14,
            color: selected ? Colors.white : _Ink.heading,
            w: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Ink.glassHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Ink.goldInk.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.remove_rounded,
              size: 18,
              color: _Ink.goldInk,
            ),
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          Text(
            '$value',
            style: _body(15, color: _Ink.heading, w: FontWeight.w700),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 18, color: _Ink.goldInk),
            onPressed: value < 20 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, this.icon, this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .6 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_Ink.goldDeep, _Ink.gold, _Ink.goldDeep],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: _Ink.night),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: _body(14, color: _Ink.night, w: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 60,
              color: _Ink.gold,
            ),
            const SizedBox(height: 14),
            Text(
              error is ApiException
                  ? (error as ApiException).message
                  : 'تعذّر فتح الدعوة',
              textAlign: TextAlign.center,
              style: _body(15),
            ),
            const SizedBox(height: 18),
            _GoldButton(
              icon: Icons.refresh_rounded,
              label: 'إعادة المحاولة',
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// BACKDROP + PAINTERS
// ===========================================================================

/// Backdrop for the chosen theme: the template's own colours plus its living
/// animation. Falls back to the deep night palette when an invitation has no
/// template, so an older invitation still looks intentional.
class _ThemedBackdrop extends StatelessWidget {
  const _ThemedBackdrop({required this.template});

  final InvitationTemplateModel? template;

  static Color _hex(String? hex, Color fallback) {
    if (hex == null) return fallback;
    try {
      var h = hex.replaceFirst('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _hex(template?.bgColor, _Ink.night);
    final accent = _hex(template?.accentColor, _Ink.gold);
    final anim = invitationAnimFromString(template?.animation);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.5),
              radius: 1.2,
              colors: [Color.lerp(bg, Colors.white, .10) ?? bg, bg],
            ),
          ),
        ),
        if (anim != InvitationAnim.none)
          AnimatedInvitationBg(anim: anim, accent: accent)
        else
          const _Particles(count: 22),
      ],
    );
  }
}

/// Slow drifting gold motes. Cheap: a handful of circles on one ticker.
/// Three depths of stars over the night, each moving at its own fraction of
/// the scroll, and a shooting star every few seconds.
///
/// Parallax is the whole trick: the near layer travels almost with the
/// content and the far layer barely moves, which is what makes a flat screen
/// read as depth. One repeating controller drives the twinkle so the field
/// costs a single repaint per frame.
class _NightField extends StatefulWidget {
  const _NightField({required this.offset});

  /// Pixels scrolled. The layers divide it between them.
  final double offset;

  @override
  State<_NightField> createState() => _NightFieldState();
}

class _NightFieldState extends State<_NightField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  /// Seeded, so the constellation is the same every time the invitation is
  /// opened — a guest who comes back twice sees the same sky.
  late final List<_Spark> _stars = List.generate(130, (i) {
    final r = math.Random(i * 2654435761 % 100003);
    final depth = i % 3; // 0 far, 2 near
    return _Spark(
      x: r.nextDouble(),
      y: r.nextDouble(),
      radius: 0.6 + depth * 0.45 + r.nextDouble() * 0.7,
      phase: r.nextDouble() * math.pi * 2,
      depth: depth,
      flare: r.nextDouble() < 0.1,
    );
  });

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
          builder: (_, _) => CustomPaint(
            painter: _NightFieldPainter(
              stars: _stars,
              t: _c.value,
              offset: widget.offset,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _Spark {
  const _Spark({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.depth,
    required this.flare,
  });

  final double x, y, radius, phase;

  /// 0 far, 1 middle, 2 near — sets both the drift and the brightness.
  final int depth;

  /// The few that get a four-point glint.
  final bool flare;
}

class _NightFieldPainter extends CustomPainter {
  const _NightFieldPainter({
    required this.stars,
    required this.t,
    required this.offset,
  });

  final List<_Spark> stars;
  final double t;
  final double offset;

  /// How far each depth travels per pixel scrolled.
  static const _drift = [0.06, 0.14, 0.26];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final dot = Paint();
    final flare = Paint()
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;

    for (final s in stars) {
      // Wrap instead of scrolling away, so the field never runs out however
      // long the invitation is.
      final shift = offset * _drift[s.depth];
      final y = ((s.y * size.height) - shift) % size.height;
      final o = Offset(s.x * size.width, y < 0 ? y + size.height : y);

      final twinkle = 0.55 + 0.45 * math.sin(t * math.pi * 2 + s.phase);
      final a = (0.18 + 0.22 * s.depth) * twinkle;
      dot.color = _Ink.goldLight.withValues(alpha: a.clamp(0.0, 1.0));
      canvas.drawCircle(o, s.radius, dot);

      if (s.flare) {
        final len = s.radius * (3 + 2 * twinkle);
        flare.color = _Ink.goldLight.withValues(alpha: a * 0.5);
        canvas.drawLine(o.translate(-len, 0), o.translate(len, 0), flare);
        canvas.drawLine(o.translate(0, -len), o.translate(0, len), flare);
      }
    }

    _shootingStar(canvas, size);
  }

  /// One every six seconds, on a path of its own, fading as it goes.
  void _shootingStar(Canvas canvas, Size size) {
    const period = 0.25; // of the 24 s cycle → every 6 s
    final n = (t / period).floor();
    final local = (t - n * period) / period; // 0..1 across its life
    if (local > 0.34) return;

    final r = math.Random(n * 7919 + 3);
    final start = Offset(
      (0.25 + r.nextDouble() * 0.7) * size.width,
      r.nextDouble() * size.height * 0.5,
    );
    final angle = math.pi * (0.74 + r.nextDouble() * 0.1);
    final dir = Offset(math.cos(angle), math.sin(angle));
    final p = Curves.easeOut.transform(local / 0.34);
    final head = start + dir * (size.shortestSide * 0.8 * p);
    final tail = head - dir * (110 * (1 - p * 0.4));
    final fade = 1 - local / 0.34;

    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            _Ink.goldLight.withValues(alpha: 0),
            _Ink.goldLight.withValues(alpha: fade * 0.85),
          ],
        ).createShader(Rect.fromPoints(tail, head)),
    );
    canvas.drawCircle(
      head,
      1.7,
      Paint()..color = _Ink.goldLight.withValues(alpha: fade),
    );
  }

  @override
  bool shouldRepaint(_NightFieldPainter old) =>
      old.t != t || old.offset != offset;
}

/// Two tilted rings turning around whatever they are given, at different
/// speeds and in opposite directions — the couple's initials with an orbit.
class _OrbitRings extends StatefulWidget {
  const _OrbitRings({
    required this.child,
    required this.accent,
    this.size = 150,
  });

  final Widget child;
  final Color accent;
  final double size;

  @override
  State<_OrbitRings> createState() => _OrbitRingsState();
}

class _OrbitRingsState extends State<_OrbitRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                painter: _OrbitPainter(t: _c.value, accent: widget.accent),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.t, required this.accent});

  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    void orbit(double rx, double ry, double tilt, double speed, double alpha) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(tilt + t * math.pi * 2 * speed);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: rx * 2,
        height: ry * 2,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = accent.withValues(alpha: alpha),
      );
      // The bead riding the ring, so the turn can actually be seen.
      canvas.drawCircle(
        Offset(rx, 0),
        1.9,
        Paint()..color = accent.withValues(alpha: alpha * 2.2),
      );
      canvas.restore();
    }

    orbit(r * 0.96, r * 0.34, 0.22, 1.0, 0.30);
    orbit(r * 0.80, r * 0.28, -0.55, -0.62, 0.22);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}

class _Particles extends StatefulWidget {
  const _Particles({required this.count});

  final int count;

  @override
  State<_Particles> createState() => _ParticlesState();
}

class _ParticlesState extends State<_Particles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  late final List<_Mote> _motes = List.generate(widget.count, (i) {
    final r = math.Random(i * 7919);
    return _Mote(
      x: r.nextDouble(),
      size: 1.0 + r.nextDouble() * 2.2,
      speed: .25 + r.nextDouble() * .7,
      phase: r.nextDouble(),
      drift: (r.nextDouble() - .5) * .12,
    );
  });

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
          painter: _ParticlePainter(motes: _motes, t: _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Mote {
  const _Mote({
    required this.x,
    required this.size,
    required this.speed,
    required this.phase,
    required this.drift,
  });

  final double x, size, speed, phase, drift;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.motes, required this.t});

  final List<_Mote> motes;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final m in motes) {
      final prog = (t * m.speed + m.phase) % 1.0;
      final y = size.height * (1 - prog);
      final x = size.width * (m.x + m.drift * math.sin(prog * math.pi * 2));
      // Fade in and out at the ends so motes don't pop.
      final fade = math.sin(prog * math.pi).clamp(0.0, 1.0);
      p.color = _Ink.goldLight.withValues(alpha: .5 * fade);
      canvas.drawCircle(Offset(x, y), m.size, p);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.t != t;
}

/// Envelope body: ivory paper with the two folded side flaps.
class _EnvelopeBodyPainter extends CustomPainter {
  _EnvelopeBodyPainter({this.accent = _Ink.gold, this.folds = true});

  final Color accent;

  /// The folded pocket is the front of the envelope; the same paper with no
  /// folds is the back panel behind everything, which is what stops the
  /// backdrop showing through the envelope's own corners.
  final bool folds;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(5));

    // Drop shadow so the envelope sits above the backdrop.
    canvas.drawRRect(
      rr.shift(const Offset(0, 14)),
      Paint()
        ..color = Colors.black.withValues(alpha: .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // Paper: warm ivory, lit from the top-left like a real photograph.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFBF5EA), Color(0xFFEFE3CE), Color(0xFFDFCFB2)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(r),
    );

    canvas.save();
    canvas.clipRRect(rr);

    // Blind-embossed florals, pressed into the stock. A flat repeating grid
    // reads as wallpaper; relief reads as paper you could run a thumb over.
    const _EmbossPainter(density: 1.0, seed: 7).paint(canvas, size);

    if (!folds) {
      canvas.restore();
      return;
    }

    // The two side folds and the bottom fold, each shaded rather than drawn as
    // a hairline, so the paper reads as folded instead of scored.
    final apex = Offset(size.width / 2, size.height * .60);

    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      left,
      Paint()..color = const Color(0xFF9C8256).withValues(alpha: .10),
    );

    final right = Path()
      ..moveTo(size.width, 0)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      right,
      Paint()..color = const Color(0xFF6B5836).withValues(alpha: .06),
    );

    final bottom = Path()
      ..moveTo(0, size.height)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      bottom,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF8A7448).withValues(alpha: .16),
            const Color(0xFF8A7448).withValues(alpha: .0),
          ],
        ).createShader(r),
    );

    // Crisp fold lines on top of the shading, so the seams read at a glance.
    final fold = Paint()
      ..color = const Color(0xFFB9A488).withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9;
    canvas.drawLine(Offset.zero, apex, fold);
    canvas.drawLine(Offset(size.width, 0), apex, fold);
    canvas.drawLine(Offset(0, size.height), apex, fold);
    canvas.drawLine(Offset(size.width, size.height), apex, fold);

    canvas.restore();

    // Foil hairline around the whole envelope.
    canvas.drawRRect(
      rr.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..color = accent.withValues(alpha: .45),
    );
  }

  @override
  bool shouldRepaint(covariant _EnvelopeBodyPainter old) =>
      old.accent != accent;
}

/// The triangular flap. Darkens slightly as it swings to suggest its inside.
class _FlapPainter extends CustomPainter {
  _FlapPainter({required this.open, this.accent = _Ink.gold});

  final double open;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    // Past halfway the flap has turned over and we are looking at its lining,
    // which on good stationery is a deeper, richer colour than the outside.
    final inside = open > .5;

    // The shadow it throws on the panel underneath. Without it, flap and back
    // are the same paper at the same tone and the fold disappears — the flap
    // stops reading as a separate sheet lying on top.
    if (!inside) {
      canvas.drawPath(
        path.shift(const Offset(0, 5)),
        Paint()
          ..color = const Color(0xFF6B5836).withValues(alpha: .28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: inside
              ? [
                  Color.lerp(accent, Colors.black, .58) ?? accent,
                  Color.lerp(accent, Colors.black, .40) ?? accent,
                ]
              : const [Color(0xFFFCF7EE), Color(0xFFE9DCC4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );

    if (inside) {
      // Lining damask, so the opened flap isn't a flat triangle.
      canvas.save();
      canvas.clipPath(path);
      const _EmbossPainter(density: .7, seed: 21).paint(canvas, size);
      canvas.restore();
    } else {
      canvas.save();
      canvas.clipPath(path);
      const _EmbossPainter(density: .8, seed: 13).paint(canvas, size);
      canvas.restore();
      // Soft shading toward the point while it is still closed.
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF9C8256).withValues(alpha: 0),
              const Color(0xFF9C8256).withValues(alpha: .18),
            ],
          ).createShader(rect),
      );
    }

    // Foil edge along the two diagonals.
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: inside ? .55 : .40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(covariant _FlapPainter old) =>
      old.open != open || old.accent != accent;
}

/// Gold wax seal with a raised rim and a monogram-ish flourish.
class _WaxSealPainter extends CustomPainter {
  _WaxSealPainter({this.initials = '', this.accent = _Ink.gold});

  /// The couple's initials, struck into the wax like a real signet.
  final String initials;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final light = Color.lerp(accent, Colors.white, .55) ?? accent;
    final deep = Color.lerp(accent, Colors.black, .45) ?? accent;

    // Cast shadow — the seal sits ON the paper, it isn't printed into it.
    canvas.drawCircle(
      c.translate(0, r * .10),
      r * .95,
      Paint()
        ..color = Colors.black.withValues(alpha: .40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // Irregular wax edge — a perfect circle reads as a sticker. Two
    // frequencies of wobble keep it from looking like a cog.
    final blob = Path();
    for (var i = 0; i <= 96; i++) {
      final a = i / 96 * math.pi * 2;
      final wobble =
          1 +
          0.030 * math.sin(a * 9 + .6) +
          0.020 * math.cos(a * 5) +
          0.012 * math.sin(a * 17);
      final p = Offset(
        c.dx + r * wobble * math.cos(a),
        c.dy + r * wobble * math.sin(a),
      );
      i == 0 ? blob.moveTo(p.dx, p.dy) : blob.lineTo(p.dx, p.dy);
    }
    blob.close();

    canvas.drawPath(
      blob,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.45),
          colors: [light, accent, deep],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.05)),
    );

    // Pressed rim: a bright inner highlight over a dark groove gives the
    // impression the signet squeezed the wax outward.
    canvas.drawCircle(
      c,
      r * .80,
      Paint()
        ..color = deep.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .10,
    );
    canvas.drawCircle(
      c.translate(-r * .02, -r * .03),
      r * .80,
      Paint()
        ..color = light.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .045,
    );

    // Fine beaded ring, the way an engraved signet edge looks.
    for (var i = 0; i < 36; i++) {
      final a = i / 36 * math.pi * 2;
      canvas.drawCircle(
        Offset(c.dx + r * .68 * math.cos(a), c.dy + r * .68 * math.sin(a)),
        r * .022,
        Paint()..color = deep.withValues(alpha: .5),
      );
    }

    // The monogram, struck darker with a light edge above it (emboss).
    if (initials.isNotEmpty) {
      for (final (dy, color) in [
        (r * .035, light.withValues(alpha: .55)),
        (0.0, deep.withValues(alpha: .85)),
      ]) {
        final tp = TextPainter(
          text: TextSpan(
            text: initials,
            style: GoogleFonts.cormorantGaramond(
              fontSize: r * .62,
              height: 1,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: r * .02,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(c.dx - tp.width / 2, c.dy - tp.height / 2 + dy),
        );
      }
    }

    // Specular sheen across the upper-left, so the wax looks waxy.
    canvas.save();
    canvas.clipPath(blob);
    canvas.drawCircle(
      c.translate(-r * .38, -r * .42),
      r * .55,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: .30),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: c.translate(-r * .38, -r * .42),
                radius: r * .55,
              ),
            ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaxSealPainter old) =>
      old.initials != initials || old.accent != accent;
}

/// Ornate double border with corner flourishes, drawn progressively so the
/// frame appears to be inscribed onto the card.
class _GoldFramePainter extends CustomPainter {
  _GoldFramePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..shader = _Ink.goldSweep.createShader(Offset.zero & size);

    final hair = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = _Ink.gold.withValues(alpha: .55);

    // Three rules at different weights — a single line looks like a border,
    // three at graded weights look like engraving.
    for (final (inset, paint) in [(13.0, gold), (18.0, hair), (23.0, gold)]) {
      final rect = Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      );
      canvas.drawPath(_partial(Path()..addRect(rect), progress), paint);
    }

    // Corner cartouches come in once the rules are mostly inscribed.
    final cf = ((progress - .55) / .45).clamp(0.0, 1.0);
    if (cf <= 0) return;

    for (final (o, sx, sy) in [
      (const Offset(23, 23), 1.0, 1.0),
      (Offset(size.width - 23, 23), -1.0, 1.0),
      (Offset(size.width - 23, size.height - 23), -1.0, -1.0),
      (Offset(23, size.height - 23), 1.0, -1.0),
    ]) {
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.scale(sx, sy);
      _cornerScroll(canvas, cf);
      canvas.restore();
    }

    // Small diamonds at the midpoint of each rule — a classic engraved break.
    final d = Paint()..color = _Ink.gold.withValues(alpha: cf);
    for (final p in [
      Offset(size.width / 2, 23),
      Offset(size.width / 2, size.height - 23),
      Offset(23, size.height / 2),
      Offset(size.width - 23, size.height / 2),
    ]) {
      final path = Path()
        ..moveTo(p.dx, p.dy - 3.4)
        ..lineTo(p.dx + 3.4, p.dy)
        ..lineTo(p.dx, p.dy + 3.4)
        ..lineTo(p.dx - 3.4, p.dy)
        ..close();
      canvas.drawPath(path, d);
    }
  }

  /// A botanical corner: a sweeping stem, two leaves and a bud, drawn from the
  /// corner outward as [t] advances.
  void _cornerScroll(Canvas canvas, double t) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = _Ink.gold.withValues(alpha: t);

    final stem = Path()
      ..moveTo(0, 34)
      ..cubicTo(0, 14, 14, 0, 34, 0);
    canvas.drawPath(_partial(stem, t), ink);

    final inner = Path()
      ..moveTo(0, 22)
      ..cubicTo(0, 10, 10, 0, 22, 0);
    canvas.drawPath(
      _partial(inner, t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = _Ink.gold.withValues(alpha: t * .6),
    );

    // Leaves, only once the stem has been drawn.
    final lt = ((t - .5) / .5).clamp(0.0, 1.0);
    if (lt <= 0) return;

    final leafPaint = Paint()..color = _Ink.gold.withValues(alpha: lt * .85);
    for (final (px, py, rot) in [(7.0, 20.0, -0.5), (20.0, 7.0, -1.1)]) {
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(7 * lt, -4 * lt, 13 * lt, 0)
        ..quadraticBezierTo(7 * lt, 4 * lt, 0, 0)
        ..close();
      canvas.drawPath(leaf, leafPaint);
      canvas.restore();
    }

    canvas.drawCircle(
      const Offset(3.4, 3.4),
      2.1 * lt,
      Paint()..color = _Ink.goldLight.withValues(alpha: lt),
    );
  }

  /// Returns the first [t] fraction of [path] — the "draw-on" effect.
  Path _partial(Path path, double t) {
    if (t >= 1) return path;
    final out = Path();
    for (final metric in path.computeMetrics()) {
      out.addPath(metric.extractPath(0, metric.length * t), Offset.zero);
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _GoldFramePainter old) =>
      old.progress != progress;
}

/// Thin single border for the small card in the envelope.
class _ThinFramePainter extends CustomPainter {
  _ThinFramePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _Ink.gold.withValues(alpha: .7 * progress),
    );
  }

  @override
  bool shouldRepaint(covariant _ThinFramePainter old) =>
      old.progress != progress;
}

/// A centred flourish: a line either side of a small diamond.
class _OrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final cx = size.width / 2;
    final line = Paint()
      ..shader = _Ink.goldSweep.createShader(Offset.zero & size)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, cy), Offset(cx - 14, cy), line);
    canvas.drawLine(Offset(cx + 14, cy), Offset(size.width, cy), line);

    final d = Path()
      ..moveTo(cx, cy - 6)
      ..lineTo(cx + 7, cy)
      ..lineTo(cx, cy + 6)
      ..lineTo(cx - 7, cy)
      ..close();
    canvas.drawPath(d, Paint()..color = _Ink.gold);
    canvas.drawCircle(Offset(cx - 12, cy), 1.6, Paint()..color = _Ink.gold);
    canvas.drawCircle(Offset(cx + 12, cy), 1.6, Paint()..color = _Ink.gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// A monogram medallion: the couple's initials inside a ringed cartouche, the
/// way engraved stationery marks a wedding.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.groom, required this.bride});

  final String groom;
  final String bride;

  String _first(String s) {
    final t = s.trim();
    return t.isEmpty ? '' : t.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    final g = _first(groom);
    final b = _first(bride);
    if (g.isEmpty && b.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: 74,
      height: 74,
      child: CustomPaint(
        painter: _MonogramRingPainter(),
        child: Center(
          child: ShaderMask(
            shaderCallback: (r) => _Ink.goldSweep.createShader(r),
            blendMode: BlendMode.srcIn,
            child: Text(
              [g, b].where((e) => e.isNotEmpty).join(' '),
              style: GoogleFonts.cormorantGaramond(
                fontSize: 26,
                height: 1,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Double ring with four cardinal ticks around the monogram.
class _MonogramRingPainter extends CustomPainter {
  const _MonogramRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.drawCircle(
      c,
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = _Ink.goldSweep.createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      c,
      r - 7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6
        ..color = _Ink.gold.withValues(alpha: .55),
    );

    // Four small ticks, at the compass points.
    final tick = Paint()
      ..color = _Ink.gold
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawLine(
        Offset(c.dx + (r - 2) * math.cos(a), c.dy + (r - 2) * math.sin(a)),
        Offset(c.dx + (r + 2) * math.cos(a), c.dy + (r + 2) * math.sin(a)),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Faint woven grain, so the card reads as pressed paper rather than a flat
/// fill. Cheap: two sets of hairlines at low alpha.
class _CardTexturePainter extends CustomPainter {
  const _CardTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = .5
      ..color = Colors.white.withValues(alpha: .022);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    final q = Paint()
      ..strokeWidth = .5
      ..color = Colors.black.withValues(alpha: .030);
    for (double x = 0; x < size.width; x += 3) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), q);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// One diagonal pass of light across the card, timed to land after the frame
/// has finished drawing.
class _SheenPainter extends CustomPainter {
  _SheenPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    // Travels from off the top-left to off the bottom-right.
    final x = (t * 2.2 - 0.6) * size.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x - size.width * .22, 0),
          Offset(x + size.width * .22, size.height),
          [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .10 * math.sin(t * math.pi)),
            Colors.white.withValues(alpha: 0),
          ],
          [0.0, 0.5, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _SheenPainter old) => old.t != t;
}

// ---- editorial section pieces ---------------------------------------------

/// A drawn flourish that separates sections. Replaces stacking every block in
/// its own box, which made the page read as a form.
class _Flourish extends StatelessWidget {
  const _Flourish();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      width: double.infinity,
      child: CustomPaint(painter: _FlourishPainter()),
    );
  }
}

class _FlourishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // Tapered rules either side, fading out toward the margins.
    for (final dir in const [-1.0, 1.0]) {
      final start = Offset(cx + dir * 26, cy);
      final end = Offset(cx + dir * (size.width / 2 - 6), cy);
      canvas.drawLine(
        start,
        end,
        line
          ..shader = ui.Gradient.linear(start, end, [
            _Ink.goldInk.withValues(alpha: .75),
            _Ink.goldInk.withValues(alpha: 0),
          ]),
      );
    }

    // Centre motif: a small vesica with a bud either side.
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _Ink.goldInk.withValues(alpha: .9);
    final leaf = Path()
      ..moveTo(cx - 13, cy)
      ..quadraticBezierTo(cx, cy - 8, cx + 13, cy)
      ..quadraticBezierTo(cx, cy + 8, cx - 13, cy)
      ..close();
    canvas.drawPath(leaf, gold);
    canvas.drawCircle(Offset(cx, cy), 2.2, Paint()..color = _Ink.goldInk);
    for (final dir in const [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(cx + dir * 19, cy),
        1.6,
        Paint()..color = _Ink.goldInk.withValues(alpha: .8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Centred section title: a small caps label above a display-face heading.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.sub});

  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (sub != null) ...[
          Text(
            sub!,
            style: _body(
              10,
              color: _Ink.goldInk.withValues(alpha: .9),
            ).copyWith(letterSpacing: 6, height: 1.2),
          ),
          const SizedBox(height: 12),
        ],
        _GoldText(title, size: 28),
      ],
    );
  }
}

/// The couple's message, set as a pull quote with gold quotation marks rather
/// than dropped into a box.
class _Quote extends StatelessWidget {
  const _Quote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            '”',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 46,
              height: .8,
              color: _Ink.goldInk.withValues(alpha: .45),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            textAlign: TextAlign.center,
            style: _body(15.5, h: 2.0).copyWith(
              fontStyle: FontStyle.italic,
              color: _Ink.heading.withValues(alpha: .88),
            ),
          ),
        ],
      ),
    );
  }
}

/// Venue, presented as a landmark rather than a form row: a ringed pin, the
/// place in the display face, and an outlined gold action.
class _VenueBlock extends StatelessWidget {
  const _VenueBlock({required this.venue, this.mapUrl});

  final String venue;
  final String? mapUrl;

  @override
  Widget build(BuildContext context) {
    // Set like the destination on a ticket rather than an address on a form:
    // label, rule, place, rule. The ringed map pin that used to lead it is
    // the same component every app in the world uses, and it said nothing
    // about this place in particular.
    return Column(
      children: [
        Text(
          'المكان',
          style: _body(
            10,
            color: _Ink.goldInk.withValues(alpha: .9),
          ).copyWith(letterSpacing: 6, height: 1.2),
        ),
        const SizedBox(height: 18),
        const _HairRule(fromLeft: true),
        const SizedBox(height: 18),
        Text(
          venue,
          textAlign: TextAlign.center,
          style: _display(27, color: _Ink.heading, h: 1.3),
        ),
        const SizedBox(height: 18),
        const _HairRule(fromLeft: false),
        if ((mapUrl ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          _OutlineGoldButton(
            icon: Icons.map_outlined,
            label: 'فتح الخريطة',
            onTap: () => openExternal(Uri.parse(mapUrl!)),
          ),
        ],
      ],
    );
  }
}

/// A quieter alternative to the filled gold button, for secondary actions.
class _OutlineGoldButton extends StatelessWidget {
  const _OutlineGoldButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _Ink.goldInk.withValues(alpha: .55)),
          gradient: LinearGradient(
            colors: [
              _Ink.goldInk.withValues(alpha: .10),
              _Ink.goldInk.withValues(alpha: .02),
            ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _Ink.goldInk),
            const SizedBox(width: 8),
            Text(
              label,
              style: _body(13.5, color: _Ink.goldInk, w: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gallery as an unboxed strip of framed photographs, each with a thin gold
/// rule around it the way a mounted print would be.
class _GalleryStrip extends StatelessWidget {
  const _GalleryStrip({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: PageController(viewportFraction: .68),
        padEnds: images.length > 1,
        itemCount: images.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: _Ink.goldInk.withValues(alpha: .40)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .45),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AppNetworkImage(
              url: images[i],
              fallbackIcon: Icons.image_outlined,
              fallbackColor: _Ink.deep,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gold shards and sparks thrown out when the wax seal is broken, plus a
/// four-point flare at the centre. This is the beat that makes opening the
/// envelope feel like an event rather than a state change.
class _SealBurstPainter extends CustomPainter {
  _SealBurstPainter({required this.t, required this.accent});

  /// 0 → intact, 1 → fully dispersed.
  final double t;
  final Color accent;

  static const _count = 26;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final light = Color.lerp(accent, Colors.white, .6) ?? accent;

    // Central flare: bright at the instant of the break, gone quickly.
    final flare = (1 - t * 2.2).clamp(0.0, 1.0);
    if (flare > 0) {
      final r = size.width * .22 * (0.4 + t * 3);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            r,
            [
              Colors.white.withValues(alpha: .9 * flare),
              light.withValues(alpha: .35 * flare),
              accent.withValues(alpha: 0),
            ],
            [0.0, 0.35, 1.0],
          ),
      );
      final arm = Paint()
        ..color = Colors.white.withValues(alpha: .8 * flare)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      final len = size.width * .40 * flare;
      canvas.drawLine(c.translate(-len, 0), c.translate(len, 0), arm);
      canvas.drawLine(c.translate(0, -len * .7), c.translate(0, len * .7), arm);
    }

    // Shards: ballistic, with gravity, spinning as they fly.
    for (var i = 0; i < _count; i++) {
      final rnd = math.Random(i * 977);
      final a = (i / _count) * math.pi * 2 + rnd.nextDouble() * .3;
      final speed = (.45 + rnd.nextDouble() * .55) * size.width * .42;
      final dist = speed * t;
      final gravity = size.height * .30 * t * t;
      final p = Offset(
        c.dx + math.cos(a) * dist,
        c.dy + math.sin(a) * dist + gravity,
      );
      final fade = (1 - t).clamp(0.0, 1.0);
      if (fade <= 0) continue;

      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + t * 7 * (rnd.nextBool() ? 1 : -1));

      final s = (2.0 + rnd.nextDouble() * 4.0) * (0.5 + fade * .5);
      final chip = Path()
        ..moveTo(-s, -s * .6)
        ..lineTo(s, -s * .2)
        ..lineTo(s * .2, s)
        ..close();
      canvas.drawPath(
        chip,
        Paint()
          ..shader = ui.Gradient.linear(Offset(-s, -s), Offset(s, s), [
            light.withValues(alpha: fade),
            accent.withValues(alpha: fade),
          ]),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SealBurstPainter old) => old.t != t;
}

// ===========================================================================
// SCENE — a painted backdrop drawn in code
// ===========================================================================

/// A full-bleed illustrated scene: layered mountains fading into mist, a still
/// lake with a soft reflection, and a botanical frame of blossoms down both
/// edges. Drawn procedurally so every theme gets one without shipping art.
///
/// Tinted entirely from the theme's own colours, so «حرير ملكي» reads navy and
/// gold while «بتلات وردية» reads blush.

/// The scene behind the hero: the theme's own artwork when it has some,
/// otherwise the painted scene drawn in code. Either way the theme's living
/// animation plays on top of it.
class _SceneLayer extends StatefulWidget {
  const _SceneLayer({
    required this.base,
    required this.accent,
    required this.template,
  });

  final Color base;
  final Color accent;
  final InvitationTemplateModel? template;

  @override
  State<_SceneLayer> createState() => _SceneLayerState();
}

class _SceneLayerState extends State<_SceneLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 34),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.template?.backgroundImage;
    final anim = invitationAnimFromString(widget.template?.animation);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (art != null && art.isNotEmpty)
          AppNetworkImage(url: art, fallbackColor: widget.base)
        else
          // Real artwork beats anything drawable in code, so the bundled cover
          // is the default. A slow Ken Burns drift keeps it from feeling like
          // a static wallpaper.
          AnimatedBuilder(
            animation: _drift,
            builder: (context, child) {
              final phase = math.sin(_drift.value * 2 * math.pi);
              return Transform.scale(
                scale: 1.06 + phase * 0.03,
                child: Transform.translate(
                  offset: Offset(phase * 8, -phase * 12),
                  child: child,
                ),
              );
            },
            child: Image.asset(
              AppAssets.invitationCover,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) => ColoredBox(color: widget.base),
            ),
          ),
        // Tint the artwork toward the theme so every theme still reads as its
        // own, and darken it enough for white type to sit safely on top.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.base.withValues(alpha: .55),
                widget.base.withValues(alpha: .28),
                widget.base.withValues(alpha: .60),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        if (anim != InvitationAnim.none)
          AnimatedInvitationBg(anim: anim, accent: widget.accent),
      ],
    );
  }
}

/// The opening screen: title, date and the couple's names set straight onto
/// the scene. No card, no box — the reference's whole first impression is
/// type on a photograph.
class _SceneHero extends StatelessWidget {
  const _SceneHero({
    required this.invitation,
    required this.enter,
    required this.height,
    required this.accent,
  });

  final InvitationModel invitation;
  final AnimationController enter;
  final double height;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMMM y', 'ar');
    final tf = DateFormat('HH:mm');

    Widget line(double start, double end, Widget child) => _Reveal(
      anim: CurvedAnimation(
        parent: enter,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
      child: child,
    );

    List<Shadow> glow(double blur) => [
      Shadow(color: Colors.black.withValues(alpha: .5), blurRadius: blur),
    ];

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Whatever photograph the couple chose, the type has to read on it.
          // Dark at the top and the foot, clear through the middle where the
          // picture is.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x73000000),
                    Color(0x1A000000),
                    Color(0x00000000),
                    Color(0x40000000),
                    Color(0x8C000000),
                  ],
                  stops: [0, 0.18, 0.46, 0.8, 1],
                ),
              ),
            ),
          ),
          // The plate's border, cut as the title arrives.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: enter,
                builder: (context, _) => CustomPaint(
                  painter: _HeroFramePainter(
                    t: Curves.easeInOut.transform(
                      Interval(0.1, 0.8).transform(enter.value),
                    ),
                    accent: accent,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  line(
                    0.0,
                    0.3,
                    Text(
                      'بسم الله الرحمن الرحيم',
                      style: _body(
                        10.5,
                        color: Colors.white.withValues(alpha: .78),
                      ).copyWith(letterSpacing: 4),
                    ),
                  ),
                  const SizedBox(height: 14),
                  line(
                    0.05,
                    0.35,
                    Text(
                      'دعوة زفاف',
                      textAlign: TextAlign.center,
                      style: _display(
                        34,
                        color: Colors.white,
                      ).copyWith(shadows: glow(18)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  line(
                    0.15,
                    0.45,
                    Text(
                      '${df.format(invitation.eventDate)}  •  '
                      '${tf.format(invitation.eventDate)}',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: .92),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  // The arch: the shape behind the type in the photograph, and
                  // the one a couple stands under. It holds the names, and it
                  // is what fills the middle of the screen that used to be a
                  // Spacer.
                  Expanded(
                    // The arch takes the width it is given rather than
                    // shrinking to the names inside it: sized to the child it
                    // came out as a narrow doorway with two words in it,
                    // instead of a span the screen stands under.
                    child: FractionallySizedBox(
                      widthFactor: 0.82,
                      child: AnimatedBuilder(
                        animation: enter,
                        builder: (context, child) => CustomPaint(
                          painter: _ArchPainter(
                            t: const Interval(
                              0.2,
                              0.9,
                              curve: Curves.easeInOutCubic,
                            ).transform(enter.value),
                            accent: accent,
                          ),
                          child: child,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(26, 40, 26, 30),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              line(
                                0.35,
                                0.7,
                                Text(
                                  invitation.groomName,
                                  textAlign: TextAlign.center,
                                  style: _display(
                                    41,
                                    color: Colors.white,
                                  ).copyWith(shadows: glow(22)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              line(
                                0.45,
                                0.75,
                                _GoldText('&', size: 24, onDark: true),
                              ),
                              const SizedBox(height: 10),
                              line(
                                0.5,
                                0.85,
                                Text(
                                  invitation.brideName,
                                  textAlign: TextAlign.center,
                                  style: _display(
                                    41,
                                    color: Colors.white,
                                  ).copyWith(shadows: glow(22)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  line(
                    0.7,
                    0.95,
                    Text(
                      'يسعدنا دعوتكم لمشاركتنا فرحتنا',
                      textAlign: TextAlign.center,
                      style: _body(
                        12.5,
                        color: Colors.white.withValues(alpha: .85),
                      ).copyWith(letterSpacing: 1.2),
                    ),
                  ),
                  const SizedBox(height: 22),
                  line(
                    0.8,
                    1.0,
                    Column(
                      children: [
                        Icon(
                          Icons.keyboard_double_arrow_down_rounded,
                          color: Colors.white.withValues(alpha: .8),
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'مرّر للأسفل',
                          style: _body(
                            11.5,
                            color: Colors.white.withValues(alpha: .75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating bar pinned above the invitation with shortcuts to each block.
class _SectionBar extends StatelessWidget {
  const _SectionBar({required this.onJump});

  final ValueChanged<int> onJump;

  static const _items = <(IconData, String, int)>[
    (Icons.favorite_border_rounded, 'الحضور', 3),
    (Icons.place_outlined, 'المكان', 1),
    (Icons.photo_camera_outlined, 'الصور', 2),
    (Icons.schedule_rounded, 'الموعد', 0),
    (Icons.chat_bubble_outline_rounded, 'التهاني', 4),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xCC0B0C18),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _Ink.goldInk.withValues(alpha: .35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (final item in _items)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onJump(item.$3);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.$1, size: 19, color: _Ink.heading),
                          const SizedBox(height: 3),
                          Text(
                            item.$2,
                            style: _body(9.5, color: _Ink.body, h: 1.1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Blind-embossed floral relief on invitation stock: sprigs, daisies and buds
/// pressed into the paper rather than printed on it.
///
/// The trick is that embossing has no colour of its own — it is only light.
/// Each motif is stroked three times: a dark copy pushed down-right (the
/// shadow in the depression), a white copy pushed up-left (the lit edge of the
/// raised area), and a faint mid-tone on top to soften the join. Nothing here
/// is a tint of gold or grey; it is the same paper colour throughout.
class _EmbossPainter extends CustomPainter {
  const _EmbossPainter({this.density = 1.0, this.seed = 7});

  /// Scales how much of the surface is covered.
  final double density;
  final int seed;

  // Offsets are deliberately sub-pixel-ish: real blind embossing is shallow.
  static const _shadow = Color(0x1A6B5836);
  static const _light = Color(0xCCFFFFFF);
  static const _mid = Color(0x0F8A7448);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final w = size.width;
    final h = size.height;

    // Vertical sprigs down both margins, the way the reference frames its
    // envelope, plus a scattering across the field.
    final count = (10 * density).round();

    for (var i = 0; i < count; i++) {
      final side = i.isEven ? 0.0 : 1.0;
      final x =
          w *
          (side == 0
              ? 0.06 + rnd.nextDouble() * 0.20
              : 0.74 + rnd.nextDouble() * 0.20);
      final y = h * (0.04 + rnd.nextDouble() * 0.92);
      final len = h * (0.10 + rnd.nextDouble() * 0.13);
      _sprig(canvas, Offset(x, y), len, rnd.nextDouble() * 0.5 - 0.25);
    }

    final daisies = (7 * density).round();
    for (var i = 0; i < daisies; i++) {
      final x = w * (0.05 + rnd.nextDouble() * 0.90);
      final y = h * (0.05 + rnd.nextDouble() * 0.90);
      _daisy(
        canvas,
        Offset(x, y),
        w * (0.030 + rnd.nextDouble() * 0.026),
        rnd.nextDouble() * math.pi,
      );
    }

    final buds = (9 * density).round();
    for (var i = 0; i < buds; i++) {
      final x = w * (0.04 + rnd.nextDouble() * 0.92);
      final y = h * (0.04 + rnd.nextDouble() * 0.92);
      _bud(
        canvas,
        Offset(x, y),
        w * (0.012 + rnd.nextDouble() * 0.012),
        rnd.nextDouble() * math.pi * 2,
      );
    }
  }

  /// Draws [path] three times to fake relief.
  void _emboss(
    Canvas canvas,
    Path path, {
    bool fill = false,
    double width = 1.2,
  }) {
    void pass(Offset d, Color c) {
      final p = Paint()
        ..color = c
        ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);
      canvas.save();
      canvas.translate(d.dx, d.dy);
      canvas.drawPath(path, p);
      canvas.restore();
    }

    pass(const Offset(0.9, 1.1), _shadow);
    pass(const Offset(-0.9, -1.1), _light);
    pass(Offset.zero, _mid);
  }

  /// A stem with alternating leaves — the botanical sprig of the reference.
  void _sprig(Canvas canvas, Offset at, double len, double lean) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(lean);

    final stem = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.10, -len * 0.45, 0, -len);
    _emboss(canvas, stem, width: 1.1);

    final pairs = (len / 9).clamp(4, 11).toInt();
    for (var i = 1; i <= pairs; i++) {
      final t = i / (pairs + 1);
      final y = -len * t;
      final s = len * 0.16 * (1 - t * 0.55);
      for (final dir in const [-1.0, 1.0]) {
        final leaf = Path()
          ..moveTo(0, y)
          ..quadraticBezierTo(
            dir * s * 0.9,
            y - s * 0.75,
            dir * s * 1.7,
            y - s * 0.30,
          )
          ..quadraticBezierTo(dir * s * 0.8, y + s * 0.10, 0, y);
        _emboss(canvas, leaf, fill: true);
      }
    }
    canvas.restore();
  }

  /// A round eight-petal flower.
  void _daisy(Canvas canvas, Offset c, double r, double rot) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    for (var k = 0; k < 8; k++) {
      final a = k / 8 * math.pi * 2;
      final petal = Path()
        ..addOval(
          Rect.fromCenter(
            center: Offset(math.cos(a) * r * 0.62, math.sin(a) * r * 0.62),
            width: r * 0.78,
            height: r * 0.52,
          ),
        );
      canvas.save();
      canvas.translate(math.cos(a) * r * 0.62, math.sin(a) * r * 0.62);
      canvas.rotate(a);
      canvas.translate(-math.cos(a) * r * 0.62, -math.sin(a) * r * 0.62);
      _emboss(canvas, petal, fill: true);
      canvas.restore();
    }
    _emboss(
      canvas,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r * 0.22)),
      fill: true,
    );
    canvas.restore();
  }

  /// A small closed bud on a short stalk.
  void _bud(Canvas canvas, Offset c, double r, double rot) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    final bud = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(r * 1.1, -r * 0.6, 0, -r * 2.0)
      ..quadraticBezierTo(-r * 1.1, -r * 0.6, 0, 0);
    _emboss(canvas, bud, fill: true);
    _emboss(
      canvas,
      Path()
        ..moveTo(0, 0)
        ..lineTo(0, r * 1.4),
      width: 0.9,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EmbossPainter old) =>
      old.density != density || old.seed != seed;
}
