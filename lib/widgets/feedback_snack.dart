import 'package:flutter/material.dart';
import '../core/theme.dart';

void showSuccessSnack(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF2E7D32),
    duration: const Duration(seconds: 2),
    content: Row(children: [
      const Icon(Icons.check_circle, color: Colors.white, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
    ]),
  ));
}

void showErrorSnack(BuildContext context, Object error) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  final msg = _humanize(error);
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFFC1452B),
    duration: const Duration(seconds: 4),
    content: Row(children: [
      const Icon(Icons.error_outline, color: Colors.white, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
    ]),
  ));
}

void showInfoSnack(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.primaryDark,
    duration: const Duration(seconds: 2),
    content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
  ));
}

String _humanize(Object e) {
  final s = e.toString();
  if (s.startsWith('Exception: ')) return s.substring(11);
  return s;
}
