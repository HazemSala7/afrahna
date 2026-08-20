import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The home page's section order, as specified.
///
/// Read off the source rather than the rendered tree: most of these rows are
/// behind a `FutureBuilder` and draw nothing at all without a server, so a
/// widget test would happily "pass" on an empty page. The order is the thing
/// being specified, and the order lives in the file.
void main() {
  test('the home sections follow the requested order', () {
    final src = File('lib/features/home/home_page.dart').readAsStringSync();

    const expected = [
      'الستوريز',
      'التصنيفات',
      'السلايدات',
      'الشركات المميّزة',
      'المتجر',
      'عروض اليوم',
      'آخر المنشورات',
      'انضم مؤخراً',
      'الأعلى تقييماً',
      'دعوات إلكترونية',
      'تواصل معنا',
      'نصائح لتخطيط فرحك',
      'ليش أفراحنا؟',
    ];

    final markers = RegExp(r'^\s*// ---- (\d+)\. (.+?) -+$', multiLine: true)
        .allMatches(src)
        .toList();

    expect(markers.length, expected.length,
        reason: 'every numbered section should be marked in the source');

    for (var i = 0; i < expected.length; i++) {
      expect(int.parse(markers[i].group(1)!), i + 1,
          reason: 'section ${i + 1} is out of sequence');
      expect(markers[i].group(2)!.trim(), expected[i],
          reason: 'position ${i + 1} should be ${expected[i]}');
    }

    // And the widgets really do sit between their markers, in that order.
    const widgets = [
      '_StoriesRail',
      '_CategoriesGrid',
      '_HeroBanner',
      '_FeaturedVendorsCarousel',
      '_MarketRow',
      '_OffersRow',
      '_LatestPostsRow',
      '_NewVendorsRow',
      '_TopRatedRow',
      '_InvitationPromoCard',
      '_AdvertiseCta',
      '_TipsSection',
      '_WhyAfrahnaSection',
    ];
    var cursor = markers.first.start;
    for (final w in widgets) {
      final at = src.indexOf('$w(', cursor);
      expect(at, greaterThan(-1), reason: '$w missing after position');
      cursor = at;
    }
  });

  test('the bar is on by default, and off exactly where it would double up',
      () {
    final scaffold =
        File('lib/widgets/app_widgets.dart').readAsStringSync();

    // The guarantee lives in one place now: AppScaffold supplies the bar
    // unless the screen brings its own or opts out.
    expect(scaffold, contains('this.showShellNav = true'));
    expect(scaffold, contains('showShellNav ? const ShellBottomNav() : null'));

    // These are tabs inside the shell, which already draws the bar. A second
    // one would stack two bars on top of each other.
    for (final path in [
      'lib/features/account/account_page.dart',
      'lib/features/planning/planning_hub_page.dart',
      'lib/features/store/marketplace_page.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('showShellNav: false'),
          reason: '$path is a shell tab and must not draw its own bar');
    }

    // …and these are pushed on top of it, so they must NOT opt out.
    for (final path in [
      'lib/features/points/points_page.dart',
      'lib/features/store/my_orders_page.dart',
      'lib/features/offers/offers_page.dart',
      'lib/features/favorites/favorites_page.dart',
      'lib/features/bookings/bookings_page.dart',
      'lib/features/account/edit_profile_page.dart',
      'lib/features/vendors/vendors_page.dart',
      'lib/features/categories/categories_page.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('AppScaffold('),
          reason: '$path should use the app scaffold');
      expect(src.contains('showShellNav: false'), isFalse,
          reason: '$path is pushed on top of the shell and needs the way out');
    }
  });
}
