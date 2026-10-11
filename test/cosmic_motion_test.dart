import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afrahna/widgets/celebration.dart';
import 'package:afrahna/widgets/cosmos.dart';
import 'package:afrahna/core/theme.dart';

import 'cosmic_harness.dart';

/// The movement itself, caught mid-flight — the frames the other render tests
/// never see, because they wait for everything to settle first.
///
/// Refresh with `flutter test test/cosmic_motion_test.dart --update-goldens`.

/// A page with a little content on it, to show the sky through and around.
class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              GoldFoilText(
                'أفراحنا',
                style: AppTheme.wordmark(40),
                textAlign: TextAlign.center,
              ),
              const NeonDivider(margin: EdgeInsets.symmetric(vertical: 18)),
              const Text(
                'ليلة العمر تبدأ من هنا',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const Spacer(),
              const GoldPill(label: 'ابدأ الآن'),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fires the burst as soon as it is on screen, so a render test can catch it.
class _Celebrating extends StatefulWidget {
  const _Celebrating();

  @override
  State<_Celebrating> createState() => _CelebratingState();
}

class _CelebratingState extends State<_Celebrating> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CelebrationBurst.show(context);
    });
  }

  @override
  Widget build(BuildContext context) => const _Page();
}

void main() {
  cosmicSetUp();

  testWidgets('the sky carries the wedding: dust, veil and rings',
      (tester) async {
    serve(const {});
    // 40 s in: two seconds into the rings drawing themselves on.
    debugCosmicTime = 40;
    await shoot(tester, cosmicApp(const CosmicPage(child: _Page())), 'sky_festive');
  });

  testWidgets('a page arrives under a scan of light', (tester) async {
    serve(const {});
    debugCosmicTime = 12;
    await shoot(
      tester,
      cosmicApp(const CosmicPage(child: _Page())),
      'page_arrival',
      // Mid-sweep: the line is halfway down and at its brightest.
      settle: const Duration(milliseconds: 450),
    );
  });

  testWidgets('a celebration bursts over the page', (tester) async {
    serve(const {});
    debugCosmicTime = 12;
    await shoot(
      tester,
      cosmicApp(const CosmicPage(child: _Celebrating())),
      'celebration',
      settle: const Duration(milliseconds: 600),
      // Every burst is thrown differently on purpose, so this one is drawn
      // for review rather than compared.
      varies: true,
    );
  });
}
