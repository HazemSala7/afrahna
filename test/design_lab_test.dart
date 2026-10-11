import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:afrahna/core/theme.dart';

/// THROWAWAY. Three directions for the home screen, rendered side by side so
/// they can be judged as pictures rather than described as adjectives.
///
/// Same content in all three — the same photograph, the same six words, the
/// same four shops — so what is being compared is the design and nothing else.
/// Delete this file once a direction is chosen.
///
///   flutter test --update-goldens test/design_lab_test.dart

const _photo = 'assets/images/cover_blush.jpg';
const _photo2 = 'assets/images/invitation_cover.jpg';
const _photo3 = 'assets/images/cover_mist.jpg';
const _photo4 = 'assets/images/cover_emerald.jpg';

const _shops = [
  ('قاعة الأصالة', 'قاعات أفراح', 'الخليل', _photo),
  ('استوديو لمسة', 'تصوير', 'نابلس', _photo2),
  ('أزياء ميلانو', 'فساتين', 'رام الله', _photo3),
  ('حلويات الشرق', 'ضيافة', 'طولكرم', _photo4),
];

// ---------------------------------------------------------------------------
// A — CINEMATIC. One photograph, held full width, and type big enough to be
// read across a room. Everything else gets out of its way.
// ---------------------------------------------------------------------------

Widget _cinematic() => _Screen(
      background: const Color(0xFFFBF6F1),
      child: Stack(
        children: [
          // The photograph is the page, not an illustration on it.
          SizedBox(
            height: 1180,
            width: double.infinity,
            child: Image.asset(_photo, fit: BoxFit.cover,
                alignment: const Alignment(0, -0.15)),
          ),
          // It fades into the page instead of ending on a hard line.
          Positioned(
            top: 760,
            left: 0,
            right: 0,
            height: 420,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FBF6F1), Color(0xCCFBF6F1), Color(0xFFFBF6F1)],
                  stops: [0, 0.62, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: 92,
            right: 44,
            left: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _glassCircle(Icons.notifications_none_rounded),
                Text('أفراحنا',
                    style: AppTheme.wordmark(30)
                        .copyWith(color: const Color(0xFF6B4132))),
                _glassCircle(Icons.favorite_border_rounded),
              ],
            ),
          ),
          // A soft lift of light under the headline: the wall behind it is
          // pale and the type is dark, so the photograph is quieted locally
          // rather than scrimmed from edge to edge.
          Positioned(
            top: 470,
            right: 0,
            left: 0,
            height: 330,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0x99FFF8F2), Color(0x33FFF8F2), Color(0x00FFF8F2)],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: 540,
            right: 44,
            left: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Kicker('من أول فكرة لآخر ضيف'),
                const SizedBox(height: 18),
                Text(
                  'فرحك\nيبدأ من هون',
                  textAlign: TextAlign.start,
                  style: AppTheme.wordmark(58).copyWith(
                    color: const Color(0xFF4A2C22),
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 22),
                Container(width: 92, height: 2, color: const Color(0xFFC9906B)),
              ],
            ),
          ),
          Positioned(
            top: 1090,
            right: 44,
            left: 44,
            child: _searchBar(),
          ),
          Positioned(
            top: 1250,
            right: 0,
            left: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: _sectionTitle('الأكثر طلبًا', 'شوف الكل'),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 560,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 44),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(width: 22),
                    itemBuilder: (_, i) => _tallCard(_shops[i]),
                  ),
                ),
                const SizedBox(height: 56),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: _ctaBand(),
                ),
              ],
            ),
          ),
        ],
      ),
    );

