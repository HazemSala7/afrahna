import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../widgets/tier_badge.dart';
import '../../core/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/cosmos.dart';
import '../bookings/bookings_page.dart';
import '../notifications/notifications_page.dart';
import '../points/points_page.dart';
import '../posts/manage_reels_page.dart';
import '../posts/vendor_posts_page.dart';
import '../store/my_orders_page.dart';
import '../subscriptions/subscription_plans.dart';
import '../vendors/edit_vendor_page.dart';
import '../vendors/manage_highlights_page.dart';
import '../vendors/manage_products_page.dart';
import '../vendors/manage_promotions_page.dart';
import '../vendors/manage_sections_page.dart';
import '../vendors/manage_stories_page.dart';
import '../vendors/vendor_details_page.dart';
import '../vendors/vendor_followers_page.dart';
import 'account_shared.dart';
import 'vendor_statement_page.dart';

/// The advertiser (vendor) home for "حسابي": a cover/logo hero with the shop's
/// live stats, quick content shortcuts (store / stories / reels / posts),
/// and the management + settings menus underneath.
class VendorAccountView extends StatefulWidget {
  const VendorAccountView({super.key, required this.session});

  final SessionController session;

  @override
  State<VendorAccountView> createState() => _VendorAccountViewState();
}

class _VendorAccountViewState extends State<VendorAccountView> {
  final _vendorService = VendorService();
  final _picker = ImagePicker();

  VendorModel? _vendor;
  bool _loading = true;
  String? _error;

  /// Set while a cover/logo image is being picked + uploaded.
  bool _savingImage = false;

  int _unread = 0;

