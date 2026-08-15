import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afrahna/core/models/models.dart';
import 'package:afrahna/features/vendors/story_viewer_page.dart';
import 'package:afrahna/features/vendors/vendor_details_page.dart';

/// A story is where a shop gets noticed, so the shop in its header has to lead
/// to the shop's page — except when the story was opened from that page, where
/// it would only stack a second copy of it.
///
/// Networking is cut off: the pages settle into their error state instead of
/// reaching the live API.
class _OfflineHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionTimeout = const Duration(milliseconds: 1);
}

VendorModel _vendor() => VendorModel(id: 313, nameAr: 'قاعة الماسة', nameEn: 'Almasa');

List<StoryModel> _stories() => [
      StoryModel(id: 1, image: 'https://example.test/s1.jpg', vendorId: 313),
      StoryModel(id: 2, image: 'https://example.test/s2.jpg', vendorId: 313),
    ];

Future<void> _pumpViewer(WidgetTester tester, {required bool canOpen}) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: StoryViewerPage(
        vendor: _vendor(),
        stories: _stories(),
        canOpenVendor: canOpen,
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() => HttpOverrides.global = _OfflineHttp());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('tapping the shop on a story opens the shop', (tester) async {
    await _pumpViewer(tester, canOpen: true);

    expect(find.text('قاعة الماسة'), findsOneWidget);
    await tester.tap(find.text('قاعة الماسة'));
    // Let the route transition run, well inside the five seconds a story
    // lasts, so this is the tap arriving and not the story timing out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(VendorDetailsPage), findsOneWidget);
  });

  testWidgets('a story opened from the shop does not lead back to it',
      (tester) async {
    await _pumpViewer(tester, canOpen: false);

    await tester.tap(find.text('قاعة الماسة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(VendorDetailsPage), findsNothing);
    // Still on the story.
    expect(find.byType(StoryViewerPage), findsOneWidget);
  });
}
