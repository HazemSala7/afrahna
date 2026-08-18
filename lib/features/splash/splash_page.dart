import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/services/notification_router.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/animations.dart';
import '../auth/login_page.dart';
import '../home/home_feed_cache.dart';
import '../home/home_page.dart';
import '../reels/reels_cache.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _logoCtrl,
    curve: Curves.elasticOut,
  );
  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _logoCtrl,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );

  late final AnimationController _glowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  /// The intro film. Null until it is playable, and stays null if it cannot
  /// be played at all — the animated logo below is a complete splash on its
  /// own, so a codec that refuses this file can never leave a black screen.
  VideoPlayerController? _intro;

  /// Resolves to the film once it is playable, or to null if it is not.
  /// [_introFinished] waits on this rather than reading [_intro], which is
  /// still null in the frame that wait begins.
  Future<VideoPlayerController?>? _introReady;

  /// True once the film is known not to be coming — a decoder that refused it,
  /// or a hold that ran out before it was ready. Until then the screen stays
  /// deliberately bare: see [build].
  bool _noIntro = false;

  final Stopwatch _sinceLaunch = Stopwatch()..start();

  /// The film's own background, so the wait before it and its first frame are
  /// the same colour and the change between them cannot be seen.
  static const Color _filmGround = Color(0xFFFAF3EC);

  /// The splash never passes faster than this — below it the app flashes by
  /// rather than opens.
  static const _minHold = Duration(milliseconds: 2100);

  /// ...and never holds the app longer than this, whatever the film does.
  static const _maxHold = Duration(milliseconds: 4000);

  @override
  void initState() {
    super.initState();
    _logoCtrl.forward();
    // Start fetching the home page's data now, in parallel with the splash
    // animation and session bootstrap, so the home tab shows instantly.
    HomeFeedCache.instance.prefetch();
    // The reels tab is the other screen that used to start from nothing:
    // fetch its first page and pull the first videos onto disk while the
    // intro plays, so it opens on a reel instead of a spinner.
    ReelsCache.instance.prefetch();
    _introReady = _startIntro();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = context.read<SessionController>();
      await Future.wait<dynamic>([
        session.bootstrap(),
        _introFinished(),
      ]);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, a, _) => FadeTransition(
            opacity: a,
            child:
                session.isSignedIn ? const HomePage() : const LoginPage(),
          ),
        ),
      );
      // Once the shell has been laid out, a link the app was launched with can
      // finally be acted on — before this point the replacement wipes it.
      // (pushReplacement's future resolves when the *new* route pops, so it
      // can't be awaited here.)
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => NotificationRouter.drainPending(),
      );
    });
  }

  Future<VideoPlayerController?> _startIntro() async {
    final c = VideoPlayerController.asset('assets/video/splash.mp4');
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return null;
      }
      // Silent: an app that starts talking the moment it is opened is
      // startling in company, and the film reads without its sound.
      await c.setVolume(0);
      await c.play();
      setState(() => _intro = c);
      return c;
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _noIntro = true);
      return null;
    }
  }

  /// Waits for the film to play out, bounded at both ends: never quicker than
  /// [_minHold], never longer than [_maxHold], so the app neither flashes past
  /// the intro nor is held shut by a decoder that never starts.
  Future<void> _introFinished() async {
    Duration remaining() {
      final left = _maxHold - _sinceLaunch.elapsed;
      return left > Duration.zero ? left : Duration.zero;
    }

    final c = await (_introReady ?? Future<VideoPlayerController?>.value())
        .timeout(remaining(), onTimeout: () => null);

    // Nothing to play, and the wait is over: show the animated splash for what
    // is left of the hold rather than finishing on an empty screen.
    if (c == null && mounted && !_noIntro) setState(() => _noIntro = true);

    if (c != null) {
      final done = Completer<void>();
      void listener() {
        final v = c.value;
        if (!done.isCompleted &&
            v.isInitialized &&
            v.position >= v.duration - const Duration(milliseconds: 120)) {
          done.complete();
        }
      }

      c.addListener(listener);
      await Future.any<void>([done.future, Future<void>.delayed(remaining())]);
      c.removeListener(listener);
    }

    final floor = _minHold - _sinceLaunch.elapsed;
    if (floor > Duration.zero) await Future<void>.delayed(floor);
  }

  @override
  void dispose() {
    _intro?.dispose();
    _logoCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intro = _intro;

    // Opening the app used to show two splashes in a row: the animated logo
    // for the second or so the film took to decode, and then the film itself.
    // Two loading screens back to back read as a stall, not as an opening.
    //
    // So while the film is still coming, the screen is just its own backdrop
    // colour — nothing to notice, nothing to replace, and the first frame of
    // the film lands on a ground that already matches it. The animated splash
    // is kept for the one case it exists to cover: a device that cannot play
    // the film at all, where a bare colour would be no splash whatsoever.
    if (intro != null && intro.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: intro.value.size.width,
              height: intro.value.size.height,
              child: VideoPlayer(intro),
            ),
          ),
        ),
      );
    }

    if (!_noIntro) {
      return const Scaffold(backgroundColor: _filmGround);
    }

    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, _) {
              final t = Curves.easeInOut.transform(_glowCtrl.value);
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + t * 0.4, -1),
                    end: Alignment(1, 1 - t * 0.4),
                    colors: const [
                      Color(0xFFFAF3EC),
                      Color(0xFFF0DDC8),
                      Color(0xFFEBD7BF),
                    ],
                  ),
                ),
              );
            },
          ),
          const Positioned.fill(child: SparkleOverlay(count: 36)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_logoCtrl, _glowCtrl]),
                  builder: (_, _) {
                    final pulse = 1 +
                        Curves.easeInOut.transform(_glowCtrl.value) * 0.04;
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value * pulse,
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.35),
                                blurRadius: 36 + 14 * _glowCtrl.value,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Image.asset(AppAssets.logo,
                                fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 700),
                  child: const Text(
                    'كل مناسباتك في مكان واحد',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 950),
                  child: Text(
                    '✨ من أعراس وحفلات إلى تنسيق وتصوير ✨',
                    style: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 1200),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
