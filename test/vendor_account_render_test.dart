import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/core/models/models.dart';
import 'package:afrahna/core/state/session.dart';
import 'package:afrahna/features/account/vendor_account_view.dart';
import 'package:afrahna/widgets/tier_badge.dart';

/// An advertiser's «حسابي». Two different point counters live on this screen —
/// the shop's, which buys subscription months, and the owner's own, which buys
/// the 50 ₪ reward — so it is worth looking at rather than assuming they read
/// as two separate things.
class _Vendor implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s,
      Future<void>? c) async {
    final body = o.path.contains('vendors/mine')
        ? jsonEncode({
            'id': 7,
            'name_ar': 'lanashadi_boutique',
            'name_en': 'lanashadi_boutique',
            'category': {'id': 1, 'name_ar': 'فساتين سهرة'},
            'city': {'id': 1, 'name_ar': 'بيت لحم'},
            'rating': 5.0,
            'reviews_count': 0,
            'views_count': 12810,
            'points': 0,
            'is_verified': true,
          })
        : '[]';
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _SignedInVendor extends SessionController {
  _SignedInVendor(this._u);
  final UserModel _u;

  @override
  bool get isSignedIn => true;

  @override
  UserModel? get user => _u;
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

  testWidgets('the owner sees their own level, next to the shop\u2019s points',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Vendor();
    await initializeDateFormatting('ar');
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final session = _SignedInVendor(UserModel(
      id: 1,
      name: 'حازم صالح',
      phone: '0599000000',
      role: 'vendor',
      pointsBalance: 7,
      rewardsTaken: 0,
      createdAt: DateTime(2026, 7, 4),
    ));

    await tester.pumpWidget(ChangeNotifierProvider<SessionController>.value(
      value: session,
      child: MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: VendorAccountView(session: session),
        ),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // The member ladder, and the two headings that keep it apart from the
    // shop's own counter.
    expect(find.byType(TierProgressStrip), findsOneWidget);
    expect(find.text('نقاطك الشخصية'), findsOneWidget);
    expect(find.text('إجمالي نقاط متجرك'), findsOneWidget);
    expect(find.textContaining('المستوى 1 · برونزي'), findsOneWidget);
    expect(find.textContaining('باقي 93 نقطة'), findsOneWidget);

    // Personal first, shop second — the order the screen was built in.
    final mine = tester.getTopLeft(find.text('نقاطك الشخصية')).dy;
    final shop = tester.getTopLeft(find.text('إجمالي نقاط متجرك')).dy;
    expect(mine, lessThan(shop));

    await expectLater(
      find.byType(VendorAccountView),
      matchesGoldenFile('goldens/vendor_account_points.png'),
    );
  });
}