/// A 3:4 photograph with the name laid over its foot. No card, no border —
/// the picture is the card.
Widget _tallCard((String, String, String, String) shop) => SizedBox(
      width: 400,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(shop.$4, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            Positioned(
              right: 26,
              left: 26,
              bottom: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.$1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${shop.$2} · ${shop.$3}',
                      style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 18,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

// ---------------------------------------------------------------------------
// B — BOUTIQUE. The arch from the photograph becomes the app's shape: every
// picture is arched, framed in a gold hairline, like a plate in an album.
// ---------------------------------------------------------------------------

Widget _boutique() => _Screen(
      background: const Color(0xFFF7F1EA),
      child: Stack(
        children: [
          Positioned(
            top: 150,
            right: 60,
            left: 60,
            height: 980,
            child: _archFrame(child: Image.asset(_photo, fit: BoxFit.cover)),
          ),
          Positioned(
            top: 78,
            right: 48,
            left: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _glassCircle(Icons.notifications_none_rounded),
                _glassCircle(Icons.menu_rounded),
              ],
            ),
          ),
          // The plate that holds the title, sitting over the foot of the arch.
          Positioned(
            top: 900,
            right: 118,
            left: 118,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 30),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x66C9906B)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x1A8E5F4A),
                      blurRadius: 40,
                      offset: Offset(0, 18)),
                ],
              ),
              child: Column(
                children: [
                  const _Rule(),
                  const SizedBox(height: 16),
                  Text('أفراحنا',
                      style: AppTheme.wordmark(40)
                          .copyWith(color: const Color(0xFF6B4132))),
                  const SizedBox(height: 10),
                  const Text('كل مناسباتك في مكان واحد',
                      style: TextStyle(
                          color: Color(0xFF9A8880),
                          fontSize: 19,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  const _Rule(),
                ],
              ),
            ),
          ),
          Positioned(
            top: 1210,
            right: 48,
            left: 48,
            child: _searchBar(),
          ),
          Positioned(
            top: 1370,
            right: 0,
            left: 0,
            child: Column(
              children: [
                const _Ornament(),
                const SizedBox(height: 20),
                const Text('الشركات المميّزة',
                    style: TextStyle(
                        color: Color(0xFF4A2C22),
                        fontSize: 30,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 28),
                SizedBox(
                  height: 470,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(width: 26),
                    itemBuilder: (_, i) => _platedCard(_shops[i]),
                  ),
                ),
                const SizedBox(height: 50),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: _ctaBand(),
                ),
              ],
            ),
          ),
        ],
      ),
    );

/// An arch, framed in a gold hairline set in from the edge, the way a mount
/// sits inside a picture frame.
Widget _archFrame({required Widget child}) {
  const shape = BorderRadius.vertical(
      top: Radius.elliptical(220, 300), bottom: Radius.circular(18));
  return Stack(
    fit: StackFit.expand,
    children: [
      ClipRRect(borderRadius: shape, child: child),
      Padding(
        padding: const EdgeInsets.all(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
                top: Radius.elliptical(206, 286), bottom: Radius.circular(8)),
            border: Border.all(color: const Color(0xB3D8AE88), width: 1.4),
          ),
        ),
      ),
    ],
  );
}

