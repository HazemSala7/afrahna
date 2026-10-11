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
import '../../widgets/feedback_snack.dart';
import '../trade/trade_timeline.dart';
import '../vendors/vendor_details_page.dart';
import 'marketplace.dart';
import '../../widgets/animations.dart';
import '../../widgets/celebration.dart';

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
          color: Color(0xFF34D17A),
          icon: Icons.check_circle_rounded,
        );
      case 'preparing':
        return const OrderStatusStyle(
          label: 'قيد التجهيز',
          color: Color(0xFFF2B35B),
          icon: Icons.soup_kitchen_rounded,
        );
      case 'ready':
        return const OrderStatusStyle(
          label: 'جاهزة',
          color: AppColors.holoAqua,
          icon: Icons.inventory_2_rounded,
        );
      case 'completed':
        return const OrderStatusStyle(
          label: 'مكتملة',
          color: AppColors.holoLavender,
          icon: Icons.verified_rounded,
        );
      case 'cancelled':
        return const OrderStatusStyle(
          label: 'ملغاة',
          color: AppColors.textMuted,
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
          color: AppColors.accent,
          icon: Icons.hourglass_top_rounded,
        );
    }
  }
}

/// «طلباتي» — the orders this customer has placed, with what each contained,
/// where it is going and how the shop answered — and, for a shop owner, the
/// orders their shop received, with the buttons that move each one along.
///
/// Every button a shop presses here reaches the customer as a notification;
/// a customer calling an order off reaches the shop the same way.
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({
    super.key,
    this.highlightId,
    this.initialIncoming = false,
  });

  /// Scroll to this order and mark it, for arrivals from a notification.
  /// One link serves both sides of an order — the customer whose order
  /// changed status and the shop that received it — so if the order is not
  /// among this account's own purchases the page looks in the shop's inbox.
  final int? highlightId;

  /// Open on the shop's incoming orders rather than this account's purchases.
  final bool initialIncoming;

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  /// False: the orders this account placed. True: the orders its shop
  /// received.
  late bool _incoming = widget.initialIncoming;

  late Future<List<OrderModel>> _future = _load();

  final GlobalKey _highlightKey = GlobalKey();
  late int? _highlightId = widget.highlightId;
  bool _didScrollHighlight = false;
  bool _didTryInbox = false;

  /// Orders with a change on its way to the server, so their buttons can't be
  /// pressed twice.
  final Set<int> _busy = {};

  Future<List<OrderModel>> _load() =>
      OrderService().list(scope: _incoming ? 'vendor' : 'customer');

  void _reload() => setState(() {
    _future = _load();
  });

  bool _runsShop(BuildContext context) {
    final role = context.read<SessionController>().user?.role;
    return role == 'vendor' || role == 'admin';
  }

  void _switchTo(bool incoming) {
    if (_incoming == incoming) return;
    setState(() {
      _incoming = incoming;
      _future = _load();
    });
  }

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
    if (!_runsShop(context)) return;
    _didTryInbox = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _switchTo(true);
    });
  }

  /// Asks for an optional reason before a rejection or a cancellation. Null
  /// when the reader backs out.
  Future<String?> _askReason({
    required String title,
    required String message,
    required String confirm,
    required String hint,
  }) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLines: 2,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: 'السبب (اختياري)',
                hintText: hint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.discount,
              foregroundColor: AppColors.ink,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    return ok == true ? text : null;
  }

  /// Moves [order] to [status] and says who has been told.
  Future<void> _move(OrderModel order, String status) async {
    String? reason;
    if (status == 'rejected') {
      reason = await _askReason(
        title: 'رفض الطلبية',
        message: 'سيصل ردّك إلى الزبون مباشرة. اكتب سبباً مختصراً إن أمكن.',
        confirm: 'رفض الطلبية',
        hint: 'مثال: المنتج غير متوفر حالياً',
      );
      if (reason == null) return;
    } else if (status == 'cancelled') {
      reason = await _askReason(
        title: 'إلغاء الطلبية',
        message: _incoming
            ? 'سيتم إبلاغ الزبون بالإلغاء.'
            : 'سيتم إبلاغ المتجر بأنك ألغيت الطلبية.',
        confirm: 'إلغاء الطلبية',
        hint: _incoming ? 'مثال: نفدت الكمية' : 'مثال: غيّرت رأيي',
      );
      if (reason == null) return;
    }

    setState(() => _busy.add(order.id));
    try {
      await OrderService().updateStatus(order.id, status, reason: reason);
      if (!mounted) return;
      if (status == 'confirmed' || status == 'completed') {
        CelebrationBurst.show(context);
      }
      showSuccessSnack(context, _doneMessage(status));
      _reload();
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e.message);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(order.id));
    }
  }

  String _doneMessage(String status) {
    if (!_incoming) return 'تم إلغاء الطلبية وإبلاغ المتجر';
    switch (status) {
      case 'confirmed':
        return 'تم تأكيد الطلبية وإبلاغ الزبون';
      case 'preparing':
        return 'بدأ التجهيز — أبلغنا الزبون';
      case 'ready':
        return 'الطلبية جاهزة — أبلغنا الزبون';
      case 'completed':
        return 'تم تسليم الطلبية وإبلاغ الزبون';
      case 'rejected':
        return 'تم رفض الطلبية وإبلاغ الزبون';
      case 'cancelled':
        return 'تم إلغاء الطلبية وإبلاغ الزبون';
    }
    return 'تم التحديث';
  }

  @override
  Widget build(BuildContext context) {
    final runsShop = _runsShop(context);
    return AppScaffold(
      appBar: PinkAppBar(
        title: _incoming ? 'الطلبات الواردة' : 'طلباتي',
        subtitle: _incoming
            ? 'الطلبات التي وصلت متجرك'
            : 'مشترياتك من متاجر أفراحنا',
      ),
      body: Column(
        children: [
          // A shop owner shops too: their purchases and their shop's orders
          // are two lists, one tap apart.
          if (runsShop)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('مشترياتي'),
                    icon: Icon(Icons.shopping_bag_rounded, size: 17),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('طلبات واردة'),
                    icon: Icon(Icons.inbox_rounded, size: 17),
                  ),
                ],
                selected: {_incoming},
                showSelectedIcon: false,
                onSelectionChanged: (s) => _switchTo(s.first),
              ),
            ),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _list() {
    return FutureBuilder<List<OrderModel>>(
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
                ? 'لا توجد طلبات واردة.\nستصلك هنا وفي الإشعارات فور طلب أي زبون.'
                : 'لا توجد طلبات بعد.\nتصفّح المتجر وأضف ما يعجبك.',
          );
        }
        if (_highlightId != null && orders.any((o) => o.id == _highlightId)) {
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
              return StaggerIn(
                index: i,
                id: 'orders.$_incoming',
                child: _OrderCard(
                  key: hi ? _highlightKey : null,
                  order: o,
                  highlighted: hi,
                  incoming: _incoming,
                  busy: _busy.contains(o.id),
                  onMove: (status) => _move(o, status),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    super.key,
    required this.order,
    required this.onMove,
    this.highlighted = false,
    this.incoming = false,
    this.busy = false,
  });

  final OrderModel order;

  /// The order a notification pointed at, marked until the reader has seen it.
  final bool highlighted;

  /// This card is in a shop's inbox rather than a customer's purchases.
  final bool incoming;

  /// A change to this order is on its way to the server.
  final bool busy;

  final ValueChanged<String> onMove;

  @override
  Widget build(BuildContext context) {
    final s = OrderStatusStyle.of(order.status);
    final df = DateFormat('d MMMM y · h:mm a', 'ar');
    final address = order.addressLine;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceHigh, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: highlighted ? AppColors.accent : s.color.withValues(alpha: .3),
          width: highlighted ? 1.6 : 1,
        ),
        boxShadow: AppDecor.lift,
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
              df.format(order.createdAt!.toLocal()),
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
                        size: 16, color: AppColors.accent),
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
          // Where it stands and how it got there — the part a customer comes
          // back to this screen for.
          TradeTimeline(
            kind: TradeKind.order,
            status: order.status,
            log: order.statusLog,
            createdAt: order.createdAt,
            updatedAt: order.updatedAt,
            viewer: incoming ? TradeViewer.shop : TradeViewer.customer,
          ),
          const Divider(height: 22),
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
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline, width: 0.8),
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
          if (incoming)
            _ShopActions(status: order.status, busy: busy, onMove: onMove)
          else if (order.status == 'pending' || order.status == 'confirmed')
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton.icon(
                  onPressed: busy ? null : () => onMove('cancelled'),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('إلغاء الطلبية'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.discount,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The shop's next move on an incoming order: one clear step forward, and a
/// way out while it is still open. Each press reaches the customer.
class _ShopActions extends StatelessWidget {
  const _ShopActions({
    required this.status,
    required this.busy,
    required this.onMove,
  });

  final String status;
  final bool busy;
  final ValueChanged<String> onMove;

  /// The one step forward from [status], as (next status, label, icon).
  (String, String, IconData)? get _next {
    switch (status) {
      case 'pending':
        return ('confirmed', 'تأكيد الطلبية', Icons.check_rounded);
      case 'confirmed':
        return ('preparing', 'بدء التجهيز', Icons.soup_kitchen_rounded);
      case 'preparing':
        return ('ready', 'الطلبية جاهزة', Icons.inventory_2_rounded);
      case 'ready':
        return ('completed', 'تم التسليم', Icons.local_shipping_rounded);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    if (next == null) return const SizedBox.shrink();
    final (to, label, icon) = next;
    final pending = status == 'pending';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  busy ? null : () => onMove(pending ? 'rejected' : 'cancelled'),
              icon: Icon(pending ? Icons.close_rounded : Icons.block_rounded,
                  size: 18),
              label: Text(pending ? 'رفض' : 'إلغاء', maxLines: 1, softWrap: false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.discount,
                side: BorderSide(
                    color: AppColors.discount.withValues(alpha: 0.6)),
                // The theme's roomy padding left «رفض» a letter per line.
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: busy ? null : () => onMove(to),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.pearl),
                    )
                  : Icon(icon, size: 18),
              label: Text(label, maxLines: 1, softWrap: false),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
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
          const Icon(Icons.person_rounded, size: 16, color: AppColors.accent),
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
                foregroundColor: AppColors.accent,
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
        border: Border.all(color: style.color.withValues(alpha: .35), width: 0.8),
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
