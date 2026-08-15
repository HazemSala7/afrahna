import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afrahna/features/invitation/invitation_view_page.dart';
import 'package:afrahna/features/reels/reels_page.dart';
import 'package:afrahna/widgets/app_widgets.dart';

/// The invitation is a full-bleed page with no app bar, and a notification
/// about an attendance reply opens it directly — so it has to carry its own
/// way back. It must be there in every state, including before the invitation
/// has loaded, which is exactly when a reader is most likely to want out.
///
/// Networking is cut off so the page settles into its error state immediately
/// instead of reaching the live API.
class _OfflineHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionTimeout = const Duration(milliseconds: 1);
}

void main() {
  setUpAll(() => HttpOverrides.global = _OfflineHttp());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('the invitation can be left again', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InvitationViewPage(code: 'abc123'),
                ),
              ),
              child: const Text('افتح الدعوة'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('افتح الدعوة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Present while the invitation is still loading, not only once it is up.
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('افتح الدعوة'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('a reel opened from a notification can be left again',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReelsPage(initialPostId: 5),
                ),
              ),
              child: const Text('افتح الريل'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('افتح الريل'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('افتح الريل'), findsOneWidget);
  });

  testWidgets('as the home tab, reels grows no dead back button',
      (tester) async {
    // Nothing to pop back to: the button must not appear at all.
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      home: ReelsPage(),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('in Arabic the arrow sits in the top-right corner',
      (tester) async {
    // AlignmentDirectional.topStart is the left in English and the right in
    // Arabic, and the app runs right-to-left — a corner on the wrong side
    // reads as a foreign control.
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Stack(children: [OverlayBackButton(onTap: () {})]),
        ),
      ),
    ));

    final icon = tester.getCenter(find.byIcon(Icons.arrow_back_rounded));
    final width = tester.getSize(find.byType(Scaffold)).width;
    expect(icon.dx, greaterThan(width / 2), reason: 'should hug the right');
    expect(icon.dy, lessThan(120), reason: 'should hug the top');
  });
}
