import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/app_widgets.dart';
import '../admin/admin_dashboard_page.dart';
import '../auth/login_page.dart';
import '../auth/register_page.dart';
import '../bookings/bookings_page.dart';
import '../delegate/delegate_dashboard_page.dart';
import '../favorites/favorites_page.dart';
import '../notifications/notifications_page.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = session.user!;
    return ListView(
      // Bottom padding clears the shell's floating bottom nav bar (the outer
      // Scaffold uses extendBody: true), so the last items can scroll into view.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
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
            label: 'محتواي (منشورات وريلز)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VendorPostsPage()),
            ),
          ),
        if (user.isVendor)
          _MenuTile(
            icon: Icons.receipt_long_outlined,
            label: 'كشف حساب (الاشتراكات والدفعات)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VendorStatementPage()),
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
          icon: Icons.lock_outline,
          label: 'تغيير كلمة المرور',
          onTap: () => _showChangePasswordSheet(context),
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
          },
        ),
        const SizedBox(height: 20),
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

const String _kSupportPhone = '+972595679605';

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
