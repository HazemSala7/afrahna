import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afrahna/core/theme.dart';
import 'package:afrahna/features/auth/login_page.dart';
import 'package:afrahna/features/home/home_page.dart';
import 'package:afrahna/features/points/points_page.dart';
import 'package:afrahna/features/splash/splash_page.dart';

import 'cosmic_harness.dart';

/// Resolves an image and waits for it, outside the fake clock.
Future<void> _precache(ImageProvider provider) {
  final done = Completer<void>();
  provider
      .resolve(ImageConfiguration.empty)
      .addListener(ImageStreamListener(
        (_, _) {
          if (!done.isCompleted) done.complete();
        },
        onError: (_, _) {
          if (!done.isCompleted) done.complete();
        },
      ));
  return done.future;
}

/// The app in its real theme — the night sky, the gold, the type — rendered so
/// the look is checked by eye rather than assumed from the code.
///
/// Unlike the older render tests these go through [AppTheme.cosmic] and the
/// same app shell as `main.dart`, because almost everything that makes a
/// screen look the way it does now comes from the theme.
///
/// Refresh with `flutter test test/cosmic_render_test.dart --update-goldens`.

final Map<String, Object> _homeData = {
  '/categories': {
    'data': [
      for (final (i, n) in const [
        'قاعات',
        'تصوير',
        'فساتين',
        'تجميل وعناية',
        'ضيافة وحلويات',
        'سيارات الزفّة',
        'دعوات',
        'زهور',
      ].indexed)
        {'id': i + 1, 'name_ar': n, 'name_en': n, 'parent_id': null},
    ],
  },
  '/vendors': {
    'data': [
      vendorJson(1, 'قاعة الأصالة', 'قاعات', 'الخليل', vip: true),
      vendorJson(2, 'استوديو لمسة', 'تصوير', 'نابلس', vip: true),
      vendorJson(3, 'أزياء ميلانو', 'فساتين', 'رام الله'),
      vendorJson(4, 'صالون هبة', 'تجميل وعناية', 'جنين'),
      vendorJson(5, 'حلويات الشرق', 'ضيافة وحلويات', 'طولكرم'),
      vendorJson(6, 'زهور فرح', 'زهور', 'بيت لحم'),
    ],
  },
  '/promotions': {
    'data': [
      {
        'id': 1,
        'title_ar': 'خصم ٣٠٪ على جلسات التصوير الخارجية',
        'discount_percent': 30,
        'is_active': true,
        'vendor': vendorJson(2, 'استوديو لمسة', 'تصوير', 'نابلس'),
      },
      {
        'id': 2,
        'title_ar': 'باقة القاعة الذهبية مع ضيافة مجانية',
        'discount_percent': 15,
        'is_active': true,
        'vendor': vendorJson(1, 'قاعة الأصالة', 'قاعات', 'الخليل'),
      },
    ],
  },
  '/stats': {
    'vendors': 504,
    'users': 23621,
    'cities': 14,
    'offers': 12,
    'likes': 18400,
    'visitors': 96000,
  },
};

final Map<String, Object> _pointsData = {
  '/points/summary': {
    'balance': 63,
    'points_per_shekel': 4,
    'value_ils': 15.75,
    'tier': 'فضي',
    'level': 2,
    'goal': 200,
    'reward_ils': 50,
    'can_claim': false,
    'rewards_taken': 1,
    'rewards': [],
    'threshold': 7,
    'daily_cap': 3,
    'daily_used': 2,
    'streak_days': 12,
    'streak_needed': 30,
    'streak_award': 90,
    'breakdown': {'signup': 5, 'invite': 9, 'reel_like': 4},
    'progress': {'reel_like': 5, 'post_comment': 6, 'review': 2},
    'invite_points': 3,
    'redemptions': [],
    'referral_code': 'HZM4K9',
    'invites_count': 3,
    'redeem_cost': 50,
    'redeem_discount': 10,
  },
};

void main() {
  cosmicSetUp();

  testWidgets('login', (tester) async {
    serve(const {});
    await shoot(tester, cosmicApp(const LoginPage()), 'login');
  });

  testWidgets('home, as a guest', (tester) async {
    serve(_homeData);
    // Varies: home shuffles its featured shops and products on every load.
    await shoot(tester, cosmicApp(const HomePage()), 'home_guest',
        size: const Size(1080, 5200), varies: true);
  });

  // After home on purpose: the intro starts the home feed's shared prefetch,
  // and home rendered after it would wait on futures from another test.
  testWidgets('the intro, at its final frame', (tester) async {
    serve(const {});
    // The wordmark sits under the app's logo, which is an asset and decodes
    // off the fake clock. Whether it had finished by the time the frame was
    // taken depended on how much else the bundle was loading that run, so
    // this golden flickered between having a logo and not. Decode it first.
    await tester.runAsync(
      () => _precache(const AssetImage(AppAssets.logo)),
    );
    // 2.4 s: the ring drawn, the name and tagline in, the app not yet moving
    // on (it leaves after 2.6 s).
    await shoot(tester, cosmicApp(const SplashPage()), 'intro',
        settle: const Duration(milliseconds: 2400));
  });

  testWidgets('points, signed in', (tester) async {
    serve(_pointsData);
    await shoot(
      tester,
      cosmicApp(const PointsPage(), session: SignedIn()),
      'points',
      size: const Size(1080, 3200),
    );
  });
}
