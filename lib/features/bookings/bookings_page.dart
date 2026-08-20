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
import 'booking_status.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key, this.initialMine = false, this.highlightId});

  /// Open on «حجوزاتي» rather than the shop's inbox. Set when arriving from
  /// the home-page card, which only ever lists the user's own bookings.
  final bool initialMine;

  /// Scroll to this booking and mark it, for arrivals from a notification.
  /// The same notification link reaches both sides of a booking, so the page
  /// looks in the other list too rather than assuming which one holds it.
  final int? highlightId;

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  Future<List<BookingModel>>? _future;

  /// Shop owners have two lists: bookings they made («حجوزاتي») and requests
  /// their shop received. Everyone else only ever has the first.
  late bool _mine = widget.initialMine;

  // Deep-link highlight state, mirroring the shop page's product highlight.
  final GlobalKey _highlightKey = GlobalKey();
  late int? _highlightId = widget.highlightId;
  bool _didScrollHighlight = false;
  bool _didTryOtherScope = false;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  void _maybeLoad() {
    final session = context.read<SessionController>();
    if (session.isSignedIn) {
      _future = BookingService().list(scope: _mine ? 'customer' : null);
    }
  }

  /// Scroll to the highlighted booking once it is laid out, then let the
  /// marking fade so the list goes back to normal.
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

  /// The booking a notification pointed at is not in the list we opened — for
  /// a shop owner that means it is in the other one, so switch over to it.
  void _highlightMissing(List<BookingModel> items, bool hasInbox) {
    if (_highlightId == null || _didTryOtherScope || !hasInbox) return;
    if (items.any((b) => b.id == _highlightId)) return;
    _didTryOtherScope = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _switchTo(!_mine);
    });
  }

  /// True when this account also runs a shop and therefore has an inbox.
  bool _hasInbox(SessionController session) {
    final role = session.user?.role;
    return role == 'vendor' || role == 'admin';
  }

  void _switchTo(bool mine) {
    if (_mine == mine) return;
    setState(() {
      _mine = mine;
      _future = BookingService().list(scope: mine ? 'customer' : 'vendor');
    });
  }

  /// The shop's answer to the request: the outcome, plus its own words when it
  /// gave a reason. Without this the customer only ever saw a coloured pill.
  Widget _vendorReply(BookingModel b) {
    final s = BookingStatusStyle.of(b.status);
    final reason = (b.cancellationReason ?? '').trim();
    final shop = b.vendor?.name ?? 'المتجر';

    final message = switch (b.status) {
      'confirmed' => 'أكّد $shop حجزك.',
      'rejected' => 'اعتذر $shop عن قبول الحجز.',
      'cancelled' => 'أُلغي الحجز.',
      'completed' => 'تم إنجاز الحجز. نتمنى أن تكون التجربة سعيدة!',
      _ => '',
    };

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mark_chat_read_rounded, size: 16, color: s.color),
              const SizedBox(width: 6),
              Text(
                'رد المتجر',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  color: s.color,
                ),
              ),
              const Spacer(),
              if (b.updatedAt != null)
                Text(
                  DateFormat('d MMM', 'ar').format(b.updatedAt!),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
            ),
          ],
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '«$reason»',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: AppColors.textDark,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
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

  void _reload() => setState(() => _future = BookingService().list());

  /// Shop side: confirm the request. The API notifies the customer, whose
  /// bookings page and home card then show the reply.
  Future<void> _confirm(BookingModel b) async {
    try {
      await BookingService().updateStatus(b.id, 'confirmed');
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد الحجز وإشعار الزبون ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Shop side: decline, with an optional reason that reaches the customer
  /// verbatim — a bare rejection with no explanation is what people complain
  /// about most.
  Future<void> _reject(BookingModel b) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الحجز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'سيصل ردّك إلى الزبون مباشرة. اكتب سبباً مختصراً إن أمكن.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'السبب (اختياري)',
                hintText: 'مثال: التاريخ محجوز مسبقاً',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفض الحجز'),
          ),
        ],
      ),
    );
    if (ok != true) {
      reason.dispose();
      return;
    }
    final text = reason.text.trim();
    reason.dispose();
    try {
      await BookingService()
          .updateStatus(b.id, 'rejected', reason: text.isEmpty ? null : text);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Confirm / reject buttons, shown to the shop on a pending request.
  Widget _vendorActions(BookingModel b) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _reject(b),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('رفض'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _confirm(b),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('تأكيد الحجز'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E9E5B),
                foregroundColor: Colors.white,
              ),
            ),
          ),
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
      // Not `cancel()` — that hits DELETE, which the API restricts to admins,
      // so it 403'd for the very people the button is shown to. Setting the
      // status is the path the API opens to customers and shops.
      await BookingService().updateStatus(b.id, 'cancelled');
      if (!mounted) return;
      _reload();
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
          // The page is always pushed (from the home card or the account menu),
        // so it needs a way back. PinkAppBar hides the arrow by itself when
        // there is nothing to pop.
        appBar: const PinkAppBar(title: 'مناسباتي'),
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
    final hasInbox = _hasInbox(session);

    return AppScaffold(

      appBar: const PinkAppBar(title: 'مناسباتي'),
      body: Column(
        children: [
          // A shop owner books services too. Without this switch their own
          // bookings were unreachable — the page only ever showed the inbox.
          if (hasInbox)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('حجوزاتي'),
                    icon: Icon(Icons.event_available_rounded, size: 17),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('طلبات واردة'),
                    icon: Icon(Icons.inbox_rounded, size: 17),
                  ),
                ],
                selected: {_mine},
                showSelectedIcon: false,
                onSelectionChanged: (s) => _switchTo(s.first),
              ),
            ),
          Expanded(child: _list(hasInbox)),
        ],
      ),
    );
  }

  Widget _list(bool hasInbox) {
    final session = context.watch<SessionController>();
    return FutureBuilder<List<BookingModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
              message: snap.error.toString(),
              onRetry: () => setState(_maybeLoad),
            );
          }
          final items = snap.data ?? const [];
          _highlightMissing(items, hasInbox);
          if (items.isEmpty) {
            return EmptyState(
              message: hasInbox && !_mine
                  ? 'لا توجد طلبات حجز واردة'
                  : 'لا يوجد حجوزات حالياً\nابدأ بحجز خدمة لمناسبتك',
              icon: Icons.event_busy,
            );
          }
          if (_highlightId != null && items.any((b) => b.id == _highlightId)) {
            _scheduleHighlightScroll();
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
                // A booking someone else made with this shop, i.e. the vendor
                // is looking at their inbox rather than their own bookings.
                final isIncoming =
                    b.customer != null && b.customer!.id != session.user?.id;
                final hi = _highlightId != null && b.id == _highlightId;
                return Container(
                  key: hi ? _highlightKey : null,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: hi
                        ? Border.all(color: AppColors.primary, width: 1.6)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: hi
                            ? AppColors.primary.withValues(alpha: .28)
                            : AppColors.cardShadow,
                        blurRadius: hi ? 18 : 12,
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
                          BookingStatusChip(status: b.status),
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
                      if (isIncoming) ...[
                        _customerBlock(b),
                        // The shop answers here; without this a reply could
                        // only ever be sent from the admin dashboard.
                        if (b.status == 'pending') _vendorActions(b),
                      ]
                      // The shop's answer, on the customer's own bookings.
                      else if (b.hasVendorReply)
                        _vendorReply(b),
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
                      // Nothing left to cancel once the booking is closed —
                      // 'rejected' used to slip through and still offer it.
                      if (b.status != 'cancelled' &&
                          b.status != 'rejected' &&
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
        });
  }
}
