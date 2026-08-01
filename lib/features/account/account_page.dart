import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_widgets.dart';
import '../admin/admin_dashboard_page.dart';
import '../auth/login_page.dart';
import '../auth/register_page.dart';
import '../bookings/bookings_page.dart';
import '../delegate/delegate_dashboard_page.dart';
import '../favorites/favorites_page.dart';
import '../notifications/notifications_page.dart';
import '../points/points_page.dart';
import '../posts/vendor_posts_page.dart';
import 'vendor_statement_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return AppScaffold(
      appBar: const PinkAppBar(title: 'حسابي', showBack: false),
      body: !session.isSignedIn
          ? const _GuestView()
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

class _SignedInView extends StatelessWidget {
  const _SignedInView({required this.session});
  final SessionController session;

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
    final manage = <_MenuItem>[
      if (user.isAdmin)
        _MenuItem(
          icon: Icons.admin_panel_settings_rounded,
          label: 'لوحة الإدارة',
          tint: _kTintTeal,
          onTap: () => go(const AdminDashboardPage()),
        ),
      if (user.isDelegate)
        _MenuItem(
          icon: Icons.badge_rounded,
          label: 'لوحة المندوب',
          tint: _kTintGold,
          onTap: () => go(const DelegateDashboardPage()),
        ),
      if (user.isVendor)
        _MenuItem(
          icon: Icons.dynamic_feed_rounded,
          label: 'محتواي (منشورات وريلز)',
          tint: _kTintTerracotta,
          onTap: () => go(const VendorPostsPage()),
        ),
      if (user.isVendor)
        _MenuItem(
          icon: Icons.receipt_long_rounded,
          label: 'كشف حساب (الاشتراكات والدفعات)',
          tint: _kTintSage,
          onTap: () => go(const VendorStatementPage()),
        ),
    ];

    final account = <_MenuItem>[
      _MenuItem(
        icon: Icons.stars_rounded,
        label: 'نقاطي ومكافآتي',
        tint: _kTintGold,
        onTap: () => go(const PointsPage()),
      ),
      _MenuItem(
        icon: Icons.calendar_month_rounded,
        label: 'مناسباتي',
        tint: _kTintMauve,
        onTap: () => go(const BookingsPage()),
      ),
      _MenuItem(
        icon: Icons.favorite_rounded,
        label: 'المفضلة',
        tint: _kTintRose,
        onTap: () => go(const FavoritesPage()),
      ),
      _MenuItem(
        icon: Icons.notifications_rounded,
        label: 'الإشعارات',
        tint: _kTintGold,
        onTap: () => go(const NotificationsPage()),
      ),
    ];

    final prefs = <_MenuItem>[
      _MenuItem(
        icon: Icons.lock_rounded,
        label: 'تغيير كلمة المرور',
        tint: _kTintTeal,
        onTap: () => _showChangePasswordSheet(context),
      ),
      _MenuItem(
        icon: Icons.language_rounded,
        label: 'اللغة',
        tint: _kTintTerracotta,
        onTap: () => _showLanguageDialog(context),
      ),
    ];

    final support = <_MenuItem>[
      _MenuItem(
        icon: Icons.help_rounded,
        label: 'المساعدة والدعم',
        tint: _kTintSage,
        onTap: () => _showSupportSheet(context),
      ),
      _MenuItem(
        icon: Icons.info_rounded,
        label: 'حول التطبيق',
        tint: _kTintMauve,
        onTap: () => _showAboutSheet(context),
      ),
    ];

    final danger = <_MenuItem>[
      _MenuItem(
        icon: Icons.logout_rounded,
        label: 'تسجيل الخروج',
        tint: AppColors.discount,
        isDestructive: true,
        onTap: () => _confirmLogout(context),
      ),
      _MenuItem(
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
          child: _ProfileHeader(
            name: user.name,
            subtitle: user.phone.isNotEmpty ? user.phone : (user.email ?? ''),
            role: user.role,
          ),
        ),
        if (manage.isNotEmpty) ...[
          const SizedBox(height: 22),
          FadeSlideIn(delay: next(), child: const _SectionLabel('الإدارة')),
          const SizedBox(height: 10),
          FadeSlideIn(delay: next(), child: _MenuGroup(items: manage)),
        ],
        const SizedBox(height: 22),
        FadeSlideIn(delay: next(), child: const _SectionLabel('حسابي')),
        const SizedBox(height: 10),
        FadeSlideIn(delay: next(), child: _MenuGroup(items: account)),
        const SizedBox(height: 22),
        FadeSlideIn(delay: next(), child: const _SectionLabel('الإعدادات')),
        const SizedBox(height: 10),
        FadeSlideIn(delay: next(), child: _MenuGroup(items: prefs)),
        const SizedBox(height: 22),
        FadeSlideIn(delay: next(), child: const _SectionLabel('الدعم')),
        const SizedBox(height: 10),
        FadeSlideIn(delay: next(), child: _MenuGroup(items: support)),
        const SizedBox(height: 22),
        FadeSlideIn(delay: next(), child: _MenuGroup(items: danger)),
        const SizedBox(height: 22),
        const _PoweredByNeurex(),
        const SizedBox(height: 150),
      ],
    );
  }
}

