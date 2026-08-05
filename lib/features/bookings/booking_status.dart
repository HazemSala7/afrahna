import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// How a booking status is worded and coloured, in one place so the bookings
/// page and the home-page card can never disagree.
///
/// `rejected` used to be missing everywhere, which meant a shop that turned a
/// booking down still showed to the customer as «قيد المراجعة».
class BookingStatusStyle {
  const BookingStatusStyle({
    required this.label,
    required this.color,
    required this.icon,
    required this.isReply,
  });

  final String label;
  final Color color;
  final IconData icon;

  /// Whether this state represents the shop having answered the request.
  final bool isReply;

  static BookingStatusStyle of(String? status) {
    switch (status) {
      case 'confirmed':
        return const BookingStatusStyle(
          label: 'مؤكّد',
          color: Color(0xFF2E9E5B),
          icon: Icons.check_circle_rounded,
          isReply: true,
        );
      case 'rejected':
        return const BookingStatusStyle(
          label: 'مرفوض',
          color: AppColors.discount,
          icon: Icons.cancel_rounded,
          isReply: true,
        );
      case 'cancelled':
        return const BookingStatusStyle(
          label: 'ملغي',
          color: Color(0xFF9A6B5E),
          icon: Icons.block_rounded,
          isReply: true,
        );
      case 'completed':
        return const BookingStatusStyle(
          label: 'مكتمل',
          color: Color(0xFF4B7BA8),
          icon: Icons.verified_rounded,
          isReply: true,
        );
      case 'pending':
      default:
        return const BookingStatusStyle(
          label: 'بانتظار رد المتجر',
          color: AppColors.primary,
          icon: Icons.hourglass_top_rounded,
          isReply: false,
        );
    }
  }
}

/// Pill showing a booking's current state.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({super.key, required this.status, this.compact = false});

  final String? status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = BookingStatusStyle.of(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4.5,
      ),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: compact ? 12 : 14, color: s.color),
          const SizedBox(width: 4),
          Text(
            s.label,
            style: TextStyle(
              color: s.color,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 10.5 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
