import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/app_widgets.dart';
import '../vendors/vendor_details_page.dart';
import 'marketplace.dart';

/// How an order's status is worded and coloured. Kept beside the bookings
/// styling in spirit: the customer should be able to tell at a glance whether
/// the shop has acted on their order.
class OrderStatusStyle {
  const OrderStatusStyle({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  static OrderStatusStyle of(String? status) {
    switch (status) {
      case 'confirmed':
        return const OrderStatusStyle(
          label: 'مؤكّدة',
          color: Color(0xFF2E9E5B),
          icon: Icons.check_circle_rounded,
        );
      case 'preparing':
        return const OrderStatusStyle(
          label: 'قيد التجهيز',
          color: Color(0xFFD08A2E),
          icon: Icons.soup_kitchen_rounded,
        );
      case 'ready':
        return const OrderStatusStyle(
          label: 'جاهزة',
          color: Color(0xFF2E8BA8),
          icon: Icons.inventory_2_rounded,
        );
      case 'completed':
        return const OrderStatusStyle(
          label: 'مكتملة',
          color: Color(0xFF4B7BA8),
          icon: Icons.verified_rounded,
        );
      case 'cancelled':
        return const OrderStatusStyle(
          label: 'ملغاة',
          color: Color(0xFF9A6B5E),
          icon: Icons.block_rounded,
        );
      case 'rejected':
        return const OrderStatusStyle(
          label: 'مرفوضة',
          color: AppColors.discount,
          icon: Icons.cancel_rounded,
        );
      case 'pending':
      default:
        return const OrderStatusStyle(
          label: 'بانتظار رد المتجر',
          color: AppColors.primary,
          icon: Icons.hourglass_top_rounded,
        );
    }
  }
}

/// «طلباتي» — the orders this customer has placed, with what each contained,
/// where it is going and how the shop answered.
///
/// Before this screen existed an order vanished the moment it was sent: the
/// invoice went to the shop and the customer had no way to look it up again.
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key, this.highlightId});

  /// Scroll to this order and mark it, for arrivals from a notification.
  /// One link serves both sides of an order — the customer whose order
  /// changed status and the shop that received it — so if the order is not
  /// among this account's own purchases the page looks in the shop's inbox.
  final int? highlightId;

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  /// False: the orders this account placed. True: the orders its shop
  /// received — only ever reached from a notification about one of them.
  bool _incoming = false;

  late Future<List<OrderModel>> _future = _load();

  final GlobalKey _highlightKey = GlobalKey();
  late int? _highlightId = widget.highlightId;
  bool _didScrollHighlight = false;
  bool _didTryInbox = false;

  Future<List<OrderModel>> _load() =>
      OrderService().list(scope: _incoming ? 'vendor' : 'customer');

  void _reload() => setState(() => _future = _load());

  /// Scroll to the highlighted order once laid out, then fade the marking.
  void _scheduleHighlightScroll() {
    if (_highlightId == null || _didScrollHighlight) return;
    _didScrollHighlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = _highlightKey.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.2,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
      }
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _highlightId = null);
    });
  }

  /// Not among this account's purchases: it is an order its shop received.
  /// Only an account that actually runs a shop has that second list — asking
  /// for it as a plain customer just returns their own orders again under the
  /// wrong heading.
  void _lookInShopInbox(List<OrderModel> orders) {
    if (_highlightId == null || _didTryInbox || _incoming) return;
    if (orders.any((o) => o.id == _highlightId)) return;
    final role = context.read<SessionController>().user?.role;
    if (role != 'vendor' && role != 'admin') return;
    _didTryInbox = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _incoming = true;
        _future = _load();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: PinkAppBar(
        title: _incoming ? 'الطلبات الواردة' : 'طلباتي',
        subtitle: _incoming
            ? 'الطلبات التي وصلت متجرك'
            : 'مشترياتك من متاجر أفراحنا',
      ),
      body: FutureBuilder<List<OrderModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
              message: snap.error is ApiException
                  ? (snap.error as ApiException).message
                  : 'تعذّر تحميل الطلبات',
              onRetry: _reload,
            );
          }
          final orders = snap.data ?? const <OrderModel>[];
          _lookInShopInbox(orders);
          if (orders.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              message: _incoming
                  ? 'لا توجد طلبات واردة.'
                  : 'لا توجد طلبات بعد.\nتصفّح المتجر وأضف ما يعجبك.',
            );
          }
          if (_highlightId != null &&
              orders.any((o) => o.id == _highlightId)) {
            _scheduleHighlightScroll();
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final o = orders[i];
                final hi = _highlightId != null && o.id == _highlightId;
                return _OrderCard(
                  key: hi ? _highlightKey : null,
                  order: o,
                  highlighted: hi,
                  incoming: _incoming,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    super.key,
    required this.order,
    this.highlighted = false,
    this.incoming = false,
  });

  final OrderModel order;

  /// The order a notification pointed at, marked until the reader has seen it.
  final bool highlighted;

  /// This card is in a shop's inbox rather than a customer's purchases.
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final s = OrderStatusStyle.of(order.status);
    final df = DateFormat('d MMMM y', 'ar');
    final address = order.addressLine;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted
              ? AppColors.primary
              : s.color.withValues(alpha: .22),
          width: highlighted ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? AppColors.primary.withValues(alpha: .28)
                : AppColors.cardShadow,
            blurRadius: highlighted ? 18 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'طلب #${order.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              _StatusChip(style: s),
            ],
          ),
          if (order.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              df.format(order.createdAt!),
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 10),
          // Whoever the reader needs next: the customer wants the shop, the
          // shop reading its own inbox wants the customer to call.
          if (incoming)
            _CustomerRow(order: order)
          else
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VendorDetailsPage(vendorId: order.vendorId),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.vendorName ?? 'المتجر',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded,
                        size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          const Divider(height: 18),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.quantity}×',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textDark),
                    ),
                  ),
                  if (item.subtotal > 0)
                    Text(
                      '₪${money(item.subtotal)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_rounded,
                    size: 15, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
          if ((order.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 15, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    order.note!.trim(),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text(
                  'الإجمالي',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  order.total > 0
                      ? '₪${money(order.total)}'
                      : 'السعر عند الطلب',
                  style: TextStyle(
                    fontSize: order.total > 0 ? 15 : 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Who placed the order, for a shop reading its own inbox. Calling them back
/// is the whole reason the shop opened the notification.
class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final name = (order.customerName ?? '').trim();
    final phone = (order.customerPhone ?? '').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name.isEmpty ? 'زبون' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          if (phone.isNotEmpty)
            TextButton.icon(
              onPressed: () => openExternal(Uri.parse('tel:$phone')),
              icon: const Icon(Icons.call_rounded, size: 16),
              label: Text(phone, style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.style});

  final OrderStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
