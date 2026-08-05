import 'package:flutter/material.dart';
// `intl` also exports a TextDirection, which would shadow the Flutter one used
// for the LTR phone number below.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_widgets.dart';
import '../admin/admin_dashboard_page.dart';
import '../auth/login_page.dart';
import '../auth/register_page.dart';
import '../bookings/bookings_page.dart';
import '../delegate/delegate_dashboard_page.dart';
import '../favorites/favorites_page.dart';
import '../invitations/invitations_page.dart';
import '../notifications/notifications_page.dart';
import '../offers/offers_page.dart';
import '../points/points_page.dart';
import '../posts/vendor_posts_page.dart';
import 'account_shared.dart';
import 'customer_header.dart';
import 'edit_profile_page.dart';
import 'followed_vendors_page.dart';
import 'vendor_account_view.dart';
import 'vendor_statement_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    // Advertisers get their own shop-centric account screen.
    final isVendor = session.isSignedIn && session.user!.isVendor;
    return AppScaffold(
      appBar:
          isVendor ? null : const PinkAppBar(title: 'حسابي', showBack: false),
      body: !session.isSignedIn
          ? const _GuestView()
          : isVendor
              ? VendorAccountView(session: session)
              : _SignedInView(session: session),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  static const _benefits = <({IconData icon, String title, String sub})>[
    (
      icon: Icons.local_fire_department_rounded,
      title: 'عروض وخصومات حصرية',
      sub: 'كن أول من يستلم أحدث العروض الخاصة'
    ),
    (
      icon: Icons.favorite_rounded,
      title: 'قائمة المفضّلة',
      sub: 'احفظ المحلات والخدمات التي تعجبك'
    ),
    (
      icon: Icons.event_available_rounded,
      title: 'تابع حجوزاتك',
      sub: 'كل مناسباتك ومواعيدك في مكان واحد'
    ),
    (
      icon: Icons.notifications_active_rounded,
      title: 'إشعارات فورية',
      sub: 'ابقَ على اطّلاع بكل جديد يخصّك'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Bottom padding clears the shell's floating bottom nav bar so the
      // login button at the end stays reachable above it.
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
      children: [
        // Hero header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5A3C), AppColors.primary, Color(0xFFC79A6A)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6), width: 2),
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: Colors.white, size: 42),
              ),
              const SizedBox(height: 14),
              const Text(
                'أنشئ حسابك واستفد من العروض 🎁',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'سجّل مجانًا ودع أفراحنا يخطّط معك ليومك المميّز',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // Benefit rows
        for (final b in _benefits) ...[
          _BenefitRow(icon: b.icon, title: b.title, sub: b.sub),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 10),
        // Primary CTA — create account
        SizedBox(
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFD4A373), Color(0xFF8B5A3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x558B5A3C),
                    blurRadius: 16,
                    offset: Offset(0, 8)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('أنشئ حساب جديد',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary — already have an account
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('لديّ حساب — تسجيل الدخول',
                style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow(
      {required this.icon, required this.title, required this.sub});
  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedInView extends StatefulWidget {
  const _SignedInView({required this.session});
  final SessionController session;

  @override
  State<_SignedInView> createState() => _SignedInViewState();
}

class _SignedInViewState extends State<_SignedInView> {
  SessionController get session => widget.session;

  /// Drives the red bubble on the notifications shortcut.
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    final n = await NotificationService().unreadCount();
    if (mounted) setState(() => _unread = n);
  }

  Future<void> _confirmLogout(BuildContext context) async {
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
    if (ok == true) await session.logout();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'سيتم حذف حسابك وجميع بياناتك نهائيًا ولا يمكن التراجع عن هذا الإجراء. هل أنت متأكد؟',
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
    if (confirm != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CenteredLoader(),
    );
    final deleted = await session.deleteAccount();
    if (!context.mounted) return;
    Navigator.pop(context); // dismiss the loading dialog
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session.error ?? 'تعذّر حذف الحساب'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = session.user!;

    void go(Widget page) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );

    // Role-specific management shortcuts (only shown when relevant).
    final manage = <AccountMenuItem>[
      if (user.isAdmin)
        AccountMenuItem(
          icon: Icons.admin_panel_settings_rounded,
          label: 'لوحة الإدارة',
          tint: kTintTeal,
          onTap: () => go(const AdminDashboardPage()),
        ),
      if (user.isDelegate)
        AccountMenuItem(
          icon: Icons.badge_rounded,
          label: 'لوحة المندوب',
          tint: kTintGold,
          onTap: () => go(const DelegateDashboardPage()),
        ),
      if (user.isVendor)
        AccountMenuItem(
          icon: Icons.dynamic_feed_rounded,
          label: 'محتواي (منشورات وريلز)',
          tint: kTintTerracotta,
          onTap: () => go(const VendorPostsPage()),
        ),
      if (user.isVendor)
        AccountMenuItem(
          icon: Icons.receipt_long_rounded,
          label: 'كشف حساب (الاشتراكات والدفعات)',
          tint: kTintSage,
          onTap: () => go(const VendorStatementPage()),
        ),
    ];

    final account = <AccountMenuItem>[
      AccountMenuItem(
        icon: Icons.manage_accounts_rounded,
        label: 'تعديل الملف الشخصي',
        subtitle: 'الاسم، الجوال، الصورة، وسائل التواصل',
        tint: kTintTeal,
        onTap: () => go(const EditProfilePage()),
      ),
      AccountMenuItem(
        icon: Icons.stars_rounded,
        label: 'نقاطي ومكافآتي',
        subtitle: '${user.pointsBalance} نقطة',
        tint: kTintGold,
        onTap: () => go(const PointsPage()),
      ),
      AccountMenuItem(
        icon: Icons.storefront_rounded,
        label: 'المحلات المتابَعة',
        tint: kTintSage,
        onTap: () => go(const FollowedVendorsPage()),
      ),
      AccountMenuItem(
        icon: Icons.calendar_month_rounded,
        label: 'مناسباتي',
        tint: kTintMauve,
        onTap: () => go(const BookingsPage()),
      ),
      AccountMenuItem(
        icon: Icons.favorite_rounded,
        label: 'المفضلة',
        tint: kTintRose,
        onTap: () => go(const FavoritesPage()),
      ),
      AccountMenuItem(
        icon: Icons.notifications_rounded,
        label: 'الإشعارات',
        tint: kTintGold,
        onTap: () => go(const NotificationsPage()),
      ),
    ];

    final prefs = <AccountMenuItem>[
      AccountMenuItem(
        icon: Icons.lock_rounded,
        label: 'تغيير كلمة المرور',
        tint: kTintTeal,
        onTap: () => showChangePasswordSheet(context),
      ),
      AccountMenuItem(
        icon: Icons.language_rounded,
        label: 'اللغة',
        tint: kTintTerracotta,
        onTap: () => showLanguageDialog(context),
      ),
    ];

    final support = <AccountMenuItem>[
      AccountMenuItem(
        icon: Icons.help_rounded,
        label: 'المساعدة والدعم',
        tint: kTintSage,
        onTap: () => showSupportSheet(context),
      ),
      AccountMenuItem(
        icon: Icons.info_rounded,
        label: 'حول التطبيق',
        tint: kTintMauve,
        onTap: () => showAppAboutSheet(context),
      ),
    ];

    final danger = <AccountMenuItem>[
      AccountMenuItem(
        icon: Icons.logout_rounded,
        label: 'تسجيل الخروج',
        tint: AppColors.discount,
        isDestructive: true,
        onTap: () => _confirmLogout(context),
      ),
      AccountMenuItem(
        icon: Icons.delete_forever_rounded,
        label: 'حذف الحساب',
        tint: AppColors.discount,
        isDestructive: true,
        onTap: () => _confirmDelete(context),
      ),
    ];

    // Each block slides in slightly after the previous one.
    var step = 0;
    Duration next() => Duration(milliseconds: 70 * step++);

    return ListView(
      // Bottom padding clears the shell's floating bottom nav bar (the outer
      // Scaffold uses extendBody: true), so the last items can scroll into view.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        FadeSlideIn(
          delay: next(),
          child: CustomerHeroCard(
            user: user,
            onEditProfile: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              );
              if (mounted) setState(() {});
            },
            onOpenPoints: () => go(const PointsPage()),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          delay: next(),
          child: CustomerQuickActions(
            actions: [
              CustomerQuickAction(
                icon: Icons.favorite_rounded,
                label: 'المفضلة',
                onTap: () => go(const FavoritesPage()),
              ),
              CustomerQuickAction(
                icon: Icons.calendar_month_rounded,
                label: 'مناسباتي',
                onTap: () => go(const BookingsPage()),
              ),
              CustomerQuickAction(
                icon: Icons.notifications_rounded,
                label: 'الإشعارات',
                badge: _unread,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsPage()),
                  );
                  _loadUnread();
                },
              ),
              CustomerQuickAction(
                icon: Icons.local_offer_rounded,
                label: 'العروض',
                onTap: () => go(const OffersPage()),
              ),
              CustomerQuickAction(
                icon: Icons.storefront_rounded,
                label: 'متابَعاتي',
                onTap: () => go(const FollowedVendorsPage()),
              ),
              CustomerQuickAction(
                icon: Icons.mail_rounded,
                label: 'دعواتي',
                onTap: () => go(const InvitationsPage()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(delay: next(), child: _AccountFacts(user: user)),
        if (manage.isNotEmpty) ...[
          const SizedBox(height: 22),
          FadeSlideIn(delay: next(), child: const AccountSectionLabel('الإدارة')),
          const SizedBox(height: 10),
          FadeSlideIn(delay: next(), child: AccountMenuGroup(items: manage)),
        ],
        const SizedBox(height: 22),
        FadeSlideIn(delay: next(), child: const AccountSectionLabel('حسابي')),
        const SizedBox(height: 10),
        FadeSlideIn(delay: next(), child: AccountMenuGroup(items: account)),
        const SizedBox(height: 22),
        FadeSlideIn(delay: next(), child: const AccountSectionLabel('الإعدادات')),
        const SizedBox(height: 10),
        FadeSlideIn(delay: next(), child: AccountMenuGroup(items: prefs)),
        const SizedBox(height: 22),
        FadeSlideIn(delay: next(), child: const AccountSectionLabel('الدعم')),
        const SizedBox(height: 10),
        FadeSlideIn(delay: next(), child: AccountMenuGroup(items: support)),
        const SizedBox(height: 22),
        FadeSlideIn(delay: next(), child: AccountMenuGroup(items: danger)),
        const SizedBox(height: 22),
        const PoweredByNeurex(),
        const SizedBox(height: 150),
      ],
    );
  }
}
/// Account facts the user can't edit: tier, join date and points at a glance.
class _AccountFacts extends StatelessWidget {
  const _AccountFacts({required this.user});
  final UserModel user;

  static String _joined(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('MMMM y', 'ar').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
      child: Row(
        children: [
          _Fact(
            icon: Icons.workspace_premium_rounded,
            label: 'تصنيف الحساب',
            value: user.tierLabel,
            tint: kTintGold,
          ),
          _FactDivider(),
          _Fact(
            icon: Icons.stars_rounded,
            label: 'رصيد النقاط',
            value: '${user.pointsBalance}',
            tint: kTintTeal,
          ),
          _FactDivider(),
          _Fact(
            icon: Icons.event_available_rounded,
            label: 'عضو منذ',
            value: _joined(user.createdAt),
            tint: kTintMauve,
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _FactDivider extends StatelessWidget {
  const _FactDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: AppColors.primaryLight.withValues(alpha: 0.7),
    );
  }
}
