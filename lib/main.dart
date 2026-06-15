import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/services/local_favorites.dart';
import 'core/services/push_notifications.dart';
import 'core/state/session.dart';
import 'core/theme.dart';
import 'features/splash/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  await LocalFavorites.instance.load();
  await PushNotificationService.instance.init();
  runApp(const AfrahnaApp());
}

class AfrahnaApp extends StatelessWidget {
  const AfrahnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionController()),
        ChangeNotifierProvider<LocalFavorites>.value(
          value: LocalFavorites.instance,
        ),
      ],
      child: MaterialApp(
        title: 'افراحنا',
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
