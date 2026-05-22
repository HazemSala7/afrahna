import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

/// Full-screen Instagram-style story viewer.
class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({
    super.key,
    required this.vendor,
    required this.stories,
    this.initialIndex = 0,
  });

  final VendorModel vendor;
  final List<StoryModel> stories;
  final int initialIndex;

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
                    AppNetworkImage(
                      url: stories[i].image,
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
                        Expanded(
                          child: Text(
                            widget.vendor.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black54),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
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
    return SizedBox(
      height: 96,
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
                ),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.accent,
                        Color(0xFFE6B450),
                        AppColors.primaryDark,
                        AppColors.primary,
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: AppNetworkImage(
                        url: s.image,
                        fallbackIcon: Icons.image_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 72,
                  child: Text(
                    s.caption.isNotEmpty
                        ? s.caption
                        : 'قصّة ${i + 1}',
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
