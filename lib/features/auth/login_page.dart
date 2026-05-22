import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final _phone = TextEditingController(text: '0599000000');
  final _password = TextEditingController(text: 'password');
  bool _loading = false;
  bool _obscure = true;
  bool _remember = true;

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
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('سيتم تفعيل هذه الخاصية قريباً'),
                                              backgroundColor: AppColors.primaryDark,
                                            ),
                                          );
                                        },
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
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'ليس لديك حساب؟ ',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const RegisterPage(),
                                            ),
                                          ),
                                          child: const Text(
                                            'أنشئ حساب جديد',
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