Widget _platedCard((String, String, String, String) shop) => SizedBox(
      width: 330,
      child: Column(
        children: [
          Expanded(
            child: _archFrame(child: Image.asset(shop.$4, fit: BoxFit.cover)),
          ),
          const SizedBox(height: 18),
          Text(shop.$1,
              style: const TextStyle(
                  color: Color(0xFF4A2C22),
                  fontSize: 23,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(shop.$3,
              style: const TextStyle(
                  color: Color(0xFFB08A72),
                  fontSize: 17,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// C — SILK. Nothing ends on a straight line. The photograph is cut by a curve,
// the sections flow into each other, and the cards overlap as they scroll.
// ---------------------------------------------------------------------------

Widget _silk() => _Screen(
      background: const Color(0xFFFDF7F3),
      child: Stack(
        children: [
          SizedBox(
            height: 1060,
            width: double.infinity,
            child: ClipPath(
              clipper: _WaveClipper(),
              child: Image.asset(_photo, fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.1)),
            ),
          ),
          // The photograph is pale; white type only reads with a wash of
          // shadow under it.
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            height: 1060,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x40000000), Color(0x14000000), Color(0x73000000)],
                    stops: [0, 0.42, 0.78],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 92,
            right: 44,
            left: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _glassCircle(Icons.notifications_none_rounded),
                Text('أفراحنا',
                    style: AppTheme.wordmark(30).copyWith(color: Colors.white)),
                _glassCircle(Icons.favorite_border_rounded),
              ],
            ),
          ),
          Positioned(
            top: 420,
            right: 48,
            left: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('يومك الكبير',
                    style: AppTheme.wordmark(52).copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Color(0x66000000), blurRadius: 24)
                        ])),
                const SizedBox(height: 12),
                const Text('خطّطيه معنا، خطوة خطوة',
                    style: TextStyle(
                        color: Color(0xE6FFFFFF),
                        fontSize: 22,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Category pills riding the curve, half on the photo and half off it.
          Positioned(
            top: 900,
            right: 0,
            left: 0,
            child: SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 44),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(width: 20),
                itemBuilder: (_, i) => _floatingCategory(
                    ['قاعات', 'تصوير', 'فساتين', 'ضيافة'][i],
                    [
                      Icons.castle_rounded,
                      Icons.photo_camera_rounded,
                      Icons.checkroom_rounded,
                      Icons.cake_rounded
                    ][i],
                    i),
              ),
            ),
          ),
          Positioned(
            top: 1160,
            right: 44,
            left: 44,
            child: _sectionTitle('مختارة لك', 'الكل'),
          ),
          Positioned(
            top: 1270,
            right: 0,
            left: 0,
            child: SizedBox(
              height: 520,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 44),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(width: 24),
                itemBuilder: (_, i) => _blobCard(_shops[i], i),
              ),
            ),
          ),
          Positioned(
            top: 1860,
            right: 44,
            left: 44,
            child: _ctaBand(),
          ),
        ],
      ),
    );

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path()
      ..lineTo(0, size.height - 150)
      ..quadraticBezierTo(size.width * 0.28, size.height,
          size.width * 0.62, size.height - 70)
      ..quadraticBezierTo(
          size.width * 0.86, size.height - 126, size.width, size.height - 210)
      ..lineTo(size.width, 0)
      ..close();
    return p;
  }

  @override
  bool shouldReclip(_) => false;
}

Widget _floatingCategory(String label, IconData icon, int i) => Column(
      children: [
        Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFC9906B).withValues(alpha: 0.28),
                  blurRadius: 30,
                  offset: const Offset(0, 14)),
            ],
          ),
          child: Icon(icon, size: 54, color: const Color(0xFFBE7F58)),
        ),
        const SizedBox(height: 14),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF4A2C22),
                fontSize: 19,
                fontWeight: FontWeight.w700)),
      ],
    );

Widget _blobCard((String, String, String, String) shop, int i) => SizedBox(
      width: 360,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(i.isEven ? 120 : 34),
            topLeft: const Radius.circular(34),
            bottomRight: const Radius.circular(34),
            bottomLeft: Radius.circular(i.isEven ? 34 : 120),
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1FC9906B), blurRadius: 36, offset: Offset(0, 16)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(i.isEven ? 108 : 22),
                    topLeft: const Radius.circular(22),
                    bottomRight: const Radius.circular(22),
                    bottomLeft: Radius.circular(i.isEven ? 22 : 108),
                  ),
                  child: Image.asset(shop.$4, fit: BoxFit.cover),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.$1,
                      style: const TextStyle(
                          color: Color(0xFF4A2C22),
                          fontSize: 23,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text('${shop.$2} · ${shop.$3}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF9A8880),
                                fontSize: 17,
                                fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded,
                          size: 20, color: Color(0xFFE6A800)),
                      const Text(' 4.8',
                          style: TextStyle(
                              color: Color(0xFF4A2C22),
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

// ---------------------------------------------------------------------------
// shared pieces
// ---------------------------------------------------------------------------

class _Screen extends StatelessWidget {
  const _Screen({required this.child, required this.background});
  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Tajawal',
        ),
        // There is no Scaffold here, so nothing hands the Texts a family and
        // every Arabic word comes out as a box. Say it once, at the top.
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: DefaultTextStyle(
            style: const TextStyle(
                fontFamily: 'Tajawal', color: Color(0xFF4A2C22)),
            child: ColoredBox(color: background, child: child),
          ),
        ),
      );
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB08A72),
          fontSize: 19,
          letterSpacing: 3,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _Rule extends StatelessWidget {
  const _Rule();
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        width: 150,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
            Color(0x00C9906B),
            Color(0xFFC9906B),
            Color(0x00C9906B),
          ]),
        ),
      );
}

