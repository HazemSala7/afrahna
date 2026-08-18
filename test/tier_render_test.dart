import 'dart:io';

import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:afrahna/core/models/models.dart';
import 'package:afrahna/core/rewards_ladder.dart';
import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/core/state/session.dart';
import 'package:afrahna/features/account/account_page.dart';
import 'package:afrahna/features/account/customer_header.dart';
import 'package:afrahna/widgets/tier_badge.dart';
import 'package:afrahna/widgets/tier_benefits.dart';

/// The level badge shows up on the home card, the account card and the facts
/// row, so it is worth looking at all four metals side by side rather than
/// trusting that «برونزي» renders like «بلاتيني».

UserModel _user({int rewardsTaken = 0, int balance = 6}) => UserModel(
      id: 1,
      name: 'حازم صالح',
      phone: '0599000000',
      pointsBalance: balance,
      rewardsTaken: rewardsTaken,
      createdAt: DateTime(2026, 7, 4),
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF3EC),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pump(const Duration(milliseconds: 1200));
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

  testWidgets('every rung is its own metal', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 5; i++) ...[
            Row(
              children: [
                TierMedal(rewardsTaken: i, size: 40),
                const SizedBox(width: 10),
                TierChip(rewardsTaken: i),
              ],
            ),
            const SizedBox(height: 10),
            TierProgressStrip(
              balance: [6, 140, 260, 800, 900][i],
              rewardsTaken: i,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );

    // The fifth row is past بلاتيني: same name, goal doubled to 1600.
    expect(RewardsLadder.goalFor(4), 1600);
    expect(find.textContaining('المستوى 5 · بلاتيني'), findsWidgets);

    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/tier_rungs.png'),
    );
  });

  testWidgets('the shared hero card leads with the level', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Empty();
    // The card formats «عضو منذ يوليو 2026» with the ar locale.
    await initializeDateFormatting('ar');
    tester.view.physicalSize = const Size(1080, 700);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(
      tester,
      CustomerHeroCard(
        user: _user(rewardsTaken: 1, balance: 63),
        onEditProfile: () {},
        onOpenPoints: () {},
      ),
    );

    expect(find.textContaining('المستوى 2 · فضي'), findsOneWidget);
    expect(find.textContaining('باقي 137 نقطة'), findsOneWidget);

    await expectLater(
      find.byType(CustomerHeroCard),
      matchesGoldenFile('goldens/tier_hero_card.png'),
    );
  });

  testWidgets('the account facts row shows the level in its own metal',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Empty();
    await initializeDateFormatting('ar');
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider<SessionController>(
      create: (_) => _Signed(_user(rewardsTaken: 1, balance: 63)),
      child: const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AccountPage(),
        ),
      ),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // A third of a row is not much space for «المستوى 2 · فضي» — if it has to
    // be ellipsised, the tile is lying about the level.
    // Three times: the hero card's strip, the facts tile, and the row for
    // this level in the benefits card.
    expect(find.text('المستوى 2 · فضي'), findsNWidgets(3));
    expect(find.text('مزايا المستويات'), findsOneWidget);

    await expectLater(
      find.byType(AccountPage),
      matchesGoldenFile('goldens/tier_account_page.png'),
    );
  });

  testWidgets('every tier says what it is worth', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester, const TierBenefitsCard(rewardsTaken: 1));

    // The member's own level opens by itself; the others stay shut until
    // asked. All four are named either way.
    for (final name in ['برونزي', 'فضي', 'ذهبي', 'بلاتيني']) {
      expect(find.textContaining(name), findsWidgets, reason: name);
    }
    expect(find.text('مستواك الآن'), findsOneWidget);
    expect(find.text('مكتمل'), findsOneWidget);
    expect(find.text('قادم'), findsNWidgets(2));

    await expectLater(
      find.byType(TierBenefitsCard),
      matchesGoldenFile('goldens/tier_benefits.png'),
    );
  });

  testWidgets('tapping a locked tier opens it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester, const TierBenefitsCard(rewardsTaken: 0));

    // Only the open level builds its perks, so these finders mean «visible»
    // rather than «somewhere in the tree».
    expect(find.textContaining('اجمع 800 نقطة'), findsNothing);
    expect(find.textContaining('اجمع 100 نقطة'), findsOneWidget);

    await tester.tap(find.textContaining('المستوى 4 · بلاتيني'));
    // AnimatedSize notices the new child during layout, then animates on the
    // frames after that — one pump lands mid-flight.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.textContaining('اجمع 800 نقطة'), findsOneWidget);
    expect(find.textContaining('200 شيكل من أفراحنا'), findsOneWidget);
    expect(find.textContaining('اجمع 100 نقطة'), findsNothing);

    await expectLater(
      find.byType(TierBenefitsCard),
      matchesGoldenFile('goldens/tier_benefits_platinum.png'),
    );
  });

  testWidgets('the wallet button turns gold when a reward is waiting',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Empty();
    await initializeDateFormatting('ar');
    tester.view.physicalSize = const Size(1080, 900);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Mid-level: the wallet is the filled control, but says nothing urgent.
    await _pump(
      tester,
      CustomerHeroCard(
        user: _user(rewardsTaken: 1, balance: 63),
        onEditProfile: () {},
        onOpenPoints: () {},
      ),
    );
    expect(find.text('محفظة النقاط'), findsOneWidget);
    expect(find.text('استلم 50 شيكل'), findsNothing);
    await expectLater(
      find.byType(CustomerHeroCard),
      matchesGoldenFile('goldens/wallet_pill_idle.png'),
    );

    // Goal reached: the same button becomes the offer itself.
    await _pump(
      tester,
      CustomerHeroCard(
        user: _user(rewardsTaken: 1, balance: 215),
        onEditProfile: () {},
        onOpenPoints: () {},
      ),
    );
    expect(find.text('استلم 50 شيكل'), findsOneWidget);
    await expectLater(
      find.byType(CustomerHeroCard),
      matchesGoldenFile('goldens/wallet_pill_ready.png'),
    );
  });

  test('the tier follows cash-outs, not the balance', () {
    // The old rule read the balance: a member with 600 points showed «ذهبي»
    // while still on the first rung, and dropped back to «برونزي» the moment
    // they were paid. Both are now impossible.
    expect(_user(balance: 600, rewardsTaken: 0).tierLabel, 'برونزي');
    expect(_user(balance: 3, rewardsTaken: 2).tierLabel, 'ذهبي');
    expect(_user(rewardsTaken: 3).tierLabel, 'بلاتيني');
    expect(_user(rewardsTaken: 7).tierLabel, 'بلاتيني');
    expect(_user(rewardsTaken: 7).tierLevel, 8);
    expect(_user(rewardsTaken: 0).tierGoal, 100);
    expect(_user(rewardsTaken: 5).tierGoal, 3200);
  });
}

class _Empty implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s,
          Future<void>? c) async =>
      ResponseBody.fromString('[]', 200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}

class _Signed extends SessionController {
  _Signed(this._u);
  final UserModel _u;

  @override
  bool get isSignedIn => true;

  @override
  UserModel? get user => _u;
}
