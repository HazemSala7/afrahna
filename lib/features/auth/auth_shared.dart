import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// Full-screen warm gradient background with decorative sparkles +
/// blurred bokeh circles. Used as a backdrop for the auth pages.
class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF3D2817),
              Color(0xFF6B4226),
              Color(0xFF8B5A3C),
              Color(0xFFB8835A),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // soft bokeh circles
            Positioned(
              top: -60,
              right: -40,
              child: _bokeh(220, const Color(0x33FFFFFF)),
            ),
            Positioned(
              top: 120,
              left: -80,
              child: _bokeh(180, const Color(0x22F0DDC8)),
            ),
            Positioned(
              bottom: -50,
              right: -30,
              child: _bokeh(160, const Color(0x33D4A373)),
            ),
            // sparkles overlay
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _SparklesPainter()),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _bokeh(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _SparklesPainter extends CustomPainter {
  const _SparklesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 36; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.6 + rnd.nextDouble() * 2.0;
      final a = 0.06 + rnd.nextDouble() * 0.18;
      paint.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glassmorphism card that hosts the form on top of the gradient.
class AuthCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AuthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 26, 22, 22),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(36),
          topRight: Radius.circular(36),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Premium app logo + tagline used at the top of every auth screen.
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
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF7E5), Color(0xFFF0DDC8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x553D2817),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                AppAssets.logo,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.primaryDark,
                  size: 44,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
            shadows: [
              Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Styled text input with leading icon, optional trailing widget,
/// and a soft cream fill matching the theme.
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
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: textDirection,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
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
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: Container(
          margin: const EdgeInsetsDirectional.only(start: 10, end: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF6E6D3), Color(0xFFEBD7BF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFFBF4EB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(const Color(0xFFE7D6BF)),
        enabledBorder: _border(const Color(0xFFE7D6BF)),
        focusedBorder: _border(AppColors.primary, width: 1.6),
        errorBorder: _border(AppColors.discount),
        focusedErrorBorder: _border(AppColors.discount, width: 1.6),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Big gold gradient CTA button used for primary auth actions.
class AuthPrimaryButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFFD4A373), Color(0xFFB8835A), Color(0xFF8B5A3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x558B5A3C),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
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
      ),
    );
  }
}

/// Ghost / outlined secondary button for actions like "browse as guest".
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
            color: AppColors.primaryDark, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFBF4EB),
          side: const BorderSide(color: AppColors.primaryLight, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Decorative divider with centered text (e.g. "أو").
class AuthOrDivider extends StatelessWidget {
  final String text;
  const AuthOrDivider({super.key, this.text = 'أو'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: Color(0xFFE7D6BF), thickness: 1),
        ),
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
        const Expanded(
          child: Divider(color: Color(0xFFE7D6BF), thickness: 1),
        ),
      ],
    );
  }
}