class _Ornament extends StatelessWidget {
  const _Ornament();
  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 120, child: _Rule()),
          SizedBox(width: 14),
          Icon(Icons.auto_awesome, size: 22, color: Color(0xFFC9906B)),
          SizedBox(width: 14),
          SizedBox(width: 120, child: _Rule()),
        ],
      );
}

Widget _glassCircle(IconData icon) => Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A8E5F4A), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Icon(icon, size: 38, color: const Color(0xFF6B4132)),
    );

Widget _searchBar() => Container(
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(56),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F8E5F4A), blurRadius: 34, offset: Offset(0, 14)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 40, color: Color(0xFFBE7F58)),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('ابحث عن قاعة، مصوّر، فستان…',
                style: TextStyle(color: Color(0xFFAE9C93), fontSize: 24)),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFC9906B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tune_rounded, size: 34, color: Colors.white),
          ),
        ],
      ),
    );

/// The foot of the page: one photograph, one promise, one button.
Widget _ctaBand() => ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: SizedBox(
        height: 300,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(_photo2, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xE6512F26), Color(0x66512F26)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 0, 36, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('نظّم مناسبتك معنا',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('فريقنا بيمشي معك من أول خطوة',
                      style: TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 20,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 34, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Text('ابدأ الآن',
                        style: TextStyle(
                            color: Color(0xFF6B4132),
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

Widget _sectionTitle(String title, String action) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(action,
                style: const TextStyle(
                    color: Color(0xFFBE7F58),
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const Icon(Icons.chevron_left_rounded,
                size: 26, color: Color(0xFFBE7F58)),
          ],
        ),
        Text(title,
            style: const TextStyle(
                color: Color(0xFF4A2C22),
                fontSize: 32,
                fontWeight: FontWeight.w800)),
      ],
    );

// ---------------------------------------------------------------------------

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final loader = FontLoader(family)
    ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
  await loader.load();
}

Future<void> _shoot(WidgetTester tester, Widget app, String name) async {
  // The lab is drawn at 1 logical pixel per device pixel, so every number in
  // this file is a real pixel on a 1080-wide phone. The app itself lays out at
  // 360dp; a direction that wins here is divided by three on the way in.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  // Asset images decode off the fake clock.
  await tester.runAsync(() async {
    for (final p in [_photo, _photo2, _photo3, _photo4]) {
      await precacheImage(AssetImage(p), tester.element(find.byType(ColoredBox).first));
    }
    await GoogleFonts.pendingFonts();
  });
  await tester.pumpAndSettle();

  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('goldens/lab/$name.png'));
}

void main() {
  setUpAll(() async {
    await _loadFont('Roboto', 'C:/Windows/Fonts/tahoma.ttf');
    for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold', 'Black']) {
      await _loadFont('Tajawal', 'assets/google_fonts/Tajawal-$w.ttf');
    }
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      await _loadFont('Reem Kufi', 'assets/google_fonts/ReemKufi-$w.ttf');
    }
    await _loadFont(
        'MaterialIcons',
        'C:/Users/User/Downloads/flutter_windows_3.41.7-stable/flutter/bin/'
            'cache/artifacts/material_fonts/materialicons-regular.otf');
    AppTheme.wordmark(20);
    await GoogleFonts.pendingFonts();
  });

  testWidgets('A — cinematic', (t) => _shoot(t, _cinematic(), 'a_cinematic'));
  testWidgets('B — boutique', (t) => _shoot(t, _boutique(), 'b_boutique'));
  testWidgets('C — silk', (t) => _shoot(t, _silk(), 'c_silk'));
}
