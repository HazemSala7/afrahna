import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../reels/reels_page.dart';
import 'reel_studio_page.dart';

/// «ريلزي» — the advertiser's own reels, laid out the way reels are actually
/// consumed: a 9:16 tile grid with the cover frame, view/like counts and a
/// play badge. Tapping one opens the real reels player.
///
/// The reel studio only ever handled *uploading*; once a reel was published
/// there was no screen anywhere that listed it back, so an advertiser could
/// neither review nor remove what they had posted.
class ManageReelsPage extends StatefulWidget {
  const ManageReelsPage({super.key, required this.vendorId});

  final int vendorId;

  @override
  State<ManageReelsPage> createState() => _ManageReelsPageState();
}

class _ManageReelsPageState extends State<ManageReelsPage> {
  late Future<List<PostModel>> _future = _load();

  Future<List<PostModel>> _load() => PostService().list(
        vendorId: widget.vendorId,
        type: PostType.reel,
        perPage: 60,
      );

  void _reload() => setState(() => _future = _load());

  Future<void> _openStudio() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReelStudioPage(vendorId: widget.vendorId),
      ),
    );
    if (mounted) _reload();
  }

  /// Opens the normal reels player starting on [reel], so the advertiser sees
  /// exactly what a customer sees.
  void _play(PostModel reel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReelsPage(initialPostId: reel.id)),
    );
  }

  Future<void> _confirmDelete(PostModel reel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الريل'),
        content: const Text(
          'سيُحذف هذا الريل نهائياً مع مشاهداته وإعجاباته. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.discount),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PostService().delete(reel.id);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الريل')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'تعذّر حذف الريل'),
        ),
      );
    }
  }

  void _openSheet(PostModel reel) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_fill_rounded,
                  color: AppColors.primary),
              title: const Text('تشغيل'),
              onTap: () {
                Navigator.pop(ctx);
                _play(reel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.discount),
              title: const Text('حذف الريل',
                  style: TextStyle(color: AppColors.discount)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(reel);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: PinkAppBar(
        title: 'الريلز',
        subtitle: 'مقاطعك المنشورة',
        actions: [
          IconButton(
            tooltip: 'ريل جديد',
            icon: const Icon(Icons.add_rounded),
            onPressed: _openStudio,
          ),
        ],
      ),
      body: FutureBuilder<List<PostModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
              message: snap.error is ApiException
                  ? (snap.error as ApiException).message
                  : 'تعذّر تحميل الريلز',
              onRetry: _reload,
            );
          }
          final reels = snap.data ?? const <PostModel>[];
          if (reels.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.movie_creation_outlined,
                        size: 64, color: AppColors.primary),
                    const SizedBox(height: 14),
                    const Text(
                      'لا يوجد ريلز بعد',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'انشر أول ريل ليظهر لزبائنك في صفحة الريلز.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: _openStudio,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إنشاء ريل'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                // 9:16 — the shape a reel is actually shot and watched in.
                childAspectRatio: 9 / 16,
              ),
              itemCount: reels.length,
              itemBuilder: (_, i) => _ReelTile(
                reel: reels[i],
                onTap: () => _play(reels[i]),
                onMore: () => _openSheet(reels[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReelTile extends StatelessWidget {
  const _ReelTile({
    required this.reel,
    required this.onTap,
    required this.onMore,
  });

  final PostModel reel;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onMore,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(
              url: reel.thumbnail ?? reel.mediaUrl,
              fallbackIcon: Icons.movie_creation_rounded,
            ),
            // Bottom scrim so the counters stay readable on bright frames.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 62,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: .70),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            const Center(
              child: Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white70, size: 30),
            ),
            if (!reel.isPublished)
              PositionedDirectional(
                top: 6,
                start: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'مخفي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            PositionedDirectional(
              top: 2,
              end: 2,
              child: InkWell(
                onTap: onMore,
                borderRadius: BorderRadius.circular(99),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.more_vert_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: 6,
              start: 7,
              end: 7,
              child: Row(
                children: [
                  const Icon(Icons.visibility_rounded,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    _compact(reel.viewsCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.favorite_rounded,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    _compact(reel.likesCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1200 → "1.2k" so the counters fit a third-width tile.
  static String _compact(int n) {
    if (n < 1000) return '$n';
    final k = n / 1000;
    return '${k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
  }
}
