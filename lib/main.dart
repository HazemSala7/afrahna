import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'widgets/cosmos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The typefaces ship inside the app rather than being fetched, so their
  // licences travel with them. Amiri and Aref Ruqaa are the invitation's
  // display faces: a guest opens that from a link, often on a weak
  // connection, and it is the last screen that should be waiting on a
  // download to show the couple's names in the right lettering.
  LicenseRegistry.addLicense(() async* {
    for (final face in const ['tajawal', 'reemkufi', 'amiri', 'arefruqaa']) {
      final text =
          await rootBundle.loadString('assets/google_fonts/OFL-$face.txt');
      yield LicenseEntryWithLineBreaks(const ['google_fonts'], text);
    }
  });
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
        theme: AppTheme.cosmic(),
        color: AppColors.background,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        scrollBehavior: const _NoScrollbarBehavior(),
        // Every page paints its own living sky (see CosmicPage). This still,
        // painted-once copy sits behind the navigator for the few routes built
        // by hand rather than through the theme, so none of them can ever show
        // an empty black frame.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.overlay,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Stack(
              fit: StackFit.expand,
              children: [const CosmicBackdrop(), child!],
            ),
          ),
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
