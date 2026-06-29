import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../home/home_page.dart';
import 'auth_shared.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _agree = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يجب الموافقة على الشروط والأحكام'),
        backgroundColor: AppColors.primaryDark,
      ));
      return;
    }
    setState(() => _loading = true);
    final session = context.read<SessionController>();
    final ok = await session.register(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      password: _password.text,
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      // Clear the auth stack AND swap in HomePage instantly. A normal
      // MaterialPageRoute here would slide in over an empty (removed) stack,
      // briefly exposing a black gap behind the transition — so use a
      // zero-duration route that paints the page from the first frame.
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => const HomePage(),
        ),
        (_) => false,
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
            Expanded(child: Text(session.error ?? 'فشل التسجيل')),
          ],
        ),
      ));
    }
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
                        _TopBar(onBack: () => Navigator.of(context).maybePop()),
                        const SizedBox(height: 6),
                        const AuthHeader(
                          title: 'أنشئ حسابك',
                          subtitle: 'انضمّ لعائلة أفراحنا واحجز خدماتك بسهولة',
                          icon: Icons.celebration_rounded,
                        ),
                        const SizedBox(height: 22),
                        Expanded(
                          child: AuthCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'إنشاء حساب جديد',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'املأ بياناتك للبدء',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  AuthField(
                                    controller: _name,
                                    label: 'الاسم الكامل',
                                    icon: Icons.person_outline_rounded,
                                    validator: (v) => (v == null || v.trim().length < 2)
                                        ? 'الاسم مطلوب'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  AuthField(
                                    controller: _phone,
                                    label: 'رقم الجوال',
                                    icon: Icons.phone_iphone_rounded,
                                    keyboardType: TextInputType.phone,
                                    textDirection: TextDirection.ltr,
                                    validator: (v) {
                                      final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
                                      if (s.length < 7) return 'رقم الجوال غير صحيح';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  AuthField(
                                    controller: _email,
                                    label: 'البريد الإلكتروني (اختياري)',
                                    icon: Icons.alternate_email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return null;
                                      if (!s.contains('@')) return 'بريد غير صحيح';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  AuthField(
                                    controller: _password,
                                    label: 'كلمة المرور',
                                    icon: Icons.lock_outline_rounded,
                                    obscure: _obscure1,
                                    suffix: IconButton(
                                      splashRadius: 22,
                                      icon: Icon(
                                        _obscure1
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: AppColors.textMuted,
                                      ),
                                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                                    ),
                                    validator: (v) => (v == null || v.length < 6)
                                        ? 'كلمة المرور قصيرة (6 خانات على الأقل)'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  AuthField(
                                    controller: _confirm,
                                    label: 'تأكيد كلمة المرور',
                                    icon: Icons.lock_reset_rounded,
                                    obscure: _obscure2,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    suffix: IconButton(
                                      splashRadius: 22,
                                      icon: Icon(
                                        _obscure2
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: AppColors.textMuted,
                                      ),
                                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                                    ),
                                    validator: (v) {
                                      if (v != _password.text) return 'كلمتا المرور غير متطابقتين';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Transform.scale(
                                        scale: 0.95,
                                        child: Checkbox(
                                          value: _agree,
                                          onChanged: (v) => setState(() => _agree = v ?? false),
                                          activeColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: RichText(
                                          text: const TextSpan(
                                            style: TextStyle(
                                              color: AppColors.textDark,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            children: [
                                              TextSpan(text: 'أوافق على '),
                                              TextSpan(
                                                text: 'الشروط والأحكام',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              TextSpan(text: ' و '),
                                              TextSpan(
                                                text: 'سياسة الخصوصية',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  AuthPrimaryButton(
                                    label: 'إنشاء الحساب',
                                    icon: Icons.person_add_alt_1_rounded,
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
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'لديك حساب مسبقاً؟ ',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(builder: (_) => const LoginPage()),
                                          ),
                                          child: const Text(
                                            'تسجيل الدخول',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w900,
                                              decoration: TextDecoration.underline,
                                              decorationColor: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
