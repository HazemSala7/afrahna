import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../admin/admin_dashboard_page.dart';
import '../auth/login_page.dart';
import '../bookings/bookings_page.dart';
import '../delegate/delegate_dashboard_page.dart';
import '../favorites/favorites_page.dart';
import '../notifications/notifications_page.dart';
import '../posts/vendor_posts_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return AppScaffold(
      appBar: const PinkAppBar(title: 'حسابي', showBack: false),
      body: !session.isSignedIn
          ? _GuestView()
          : _SignedInView(session: session),
    );
  }
}

class _GuestView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person_outline,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('سجّل الدخول لتجربة كاملة',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('احفظ المفضلة، تابع حجوزاتك، واستلم العروض',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                ),
                child: const Text('تسجيل الدخول'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInView extends StatelessWidget {
  const _SignedInView({required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final user = session.user!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE6EF), Color(0xFFFFD6E3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                child: Text(
                  user.name.isNotEmpty ? user.name.characters.first : '؟',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(
                      user.phone.isNotEmpty ? user.phone : (user.email ?? ''),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                      textDirection: TextDirection.ltr,
                    ),
                    if (user.role != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.role!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (user.isAdmin)
          _MenuTile(
            icon: Icons.admin_panel_settings,
            label: 'لوحة الإدارة',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
            ),
          ),
        if (user.isDelegate)
          _MenuTile(
            icon: Icons.badge,
            label: 'لوحة المندوب',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DelegateDashboardPage()),
            ),
          ),
        if (user.isVendor)
          _MenuTile(
            icon: Icons.dynamic_feed,
            label: 'محتواي (منشورات وريلز ودورات)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VendorPostsPage()),
            ),
          ),
        _MenuTile(
          icon: Icons.calendar_month,
          label: 'مناسباتي',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BookingsPage()),
          ),
        ),
        _MenuTile(
          icon: Icons.favorite_border,
          label: 'المفضلة',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FavoritesPage()),
          ),
        ),
        _MenuTile(
          icon: Icons.notifications_none,
          label: 'الإشعارات',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
        ),
        _MenuTile(
          icon: Icons.language,
          label: 'اللغة',
          onTap: () => _showLanguageDialog(context),
        ),
        _MenuTile(
          icon: Icons.help_outline,
          label: 'المساعدة والدعم',
          onTap: () => _showSupportSheet(context),
        ),
        _MenuTile(
          icon: Icons.info_outline,
          label: 'حول التطبيق',
          onTap: () => _showAboutSheet(context),
        ),
        const SizedBox(height: 16),
        _MenuTile(
          icon: Icons.logout,
          label: 'تسجيل الخروج',
          isDestructive: true,
          onTap: () async {
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
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('خروج'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await session.logout();
            }
          },
        ),
        _MenuTile(
          icon: Icons.delete_forever,
          label: 'حذف الحساب',
          isDestructive: true,
          onTap: () async {
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
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('حذف نهائي'),
                  ),
                ],
              ),
            );
            if (confirm != true) return;

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  const Center(child: CircularProgressIndicator()),
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
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Settings actions (Language / Support / About)
// ---------------------------------------------------------------------------

const String _kSupportPhone = '+972595679605';

Future<void> _openUri(Uri uri) async {
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

void _showLanguageDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('اللغة'),
      content: const Text(
          'التطبيق متوفّر باللغة العربية حاليًا، وسيتم دعم الإنجليزية قريبًا.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

void _showSupportSheet(BuildContext context) {
  final digits = _kSupportPhone.replaceAll(RegExp(r'\D'), '');
  final msg = Uri.encodeComponent('مرحباً، أحتاج للمساعدة في تطبيق أفراحنا');
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('المساعدة والدعم',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
            title: const Text('تواصل عبر واتساب'),
            onTap: () {
              Navigator.pop(context);
              _openUri(Uri.parse('https://wa.me/$digits?text=$msg'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.call, color: AppColors.primary),
            title: const Text('اتصال هاتفي'),
            subtitle: const Text(_kSupportPhone,
                textDirection: TextDirection.ltr),
            onTap: () {
              Navigator.pop(context);
              _openUri(Uri(scheme: 'tel', path: _kSupportPhone));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _showAboutSheet(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'أفراحنا',
    applicationVersion: 'الإصدار 1.8.0',
    applicationIcon: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset('assets/images/logo.png',
          width: 52, height: 52, errorBuilder: (_, _, _) => const Icon(
              Icons.celebration, size: 44, color: AppColors.primary)),
    ),
    children: const [
      SizedBox(height: 8),
      Text(
        'أفراحنا — دليلك الشامل لتجهيز المناسبات والأعراس: قاعات، خدمات، '
        'عروض خاصة، ريلز وأكثر. كل ما تحتاجه ليومك المميّز في مكان واحد.',
      ),
    ],
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDestructive ? Colors.red : AppColors.textDark,
            )),
        trailing:
            const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
