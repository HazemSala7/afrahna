import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/services/notification_router.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/shell_bottom_nav.dart';

/// Notifications screen — list user's personal + broadcast notifications.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationService();
  late Future<List<NotificationModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.list();
  }

  Future<void> _refresh() async {
    // NOTE: a block body is required. `setState(() => _future = ...)` returns
    // the assigned Future from the closure, which Flutter rejects.
    setState(() {
      _future = _service.list();
    });
    await _future;
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      if (mounted) await _refresh();
    } catch (_) {}
  }

  Future<void> _onTap(NotificationModel n) async {
    if (!n.isRead) {
      try {
        await _service.markRead(n.id);
      } catch (_) {}
    }
    if (mounted) await _refresh();
    // Deep-link to the related content (shop, reel, booking, invitation, ...).
    // `fromList` keeps a notification with no usable link from pushing another
    // copy of this very screen.
    NotificationRouter.handle(n.link, type: n.type, fromList: true);
  }

  @override
  Widget build(BuildContext context) {
    // Flat, light background (no darkening gradient) so the page reads bright.
    return Scaffold(
      bottomNavigationBar: const ShellBottomNav(),
      backgroundColor: const Color(0xFFFCF8F3),
      appBar: PinkAppBar(
        title: 'الإشعارات',
        actions: [
          IconButton(
            tooltip: 'تعليم الكل كمقروء',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _NotificationsToggle(),
            Expanded(
              child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: FutureBuilder<List<NotificationModel>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const CenteredLoader();
              }
              if (snap.hasError) {
                return ErrorState(
                  message: snap.error.toString(),
                  onRetry: _refresh,
                );
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    EmptyState(
                      message: 'لا توجد إشعارات حالياً',
                      icon: Icons.notifications_none_rounded,
                    ),
                  ],
                );
              }
              final unread = items.where((n) => !n.isRead).length;
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i == 0) return _HeaderStrip(total: items.length, unread: unread);
                  final n = items[i - 1];
                  return _NotificationTile(n: n, onTap: () => _onTap(n));
                },
              );
            },
          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Switch that lets the user turn all notifications on/off (offer alerts, …).
class _NotificationsToggle extends StatefulWidget {
  const _NotificationsToggle();

  @override
  State<_NotificationsToggle> createState() => _NotificationsToggleState();
}

class _NotificationsToggleState extends State<_NotificationsToggle> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    if (user == null) return const SizedBox.shrink(); // guests have no prefs
    final enabled = user.notificationsEnabled;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
            color: enabled ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تلقّي الإشعارات',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.textDark)),
                Text('عروض المعلنين الذين تتابعهم وتنبيهات أخرى',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: enabled,
              activeThumbColor: AppColors.primary,
              onChanged: (v) async {
                final ctrl = context.read<SessionController>();
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _busy = true);
                try {
                  await ctrl.setNotificationsEnabled(v);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.toString())));
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
            ),
        ],
      ),
    );
  }
}

/// Small summary row above the list showing totals.
class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.total, required this.unread});
  final int total;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          Text(
            '$total إشعار',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$unread غير مقروء',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.n, required this.onTap});
  final NotificationModel n;
  final VoidCallback onTap;

  /// One colour and one icon per kind of notification the backend sends, so
  /// the list is scannable: money is green, an order is amber, a wedding
  /// reply is pink, and so on.
  Color _accent() {
    switch (n.type) {
      case 'booking':
        return const Color(0xFF7C5CFF);
      case 'order':
        return const Color(0xFFD08A2E);
      case 'invitation':
        return AppColors.primary;
      case 'payment':
      case 'subscription':
        return const Color(0xFF2E9E5B);
      case 'promo':
        return AppColors.discount;
      case 'post':
      case 'comment':
        return const Color(0xFF3E8BC4);
      case 'review':
        return const Color(0xFFC9A24D);
      case 'follow':
      case 'vendor':
      case 'service':
        return const Color(0xFF4B7BA8);
      case 'system':
        return const Color(0xFF38BDF8);
      default:
        return AppColors.primary;
    }
  }

  IconData _icon() {
    switch (n.type) {
      case 'booking':
        return Icons.event_available_rounded;
      case 'order':
        return Icons.receipt_long_rounded;
      case 'invitation':
        return Icons.favorite_rounded;
      case 'payment':
      case 'subscription':
        return Icons.payments_rounded;
      case 'promo':
        return Icons.local_offer_rounded;
      case 'post':
        return Icons.photo_library_rounded;
      case 'comment':
        return Icons.mode_comment_rounded;
      case 'review':
        return Icons.star_rounded;
      case 'follow':
        return Icons.person_add_alt_1_rounded;
      case 'vendor':
      case 'service':
        return Icons.storefront_rounded;
      case 'system':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _timeAgo(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
    if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
    return '${d.year}/${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0x0F000000),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accent side bar highlights unread notifications.
                Container(width: 4, color: n.isRead ? Colors.transparent : accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon(), color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title.isEmpty ? 'إشعار' : n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: Color(0xFF2A1A22),
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsetsDirectional.only(start: 6),
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (n.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        n.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(n.createdAt),
                      style: TextStyle(
                        color: AppColors.textMuted.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}
