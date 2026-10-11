import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/features/invitation/invitation_view_page.dart';

/// The sealed envelope is the first thing a guest sees, and the wax seal is
/// the one thing on it the eye lands on. It has to sit on the exact middle of
/// the screen; it used to sit at 0.44 of the height, which read as a mistake.
///
/// Measured rather than eyeballed, because the number it depends on is buried
/// in the envelope's proportions and any later change to the flap or the
/// pocket moves it without anyone noticing.
class _CannedInvitation implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async =>
      ResponseBody.fromString(
        jsonEncode({
          'invitation': {
            'id': 1,
            'code': 'abc123',
            'bride_name': 'دانا',
            'groom_name': 'هاني',
            'event_date': '2027-06-12T18:00:00',
            'venue': 'قاعة الأصالة',
          },
          'confirmed_count': 0,
          'wishes': [],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('the wax seal sits on the middle of the screen', (tester) async {
    // The Dio interceptor reads the auth token out of storage before every
    // request; without the mock it never resolves and the page never loads.
    // The envelope floats on an idle cycle now, so the seal is only at its
    // designed place at rest. Hold it still and the measurement is exact.
    debugInvitationStill = true;
    addTearDown(() => debugInvitationStill = false);
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _CannedInvitation();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: InvitationViewPage(code: 'abc123'),
      ),
    ));
    // The page fetches, then the envelope breathes on a repeating animation,
    // so settle by pumping a fixed stretch rather than waiting for stillness.
    // The fetch and the token read are real async work, so let them run off
    // the fake clock before pumping the frames the envelope needs.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    final seal = find.byKey(const ValueKey('wax-seal'));
    expect(seal, findsOneWidget, reason: 'the envelope never got as far as the seal');

    final screen = tester.getRect(find.byType(InvitationViewPage));
    final centreOfScreen = screen.top + screen.height / 2;
    final centreOfSeal = tester.getRect(seal).center.dy;

    // Within a pixel: the two are the same point, not merely close.
    expect((centreOfSeal - centreOfScreen).abs(), lessThan(1.0),
        reason: 'seal centre $centreOfSeal vs screen centre $centreOfScreen');

    // Let the idle animation stop before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
