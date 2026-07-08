import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/auth_storage.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../home/home_page.dart';
import 'auth_shared.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    _loadLastLogin();
  }

  Future<void> _loadLastLogin() async {
    final last = await AuthStorage.instance.readLastLogin();
    if (last != null && mounted) {
      setState(() {
        _phone.text = last.phone;
        _password.text = last.password;
      });
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final session = context.read<SessionController>();
    final ok = await session.login(_phone.text.trim(), _password.text);
    if (ok) {
      // Remember (or forget) the last credentials for next launch.
      if (_remember) {
        await AuthStorage.instance
            .writeLastLogin(_phone.text.trim(), _password.text);
      } else {
        await AuthStorage.instance.clearLastLogin();
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(session.error ?? 'فشل تسجيل الدخول')),
          ],
        ),
      ));
    }
  }

  /// رقم الدعم لاستعادة كلمة المرور.
  static const String _supportPhone = '+972595679605';

  Future<void> _openUri(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          content: Text('تعذّر فتح التطبيق المطلوب'),
        ),
      );
    }
  }

  void _forgotPassword() {
    final phone = _phone.text.trim();
    final digits = _supportPhone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent(
      'مرحباً، نسيت كلمة المرور الخاصة بحسابي في تطبيق أفراحنا'
      '${phone.isNotEmpty ? '\nرقم الجوال المسجّل: $phone' : ''}'
      '\nأرجو مساعدتي في إعادة تعيين كلمة المرور.',
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
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
            const Icon(Icons.lock_reset_rounded,
                color: AppColors.primary, size: 40),
            const SizedBox(height: 10),
            const Text(
              'استعادة كلمة المرور',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'تواصل مع فريق الدعم لإعادة تعيين كلمة المرور الخاصة بك.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _openUri(Uri.parse('https://wa.me/$digits?text=$msg'));
              },
              icon: const Icon(Icons.chat_rounded),
              label: const Text('تواصل عبر واتساب',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _openUri(Uri(scheme: 'tel', path: _supportPhone));
              },
              icon: const Icon(Icons.call_rounded),
              label: const Text('اتصال هاتفي',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 28),
                        const AuthHeader(
                          title: 'أهلاً بعودتك',
                          subtitle: 'سجّل دخولك لمتابعة تخطيط فرحك',
                        ),
                        const SizedBox(height: 28),
                        Expanded(
                          child: AuthCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'تسجيل الدخول',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'أدخل بياناتك للوصول إلى حسابك',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  AuthField(
                                    controller: _phone,
                                    label: 'رقم الجوال',
                                    icon: Icons.phone_iphone_rounded,
                                    keyboardType: TextInputType.phone,
                                    textDirection: TextDirection.ltr,
                                    gradient: AuthField.rtlFill,
                                    validator: (v) {
                                      final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
                                      if (s.length < 7) return 'رقم الجوال غير صحيح';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  AuthField(
                                    controller: _password,
                                    label: 'كلمة المرور',
                                    icon: Icons.lock_outline_rounded,
                                    gradient: AuthField.rtlFill,
                                    obscure: _obscure,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    suffix: IconButton(
                                      splashRadius: 22,
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: AppColors.textMuted,
                                      ),
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.length < 6) ? 'كلمة المرور قصيرة' : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Transform.scale(
                                        scale: 0.95,
                                        child: Checkbox(
                                          value: _remember,
                                          onChanged: (v) => setState(() => _remember = v ?? true),
                                          activeColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                      const Text(
                                        'تذكّرني',
                                        style: TextStyle(
                                          color: AppColors.textDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: _forgotPassword,
                                        child: const Text(
                                          'نسيت كلمة المرور؟',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  AuthPrimaryButton(
                                    label: 'تسجيل الدخول',
                                    icon: Icons.login_rounded,
                                    loading: _loading,
                                    onPressed: _submit,
                                  ),
                                  const SizedBox(height: 16),
                                  const AuthOrDivider(),
                                  const SizedBox(height: 16),
                                  AuthGhostButton(
                                    label: 'تصفّح كزائر',
                                    icon: Icons.explore_outlined,
                                    onPressed: () => Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (_) => const HomePage()),
                                    ),
                                  ),
                                  const Spacer(),
                                  // Create-account banner — a tidy hook to sign up.
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterPage(),
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFF6E6D3),
                                            Color(0xFFFBF4EB)
                                          ],
                                          begin: Alignment.centerRight,
                                          end: Alignment.centerLeft,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.25)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                                Icons.card_giftcard_rounded,
                                                color: AppColors.primaryDark,
                                                size: 22),
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text('ليس لديك حساب؟',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 13.5,
                                                        color:
                                                            AppColors.textDark)),
                                                SizedBox(height: 2),
                                                Text(
                                                    'أنشئ حسابك واستمتع بالعروض الحصرية',
                                                    style: TextStyle(
                                                        color:
                                                            AppColors.textMuted,
                                                        fontSize: 11.5)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 9),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFD4A373),
                                                  Color(0xFF8B5A3C)
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text('أنشئ حساب',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 13)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
