import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/core/models/models.dart';
import 'package:afrahna/core/services/local_favorites.dart';
import 'package:afrahna/core/state/cart.dart';
import 'package:afrahna/core/state/session.dart';
import 'package:afrahna/core/theme.dart';
import 'package:afrahna/widgets/cosmos.dart';

/// What the cosmic render tests share: a canned API, the app shell as
/// `main.dart` builds it, and a camera that waits for fonts and animations.

/// Answers each request from the first route whose pattern matches the whole
/// path; anything unmatched gets `[]`, which the services read as "nothing".
class CannedApi implements HttpClientAdapter {
  CannedApi(Map<String, Object> routes)
      : _routes = [
          for (final e in routes.entries) (RegExp('^${e.key}\$'), e.value),
        ];
  final List<(RegExp, Object)> _routes;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    Object body = const <Object>[];
    for (final (pattern, value) in _routes) {
      if (pattern.hasMatch(o.path)) {
        body = value;
        break;
      }
    }
    // A route may answer with an error: a map carrying `__status` is sent
    // with that status, the key removed, so a test can serve a 422.
    var status = 200;
    if (body is Map && body.containsKey('__status')) {
      final m = Map<String, Object?>.from(body);
      status = (m.remove('__status') as num).toInt();
      body = m;
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void serve(Map<String, Object> routes) =>
    ApiClient.instance.dio.httpClientAdapter = CannedApi(routes);

/// A session that is signed in without going through the network.
class SignedIn extends SessionController {
  SignedIn([UserModel? user]) {
    if (user != null) setUser(user);
  }

  @override
  bool get isSignedIn => true;
}

Widget cosmicApp(Widget home, {SessionController? session}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>(
            create: (_) => session ?? SessionController()),
        ChangeNotifierProvider(create: (_) => CartController()),
        ChangeNotifierProvider<LocalFavorites>.value(
            value: LocalFavorites.instance),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.cosmic(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
            fit: StackFit.expand,
            children: [const CosmicBackdrop(), child!],
          ),
        ),
        home: home,
      ),
    );

/// Renders [app] and checks it against `goldens/cosmic/[name].png`.
///
/// [varies] marks a screen that is not the same from one run to the next —
/// it prints dates relative to today (due dates, «قبل ٩ س», this month's
/// calendar) or shuffles what it shows on each load, as home does. It is
/// written on `--update-goldens` for review but not compared otherwise.
Future<void> shoot(
  WidgetTester tester,
  Widget app,
  String name, {
  Size size = const Size(1080, 2340),
  Duration settle = const Duration(milliseconds: 2750),
  bool varies = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  // Fonts come from assets through real I/O, which only completes outside the
  // fake clock.
  await tester.runAsync(() => GoogleFonts.pendingFonts());
  const step = Duration(milliseconds: 250);
  for (var left = settle; left > Duration.zero; left -= step) {
    await tester.pump(left < step ? left : step);
    if (left == settle) await tester.runAsync(() => GoogleFonts.pendingFonts());
  }

  if (!varies || autoUpdateGoldenFiles) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/cosmic/$name.png'),
    );
  }

  // Leave nothing running: the sky, the sliders and the auto-scrollers all
  // hold timers or tickers until their widgets are gone.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 8));
}

/// The app shell's `builder`, for tests that build their own [MaterialApp]:
/// right to left, over the still sky.
Widget cosmicBuilder(BuildContext context, Widget? child) => Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        fit: StackFit.expand,
        children: [const CosmicBackdrop(), child!],
      ),
    );

/// For a test file's `setUpAll`: loads the theme's fonts from the bundled
/// assets (real I/O, so it has to happen outside a test's fake clock) and
/// holds the sky still, so renders come out the same on every run.
Future<void> preloadCosmic() async {
  debugCosmicTime = 40;
  AppTheme.cosmic();
  AppTheme.wordmark(20);
  await GoogleFonts.pendingFonts();
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final loader = FontLoader(family)
    ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
  await loader.load();
}

/// Registers the set-up every cosmic render test needs.
void cosmicSetUp() {
  setUpAll(() async {
    // Pictures on a page go through the image cache, which asks the platform
    // for a directory before it fetches anything. There is no platform here,
    // so answer with a scratch folder; the fetch itself then fails (the test
    // HTTP client answers 400) and every picture falls back to its placeholder.
    TestWidgetsFlutterBinding.ensureInitialized();
    final scratch = Directory.systemTemp.createTempSync('cosmic_cache').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => scratch,
    );
    await _loadFont('Roboto', 'C:/Windows/Fonts/tahoma.ttf');
    await _loadFont('Segoe UI Emoji', 'C:/Windows/Fonts/seguiemj.ttf');
    await _loadFont(
        'MaterialIcons',
        'C:/Users/User/Downloads/flutter_windows_3.41.7-stable/flutter/bin/'
            'cache/artifacts/material_fonts/materialicons-regular.otf');
    await initializeDateFormatting('ar');
  });

  setUp(() {
    // The same sky every run: 40 s in, between two shooting stars.
    debugCosmicTime = 40;
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
}

Map<String, Object> vendorJson(int id, String name, String category,
        String city,
        {bool vip = false}) =>
    {
      'id': id,
      'name_ar': name,
      'name_en': name,
      'category': {'id': id, 'name_ar': category},
      'city': {'id': 8, 'name_ar': city},
      'rating': 4.6 + (id % 4) / 10,
      'reviews_count': 40 + id * 17,
      'is_vip': vip,
      'is_featured': true,
      'is_verified': true,
    };
