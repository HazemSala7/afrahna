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
  const ReelsPage({super.key, this.initialPostId});

  /// When set (e.g. opened from a notification), the feed opens on this reel.
  final int? initialPostId;

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final _service = PostService();
  final _controller = PageController();

  static const _pageSize = 10;
  final List<PostModel> _reels = [];
  final Set<int> _ids = {};
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _initialLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  bool _hasMedia(PostModel r) =>
      (r.mediaUrl?.isNotEmpty ?? false) || (r.thumbnail?.isNotEmpty ?? false);

  void _addAll(Iterable<PostModel> items) {
    for (final r in items) {
      if (!_hasMedia(r)) continue;
      if (_ids.add(r.id)) _reels.add(r);
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    _reels.clear();
    _ids.clear();
    _page = 0;
    _hasMore = true;
    try {
      // Deep link: open the feed on the requested reel (prepend it first).
      final target = widget.initialPostId;
      if (target != null) {
        try {
          final p = await _service.show(target);
          if (_hasMedia(p) && _ids.add(p.id)) _reels.add(p);
        } catch (_) {}
      }
      final res = await _service.listPaged(
          type: PostType.reel, page: 1, perPage: _pageSize);
      _page = 1;
      _hasMore = res.hasMore;
      _addAll(res.items);
      if (mounted) setState(() => _initialLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _initialLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final res = await _service.listPaged(
          type: PostType.reel, page: _page + 1, perPage: _pageSize);
      _page += 1;
      _hasMore = res.hasMore;
      final before = _reels.length;
      _addAll(res.items);
      if (mounted && _reels.length != before) setState(() {});
    } catch (_) {
      // Ignore — it will retry on the next scroll.
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _refresh() => _loadInitial();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          if (_initialLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (_error != null && _reels.isEmpty) {
            return _ErrorState(error: _error, onRetry: _refresh);
          }
          if (_reels.isEmpty) {
            return _EmptyState(onRefresh: _refresh);
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            child: PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              itemCount: _reels.length,
              // Load the next page as the user nears the end.
              onPageChanged: (i) {
                if (i >= _reels.length - 3) _loadMore();
              },
              itemBuilder: (context, i) => _ReelItem(
                key: ValueKey(_reels[i].id),
                reel: _reels[i],
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

  void _openVendor() {
    final vendor = widget.reel.vendor;
    if (vendor == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VendorDetailsPage(vendorId: vendor.id),
      ),
    );
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
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.92),
                      ],
                      stops: const [0, 0.4, 0.72, 1],
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
              left: 10,
              // Lift above the bottom nav bar + the device's gesture/safe area
              // so nothing is hidden on phones with a taller bottom inset.
              bottom: 124 + MediaQuery.of(context).viewPadding.bottom,
              child: _SideActions(
                logo: vendor?.logo,
                likes: _likes,
                liked: _liked,
                comments: reel.commentsCount,
                views: reel.viewsCount,
                onProfileTap: vendor == null ? null : _openVendor,
                onLike: _toggleLike,
                onComment: () => _openComments(context),
              ),
            ),
            // Bottom info (vendor + caption) — kept above the bottom nav bar.
            Positioned(
              right: 16,
              left: 78,
              bottom: 124 + MediaQuery.of(context).viewPadding.bottom,
              child: _BottomInfo(
                vendor: vendor,
                title: reel.title,
                body: reel.body,
                onVendorTap: vendor == null ? null : _openVendor,
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
    required this.logo,
    required this.likes,
    required this.liked,
    required this.comments,
    required this.views,
    required this.onProfileTap,
    required this.onLike,
    required this.onComment,
  });

  final String? logo;
  final int likes;
  final bool liked;
  final int comments;
  final int views;
  final VoidCallback? onProfileTap;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProfileAvatar(logo: logo, onTap: onProfileTap),
        const SizedBox(height: 22),
        _ActionButton(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
          color: liked ? Colors.red : Colors.white,
          label: _fmt(likes),
          onTap: onLike,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.mode_comment_rounded,
          color: Colors.white,
          label: _fmt(comments),
          onTap: onComment,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.remove_red_eye_rounded,
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

/// Round profile avatar with a small red "+" follow badge — TikTok style.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.logo, required this.onTap});

  final String? logo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 50,
        height: 60,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(blurRadius: 6, color: Colors.black45),
                ],
              ),
              child: ClipOval(
                child: (logo != null && logo!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: logo!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: Colors.white24),
                        errorWidget: (_, _, _) => Container(
                          color: Colors.white24,
                          child: const Icon(Icons.storefront_rounded,
                              color: Colors.white, size: 22),
                        ),
                      )
                    : Container(
                        color: Colors.white24,
                        child: const Icon(Icons.storefront_rounded,
                            color: Colors.white, size: 22),
                      ),
              ),
            ),
            Positioned(
              bottom: -9,
              child: Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
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

class _BottomInfo extends StatefulWidget {
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
  State<_BottomInfo> createState() => _BottomInfoState();
}

class _BottomInfoState extends State<_BottomInfo> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.title?.trim() ?? '';
    final b = widget.body?.trim() ?? '';
    final caption = (t.isNotEmpty && b.isNotEmpty && t != b)
        ? '$t\n$b'
        : (t.isNotEmpty ? t : b);
    final name = widget.vendor?.nameAr ?? widget.vendor?.nameEn ?? 'معلن';
    final long = caption.length > 70 || caption.contains('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shop name + follow pill — bold and prominent, like TikTok's @handle.
        GestureDetector(
          onTap: widget.onVendorTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: 0.2,
                    shadows: [
                      Shadow(blurRadius: 6, color: Colors.black87),
                      Shadow(blurRadius: 12, color: Colors.black54),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'متابعة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: long ? () => setState(() => _expanded = !_expanded) : null,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption,
                  maxLines: _expanded ? 10 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14.5,
                    height: 1.35,
                    shadows: [
                      Shadow(blurRadius: 6, color: Colors.black87),
                      Shadow(blurRadius: 10, color: Colors.black54),
                    ],
                  ),
                ),
                if (long)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _expanded ? 'إخفاء' : 'المزيد',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        // "Original sound" row — the signature TikTok touch.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note_rounded,
                color: Colors.white,
                size: 15,
                shadows: [Shadow(blurRadius: 4, color: Colors.black87)]),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'الصوت الأصلي · $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  shadows: [Shadow(blurRadius: 5, color: Colors.black87)],
                ),
              ),
            ),
          ],
        ),
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
