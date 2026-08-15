import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afrahna/widgets/animations.dart';

/// Scrolling back up a long page must not replay the entrance animation.
///
/// A list disposes children that are far off-screen and mounts them again on
/// the way back. An entrance animation that starts in initState therefore runs
/// again every time a section returns: the section fades from nothing and
/// slides up under the finger, which reads as the page snagging and refusing
/// to scroll up.
double _opacityOf(WidgetTester tester, String text) {
  final fade = tester.widget<FadeTransition>(
    find.ancestor(of: find.text(text), matching: find.byType(FadeTransition)).first,
  );
  return fade.opacity.value;
}

Widget _page({bool withId = true}) => MaterialApp(
      home: Scaffold(
        body: ListView(
          // Small cache extent so sections leave the tree the way they do on
          // a real phone with a long home page.
          cacheExtent: 10,
          children: [
            for (var i = 0; i < 12; i++)
              FadeSlideIn(
                id: withId ? 'section-$i' : null,
                child: SizedBox(height: 400, child: Center(child: Text('قسم $i'))),
              ),
          ],
        ),
      ),
    );

void main() {
  setUp(FadeSlideIn.debugResetPlayed);

  testWidgets('a section plays its entrance once, on first sight',
      (tester) async {
    await tester.pumpWidget(_page());
    expect(_opacityOf(tester, 'قسم 0'), 0.0);   // starts hidden
    await tester.pumpAndSettle();
    expect(_opacityOf(tester, 'قسم 0'), 1.0);   // and arrives
  });

  testWidgets('coming back to a section does not replay it', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    // Down past the first sections, then back to the top.
    await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, 3000), 3000);
    await tester.pump();

    // The section is on screen again: it must be fully there already, not
    // fading in from nothing while the finger is still moving.
    expect(_opacityOf(tester, 'قسم 0'), 1.0);
  });

  testWidgets('without an id it replays — the behaviour being fixed',
      (tester) async {
    await tester.pumpWidget(_page(withId: false));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, 3000), 3000);
    await tester.pump();

    // Faded out and sliding again while the finger is still on the screen:
    // this is exactly the snag on the home page.
    expect(_opacityOf(tester, 'قسم 0'), lessThan(1.0));
  });
}
