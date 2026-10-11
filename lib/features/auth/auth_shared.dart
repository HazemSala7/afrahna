import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../widgets/cosmos.dart';

/// The auth screens' backdrop: the page's own night sky, with a gold-and-violet
/// nebula glowing where the logo sits and three thin orbits turning slowly
/// round it — the first thing a new visitor sees of the app.
class AuthBackground extends StatefulWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) =>
                      CustomPaint(painter: _OrbitsPainter(_c.value)),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// The nebula behind the logo and the orbits round it.
class _OrbitsPainter extends CustomPainter {
  _OrbitsPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = Offset(size.width / 2, 150);

    void glow(Offset o, double r, Color color) => canvas.drawCircle(
          o,
          r,
          Paint()
            ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: o, radius: r)),
        );

    // Indigo wide, gold tight at the heart: a gold glow spread over the whole
    // header reads as brown haze, not light.
    glow(c.translate(-size.width * 0.2, 40), size.width * 0.85,
        const Color(0xFF3A2F9E).withValues(alpha: 0.22));
    glow(c, size.width * 0.42, AppColors.accent.withValues(alpha: 0.20));
    glow(c.translate(size.width * 0.32, -30), size.width * 0.4,
        AppColors.holoLavender.withValues(alpha: 0.14));
    glow(c.translate(-size.width * 0.34, 110), size.width * 0.3,
        AppColors.holoAqua.withValues(alpha: 0.07));

    // Three tilted orbits, turning at different speeds, each carrying one
    // bead of light.
    const orbits = [
      (rx: 150.0, ry: 52.0, tilt: -0.28, speed: 1.0, color: AppColors.accent),
      (rx: 190.0, ry: 70.0, tilt: 0.22, speed: -0.7, color: AppColors.holoLavender),
      (rx: 118.0, ry: 124.0, tilt: 0.0, speed: 0.5, color: AppColors.holoAqua),
    ];
    for (final o in orbits) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(o.tilt);
      final rect = Rect.fromCenter(
          center: Offset.zero, width: o.rx * 2, height: o.ry * 2);
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = o.color.withValues(alpha: 0.22),
      );
      final a = t * o.speed * math.pi * 2;
      final bead = Offset(math.cos(a) * o.rx, math.sin(a) * o.ry);
      canvas.drawCircle(
        bead,
        6,
        Paint()
          ..color = o.color.withValues(alpha: 0.35)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5),
      );
      canvas.drawCircle(bead, 2, Paint()..color = o.color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_OrbitsPainter old) => old.t != t;
}

/// The form's glass panel, rising from the bottom of the screen with a line of
/// light along its top edge.
class AuthCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AuthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 26, 22, 22),
  });

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(36),
    topRight: Radius.circular(36),
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: Color(0x1F8E5F4A),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surface.withValues(alpha: 0.94),
                  AppColors.surfaceHigh.withValues(alpha: 0.97),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 36,
                  right: 36,
                  height: 1.4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.accent.withValues(alpha: 0),
                        AppColors.accent.withValues(alpha: 0.9),
                        AppColors.holoLavender.withValues(alpha: 0.6),
                        AppColors.accent.withValues(alpha: 0),
                      ]),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's mark in a ring of holographic light, the title in gold foil and a
/// line of pearl beneath — at the top of every auth screen.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.favorite_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final display = Theme.of(context).textTheme.headlineMedium;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.36),
                blurRadius: 40,
                spreadRadius: -4,
              ),
            ],
          ),
          child: HoloRing(
            size: 112,
            stroke: 2.6,
            gap: 5,
            child: ColoredBox(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Image.asset(
                  AppAssets.logo,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    icon,
                    color: AppColors.accent,
                    size: 44,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        GoldFoilText(
          title,
          textAlign: TextAlign.center,
          style: (display ?? const TextStyle()).copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textDark.withValues(alpha: 0.78),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// A field of dark glass with a gold hairline that lights up champagne when
/// it has focus. The icon sits in its own small pane of glass.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;

  /// Optional gradient fill behind the field (used for the login inputs).
  final Gradient? gradient;

  /// The faint sheen of glass behind the login inputs.
  static const rtlFill = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0x1FC08B56), Color(0x0AFFFFFF)],
  );

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textDirection,
    this.obscure = false,
    this.suffix,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.gradient,
    this.focusNode,
    this.onChanged,
  });

  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: textDirection,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      focusNode: focusNode,
      onChanged: onChanged,
      validator: validator,
      cursorColor: AppColors.accent,
      style: const TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: Container(
          margin: const EdgeInsetsDirectional.only(start: 10, end: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        // When a gradient is provided, keep the field transparent so the
        // gradient behind it shows through.
        filled: gradient == null,
        fillColor: AppColors.surfaceHigh.withValues(alpha: 0.7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(AppColors.hairline),
        enabledBorder: _border(AppColors.hairline),
        focusedBorder: _border(AppColors.accent, width: 1.6),
        errorBorder: _border(AppColors.discount),
        focusedErrorBorder: _border(AppColors.discount, width: 1.6),
      ),
    );

    if (gradient == null) return field;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: field,
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// The primary action: liquid gold with a band of light crossing it every few
/// seconds and a glow underneath, dark type on top for full contrast.
class AuthPrimaryButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.loading = false,
    this.onPressed,
  });

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sheen.stop();
    } else if (!_sheen.isAnimating) {
      _sheen.repeat();
    }
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(18));
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: AppColors.goldGradient,
          // A glow, not a shelf: light, wide and pulled in at the edges.
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.32),
              blurRadius: 34,
              spreadRadius: -10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The band of light, crossing in the first third of each cycle.
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _sheen,
                  builder: (_, _) {
                    final t = (_sheen.value / 0.33).clamp(0.0, 1.0);
                    if (t >= 1) return const SizedBox.shrink();
                    return FractionalTranslation(
                      translation: Offset(-1.3 + 2.6 * t, 0),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1, -0.6),
                            end: Alignment(1, 0.6),
                            colors: [
                              Color(0x00FFFFFF),
                              Color(0x73FFFFFF),
                              Color(0x00FFFFFF),
                            ],
                            stops: [0.35, 0.5, 0.65],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.loading
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          widget.onPressed?.call();
                        },
                  splashColor: Colors.white.withValues(alpha: 0.25),
                  child: Center(
                    child: widget.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.ink,
                              strokeWidth: 2.4,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(widget.icon,
                                    color: AppColors.ink, size: 20),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                widget.label,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
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

/// Secondary action — a pane of glass with a gold edge (e.g. browse as guest).
class AuthGhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  const AuthGhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.explore_outlined,
            color: AppColors.accent, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.04),
          side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.6), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Two lines of light fading out from a word in the middle (e.g. "أو").
class AuthOrDivider extends StatelessWidget {
  final String text;
  const AuthOrDivider({super.key, this.text = 'أو'});

  @override
  Widget build(BuildContext context) {
    Widget line(bool towardsStart) => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0),
                  AppColors.accent.withValues(alpha: 0.55),
                ],
                begin: towardsStart
                    ? AlignmentDirectional.centerStart
                    : AlignmentDirectional.centerEnd,
                end: towardsStart
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
              ),
            ),
          ),
        );

    return Row(
      children: [
        line(true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        line(false),
      ],
    );
  }
}
