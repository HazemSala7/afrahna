import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/services/local_favorites.dart';
import 'core/services/notification_router.dart';
import 'core/services/push_notifications.dart';
import 'core/state/cart.dart';
import 'core/state/session.dart';
import 'core/theme.dart';
import 'features/auth/register_page.dart';
import 'features/invitation/invitation_view_page.dart';
import 'features/splash/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  await LocalFavorites.instance.load();
  await PushNotificationService.instance.init();
  runApp(const AfrahnaApp());

  // A tapped invite link must land the friend on sign-up — the inviter's point
  // is only credited when an account is actually created. Signed-in users keep
  // browsing; the code simply stays stored and unused.
  NotificationRouter.onInvite = (code) {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    final ctx = nav.context;
    if (ctx.read<SessionController>().isSignedIn) return;
    nav.push(MaterialPageRoute(builder: (_) => const RegisterPage()));
  };

  // An invitation link opens the invitation itself, for anyone who taps it —
  // guest or member. The code in the URL is the capability to view it.
  NotificationRouter.onInvitation = (code) {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => InvitationViewPage(code: code),
    ));
  };

  // Start listening for share/deep links after the app is running.
  unawaited(initDeepLinks());
}

class AfrahnaApp extends StatelessWidget {
  const AfrahnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionController()),
        // Shared cart: one shop at a time, restored from the last session.
        ChangeNotifierProvider(create: (_) => CartController()..load()),
        ChangeNotifierProvider<LocalFavorites>.value(
          value: LocalFavorites.instance,
        ),
      ],
      child: MaterialApp(
        title: 'افراحنا',
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        scrollBehavior: const _NoScrollbarBehavior(),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: const SplashPage(),
      ),
    );
  }
}

/// Hides the always-visible scrollbar (which renders as a dark bar on the
/// left edge in RTL on web/desktop) while keeping smooth scrolling.
class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
