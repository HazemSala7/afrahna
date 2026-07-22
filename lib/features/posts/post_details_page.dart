import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../auth/login_page.dart';
import '../auth/register_page.dart';
import '../vendors/vendor_details_page.dart';
import 'vendor_posts_feed.dart';

/// Values handed back to the feed card when the details page closes, so the
/// card can reflect any like/comment changes made here.
class PostDetailsResult {
  const PostDetailsResult({
    required this.liked,
    required this.likes,
    required this.comments,
  });
  final bool liked;
  final int likes;
  final int comments;
}

/// A dedicated, full-screen view of a single post — opened when the user taps
/// a post in the feed, exactly like opening a post on Facebook: the content on
/// top, then all the comments, with a composer pinned to the bottom.
class PostDetailsPage extends StatefulWidget {
  const PostDetailsPage({
    super.key,
    required this.post,
    this.focusComment = false,
    this.liked,
    this.likes,
    this.comments,
  });

  final PostModel post;
  final bool focusComment;

  /// Live like/comment state from the caller (e.g. the feed card). When null,
  /// the page falls back to the post's own counts — this is what the home
  /// "latest posts" row relies on, otherwise every post showed 0/0.
  final bool? liked;
  final int? likes;
  final int? comments;

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  final _service = PostService();
  final _commentService = PostCommentService();
  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  late bool _liked;
  late int _likes;
  late int _comments;
  bool _liking = false;
  bool _sending = false;
  Future<List<PostCommentModel>>? _future;

  @override
  void initState() {
    super.initState();
    _liked = widget.liked ?? widget.post.isLiked;
    _likes = widget.likes ?? widget.post.likesCount;
    _comments = widget.comments ?? widget.post.commentsCount;
    _future = _commentService.list(widget.post.id);
    // The caller may hand us a stale, cached post (e.g. the home "latest posts"
    // row). Pull the live counts + like state from the server so a like made
    // earlier is reflected when the post is reopened.
    _refreshPost();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _inputFocus.requestFocus();
      });
    }
  }

  /// Reconcile like/comment state with the server (skipped while a like toggle
  /// is in flight so we never clobber the user's optimistic tap).
  Future<void> _refreshPost() async {
    try {
      final fresh = await _service.show(widget.post.id);
      if (!mounted || _liking) return;
      setState(() {
        _liked = fresh.isLiked;
        _likes = fresh.likesCount;
        _comments = fresh.commentsCount;
      });
    } catch (_) {
      // Keep the values we already have.
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  PostDetailsResult get _result =>
      PostDetailsResult(liked: _liked, likes: _likes, comments: _comments);

  Future<void> _toggleLike() async {
    if (!context.read<SessionController>().isSignedIn) {
      _requireLogin('سجّل الدخول للإعجاب بالمنشورات');
      return;
    }
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

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final c = await _commentService.create(widget.post.id, text);
      if (!mounted) return;
      _input.clear();
      _inputFocus.unfocus();
      if (c.isApproved) {
        setState(() {
          _comments += 1;
          _future = _commentService.list(widget.post.id);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('تم استلام تعليقك وسيظهر بعد موافقة الإدارة'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر إرسال التعليق: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _requireLogin(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openVendor() {
    final vendor = widget.post.vendor;
    if (vendor == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VendorDetailsPage(vendorId: vendor.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final p = widget.post;
    final vendor = p.vendor;
    final body = p.body?.trim() ?? '';
    final images = p.gallery;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _result);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          title: const Text(
            'المنشور',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          iconTheme: const IconThemeData(color: AppColors.textDark),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ---- Post header ----
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _openVendor,
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage:
                                (vendor?.logo != null && vendor!.logo!.isNotEmpty)
                                    ? NetworkImage(vendor.logo!)
                                    : null,
                            child: (vendor?.logo == null ||
                                    (vendor?.logo ?? '').isEmpty)
                                ? const Icon(Icons.storefront,
                                    color: Colors.white, size: 22)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openVendor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vendor?.name ?? 'معلن',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  _timeAgo(p.createdAt),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ---- Body text ----
                  if (body.isNotEmpty)
                    Container(
                      color: Colors.white,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                      child: Text(
                        body,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.7,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  // ---- Images ----
                  if (images.isNotEmpty)
                    Container(
                      color: Colors.white,
                      child: PostGallery(images: images),
                    ),
                  // ---- Counts ----
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Row(
                      children: [
                        if (_likes > 0) ...[
                          const Icon(Icons.favorite,
                              color: Color(0xFFE0353B), size: 16),
                          const SizedBox(width: 4),
                          Text('$_likes',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        ],
                        const Spacer(),
                        if (_comments > 0)
                          Text('$_comments تعليق',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                  // ---- Action buttons ----
                  Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: _liked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _liked
                                    ? const Color(0xFFE0353B)
                                    : AppColors.textMuted,
                                label: 'إعجاب',
                                onTap: _toggleLike,
                              ),
                            ),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.mode_comment_outlined,
                                color: AppColors.textMuted,
                                label: 'تعليق',
                                onTap: () => _inputFocus.requestFocus(),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ---- Comments ----
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: const [
                        Text(
                          'التعليقات',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FutureBuilder<List<PostCommentModel>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          ),
                        );
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'تعذّر تحميل التعليقات\n${snap.error}',
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        );
                      }
                      final items = snap.data ?? const <PostCommentModel>[];
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 24),
                          child: Column(
                            children: [
                              Icon(Icons.mode_comment_outlined,
                                  size: 48, color: AppColors.textMuted),
                              SizedBox(height: 10),
                              Text('لا توجد تعليقات بعد. كن أول من يعلّق!',
                                  style:
                                      TextStyle(color: AppColors.textMuted)),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final c in items)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: _CommentTile(comment: c),
                            ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            // ---- Composer / login gate pinned to the bottom ----
            SafeArea(
              top: false,
              child: session.isSignedIn
                  ? _Composer(
                      controller: _input,
                      focusNode: _inputFocus,
                      sending: _sending,
                      onSend: _send,
                    )
                  : const _LoginGate(),
            ),
          ],
        ),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final PostCommentModel comment;

  @override
  Widget build(BuildContext context) {
    final name = comment.displayName;
    final avatar = comment.user?.avatar;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: (avatar != null && avatar.isNotEmpty)
                ? NetworkImage(avatar)
                : null,
            child: (avatar == null || avatar.isEmpty)
                ? const Icon(Icons.person,
                    color: AppColors.primaryDark, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      fontSize: 13,
                    )),
                const SizedBox(height: 4),
                Text(comment.body,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      height: 1.4,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.primaryLight)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'اكتب تعليقاً...',
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primaryLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primaryLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: sending ? null : onSend,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginGate extends StatelessWidget {
  const _LoginGate();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'للتعليق يجب تسجيل الدخول أو إنشاء حساب',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  child: const Text('إنشاء حساب',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  child: const Text('تسجيل الدخول',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
