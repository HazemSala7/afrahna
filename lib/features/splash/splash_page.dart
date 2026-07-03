import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/animations.dart';
import '../auth/login_page.dart';
import '../home/home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _logoCtrl,
    curve: Curves.elasticOut,
  );
  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _logoCtrl,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );

  late final AnimationController _glowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _logoCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = context.read<SessionController>();
      await Future.wait<dynamic>([
        session.bootstrap(),
        Future<void>.delayed(const Duration(milliseconds: 2100)),
      ]);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, a, _) => FadeTransition(
            opacity: a,
            child:
                session.isSignedIn ? const HomePage() : const LoginPage(),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, _) {
              final t = Curves.easeInOut.transform(_glowCtrl.value);
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + t * 0.4, -1),
                    end: Alignment(1, 1 - t * 0.4),
                    colors: const [
                      Color(0xFFFAF3EC),
                      Color(0xFFF0DDC8),
                      Color(0xFFEBD7BF),
                    ],
                  ),
                ),
              );
            },
          ),
          const Positioned.fill(child: SparkleOverlay(count: 36)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_logoCtrl, _glowCtrl]),
                  builder: (_, _) {
                    final pulse = 1 +
                        Curves.easeInOut.transform(_glowCtrl.value) * 0.04;
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value * pulse,
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.35),
                                blurRadius: 36 + 14 * _glowCtrl.value,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Image.asset(AppAssets.logo,
                                fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 700),
                  child: const Text(
                    'كل مناسباتك في مكان واحد',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 950),
                  child: Text(
                    '✨ من أعراس وحفلات إلى تنسيق وتصوير ✨',
                    style: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 1200),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.4,
                    ),
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
