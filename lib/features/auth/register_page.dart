import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/accounts_services.dart';
import '../../core/services/referral_storage.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/cosmos.dart';
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
  final _referral = TextEditingController();
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _agree = true;

  /// What the server said was wrong with a field, shown under that field
  /// and cleared the moment the field is edited again.
  final _serverErrors = <String, String>{};
  static const _fieldOrder = [
    'name', 'phone', 'email', 'referral_code', 'password',
  ];
  final _fieldKeys = {for (final f in _fieldOrder) f: GlobalKey()};
  final _focus = {for (final f in _fieldOrder) f: FocusNode()};

  String? _serverError(String field) => _serverErrors[field];

  void _clearServerError(String field) {
    if (_serverErrors.remove(field) != null) setState(() {});
  }

  /// Puts the server's complaints under their fields, scrolls the first one
  /// into view and gives it the cursor. False when none of them belongs to
  /// a field on this form, so the caller falls back to a banner.
  bool _showServerErrors(Map<String, String> errors) {
    final mine = <String, String>{};
    for (final e in errors.entries) {
      // The confirmation rule reports on the password itself.
      final key = e.key == 'password_confirmation' ? 'password' : e.key;
      if (_fieldOrder.contains(key)) mine[key] = e.value;
    }
    if (mine.isEmpty) return false;
    setState(() => _serverErrors..clear()..addAll(mine));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _formKey.currentState?.validate();
      final first = _fieldOrder.firstWhere(mine.containsKey);
      final ctx = _fieldKeys[first]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.2,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
      _focus[first]?.requestFocus();
    });
    return true;
  }

  /// True when the code was filled in from an invite link rather than typed.
  bool _referralFromLink = false;

  @override
  void initState() {
    super.initState();
    _loadPendingReferral();
  }

  /// Who the waiting invite code belongs to, once the server has confirmed
  /// it — shown under the field so the friend sees they were invited rather
  /// than reading a bare code.
  String? _inviterName;

  /// Pre-fills the invite code, from the tapped link or from the clipboard.
  ///
  /// The link is only captured when the app was already installed. A friend
  /// who taps the link, installs, and opens the app arrives with nothing —
  /// the invite page copies the code for exactly this reason, and until now
  /// nobody read it, so the inviter lost the point unless the friend typed
  /// the code by hand.
  Future<void> _loadPendingReferral() async {
    var code = await ReferralStorage.read();
    code ??= await _codeFromClipboard();
    if (code == null || !mounted || _referral.text.trim().isNotEmpty) return;

    setState(() {
      _referral.text = code!;
      _referralFromLink = true;
    });

    final name = await ReferralService().ownerName(code);
    if (mounted && name != null) setState(() => _inviterName = name);
  }

  /// A code sitting on the clipboard, if that is what it is.
  ///
  /// Only accepted when it looks like nothing else: the shape of a code and
  /// no spaces. Anything a friend happens to have copied — a phone number, a
  /// sentence — is left alone.
  Future<String?> _codeFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = (data?.text ?? '').trim();
      if (raw.isEmpty || raw.length > 16 || raw.contains(RegExp(r'\s'))) return null;
      final code = ReferralStorage.normalize(raw);
      if (code == null || code != raw.toUpperCase()) return null;
      return await ReferralService().ownerName(code) == null ? null : code;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _referral.dispose();
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يجب الموافقة على الشروط والأحكام'),
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
      referralCode: _referral.text.trim().isEmpty ? null : _referral.text.trim(),
    );
    // The code has now been handed to the server, so it must not be reused on
    // a second account from the same device.
    if (ok) await ReferralStorage.clear();
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
          // Hand-built, so it brings its own living sky.
          pageBuilder: (_, _, _) => const CosmicPage(child: HomePage()),
        ),
        (_) => false,
      );
    } else if (!_showServerErrors(session.fieldErrors)) {
      // Nothing the form can point at: say it in a banner.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.discount),
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
                                    key: _fieldKeys['name'],
                                    focusNode: _focus['name'],
                                    onChanged: (_) => _clearServerError('name'),
                                    controller: _name,
                                    label: 'الاسم الكامل',
                                    icon: Icons.person_outline_rounded,
                                    validator: (v) =>
                                        _serverError('name') ??
                                        ((v == null || v.trim().length < 2)
                                            ? 'الاسم مطلوب'
                                            : null),
                                  ),
                                  const SizedBox(height: 12),
                                  AuthField(
                                    key: _fieldKeys['phone'],
                                    focusNode: _focus['phone'],
                                    onChanged: (_) => _clearServerError('phone'),
                                    controller: _phone,
                                    label: 'رقم الجوال',
                                    icon: Icons.phone_iphone_rounded,
                                    keyboardType: TextInputType.phone,
                                    validator: (v) {
                                      final fromServer = _serverError('phone');
                                      if (fromServer != null) return fromServer;
                                      final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
                                      if (s.length < 7) return 'رقم الجوال غير صحيح';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  AuthField(
                                    key: _fieldKeys['email'],
                                    focusNode: _focus['email'],
                                    onChanged: (_) => _clearServerError('email'),
                                    controller: _email,
                                    label: 'البريد الإلكتروني (اختياري)',
                                    icon: Icons.alternate_email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      final fromServer = _serverError('email');
                                      if (fromServer != null) return fromServer;
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return null;
                                      if (!s.contains('@')) return 'بريد غير صحيح';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  AuthField(
                                    key: _fieldKeys['referral_code'],
                                    focusNode: _focus['referral_code'],
                                    onChanged: (_) =>
                                        _clearServerError('referral_code'),
                                    controller: _referral,
                                    label: 'كود دعوة صديق (اختياري)',
                                    icon: Icons.group_add_rounded,
                                    textDirection: TextDirection.ltr,
                                    validator: (_) => _serverError('referral_code'),
                                  ),
                                  if (_referralFromLink)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6, right: 6),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded,
                                              size: 15, color: Color(0xFF1B9C5A)),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              _inviterName != null
                                                  ? 'دعاك $_inviterName إلى أفراحنا 🎉'
                                                  : 'تم تعبئة كود الدعوة تلقائيًا',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1B9C5A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  AuthField(
                                    key: _fieldKeys['password'],
                                    focusNode: _focus['password'],
                                    onChanged: (_) => _clearServerError('password'),
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
                                    validator: (v) =>
                                        _serverError('password') ??
                                        ((v == null || v.length < 3)
                                            ? 'كلمة المرور قصيرة (3 خانات على الأقل)'
                                            : null),
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
                                        child: const Text.rich(
                                          TextSpan(
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
