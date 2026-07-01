import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/models/models.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

/// Full-screen Instagram-style viewer for a single highlight's items
/// (images shown for a fixed duration, videos played to completion).
class HighlightViewerPage extends StatefulWidget {
  const HighlightViewerPage({
    super.key,
    required this.vendor,
    required this.highlight,
    this.initialIndex = 0,
  });

  final VendorModel vendor;
  final HighlightModel highlight;
  final int initialIndex;

  @override
  State<HighlightViewerPage> createState() => _HighlightViewerPageState();
}

class _HighlightViewerPageState extends State<HighlightViewerPage>
    with SingleTickerProviderStateMixin {
  static const Duration _imageDuration = Duration(seconds: 5);

  late PageController _pageController;
  late AnimationController _imageProgress;
  VideoPlayerController? _video;
  bool _videoReady = false;
  int _index = 0;
  bool _paused = false;

  List<HighlightItemModel> get _items => widget.highlight.items;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _items.length - 1);
    _pageController = PageController(initialPage: _index);
    _imageProgress = AnimationController(vsync: this, duration: _imageDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      });
    _startItem();
  }

  @override
  void dispose() {
    _imageProgress.dispose();
    _pageController.dispose();
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    super.dispose();
  }

  void _startItem() {
    // Tear down any previous video.
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    _video = null;
    _videoReady = false;
    _imageProgress.stop();
    _imageProgress.reset();

    if (_items.isEmpty) return;
    final item = _items[_index];

    if (item.isVideo) {
      final c = VideoPlayerController.networkUrl(Uri.parse(item.mediaUrl));
      _video = c;
      c.initialize().then((_) {
        if (!mounted || _video != c) return;
        setState(() => _videoReady = true);
        c
          ..addListener(_onVideoTick)
          ..play();
      }).catchError((_) {
        // If a video fails to load, don't get stuck — move on.
        if (mounted && _video == c) _next();
      });
    } else {
      _imageProgress.forward();
    }
    setState(() {});
  }

  void _onVideoTick() {
    final c = _video;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur > Duration.zero && c.value.position >= dur && !c.value.isPlaying) {
      _next();
    } else {
      // Drive the progress bar repaint.
      if (mounted) setState(() {});
    }
  }

  void _next() {
    if (_index >= _items.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index++);
    _pageController.animateToPage(
      _index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _startItem();
  }

  void _prev() {
    if (_index == 0) {
      _startItem();
      return;
    }
    setState(() => _index--);
    _pageController.animateToPage(
      _index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _startItem();
  }

  void _pause(bool v) {
    setState(() => _paused = v);
    final c = _video;
    if (v) {
      _imageProgress.stop();
      c?.pause();
    } else {
      final item = _items.isNotEmpty ? _items[_index] : null;
      if (item != null && item.isVideo) {
        c?.play();
      } else {
        _imageProgress.forward();
      }
    }
  }

  double _progressFor(int i) {
    if (i < _index) return 1;
    if (i > _index) return 0;
    final item = _items[i];
    if (item.isVideo) {
      final c = _video;
      if (c != null && c.value.isInitialized) {
        final dur = c.value.duration.inMilliseconds;
        if (dur > 0) {
          return (c.value.position.inMilliseconds / dur).clamp(0.0, 1.0);
        }
      }
      return 0;
    }
    return _imageProgress.value;
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('لا يوجد محتوى', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final w = MediaQuery.of(context).size.width;
                // RTL: tap on left = next, tap on right = prev.
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
                itemCount: _items.length,
                itemBuilder: (_, i) => _buildItem(_items[i]),
              ),
            ),

            // Top: progress bars + header.
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
                        for (int i = 0; i < _items.length; i++) ...[
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: _progressFor(i),
                                minHeight: 3,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            ),
                          ),
                          if (i != _items.length - 1)
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
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: ClipOval(
                            child: AppNetworkImage(
                              url: widget.vendor.logo ?? widget.vendor.cover,
                              fallbackIcon: Icons.storefront,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
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
                              Text(
                                widget.highlight.title,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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

            // Bottom caption.
            if ((_items[_index].caption ?? '').isNotEmpty)
              Positioned(
                bottom: 24,
                left: 18,
                right: 18,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _items[_index].caption!,
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

  Widget _buildItem(HighlightItemModel item) {
    Widget media;
    if (item.isVideo) {
      media = (_videoReady && _video != null)
          ? FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _video!.value.size.width,
                height: _video!.value.size.height,
                child: VideoPlayer(_video!),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white));
    } else {
      media = AppNetworkImage(
        url: item.mediaUrl,
        fallbackIcon: Icons.image_outlined,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        media,
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
    );
  }
}

/// Horizontal rail of permanent highlight circles (Instagram-style).
class HighlightsRail extends StatelessWidget {
  const HighlightsRail({
    super.key,
    required this.vendor,
    required this.highlights,
  });
  final VendorModel vendor;
  final List<HighlightModel> highlights;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: highlights.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final h = highlights[i];
          return GestureDetector(
            onTap: h.items.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HighlightViewerPage(
                          vendor: vendor,
                          highlight: h,
                        ),
                      ),
                    ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
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
                        url: h.cover,
                        fallbackIcon: Icons.auto_awesome_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 74,
                  child: Text(
                    h.title,
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
