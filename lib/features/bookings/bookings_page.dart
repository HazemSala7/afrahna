import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/app_widgets.dart';
import '../auth/login_page.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  Future<List<BookingModel>>? _future;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  void _maybeLoad() {
    final session = context.read<SessionController>();
    if (session.isSignedIn) {
      _future = BookingService().list();
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.redAccent;
      case 'completed':
        return Colors.blueGrey;
      default:
        return AppColors.primary;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return 'مؤكد';
      case 'cancelled':
        return 'ملغي';
      case 'completed':
        return 'مكتمل';
      case 'pending':
      default:
        return 'قيد المراجعة';
    }
  }

  /// Contact panel for the person who made the booking. Shown only to the
  /// vendor/admin viewing an incoming booking (never to the customer looking at
  /// their own list — there `customer.id` equals the signed-in user's id).
  Widget _customerBlock(BookingModel b) {
    final c = b.customer!;
    final phone = c.phone.trim();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: .15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.name.isEmpty ? 'صاحب الحجز' : c.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    phone,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openExternal(Uri.parse('tel:$phone')),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('اتصال'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final uri = vendorWhatsappUri(
                        phone,
                        message:
                            'مرحباً ${c.name.isEmpty ? '' : c.name}، بخصوص حجزك عبر تطبيق أفراحنا.',
                      );
                      if (uri != null) openExternal(uri);
                    },
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('واتساب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _cancel(BookingModel b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: const Text('هل أنت متأكد من إلغاء هذا الحجز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BookingService().cancel(b.id);
      setState(() {
        _future = BookingService().list();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (!session.isSignedIn) {
      return AppScaffold(
        appBar: const PinkAppBar(title: 'مناسباتي', showBack: false),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month,
                    size: 72, color: AppColors.primary),
                const SizedBox(height: 14),
                const Text('سجّل الدخول لعرض حجوزاتك ومناسباتك',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  child: const Text('تسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AppScaffold(
      appBar: const PinkAppBar(title: 'مناسباتي', showBack: false),
      body: FutureBuilder<List<BookingModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
              message: snap.error.toString(),
              onRetry: () => setState(() {
                _future = BookingService().list();
              }),
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const EmptyState(
              message: 'لا يوجد حجوزات حالياً\nابدأ بحجز خدمة لمناسبتك',
              icon: Icons.event_busy,
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              setState(() {
                _future = BookingService().list();
              });
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final b = items[i];
                final df = DateFormat('EEEE، d MMMM y', 'ar');
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              df.format(b.eventDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(b.status)
                                  .withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(b.status),
                              style: TextStyle(
                                color: _statusColor(b.status),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (b.service != null)
                        Row(
                          children: [
                            const Icon(Icons.design_services,
                                size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(child: Text(b.service!.title)),
                          ],
                        ),
                      if (b.vendor != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.storefront,
                                  size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(child: Text(b.vendor!.name)),
                            ],
                          ),
                        ),
                      if (b.guestsCount != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.groups,
                                  size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text('${b.guestsCount} مدعو'),
                            ],
                          ),
                        ),
                      if (b.customer != null &&
                          b.customer!.id != session.user?.id)
                        _customerBlock(b),
                      if (b.totalPrice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${b.totalPrice!.toStringAsFixed(0)} ₪',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      if (b.status != 'cancelled' &&
                          b.status != 'completed')
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: () => _cancel(b),
                            icon: const Icon(Icons.cancel_outlined,
                                color: Colors.red),
                            label: const Text('إلغاء الحجز',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
