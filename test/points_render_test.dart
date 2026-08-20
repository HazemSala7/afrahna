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
import 'package:afrahna/core/state/session.dart';
import 'package:afrahna/features/points/points_page.dart';
import 'package:afrahna/widgets/shell_bottom_nav.dart';

/// Renders «نقاطي» against a canned summary so the rewards ladder can be
/// looked at, not just compiled. Run with `--update-goldens` to refresh.
class _Json implements HttpClientAdapter {
  _Json(this.body);
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s,
          Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

class _SignedIn extends SessionController {
  @override
  bool get isSignedIn => true;
}

Map<String, dynamic> _summary({
  int balance = 63,
  int rewardsTaken = 1,
  bool canClaim = false,
}) =>
    {
      'balance': balance,
      'points_per_shekel': 4,
      'value_ils': balance / 4,
      'tier': ['برونزي', 'فضي', 'ذهبي', 'بلاتيني'][rewardsTaken.clamp(0, 3)],
      'level': rewardsTaken + 1,
      'goal': [100, 200, 400, 800][rewardsTaken.clamp(0, 3)],
      'reward_ils': 50,
      'can_claim': canClaim,
      'rewards_taken': rewardsTaken,
      'rewards': [
        {
          'id': 1,
          'points': 100,
          'amount_ils': 50,
          'tier': 'برونزي',
          'level': 1,
          'created_at': '2026-07-02T10:00:00+03:00',
        },
      ],
      'threshold': [5, 7, 10, 15][rewardsTaken.clamp(0, 3)],
      'daily_cap': 3,
      'daily_used': 2,
      'streak_days': 12,
      'streak_needed': 30,
      'streak_award': 90,
      'breakdown': {
        'signup': 5,
        'invite': 9,
        'reel_like': 4,
        'post_comment': 2,
        'review': 1,
      },
      'progress': {
        'reel_like': 5,
        'post_like': 1,
        'reel_comment': 3,
        'post_comment': 6,
        'story_comment': 0,
        'review': 2,
        'service_comment': 0,
      },
      'invite_points': 3,
      'redemptions': [],
      'referral_code': 'HZM4K9',
      'invites_count': 3,
      'redeem_cost': 50,
      'redeem_discount': 10,
    };

Future<void> _pumpPage(WidgetTester tester, Map<String, dynamic> data) async {
  SharedPreferences.setMockInitialValues({});
  ApiClient.instance.dio.httpClientAdapter = _Json(data);
  await initializeDateFormatting('ar');

  await tester.pumpWidget(MultiProvider(
    providers: [ChangeNotifierProvider<SessionController>(create: (_) => _SignedIn())],
    child: const MaterialApp(
      locale: Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: PointsPage(),
      ),
    ),
  ));
  // Three pumps, not one: the summary future resolves on the first, the page
  // (and its entrance tweens) is built on the second, and the third is what
  // actually advances those tweens to their end value.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1400));
  await tester.pump(const Duration(milliseconds: 1400));
}

void main() {
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/tahoma.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')..addFont(
          Future.value(font.readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
  });

  testWidgets('the rewards ladder renders', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpPage(tester, _summary());

    // The ladder must name every rung, not just the one the member is on.
    for (final name in ['برونزي', 'فضي', 'ذهبي', 'بلاتيني']) {
      expect(find.text(name), findsWidgets, reason: 'rung $name missing');
    }
    expect(find.textContaining('باقي 137 نقطة'), findsOneWidget);
    // The screen is pushed on top of the shell, so it carries the bar itself.
    expect(find.byType(ShellBottomNav), findsOneWidget);

    await expectLater(
      find.byType(PointsPage),
      matchesGoldenFile('goldens/points_ladder.png'),
    );
  });

  testWidgets('the lower half renders', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpPage(tester, _summary());
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pump(const Duration(milliseconds: 900));

    await expectLater(
      find.byType(PointsPage),
      matchesGoldenFile('goldens/points_lower.png'),
    );
  });

  testWidgets('a claimable balance offers the reward', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpPage(
        tester, _summary(balance: 215, rewardsTaken: 1, canClaim: true));

    expect(find.textContaining('استلم 50 شيكل'), findsOneWidget);

    await expectLater(
      find.byType(PointsPage),
      matchesGoldenFile('goldens/points_claimable.png'),
    );
  });

  testWidgets('claiming celebrates', (tester) async {
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpPage(
        tester, _summary(balance: 215, rewardsTaken: 1, canClaim: true));

    await tester.tap(find.textContaining('استلم 50 شيكل'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.textContaining('مبروك! 50 شيكل'), findsOneWidget);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/points_celebration.png'),
    );
  });
}
