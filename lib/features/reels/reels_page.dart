import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../vendors/vendor_details_page.dart';
import 'reel_comments_sheet.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final _service = PostService();
  final _controller = PageController();
  Future<List<PostModel>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PostModel>> _load() async {
    final all = await _service.list(type: PostType.reel, perPage: 30);
    // Skip reels with no media at all (broken uploads).
    return all
        .where((r) =>
            (r.mediaUrl?.isNotEmpty ?? false) ||
            (r.thumbnail?.isNotEmpty ?? false))
        .toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<List<PostModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snap.hasError) {
            return _ErrorState(error: snap.error, onRetry: _refresh);
          }
          final reels = snap.data ?? const <PostModel>[];
          if (reels.isEmpty) {
            return _EmptyState(onRefresh: _refresh);
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            child: PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              itemCount: reels.length,
              itemBuilder: (context, i) => _ReelItem(
                key: ValueKey(reels[i].id),
                reel: reels[i],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// SINGLE REEL
// ===========================================================================

class _ReelItem extends StatefulWidget {
  const _ReelItem({super.key, required this.reel});

  final PostModel reel;

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  VideoPlayerController? _video;
  bool _isVideo = false;
  bool _initFailed = false;
  bool _isPaused = false;
  bool _liked = false;
  bool _viewSent = false;
  late int _likes;
  double _lastVisible = 0;

  @override
  void initState() {
    super.initState();
    _likes = widget.reel.likesCount;
    _liked = widget.reel.isLiked;
    _maybeInitVideo();
  }

  void _maybeInitVideo() {
    final url = widget.reel.mediaUrl;
    if (url == null || url.isEmpty) return;
    final lower = url.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.contains('video')) {
      _isVideo = true;
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      _video = c;
      c.setLooping(true);
      c.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        // Autoplay if this reel is already visible when init completes.
        if (_lastVisible > 0.6 && !_isPaused) {
          c.play();
        }
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _initFailed = true);
      });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  void _onVisibility(VisibilityInfo info) {
    _lastVisible = info.visibleFraction;
    final v = _video;
    // Count one view the first time this reel becomes meaningfully visible.
    if (!_viewSent && info.visibleFraction > 0.6) {
      _viewSent = true;
      PostService().markViewed(widget.reel.id);
    }
    if (v == null) return;
    if (info.visibleFraction > 0.6) {
      if (!_isPaused && !v.value.isPlaying && v.value.isInitialized) v.play();
    } else {
      if (v.value.isPlaying) v.pause();
    }
  }

  void _togglePlay() {
    final v = _video;
    if (v == null || !v.value.isInitialized) return;
    setState(() {
      if (v.value.isPlaying) {
        v.pause();
        _isPaused = true;
      } else {
        v.play();
        _isPaused = false;
      }
    });
  }

  Future<void> _toggleLike() async {
    if (!context.read<SessionController>().isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول للإعجاب بالريلز')),
      );
      return;
    }
    // Optimistic update, then reconcile with the server's real count.
    final prevLiked = _liked;
    final prevLikes = _likes;
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      final res = await PostService().toggleLike(widget.reel.id);
      if (!mounted) return;
      setState(() {
        _liked = res.liked;
        _likes = res.likes;
      });
    } catch (_) {
      if (!mounted) return;
      // Revert on failure.
      setState(() {
        _liked = prevLiked;
        _likes = prevLikes;
      });
    }
  }

  void _openComments(BuildContext context) {
    // Pause video while the sheet is open.
    final v = _video;
    final wasPlaying = v?.value.isPlaying ?? false;
    if (wasPlaying) v?.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReelCommentsSheet(postId: widget.reel.id),
    ).whenComplete(() {
      if (wasPlaying && !_isPaused && mounted) v?.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;
    final vendor = reel.vendor;

    return VisibilityDetector(
      key: ValueKey('reel-vis-${reel.id}'),
      onVisibilityChanged: _onVisibility,
      child: GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMedia(),
            // Bottom gradient
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0, 0.45, 0.8, 1],
                    ),
                  ),
                ),
              ),
            ),
            // Pause indicator
            if (_isPaused && _isVideo)
              const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 92,
                  color: Colors.white70,
                ),
              ),
            // Side actions (right side in RTL = leading)
            Positioned(
              left: 12,
              bottom: 110,
              child: _SideActions(
                likes: _likes,
                liked: _liked,
                comments: reel.commentsCount,
                views: reel.viewsCount,
                onLike: _toggleLike,
                onComment: () => _openComments(context),
              ),
            ),
            // Bottom info (vendor + caption)
            Positioned(
              right: 16,
              left: 80,
              bottom: 28,
              child: _BottomInfo(
                vendor: vendor,
                title: reel.title,
                body: reel.body,
                onVendorTap: vendor == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                VendorDetailsPage(vendorId: vendor.id),
                          ),
                        );
                      },
              ),
            ),
            // Top safe-area title bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: const [
                      Text(
                        'ريلز',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.camera_alt_outlined,
                          color: Colors.white, size: 26),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia() {
    final reel = widget.reel;
    final thumb = reel.thumbnail ?? reel.mediaUrl;

    if (_isVideo) {
      final v = _video;
      if (v != null && v.value.isInitialized && !_initFailed) {
        return Center(
          child: AspectRatio(
            aspectRatio: v.value.aspectRatio,
            child: VideoPlayer(v),
          ),
        );
      }
      // Fallback to thumbnail while loading or on failure
      if (thumb != null && thumb.isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: thumb,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: Colors.black),
              errorWidget: (_, _, _) => Container(color: Colors.black),
            ),
            if (!_initFailed)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        );
      }
      return Container(color: Colors.black);
    }

    if (thumb != null && thumb.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumb,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(color: Colors.black),
        errorWidget: (_, _, _) => Container(
          color: Colors.black,
          child: const Icon(Icons.broken_image_outlined,
              color: Colors.white24, size: 80),
        ),
      );
    }

    return Container(color: Colors.black);
  }
}

