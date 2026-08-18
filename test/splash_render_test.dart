import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/core/state/session.dart';
import 'package:afrahna/features/splash/splash_page.dart';

/// What the app actually shows in the seconds before the home page.
///
/// The video cannot play in a test binding, so this is the fallback branch —
/// which is exactly the branch worth looking at: it is what every user sees
/// while the film is still being decoded.
class _Empty implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s,
          Future<void>? c) async =>
      ResponseBody.fromString('[]', 200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/tahoma.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(font.readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
  });

  testWidgets('nothing is shown in front of the film', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Empty();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SessionController())],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SplashPage(),
        ),
      ),
    ));

    // First frame, while the film is still being opened: the app used to draw
    // a whole animated splash here — logo, taglines, spinner — and then throw
    // it away the moment the film was ready. Two openings in a row.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('كل مناسباتك'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the wait is painted in the colour of the film', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Empty();
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SessionController())],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SplashPage(),
        ),
      ),
    ));

    // Cream, not white and not black: the handover to the film's first frame
    // has to be invisible, and the OS window behind it is painted to match in
    // res/values/colors.xml and LaunchScreen.storyboard.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFFFAF3EC));

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