/// Branded footer credit — taps through to Neurex on WhatsApp.
class _PoweredByNeurex extends StatelessWidget {
  const _PoweredByNeurex();

  static const _phone = '972595324689';

  Future<void> _contact() async {
    final msg = Uri.encodeComponent(
        'مرحباً Neurex 👋، تواصلت معكم من تطبيق أفراحنا.');
    await _openUri(Uri.parse('https://wa.me/$_phone?text=$msg'));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Made with love"
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'صُنع بكل ',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text('❤️', style: TextStyle(fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 8),
          // Powered by Neurex — tappable pill.
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _contact,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6D4AFF), Color(0xFF9C6BFF)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6D4AFF).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 15),
                    SizedBox(width: 7),
                    Text(
                      'Powered by ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Neurex',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'تواصل معنا عبر واتساب',
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings actions (Language / Support / About)
// ---------------------------------------------------------------------------

const String _kSupportPhone = '+972599252493';

Future<void> _openUri(Uri uri) async {
  await openExternal(uri);
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

void _showChangePasswordSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

/// Bottom sheet letting the signed-in user (any role) change their own
/// password: current + new + confirm, with show/hide toggles.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService().changePassword(
        currentPassword: _current.text,
        newPassword: _new.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور ✓')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const Text('تغيير كلمة المرور',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 16),
              _field(_current, 'كلمة المرور الحالية'),
              const SizedBox(height: 12),
              _field(_new, 'كلمة المرور الجديدة',
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'الحد الأدنى 6 أحرف' : null),
              const SizedBox(height: 12),
              _field(_confirm, 'تأكيد كلمة المرور الجديدة',
                  validator: (v) =>
                      v != _new.text ? 'كلمتا المرور غير متطابقتين' : null),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      obscureText: _obscure,
      validator: validator ??
          (v) => (v == null || v.isEmpty) ? 'حقل مطلوب' : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscure
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

// ===========================================================================
// ACCOUNT MENU — grouped, tinted rows
// ===========================================================================

// Warm accent tints so each row reads distinctly instead of one flat brown.
const Color _kTintTeal = Color(0xFF5FA9A0);
const Color _kTintGold = Color(0xFFCB9A3E);
const Color _kTintTerracotta = Color(0xFFDD8A6A);
const Color _kTintSage = Color(0xFF8FA97E);
const Color _kTintMauve = Color(0xFFAF8FC4);
const Color _kTintRose = Color(0xFFD98CA0);

/// One row in the account menu.
class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.tint,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback? onTap;
  final bool isDestructive;
}

/// Small muted heading above each menu group.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// A rounded card holding related rows, separated by hairline dividers.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
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
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 66, end: 14),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.primaryLight.withValues(alpha: 0.55),
                ),
              ),
            _MenuTile(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item});
  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.tint;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: item.isDestructive ? color : AppColors.textDark,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: item.isDestructive
                    ? color.withValues(alpha: 0.7)
                    : AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient profile card at the top of the account page.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    this.role,
  });

  final String name;
  final String subtitle;
  final String? role;

  static String _roleLabel(String r) {
    switch (r.toLowerCase()) {
      case 'vendor':
        return 'مزوّد خدمة';
      case 'admin':
        return 'مدير';
      case 'delegate':
        return 'مندوب';
      case 'customer':
      case 'user':
        return 'عميل';
      default:
        return r;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first : '؟';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -24,
            bottom: -34,
            child: Icon(
              Icons.celebration_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            top: 14,
            left: 26,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 15,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  child: CircleAvatar(
                    radius: 33,
                    backgroundColor: Colors.white,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (role != null && role!.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _roleLabel(role!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
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
