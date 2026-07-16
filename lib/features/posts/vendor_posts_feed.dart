import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import 'post_details_page.dart';

/// A Facebook-style feed of a vendor's regular posts (text + images) with
/// reactions and comments. Used on the vendor profile and the owner's tab.
class VendorPostsFeed extends StatefulWidget {
  const VendorPostsFeed({
    super.key,
    required this.vendorId,
    this.canManage = false,
    this.showHeader = false,
    this.padding,
  });

  final int vendorId;
  final bool canManage;

  /// Show a "المنشورات" section header above the list when non-empty.
  final bool showHeader;
  final EdgeInsets? padding;

  @override
  State<VendorPostsFeed> createState() => VendorPostsFeedState();
}

class VendorPostsFeedState extends State<VendorPostsFeed> {
  final _service = PostService();
  late Future<List<PostModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PostModel>> _load() =>
      _service.list(vendorId: widget.vendorId, type: PostType.post, perPage: 50);

  /// Public: reload from outside (e.g. after creating a post).
  void reload() {
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<void> _delete(PostModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنشور'),
        content: const Text('هل تريد حذف هذا المنشور؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(p.id);
      reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PostModel>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final posts = snap.data ?? const <PostModel>[];
        if (posts.isEmpty) {
          if (widget.canManage) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('لا توجد منشورات بعد — اضغط "منشور جديد"',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        return ListView.separated(
          shrinkWrap: !widget.canManage,
          physics: widget.canManage
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          padding: widget.padding ?? EdgeInsets.zero,
          itemCount: posts.length + (widget.showHeader ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (widget.showHeader && i == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(Icons.dynamic_feed_rounded,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('المنشورات',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.textDark)),
                  ],
                ),
              );
            }
            final p = posts[i - (widget.showHeader ? 1 : 0)];
            return PostFeedCard(
              post: p,
              onDelete: widget.canManage ? () => _delete(p) : null,
            );
          },
        );
      },
    );
  }
}

class PostFeedCard extends StatefulWidget {
  const PostFeedCard({super.key, required this.post, this.onDelete});
  final PostModel post;
  final VoidCallback? onDelete;

  @override
  State<PostFeedCard> createState() => _PostFeedCardState();
}

class _PostFeedCardState extends State<PostFeedCard> {
  final _service = PostService();
  late bool _liked;
  late int _likes;
  late int _comments;
  bool _liking = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _likes = widget.post.likesCount;
    _comments = widget.post.commentsCount;
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    setState(() {
      _liking = true;
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      final res = await _service.toggleLike(widget.post.id);
      if (mounted) {
        setState(() {
          _liked = res.liked;
          _likes = res.likes;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likes += _liked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  void _openComments() => _openDetails(focusComment: true);

  /// Open the post in a dedicated full page (Facebook-style), then sync any
  /// like/comment changes back into this card.
  Future<void> _openDetails({bool focusComment = false}) async {
    final result = await Navigator.push<PostDetailsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailsPage(
          post: widget.post,
          focusComment: focusComment,
          liked: _liked,
          likes: _likes,
          comments: _comments,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _liked = result.liked;
        _likes = result.likes;
        _comments = result.comments;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final vendor = p.vendor;
    final images = p.gallery;
    final body = p.body?.trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tapping the post content opens the full post page (Facebook-style).
          InkWell(
            onTap: () => _openDetails(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage:
                      (vendor?.logo != null && vendor!.logo!.isNotEmpty)
                          ? NetworkImage(vendor.logo!)
                          : null,
                  child: (vendor?.logo == null || (vendor?.logo ?? '').isEmpty)
                      ? const Icon(Icons.storefront,
                          color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendor?.name ?? 'معلن',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.textDark)),
                      Text(_timeAgo(p.createdAt),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11.5)),
                    ],
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: widget.onDelete,
                  ),
              ],
            ),
          ),
          // Body text
          if (body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(body,
                  style: const TextStyle(
                      fontSize: 14.5, height: 1.6, color: AppColors.textDark)),
            ),
          // Images
          if (images.isNotEmpty) PostGallery(images: images),
              ],
            ),
          ),
          // Counts
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                if (_likes > 0) ...[
                  const Icon(Icons.favorite, color: Color(0xFFE0353B), size: 15),
                  const SizedBox(width: 4),
                  Text('$_likes',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12.5)),
                ],
                const Spacer(),
                if (_comments > 0)
                  Text('$_comments تعليق',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Actions
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  icon: _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? const Color(0xFFE0353B) : AppColors.textMuted,
                  label: 'إعجاب',
                  onTap: _toggleLike,
                ),
              ),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.mode_comment_outlined,
                  color: AppColors.textMuted,
                  label: 'تعليق',
                  onTap: _openComments,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _timeAgo(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
    if (diff.inDays < 30) return 'قبل ${diff.inDays} يوم';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class PostGallery extends StatefulWidget {
  const PostGallery({super.key, required this.images});
  final List<String> images;

  @override
  State<PostGallery> createState() => _PostGalleryState();
}

class _PostGalleryState extends State<PostGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    return AspectRatio(
      aspectRatio: 1,
      child: imgs.length <= 1
          ? AppNetworkImage(
              url: imgs.isNotEmpty ? imgs.first : null,
              fit: BoxFit.cover,
              fallbackIcon: Icons.image_outlined,
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: imgs.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => AppNetworkImage(
                      url: imgs[i],
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.image_outlined,
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_index + 1}/${imgs.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(imgs.length, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: active ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
    );
  }
}
