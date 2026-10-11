import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/core/state/session.dart';
import 'package:afrahna/core/theme.dart';
import 'package:afrahna/features/splash/splash_page.dart';

/// The opening sequence, and the promise it rests on: that the colour the
/// phone shows while the app starts is the colour the intro opens on.
class _Empty implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s,
          Future<void>? c) async =>
      ResponseBody.fromString('[]', 200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}

Widget _splash() => MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SessionController())],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SplashPage(),
        ),
      ),
    );

/// 0xRRGGBB of a colour, without its alpha.
int _rgb(Color c) => c.toARGB32() & 0xFFFFFF;

void main() {
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/tahoma.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(font.readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
  });

  testWidgets('the intro opens with no spinner and names the app',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Empty();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_splash());

    // An opening, not a loading screen: nothing on it says "wait".
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Once the ring has drawn itself the name and the tagline are there.
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('أفراحنا'), findsOneWidget);
    expect(find.text('كل مناسباتك في مكان واحد'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the intro sits on the sky, with no ground of its own',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Empty();
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_splash());

    // Transparent: what shows is the sky, which starts at AppColors.space.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.transparent);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  test('the launch screens are painted the colour the intro opens on', () {
    // Android: the launch window.
    final xml =
        File('android/app/src/main/res/values/colors.xml').readAsStringSync();
    final android = RegExp(r'<color name="splashGround">#([0-9A-Fa-f]{6})</color>')
        .firstMatch(xml);
    expect(android, isNotNull, reason: 'splashGround missing from colors.xml');
    expect(int.parse(android!.group(1)!, radix: 16), _rgb(AppColors.space),
        reason: 'res/values/colors.xml splashGround must equal AppColors.space');

    // iOS: the launch storyboard, written as 0..1 components.
    final board = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
        .readAsStringSync();
    final ios = RegExp(
      r'key="backgroundColor" red="([0-9.]+)" green="([0-9.]+)" blue="([0-9.]+)"',
    ).firstMatch(board);
    expect(ios, isNotNull, reason: 'backgroundColor missing from storyboard');
    int channel(int i) => (double.parse(ios!.group(i)!) * 255).round();
    expect((channel(1) << 16) | (channel(2) << 8) | channel(3),
        _rgb(AppColors.space),
        reason: 'LaunchScreen.storyboard must equal AppColors.space');
  });
}