  /// Requests waiting on the shop's answer. Null until counted (or when the
  /// count could not be fetched — the tiles still open the lists).
  int? _pendingBookings;
  int? _pendingOrders;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUnread();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    Future<int?> count(Future<List<Object>> list) async {
      try {
        return (await list).length;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      count(BookingService().list(scope: 'vendor', status: 'pending')),
      count(OrderService().list(scope: 'vendor', status: 'pending')),
    ]);
    if (!mounted) return;
    setState(() {
      _pendingBookings = results[0];
      _pendingOrders = results[1];
    });
  }

  /// Opens one of the inboxes, and recounts on the way back — the shop has
  /// probably just answered something.
  Future<void> _openInbox(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _loadInbox();
  }

  Future<void> _load() async {
    try {
      final v = await _vendorService.mine();
      if (!mounted) return;
      setState(() {
        _vendor = v;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadUnread() async {
    final n = await NotificationService().unreadCount();
    if (mounted) setState(() => _unread = n);
  }

  Future<void> _refresh() async {
    await Future.wait([_load(), _loadUnread(), _loadInbox()]);
  }

  void _go(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Picks one image, uploads it, and saves it as the shop's cover or logo.
  Future<void> _changeImage({required bool cover}) async {
    final vendor = _vendor;
    if (vendor == null || _savingImage) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  cover ? 'تعديل صورة الغلاف' : 'تعديل الصورة الشخصية',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
              ),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: AppColors.primary,
              ),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    XFile? picked;
    try {
      picked = await _picker.pickImage(source: source, imageQuality: 88);
    } catch (_) {
      _snack('تعذّر فتح المعرض');
      return;
    }
    if (picked == null) return;

    setState(() => _savingImage = true);
    try {
      final url = await UploadService().uploadFile(
        picked.path,
        folder: cover ? 'vendors/covers' : 'vendors/logos',
      );
      final updated = await _vendorService.update(vendor.id, {
        if (cover) 'cover_image': url else 'logo': url,
      });
      if (!mounted) return;
      setState(() {
        _vendor = updated;
        _savingImage = false;
      });
      _snack(cover ? 'تم تحديث صورة الغلاف ✓' : 'تم تحديث الصورة الشخصية ✓');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _savingImage = false);
      _snack(e.message);
    }
  }

  Future<void> _editProfile() async {
    final vendor = _vendor;
    if (vendor == null) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditVendorPage(vendor: vendor)),
    );
    if (mounted) _load();
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.session.logout();
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'سيتم حذف حسابك ومتجرك وجميع بياناتك نهائيًا ولا يمكن التراجع عن هذا '
          'الإجراء. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CenteredLoader(),
    );
    final deleted = await widget.session.deleteAccount();
    if (!mounted) return;
    Navigator.pop(context); // dismiss the loading dialog
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.session.error ?? 'تعذّر حذف الحساب'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// The hamburger sheet: settings + support, kept out of the main scroll so
  /// the page stays focused on the shop itself.
  void _openMenuSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              AccountMenuGroup(
                items: [
                  AccountMenuItem(
                    icon: Icons.lock_rounded,
                    label: 'تغيير كلمة المرور',
                    tint: kTintTeal,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      showChangePasswordSheet(context);
                    },
                  ),
                  AccountMenuItem(
                    icon: Icons.language_rounded,
                    label: 'اللغة',
                    tint: kTintTerracotta,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      showLanguageDialog(context);
                    },
                  ),
                  AccountMenuItem(
                    icon: Icons.help_rounded,
                    label: 'المساعدة والدعم',
                    tint: kTintSage,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      showSupportSheet(context);
                    },
                  ),
                  AccountMenuItem(
                    icon: Icons.info_rounded,
                    label: 'حول التطبيق',
                    tint: kTintMauve,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      showAppAboutSheet(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendor = _vendor;

    // Each block slides in slightly after the previous one.
    var step = 0;
    Duration next() => Duration(milliseconds: 70 * step++);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Bottom padding clears the shell's floating bottom nav bar.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
        children: [
          _TopBar(
            unread: _unread,
            onNotifications: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
              _loadUnread();
            },
            onMenu: _openMenuSheet,
          ),
          const SizedBox(height: 14),

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: CenteredLoader(label: 'جارٍ تحميل بيانات متجرك...'),
            )
          else if (vendor == null)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: ErrorState(
                message: _error ?? 'تعذّر تحميل بيانات متجرك',
                onRetry: () {
                  setState(() => _loading = true);
                  _load();
                },
              ),
            )
          else ...[
            FadeSlideIn(
              id: 'vendor.0',
              delay: next(),
              child: _VendorHero(
                vendor: vendor,
                busy: _savingImage,
                onTapAvatar: () => _changeImage(cover: false),
                onPreview: () => _go(VendorDetailsPage(vendorId: vendor.id)),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              id: 'vendor.1',
              delay: next(),
              child: Row(
                children: [
                  Expanded(
                    child: _GhostButton(
                      icon: Icons.image_rounded,
                      label: 'تعديل الغلاف',
                      onTap: _savingImage
                          ? null
                          : () => _changeImage(cover: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GhostButton(
                      icon: Icons.person_rounded,
                      label: 'تعديل الصورة الشخصية',
                      onTap: _savingImage
                          ? null
                          : () => _changeImage(cover: false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // What customers are waiting on — first, above everything the
            // shop can tend to later.
            FadeSlideIn(
              id: 'vendor.1b',
              delay: next(),
              child: _TradeInbox(
                pendingBookings: _pendingBookings,
                pendingOrders: _pendingOrders,
                // Orders come from products, which only a store has — but an
                // order already waiting is shown whatever the shop is now.
                showOrders: vendor.isStore || (_pendingOrders ?? 0) > 0,
                onBookings: () => _openInbox(const BookingsPage()),
                onOrders: () =>
                    _openInbox(const MyOrdersPage(initialIncoming: true)),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              id: 'vendor.2',
              delay: next(),
              child: _QuickActions(vendor: vendor, go: _go),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              id: 'vendor.3',
              delay: next(),
              child: AccountMenuGroup(
                items: [
                  AccountMenuItem(
                    icon: Icons.notifications_rounded,
                    label: 'الإشعارات',
                    subtitle: 'عرض جميع الإشعارات والتنبيهات',
                    tint: kTintRose,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      );
                      _loadUnread();
                    },
                  ),
                  AccountMenuItem(
                    icon: Icons.person_rounded,
                    label: 'تعديل الملف الشخصي',
                    subtitle: 'تحديث معلومات ووسائل التواصل',
                    tint: kTintMauve,
                    onTap: _editProfile,
                  ),
                  AccountMenuItem(
                    icon: Icons.stars_rounded,
                    label: 'نقاطي ومكافآتي',
                    subtitle: 'رصيدك من نقاط أفراحنا',
                    tint: kTintGold,
                    onTap: () => _go(const PointsPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // A shop owner is also a member: they collect أفراحنا points and
            // climb the same ladder as everyone else. Those points were only
            // visible on the customer account screen, which an advertiser
            // never sees — so their level lives here, immediately above the
            // store's own points and clearly separated from them.
            if (widget.session.user != null)
              FadeSlideIn(
                id: 'vendor.3b',
                delay: next(),
                child: _MemberPointsCard(
                  user: widget.session.user!,
                  onTap: () => _go(const PointsPage()),
                ),
              ),
            if (widget.session.user != null) const SizedBox(height: 16),
            FadeSlideIn(
              id: 'vendor.4',
              delay: next(),
              child: _StorePointsCard(
                vendor: vendor,
                onDetails: () => _go(const VendorStatementPage()),
              ),
            ),
            const SizedBox(height: 22),
            FadeSlideIn(
              id: 'vendor.5',
              delay: next(),
              child: const AccountSectionLabel('إدارة المتجر'),
            ),
            const SizedBox(height: 10),
            FadeSlideIn(
              id: 'vendor.6',
              delay: next(),
              child: AccountMenuGroup(
                items: [
                  AccountMenuItem(
                    icon: Icons.workspace_premium_rounded,
                    label: 'باقات الاشتراك',
                    subtitle: vendor.subscriptionLabel,
                    tint: kTintGold,
                    onTap: () => _go(
                      SubscriptionPlansPage(currentPlan: vendor.activePlan),
                    ),
                  ),
                  AccountMenuItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'كشف الحساب والدفعات',
                    tint: kTintSage,
                    onTap: () => _go(const VendorStatementPage()),
                  ),
                  AccountMenuItem(
                    icon: Icons.local_offer_rounded,
                    label: 'العروض والخصومات',
                    tint: kTintTerracotta,
                    subtitle: vendor.allowOffers ? null : 'غير مفعّلة لاشتراكك',
                    onTap: vendor.allowOffers
                        ? () => _go(ManagePromotionsPage(vendorId: vendor.id))
                        : () => _featureClosed(context, 'العروض'),
                  ),
                  AccountMenuItem(
                    icon: Icons.auto_awesome_motion_rounded,
                    label: 'الهايلايت',
                    tint: kTintMauve,
                    onTap: () => _go(ManageHighlightsPage(vendorId: vendor.id)),
                  ),
                  if (vendor.isStore)
                    AccountMenuItem(
                      icon: Icons.category_rounded,
                      label: 'أقسام المتجر',
                      tint: kTintTeal,
                      onTap: () => _go(ManageSectionsPage(vendorId: vendor.id)),
                    ),
                  AccountMenuItem(
                    icon: Icons.groups_rounded,
                    label: 'المتابعون',
                    subtitle: '${_fmt(vendor.followersCount)} متابع',
                    tint: kTintRose,
                    onTap: () => _go(VendorFollowersPage(vendorId: vendor.id)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FadeSlideIn(
              id: 'vendor.7',
              delay: next(),
              child: AccountMenuGroup(
                items: [
                  AccountMenuItem(
                    icon: Icons.logout_rounded,
                    label: 'تسجيل الخروج',
                    tint: AppColors.discount,
                    isDestructive: true,
                    onTap: _confirmLogout,
                  ),
                  AccountMenuItem(
                    icon: Icons.delete_forever_rounded,
                    label: 'حذف الحساب',
                    tint: AppColors.discount,
                    isDestructive: true,
                    onTap: _confirmDelete,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const PoweredByNeurex(),
          ],
        ],
      ),
    );
  }
}

/// Thousands-separated count, e.g. 23456 → "23,456".
String _fmt(num n) => NumberFormat.decimalPattern('en').format(n);

// ===========================================================================
// TOP BAR — bell + brand + menu
// ===========================================================================

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.unread,
    required this.onNotifications,
    required this.onMenu,
  });

  final int unread;
  final VoidCallback onNotifications;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // start (right in RTL) → notifications
        Stack(
          clipBehavior: Clip.none,
          children: [
            _CircleIconButton(
              icon: Icons.notifications_none_rounded,
              onTap: onNotifications,
            ),
            if (unread > 0)
              PositionedDirectional(
                top: 2,
                start: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: AppColors.discount,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.hairline, width: 1.5),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Spacer(),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    AppAssets.logo,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'أفراحنا',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              'كل ما يلزم مناسباتك في مكان واحد',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const Spacer(),
        // end (left in RTL) → settings menu
        _CircleIconButton(icon: Icons.menu_rounded, onTap: onMenu),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.textDark, size: 22),
        ),
      ),
    );
  }
}

// ===========================================================================
// HERO — cover + logo + live shop stats
// ===========================================================================

class _VendorHero extends StatelessWidget {
  const _VendorHero({
    required this.vendor,
    required this.busy,
    required this.onTapAvatar,
    required this.onPreview,
  });

  final VendorModel vendor;
  final bool busy;
  final VoidCallback onTapAvatar;

  /// Opens the public shop page, so the advertiser sees what customers see.
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final hasCover = (vendor.cover ?? '').isNotEmpty;
    final rating = vendor.rating ?? 0;
    final subtitle = [
      vendor.category?.name,
      vendor.city?.name,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: AppColors.brandDeepGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Cover photo (when set) behind a scrim that keeps text readable.
          if (hasCover)
            Positioned.fill(
              child: AppNetworkImage(
                url: vendor.cover,
                fallbackIcon: Icons.storefront_rounded,
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: hasCover
                      ? [
                          const Color(0xFF3D2817).withValues(alpha: 0.82),
                          const Color(0xFF6B4226).withValues(alpha: 0.72),
                          const Color(0xFF8B5A3C).withValues(alpha: 0.62),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),
          // Decorative flourish
          Positioned(
            left: -26,
            bottom: -36,
            child: Icon(
              Icons.celebration_rounded,
              size: 132,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Verified pill (end side) + preview shortcut
                Row(
                  children: [
                    _PreviewChip(onTap: onPreview),
                    const Spacer(),
                    if (vendor.isVerified) const _VerifiedChip(),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            vendor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              shadows: [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.place_rounded,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    subtitle.join(' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _StatChip(
                                icon: Icons.star_rounded,
                                iconColor: const Color(0xFFFFC961),
                                text: rating > 0
                                    ? '${rating.toStringAsFixed(1)} '
                                          '(${_fmt(vendor.reviewsCount ?? 0)} تقييم)'
                                    : 'لا توجد تقييمات بعد',
                              ),
                              _StatChip(
                                icon: Icons.visibility_rounded,
                                text: '${_fmt(vendor.viewsCount)} مشاهدة',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _HeroAvatar(
                      url: vendor.logo,
                      busy: busy,
                      onTap: onTapAvatar,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({
    required this.url,
    required this.busy,
    required this.onTap,
  });

  final String? url;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: AppColors.hairline.withValues(alpha: 0.85),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: busy
                  ? Container(
                      color: AppColors.primaryLight,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : AppNetworkImage(
                      url: url,
                      fallbackIcon: Icons.storefront_rounded,
                    ),
            ),
          ),
          // Camera badge — tap to replace the logo.
          PositionedDirectional(
            bottom: -2,
            start: -2,
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: busy ? null : onTap,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.hairline, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3D08A), Color(0xFFE6B450)],
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE6B450).withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 13, color: Color(0xFFE5BE94)),
          SizedBox(width: 4),
          Text(
            'معلن موثّق',
            style: TextStyle(
              color: Color(0xFFE5BE94),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new_rounded, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'معاينة متجري',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.text, this.iconColor});

  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor ?? Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// COVER / AVATAR BUTTONS
// ===========================================================================

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primaryLight, width: 1.3),
            boxShadow: AppDecor.lift,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: enabled ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: enabled
                        ? AppColors.primaryDark
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// QUICK ACTIONS — store / stories / reels / posts
// ===========================================================================

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.vendor, required this.go});

  final VendorModel vendor;
  final void Function(Widget page) go;

  @override
  Widget build(BuildContext context) {
    final tiles = <_QuickTileData>[
      // A shop that sells products may also offer services — a hall sells
      // decoration and books evenings. These used to be either/or, which left
      // every «متجر» with no way to add a service at all.
      if (vendor.isStore)
        _QuickTileData(
          icon: Icons.shopping_bag_rounded,
          title: 'المتجر',
          sub: 'إدارة المنتجات والطلبات',
          colors: const [Color(0xFFF8896B), Color(0xFFE05B6E)],
          onTap: () => go(ManageProductsPage(vendorId: vendor.id)),
        ),
      _QuickTileData(
        icon: Icons.design_services_rounded,
        title: 'خدماتي',
        sub: 'إضافة وإدارة الخدمات',
        colors: const [Color(0xFFF2A65A), Color(0xFFD9774B)],
        onTap: () => go(const VendorPostsPage()),
      ),
      _QuickTileData(
        icon: Icons.add_circle_rounded,
        title: 'الستوريز',
        sub: 'إضافة وإدارة القصص',
        colors: const [Color(0xFFB07BE0), Color(0xFF7C4DC4)],
        onTap: () => go(ManageStoriesPage(vendorId: vendor.id)),
        locked: !vendor.allowStories,
      ),
      _QuickTileData(
        icon: Icons.movie_creation_rounded,
        title: 'الريلز',
        sub: 'عرض وإدارة مقاطعك',
        colors: const [Color(0xFFF8B75C), Color(0xFFEE8A3C)],
        // Lands on the list of published reels (with an add button) rather
        // than straight into the uploader — an advertiser had no way to see
        // or remove what they had already posted.
        onTap: () => go(ManageReelsPage(vendorId: vendor.id)),
        locked: !vendor.allowReels,
      ),
      _QuickTileData(
        icon: Icons.article_rounded,
        title: 'المنشورات',
        sub: 'إنشاء وإدارة المنشورات',
        colors: const [Color(0xFF6FB6F5), Color(0xFF3D7BE0)],
        onTap: () => go(const VendorPostsPage()),
        locked: !vendor.allowPosts,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppDecor.lift,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final t in tiles) Expanded(child: _QuickTile(data: t))],
      ),
    );
  }
}

/// Tells a shop, where it tapped, that a feature is switched off for it.
void _featureClosed(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'ميزة $feature غير مفعّلة لاشتراكك. تواصل مع إدارة أفراحنا لتفعيلها.',
        ),
      ),
    );
}

class _QuickTileData {
  const _QuickTileData({
    required this.icon,
    required this.title,
    required this.sub,
    required this.colors,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String sub;
  final List<Color> colors;
  final VoidCallback onTap;

  /// Switched off for this shop by an admin: drawn grey with a padlock, and
  /// a tap explains rather than opens. The tile stays so the shop knows the
  /// feature exists.
  final bool locked;
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.data});
  final _QuickTileData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: data.locked
            ? () => _featureClosed(context, data.title)
            : data.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: data.locked
                        ? const [Color(0xFFBDB4AE), Color(0xFF9A8F88)]
                        : data.colors,
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (data.locked
                              ? const Color(0xFF9A8F88)
                              : data.colors.last)
                          .withValues(alpha: 0.38),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  data.locked ? Icons.lock_rounded : data.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.locked ? 'غير مفعّلة لاشتراكك' : data.sub,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  height: 1.3,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// STORE POINTS CARD
// ===========================================================================

/// The owner's own أفراحنا level, on the advertiser account screen.
///
/// Two point counters share this page and they are not the same thing: the
/// store's points buy subscription months, these buy the member's 50 ₪. The
/// heading and the note exist to keep the two from reading as one number in
/// two places.
class _MemberPointsCard extends StatelessWidget {
  const _MemberPointsCard({required this.user, required this.onTap});

  final UserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppDecor.lift,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.stars_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'نقاطك الشخصية',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              // Wrapped in its own Material: the card is a plain Container, so
              // an InkWell here has no surface to splash on and throws.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(99),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'عرض',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TierProgressStrip(
            balance: user.pointsBalance,
            rewardsTaken: user.rewardsTaken,
            onTap: onTap,
          ),
          const SizedBox(height: 8),
          const Text(
            'منفصلة عن نقاط المتجر: هذه نقاطك كعضو في أفراحنا، وتلك تُحتسب'
            ' لاشتراك متجرك.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorePointsCard extends StatelessWidget {
  const _StorePointsCard({required this.vendor, required this.onDetails});

  final VendorModel vendor;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.surface],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE9CFA4)),
        boxShadow: AppDecor.lift,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'إجمالي نقاط متجرك',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _fmt(vendor.pointsBalance),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFB4832F),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFFE0AE44),
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1000 نقطة = شهر اشتراك مجاني'
                      '${vendor.beneficiariesCount > 0 ? ' • استفاد '
                                '${_fmt(vendor.beneficiariesCount)} عميل' : ''}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF3D08A), Color(0xFFE0AE44)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE0AE44).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB4832F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onDetails,
              child: const Text(
                'عرض تفاصيل النقاط والاشتراك',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// INBOX — what customers are waiting on
// ===========================================================================

/// The shop's two inboxes — booking requests and store orders — with how
/// many of each are still waiting on an answer. A customer who booked is
/// following the request from their side; this is where the shop answers.
class _TradeInbox extends StatelessWidget {
  const _TradeInbox({
    required this.pendingBookings,
    required this.pendingOrders,
    required this.showOrders,
    required this.onBookings,
    required this.onOrders,
  });

  final int? pendingBookings;
  final int? pendingOrders;
  final bool showOrders;
  final VoidCallback onBookings;
  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _InboxTile(
        icon: Icons.event_available_rounded,
        title: 'الحجوزات الواردة',
        waiting: pendingBookings,
        tint: AppColors.holoLavender,
        onTap: onBookings,
      ),
      if (showOrders)
        _InboxTile(
          icon: Icons.receipt_long_rounded,
          title: 'طلبات المتجر',
          waiting: pendingOrders,
          tint: AppColors.holoAqua,
          onTap: onOrders,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AccountSectionLabel('طلبات الزبائن'),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({
    required this.icon,
    required this.title,
    required this.waiting,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int? waiting;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = waiting ?? 0;
    final urgent = n > 0;

    return GlassPanel(
      tint: urgent ? AppColors.accent : tint,
      glow: urgent,
      radius: 20,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.12),
                  border: Border.all(color: tint.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.25),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Icon(icon, color: tint, size: 21),
              ),
              const Spacer(),
              if (urgent)
                Container(
                  constraints: const BoxConstraints(minWidth: 26),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Text(
                    n > 99 ? '99+' : '$n',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            waiting == null
                ? 'اضغط للعرض'
                : urgent
                ? (n == 1 ? 'طلب واحد بانتظار ردّك' : '$n بانتظار ردّك')
                : 'لا طلبات بانتظارك',
            style: TextStyle(
              color: urgent ? AppColors.accent : AppColors.textMuted,
              fontWeight: urgent ? FontWeight.w800 : FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
