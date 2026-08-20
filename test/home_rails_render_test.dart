import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/core/state/session.dart';
import 'package:afrahna/features/home/home_page.dart';

/// The top of the home page: the stories rail, the category row and the
/// slider. All three were reworked for how they behave under a finger, so the
/// look is worth checking rather than assuming.
class _Home implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s,
      Future<void>? c) async {
    String body = '[]';
    if (o.path.contains('categories')) {
      body = jsonEncode([
        for (final n in [
          'لوازم الحفلات',
          'الأزياء والموضة',
          'طعام وضيافة',
          'هدايا وإكسسوارات',
          'السيارات',
          'تصوير',
          'قاعات',
          'تجميل وعناية',
        ])
          {'id': n.hashCode.abs() % 1000, 'name_ar': n, 'name_en': n},
      ]);
    }
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

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

  testWidgets('the category row sits still and reads as one set', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Home();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    tester.view.physicalSize = const Size(1080, 1400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SessionController())],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HomePage(),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // The row used to scroll itself, which is why the tiles were hard to hit:
    // the target moved between deciding and touching. Its offset must not
    // change on its own.
    final list = find.byType(ListView);
    expect(list, findsWidgets);

    await expectLater(
      find.byType(HomePage),
      matchesGoldenFile('goldens/home_rails.png'),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
