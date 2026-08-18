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
import 'package:afrahna/features/reels/reels_cache.dart';
import 'package:afrahna/features/reels/reels_page.dart';

/// Warming the feed during the splash only pays off if the feed then uses what
/// was warmed. If the page fetched page one again anyway, the prefetch would
/// be a wasted request and the tab would still open on a spinner.
class _Counting implements HttpClientAdapter {
  _Counting(this.body);
  final String body;
  final List<String> posts = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s,
      Future<void>? c) async {
    if (o.path.contains('/posts')) posts.add('${o.queryParameters}');
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('the feed opens on what the splash already fetched',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    final http = _Counting(File('test/_reels_fixture.json').readAsStringSync());
    ApiClient.instance.dio.httpClientAdapter = http;

    // Splash: fetch page one ahead of time. runAsync, because awaiting a real
    // network future inside the fake-async zone of testWidgets never returns.
    await tester.runAsync(() => ReelsCache.instance.prefetch(warm: 0));
    expect(http.posts.length, 1, reason: 'the prefetch should fetch the page once');
    expect(ReelsCache.instance.isReady, isTrue);

    // Opening the tab must not ask for that same page again.
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SessionController())],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(textDirection: TextDirection.rtl, child: ReelsPage()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Page one must not be asked for twice; later pages are normal paging.
    final pageOne = http.posts.where((q) => q.contains('page: 1')).length;
    expect(pageOne, 1,
        reason: 'the feed refetched page one instead of using the prefetch: ${http.posts}');
    expect(find.byType(PageView), findsOneWidget);
    expect(tester.getSize(find.byType(PageView)).height, greaterThan(0));

    // Handed over once — a later open loads fresh.
    expect(ReelsCache.instance.isReady, isFalse);

    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  });
}
