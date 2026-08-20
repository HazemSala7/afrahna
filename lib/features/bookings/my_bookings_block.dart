import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/section_header.dart';
import 'booking_status.dart';
import 'bookings_page.dart';

class MyBookingsBlock extends StatefulWidget {
  const MyBookingsBlock({super.key});

  @override
  State<MyBookingsBlock> createState() => MyBookingsBlockState();
}

class MyBookingsBlockState extends State<MyBookingsBlock> {
  Future<List<BookingModel>>? _future;
  bool _wasSignedIn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load on first build and again whenever the user signs in, so a booking
    // made right after logging in still appears without a restart.
    final signedIn = context.watch<SessionController>().isSignedIn;
    if (signedIn != _wasSignedIn) {
      _wasSignedIn = signedIn;
      _future = signedIn ? _load() : null;
    }
  }

  /// Always the customer scope — a shop owner's default booking view is their
  /// shop's inbox, and their own bookings would otherwise never reach them.
  Future<List<BookingModel>> _load() =>
      BookingService().list(scope: 'customer');

  Future<void> _openAll() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookingsPage(initialMine: true)),
    );
    // The customer may have cancelled something while they were in there.
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<List<BookingModel>>(
      future: future,
      builder: (context, snap) {
        // A failed or empty request must not leave a heading with nothing
        // under it — the whole block just disappears.
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final me = context.read<SessionController>().user?.id;
        // Belt and braces: until the API deploys `scope`, a shop owner's
        // request still comes back as their shop's inbox. Those are other
        // people's bookings and must never appear under «حجوزاتي».
        final all = (snap.data ?? const <BookingModel>[])
            .where((b) => b.customer == null || b.customer!.id == me)
            .toList();
        if (all.isEmpty) return const SizedBox.shrink();

        // Anything the shop has answered floats to the front; the rest follow
        // by event date. That puts a fresh «مؤكّد» or «مرفوض» first.
        final items = [...all]..sort((a, b) {
            final byReply = (b.hasVendorReply ? 1 : 0) - (a.hasVendorReply ? 1 : 0);
            if (byReply != 0) return byReply;
            return b.eventDate.compareTo(a.eventDate);
          });
        final shown = items.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: 'حجوزاتي',
                emoji: '🗓️',
                onSeeAll: _openAll,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _BookingMiniCard(booking: shown[i], onTap: _openAll),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

/// Compact booking card for the home row.
class _BookingMiniCard extends StatelessWidget {
  const _BookingMiniCard({required this.booking, required this.onTap});

  final BookingModel booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final style = BookingStatusStyle.of(b.status);
    final reason = (b.cancellationReason ?? '').trim();
    final df = DateFormat('d MMMM y', 'ar');

    return SizedBox(
      width: 252,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              // A shop reply is tinted in its own colour so a confirmation or a
              // rejection is readable at a glance, without opening anything.
              border: Border.all(
                color: b.hasVendorReply
                    ? style.color.withValues(alpha: .35)
                    : AppColors.primaryLight,
                width: b.hasVendorReply ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.service?.title ?? 'حجز',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        b.vendor?.name ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.event_rounded,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      df.format(b.eventDate),
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                if (reason.isNotEmpty)
                  Text(
                    '«$reason»',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: style.color,
                    ),
                  ),
                const SizedBox(height: 6),
                BookingStatusChip(status: b.status, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Home-page showcase for electronic invitations. The card runs one of the
/// real invitation themes behind it, so the feature sells itself: what you see
/// moving here is exactly what the finished invitation looks like.
