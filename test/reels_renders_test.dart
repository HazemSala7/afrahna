import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/core/state/session.dart';
import 'package:afrahna/features/reels/reels_page.dart';

/// The reels feed must actually occupy the screen.
///
/// It once rendered nothing at all — black, no spinner, no message — because
/// the page's Stack took its size from the back button, which is deliberately
/// nothing when the feed is the home tab rather than a pushed route. The Stack
/// measured zero, the feed had no space, and no reel was ever built. Checking
/// only that the back button is absent does not catch that; the size does.
class _Fixture implements HttpClientAdapter {
  _Fixture(this.body);
  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s,
          Future<void>? c) async =>
      ResponseBody.fromString(body, 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('the feed fills the screen as the home tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Reel items watch their own visibility on a timer; fire it immediately
    // so nothing is left pending when the test ends.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    ApiClient.instance.dio.httpClientAdapter =
        _Fixture(File('test/_reels_fixture.json').readAsStringSync());

    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SessionController())],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ReelsPage(), // as a tab: nothing to pop back to
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final screen = tester.getSize(find.byType(MaterialApp));

    // The page itself, not a collapsed box.
    final body = tester.getSize(
      find.descendant(of: find.byType(Scaffold), matching: find.byType(Stack)).first,
    );
    expect(body.height, screen.height, reason: 'the page collapsed');

    // And the feed inside it.
    expect(find.byType(PageView), findsOneWidget);
    expect(tester.getSize(find.byType(PageView)).height, greaterThan(0),
        reason: 'the feed has no room to build reels in');

    // Let the visibility callbacks the reels schedule during paint run, so
    // none is left pending when the tree is torn down.
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  });
}
