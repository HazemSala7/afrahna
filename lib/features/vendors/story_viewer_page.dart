import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import 'vendor_details_page.dart';

/// Full-screen Instagram-style story viewer.
class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({
    super.key,
    required this.vendor,
    required this.stories,
    this.initialIndex = 0,
    this.canOpenVendor = true,
  });

  final VendorModel vendor;
  final List<StoryModel> stories;
  final int initialIndex;

  /// Whether tapping the shop in the header opens its page. False when the
  /// story was opened from that page to begin with — pushing a second copy of
  /// it on top of itself would only make the back button lie.
  final bool canOpenVendor;

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  static const Duration _storyDuration = Duration(seconds: 5);

  late PageController _pageController;
  late AnimationController _progress;
  int _index = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _pageController = PageController(initialPage: _index);
    _progress = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      });
    _start();
  }

  void _start() {
    _progress
      ..stop()
      ..reset()
      ..forward();
  }

  void _next() {
    if (_index >= widget.stories.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index++);
    _pageController.animateToPage(
      _index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _start();
  }

  void _prev() {
    if (_index == 0) {
      _start();
      return;
    }
    setState(() => _index--);
    _pageController.animateToPage(
      _index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _start();
  }

  void _pause(bool v) {
    setState(() => _paused = v);
    if (v) {
      _progress.stop();
    } else {
      _progress.forward();
    }
  }

  /// Open the shop whose story this is.
  ///
  /// A story is where a shop gets noticed, and there was no way through from
  /// it to the shop itself. The story is held while the page is open,
  /// otherwise its five seconds would run out behind your back — the viewer
  /// closes itself on the last one, so you would return to a screen that had
  /// already dismissed itself.
  Future<void> _openVendor() async {
    _pause(true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VendorDetailsPage(vendorId: widget.vendor.id),
      ),
    );
    if (mounted) _pause(false);
  }

  @override
  void dispose() {
    _progress.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stories = widget.stories;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final w = MediaQuery.of(context).size.width;
                // RTL: tap on left = next, tap on right = prev
                if (d.globalPosition.dx < w / 3) {
                  _next();
                } else if (d.globalPosition.dx > w * 2 / 3) {
                  _prev();
                }
              },
              onLongPressStart: (_) => _pause(true),
              onLongPressEnd: (_) => _pause(false),
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stories.length,
                itemBuilder: (_, i) => Stack(
                  fit: StackFit.expand,
                  children: [
                    // Show the full uploaded image without cropping
                    // (letterboxed on the black background).
                    AppNetworkImage(
                      url: stories[i].image,
                      fit: BoxFit.contain,
                      fallbackIcon: Icons.image_outlined,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x99000000),
                            Color(0x00000000),
                            Color(0x88000000),
                          ],
                          stops: [0.0, 0.35, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top: progress bars + header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (int i = 0; i < stories.length; i++) ...[
                          Expanded(
                            child: _ProgressBar(
                              controller: _progress,
                              isActive: i == _index,
                              isDone: i < _index,
                            ),
                          ),
                          if (i != stories.length - 1)
                            const SizedBox(width: 4),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // The shop itself is the link to its page, the way it
                        // works everywhere else stories exist.
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.canOpenVendor ? _openVendor : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: ClipOval(
                                    child: AppNetworkImage(
                                      url: widget.vendor.logo ??
                                          widget.vendor.cover,
                                      fallbackIcon: Icons.storefront,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    widget.vendor.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      shadows: [
                                        Shadow(
                                            blurRadius: 6,
                                            color: Colors.black54),
                                      ],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.canOpenVendor) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_left_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom-start: how many people have seen this story.
            PositionedDirectional(
              bottom: stories[_index].caption.isNotEmpty ? 88 : 24,
              start: 18,
              child: _ViewersPill(count: stories[_index].viewsCount),
            ),

            // Bottom: caption
            if (stories[_index].caption.isNotEmpty)
              Positioned(
                bottom: 24,
                left: 18,
                right: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    stories[_index].caption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ),

            if (_paused)
              const Center(
                child: Icon(Icons.pause_circle_filled,
                    color: Colors.white70, size: 54),
              ),
          ],
        ),
      ),
    );
  }
}

/// "١٬٢٠٤ مشاهدة" — the story's viewer count, shown over the media.
class _ViewersPill extends StatelessWidget {
  const _ViewersPill({required this.count});
  final int count;

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            '${_fmt(count)} مشاهدة',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(blurRadius: 5, color: Colors.black87)],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.controller,
    required this.isActive,
    required this.isDone,
  });
  final AnimationController controller;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final value = isDone ? 1.0 : (isActive ? controller.value : 0.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 3,
            backgroundColor: Colors.white24,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      },
    );
  }
}

/// Horizontal stories ring (Instagram-style avatars with gradient ring).
class StoriesRing extends StatelessWidget {
  const StoriesRing({
    super.key,
    required this.vendor,
    required this.stories,
  });
  final VendorModel vendor;
  final List<StoryModel> stories;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();
    // Portrait 9:16 cards (like Instagram/WhatsApp status previews) so the
    // story image shows almost in full instead of being crammed into a tiny
    // circle that crops most of it away.
    const cardW = 92.0;
    const cardH = 164.0; // ≈ 9:16 so portrait stories fill without cropping
    return SizedBox(
      height: cardH + 26,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final s = stories[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoryViewerPage(
                  vendor: vendor,
                  stories: stories,
                  initialIndex: i,
                  // Already on this shop's page.
                  canOpenVendor: false,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: cardW,
                  height: cardH,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const SweepGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.accent,
                        Color(0xFFE6B450),
                        AppColors.primaryDark,
                        AppColors.primary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      color: Colors.black,
                      child: AppNetworkImage(
                        url: s.image,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.image_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: cardW,
                  child: Text(
                    s.caption.isNotEmpty ? s.caption : 'قصّة ${i + 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
