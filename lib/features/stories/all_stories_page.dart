import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../vendors/story_viewer_page.dart';
import '../../widgets/shell_bottom_nav.dart';

/// App-wide stories screen: every vendor that has active stories, shown as
/// Instagram-style rings. Tapping a ring opens that vendor's stories in the
/// full-screen viewer. Replaces the old search tab in the bottom nav.
class AllStoriesPage extends StatefulWidget {
  const AllStoriesPage({super.key});

  @override
  State<AllStoriesPage> createState() => _AllStoriesPageState();
}

class _AllStoriesPageState extends State<AllStoriesPage> {
  final _service = StoryService();
  late Future<List<_VendorStories>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Fetch all stories and group them by vendor (preserving newest-first order).
  Future<List<_VendorStories>> _load() async {
    final stories = await _service.listAll();
    final order = <int>[];
    final byVendor = <int, _VendorStories>{};
    for (final s in stories) {
      final v = s.vendor;
      final vid = v?.id ?? s.vendorId;
      if (v == null || vid == null) continue;
      if ((s.image).isEmpty) continue;
      final group = byVendor[vid];
      if (group == null) {
        order.add(vid);
        byVendor[vid] = _VendorStories(vendor: v, stories: [s]);
      } else {
        group.stories.add(s);
      }
    }
    return order.map((id) => byVendor[id]!).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const ShellBottomNav(),
      backgroundColor: AppColors.background,
      appBar: const PinkAppBar(title: 'القصص', showBack: false),
      body: FutureBuilder<List<_VendorStories>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
              message: snap.error.toString(),
              onRetry: _refresh,
            );
          }
          final groups = snap.data ?? const <_VendorStories>[];
          if (groups.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.28),
                  const Icon(Icons.auto_awesome_rounded,
                      size: 64, color: AppColors.primaryLight),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'لا توجد قصص حالياً',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text('اسحب للأسفل للتحديث',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 120),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 18,
                crossAxisSpacing: 12,
                childAspectRatio: 0.74,
              ),
              itemCount: groups.length,
              itemBuilder: (_, i) => _StoryRingTile(group: groups[i]),
            ),
          );
        },
      ),
    );
  }
}

class _VendorStories {
  _VendorStories({required this.vendor, required this.stories});
  final VendorModel vendor;
  final List<StoryModel> stories;
}

/// One vendor's story ring + name + count. Tapping opens the story viewer.
class _StoryRingTile extends StatelessWidget {
  const _StoryRingTile({required this.group});
  final _VendorStories group;

  @override
  Widget build(BuildContext context) {
    final vendor = group.vendor;
    final cover = group.stories.first.image;
    final logo = vendor.logo;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryViewerPage(
            vendor: vendor,
            stories: group.stories,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Gradient story ring.
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Color(0xFFF4C64B),
                      Color(0xFFE1306C),
                      Color(0xFFC13584),
                      Color(0xFFF4C64B),
                      Color(0xFFFF7A45),
                      Color(0xFFF4C64B),
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: AppNetworkImage(
                      url: (logo != null && logo.isNotEmpty) ? logo : cover,
                      fallbackIcon: Icons.storefront_rounded,
                    ),
                  ),
                ),
              ),
              // Story count badge.
              Positioned(
                bottom: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1306C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '${group.stories.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            vendor.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
