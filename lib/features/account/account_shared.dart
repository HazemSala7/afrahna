import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../core/utils/link_launcher.dart';

// ===========================================================================
// ACCOUNT MENU — grouped, tinted rows shared by the customer and the
// advertiser (vendor) account screens.
// ===========================================================================

// Warm accent tints so each row reads distinctly instead of one flat brown.
const Color kTintTeal = Color(0xFF5FA9A0);
const Color kTintGold = Color(0xFFCB9A3E);
const Color kTintTerracotta = Color(0xFFDD8A6A);
const Color kTintSage = Color(0xFF8FA97E);
const Color kTintMauve = Color(0xFFAF8FC4);
const Color kTintRose = Color(0xFFD98CA0);

/// One row in the account menu.
class AccountMenuItem {
  const AccountMenuItem({
    required this.icon,
    required this.label,
    required this.tint,
    this.subtitle,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final Color tint;

  /// Optional helper line under the label (advertiser rows use it).
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;
}

/// Small muted heading above each menu group.
class AccountSectionLabel extends StatelessWidget {
  const AccountSectionLabel(this.text, {super.key});
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
class AccountMenuGroup extends StatelessWidget {
  const AccountMenuGroup({super.key, required this.items});
  final List<AccountMenuItem> items;

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
            _AccountMenuTile(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  const _AccountMenuTile({required this.item});
  final AccountMenuItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.tint;
    final hasSub = item.subtitle != null && item.subtitle!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: hasSub ? 11 : 12,
          ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color:
                            item.isDestructive ? color : AppColors.textDark,
                      ),
                    ),
                    if (hasSub) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.25,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
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

/// Branded footer credit — taps through to Neurex on WhatsApp.
class PoweredByNeurex extends StatelessWidget {
  const PoweredByNeurex({super.key});

  static const _phone = '972595324689';

  Future<void> _contact() async {
    final msg = Uri.encodeComponent(
        'مرحباً Neurex 👋، تواصلت معكم من تطبيق أفراحنا.');
    await openAccountUri(Uri.parse('https://wa.me/$_phone?text=$msg'));
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
// Settings actions (Language / Support / About / Password)
// ---------------------------------------------------------------------------

const String kSupportPhone = '+972599252493';

Future<void> openAccountUri(Uri uri) async {
  await openExternal(uri);
}

void showLanguageDialog(BuildContext context) {
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

void showSupportSheet(BuildContext context) {
  final digits = kSupportPhone.replaceAll(RegExp(r'\D'), '');
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
              openAccountUri(Uri.parse('https://wa.me/$digits?text=$msg'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.call, color: AppColors.primary),
            title: const Text('اتصال هاتفي'),
            subtitle:
                const Text(kSupportPhone, textDirection: TextDirection.ltr),
            onTap: () {
              Navigator.pop(context);
              openAccountUri(Uri(scheme: 'tel', path: kSupportPhone));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void showAppAboutSheet(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'أفراحنا',
    applicationVersion: 'الإصدار 1.8.0',
    applicationIcon: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset('assets/images/logo.png',
          width: 52,
          height: 52,
          errorBuilder: (_, _, _) => const Icon(Icons.celebration,
              size: 44, color: AppColors.primary)),
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

void showChangePasswordSheet(BuildContext context) {
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
      validator:
          validator ?? (v) => (v == null || v.isEmpty) ? 'حقل مطلوب' : null,
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
