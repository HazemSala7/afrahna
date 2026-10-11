import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/main.dart';

/// The whole app, booted the way a phone boots it: every provider wired up,
/// the intro on screen. It is a smoke test — if the provider tree or the
/// splash route is broken, nothing else in the suite gets that far.
///
/// The intro prefetches the home feed from `initState`, so the network is
/// stubbed; left real, the request stays pending and the test fails on timers
/// that have nothing to do with what it is checking.
class _Empty implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async =>
      ResponseBody.fromString('[]', 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('App boots and shows splash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Empty();

    await tester.pumpWidget(const AfrahnaApp());
    await tester.pump();

    // The wordmark carries the hamza: «أفراحنا».
    expect(find.text('أفراحنا'), findsWidgets);

    // Let the intro's own animations finish and unmount it, so the test does
    // not end holding its timers.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