// ===========================================================================
// SIDE ACTIONS
// ===========================================================================

class _SideActions extends StatelessWidget {
  const _SideActions({
    required this.likes,
    required this.liked,
    required this.comments,
    required this.views,
    required this.onLike,
    required this.onComment,
  });

  final int likes;
  final bool liked;
  final int comments;
  final int views;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
          color: liked ? Colors.red : Colors.white,
          label: _fmt(likes),
          onTap: onLike,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          color: Colors.white,
          label: _fmt(comments),
          onTap: onComment,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.remove_red_eye_outlined,
          color: Colors.white,
          label: _fmt(views),
          onTap: null,
        ),
      ],
    );
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: color,
              size: 34,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// BOTTOM INFO
// ===========================================================================

class _BottomInfo extends StatelessWidget {
  const _BottomInfo({
    required this.vendor,
    required this.title,
    required this.body,
    required this.onVendorTap,
  });

  final VendorModel? vendor;
  final String? title;
  final String? body;
  final VoidCallback? onVendorTap;

  @override
  Widget build(BuildContext context) {
    final caption = (title?.trim().isNotEmpty ?? false)
        ? title!
        : (body?.trim() ?? '');
    final logo = vendor?.logo;
    final name = vendor?.nameAr ?? vendor?.nameEn ?? 'معلن';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onVendorTap,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: (logo != null && logo.isNotEmpty)
                    ? CachedNetworkImageProvider(logo)
                    : null,
                child: (logo == null || logo.isEmpty)
                    ? const Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'متابعة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
              height: 1.4,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
      ],
    );
  }
}

// ===========================================================================
// EMPTY / ERROR
// ===========================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.movie_filter_outlined,
                      color: Colors.white38, size: 80),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد ريلز حالياً',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'اسحب للأسفل للتحديث',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.white70, size: 64),
            const SizedBox(height: 12),
            Text(
              '$error'.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
