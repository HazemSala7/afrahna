import 'package:flutter/material.dart';
import '../core/theme.dart';

/// A floating pane of glass with its news written in light: the edge and the
/// icon carry the colour (green done, coral failed, gold for a note), the
/// glass stays the same, so a snack bar never punches a flat slab of colour
/// through the night sky.
SnackBar _glassSnack({
  required IconData? icon,
  required Color tone,
  required String message,
  required Duration duration,
}) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.surfaceHigh,
    elevation: 0,
    duration: duration,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: tone.withValues(alpha: 0.55)),
    ),
    content: Row(children: [
      if (icon != null) ...[
        Icon(icon, color: tone, size: 20, shadows: [
          Shadow(color: tone.withValues(alpha: 0.7), blurRadius: 10),
        ]),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ]),
  );
}

void showSuccessSnack(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(_glassSnack(
    icon: Icons.check_circle,
    tone: const Color(0xFF34D17A),
    message: message,
    duration: const Duration(seconds: 2),
  ));
}

void showErrorSnack(BuildContext context, Object error) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(_glassSnack(
    icon: Icons.error_outline,
    tone: AppColors.discount,
    message: _humanize(error),
    duration: const Duration(seconds: 4),
  ));
}

void showInfoSnack(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(_glassSnack(
    icon: null,
    tone: AppColors.accent,
    message: message,
    duration: const Duration(seconds: 2),
  ));
}

String _humanize(Object e) {
  final s = e.toString();
  if (s.startsWith('Exception: ')) return s.substring(11);
  return s;
}
