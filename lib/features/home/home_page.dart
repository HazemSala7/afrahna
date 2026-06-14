import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/models/models.dart';
import '../../core/services/location_service.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_widgets.dart';
import '../account/account_page.dart';
import '../assistant/assistant_page.dart';
import '../calendar/calendar_page.dart';
import '../categories/categories_page.dart';
import '../categories/category_tabs_page.dart';
import '../coordinator/coordinator_page.dart';
import '../favorites/favorites_page.dart';
import '../invitations/invitations_page.dart';
import '../notifications/notifications_page.dart';
import '../offers/offers_page.dart';
import '../reels/reels_page.dart';
import '../tasks/tasks_page.dart';
import '../vendors/vendor_details_page.dart';
import '../vendors/vendors_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialTab = 2});

  /// Tab to show when the shell is first built (2 = الرئيسية).
  final int initialTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _currentTab = widget.initialTab; // الرئيسية = الوسط (افتراضي)

  @override
  Widget build(BuildContext context) {
    // In an RTL Row, the first child is rendered at the start (visual RIGHT).
    // For natural Arabic UX we want: حسابي (account) on the RIGHT
    // and بحث (search) on the LEFT, with الرئيسية in the centre.
    // Children order (start→end / right→left): حسابي، المفضلة، الرئيسية، ريلز، بحث.
    final pages = <Widget>[
      const AccountPage(),          // 0 - حسابي (rightmost)
      const FavoritesPage(),        // 1 - المفضلة
      const _HomeTab(),             // 2 - الرئيسية (centre)
      const ReelsPage(),            // 3 - ريلز
      const _SearchTab(),           // 4 - بحث (leftmost)
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _currentTab, children: pages),
      floatingActionButton: _currentTab == 2
          ? AiCompanionFab(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AssistantPage()),
                );
              },
            )
          : null,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: AppBottomNav(
        current: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
      ),
    );
  }
}

// ===========================================================================
// HOME TAB
// ===========================================================================

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late Future<List<CategoryModel>> _categoriesFuture;
  late Future<List<PromotionModel>> _promosFuture;
  late Future<List<VendorModel>> _topVendorsFuture;
  late Future<List<VendorModel>> _featuredVendorsFuture;
  late Future<List<SliderModel>> _slidersFuture;

  Position? _userPos;

  @override
  void initState() {
    super.initState();
    _load();
    _loadLocation();
  }

  void _load() {
    _categoriesFuture = CategoryService().list(tree: true);
    _promosFuture = PromotionService().list();
    _topVendorsFuture = VendorService().list();
    _featuredVendorsFuture =
        VendorService().list(featured: true, perPage: 12);
    _slidersFuture = SliderService().list();
  }

  Future<void> _loadLocation() async {
    final pos = await LocationService.instance.current();
    if (mounted && pos != null) {
      setState(() => _userPos = pos);
    }
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([
      _categoriesFuture,
      _promosFuture,
      _topVendorsFuture,
      _featuredVendorsFuture,
      _slidersFuture,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
            children: [
              const _TopBar(),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: const _SearchBar(),
              ),
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: _CategoriesGrid(future: _categoriesFuture),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _HeroBanner(future: _slidersFuture),
              ),
              const SizedBox(height: 15),
              FadeSlideIn(
                delay: const Duration(milliseconds: 380),
                child: _SectionHeader(
                  title: 'الشركات المميّزة',
                  emoji: '🏆',
                  onSeeAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VendorsPage(
                        title: 'الشركات المميّزة',
                        featuredOnly: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 440),
                child: _FeaturedVendorsCarousel(
                    future: _featuredVendorsFuture, userPos: _userPos),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                delay: const Duration(milliseconds: 460),
                child: CountdownCard(
                  title: 'موسم الأعراس يبدأ — لا تفوّت العروض',
                  target: DateTime.now()
                      .add(const Duration(days: 30)),
                ),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                delay: const Duration(milliseconds: 480),
                child: _SectionHeader(
                  title: 'عروض اليوم',
                  emoji: '🔥',
                  onSeeAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OffersPage()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 540),
                child: _OffersRow(future: _promosFuture),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                delay: const Duration(milliseconds: 520),
                child: _SectionHeader(
                  title: 'الأكثر تقييماً',
                  emoji: '⭐',
                  onSeeAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VendorsPage()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 580),
                child: _TopRatedRow(future: _topVendorsFuture, userPos: _userPos),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                delay: const Duration(milliseconds: 660),
                child: const _QuickActionsRow(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// TOP BAR
// ===========================================================================

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // start (right in RTL) → invisible spacer to keep logo centered
        const SizedBox(width: 40, height: 40),
        const Spacer(),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    AppAssets.logo,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'أفراحنا',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              'كل مناسباتك في مكان واحد',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
        const Spacer(),
        // end (left in RTL) → notifications
        Stack(
          clipBehavior: Clip.none,
          children: [
            _CircleIconButton(
              icon: Icons.notifications_none_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.discount,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.textDark, size: 22),
        ),
      ),
    );
  }
}

// ===========================================================================
// SEARCH BAR
// ===========================================================================

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextField(
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          if (v.trim().isEmpty) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VendorsPage(title: 'نتائج: $v'),
            ),
          );
        },
        decoration: InputDecoration(
          hintText: 'ابحث عن خدمات، محلات، عروض والمزيد...',
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          suffixIcon: Container(
            margin: const EdgeInsetsDirectional.only(end: 6),
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// HERO BANNER
// ===========================================================================

class _HeroBanner extends StatefulWidget {
  const _HeroBanner({required this.future});
  final Future<List<SliderModel>> future;

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  final _controller = PageController();
  int _index = 0;
  Timer? _timer;
  List<SliderModel> _slides = const [];

  static const List<SliderModel> _fallback = [
    SliderModel(
      id: -1,
      image: '',
      titleAr: 'أفخم قاعات الأفراح',
      subtitleAr: 'احجز قاعة أحلامك بأفضل الأسعار',
      ctaAr: 'استكشف القاعات',
      badgeAr: 'إعلان مميّز',
    ),
  ];

  void _startTimer() {
    _timer?.cancel();
    if (_slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SliderModel>>(
      future: widget.future,
      builder: (context, snap) {
        final data = snap.data ?? const <SliderModel>[];
        final slides = data.isNotEmpty ? data : _fallback;
        if (!identical(slides, _slides)) {
          _slides = slides;
          if (_index >= _slides.length) _index = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer());
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 200,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _HeroSlideView(slide: _slides[i]),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: SparkleOverlay(count: 14),
                  ),
                ),
                if (_slides.length > 1)
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroSlideView extends StatelessWidget {
  const _HeroSlideView({required this.slide});
  final SliderModel slide;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OffersPage()),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image background (falls back to brand gradient on error / empty).
          if (slide.image.isNotEmpty)
            AppNetworkImage(
              url: slide.image,
              fallbackIcon: Icons.celebration,
            )
          else
            Container(
              decoration: const BoxDecoration(
                  gradient: AppColors.brandDeepGradient),
            ),
          // Dark overlay so text stays readable.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.55),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Badge (top-start = top-right in RTL).
          if (slide.badge.isNotEmpty)
            PositionedDirectional(
              top: 12,
              start: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  slide.badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          // Text content.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  slide.title,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(blurRadius: 6, color: Colors.black54),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  slide.subtitle,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                  ),
                ),
                if (slide.cta.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OffersPage()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(slide.cta),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// CATEGORIES GRID (2 rows × 5 columns)
// ===========================================================================

IconData _iconForCategory(String name) {
  final n = name.toLowerCase();
  if (n.contains('سيار') || n.contains('car')) {
    return Icons.directions_car_filled_rounded;
  }
  if (n.contains('فستان') || n.contains('بدل') || n.contains('dress')) {
    return Icons.checkroom_rounded;
  }
  if (n.contains('dj') || n.contains('موسيق') || n.contains('زف')) {
    return Icons.music_note_rounded;
  }
  if (n.contains('صور') || n.contains('استوديو') || n.contains('photo')) {
    return Icons.photo_camera_rounded;
  }
  if (n.contains('قاع') || n.contains('صال') || n.contains('hall')) {
    return Icons.holiday_village_rounded;
  }
  if (n.contains('حلوي') || n.contains('كيك') || n.contains('cake')) {
    return Icons.cake_rounded;
  }
  if (n.contains('ورد') || n.contains('زهور') || n.contains('flower')) {
    return Icons.local_florist_rounded;
  }
  if (n.contains('فندق') || n.contains('شقة') || n.contains('hotel')) {
    return Icons.hotel_rounded;
  }
  if (n.contains('مطعم') ||
      n.contains('قهوة') ||
      n.contains('طعام') ||
      n.contains('cater')) {
    return Icons.local_cafe_rounded;
  }
  if (n.contains('مكياج') || n.contains('makeup')) {
    return Icons.face_retouching_natural;
  }
  if (n.contains('دعو') || n.contains('invit')) {
    return Icons.mail_rounded;
  }
  return Icons.category_rounded;
}

class _CategoriesGrid extends StatefulWidget {
  const _CategoriesGrid({required this.future});
  final Future<List<CategoryModel>> future;

  @override
  State<_CategoriesGrid> createState() => _CategoriesGridState();
}

class _CategoriesGridState extends State<_CategoriesGrid> {
  final ScrollController _controller = ScrollController();
  Timer? _hintTimer;
  bool _userInteracted = false;

  @override
  void initState() {
    super.initState();
    // Subtle periodic "nudge" so users notice the list is scrollable.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startHintLoop());
  }

  void _startHintLoop() {
    _hintTimer?.cancel();
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _userInteracted) return;
      if (!_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) return;
      final current = _controller.offset;
      final target = current < 1 ? 28.0 : 0.0;
      await _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryModel>>(
      future: widget.future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 96,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5),
              ),
            ),
          );
        }
        final all = snap.data ?? const <CategoryModel>[];
        if (all.isEmpty) return const SizedBox.shrink();

        const showMoreThreshold = 12;
        final showMore = all.length > showMoreThreshold;
        final visible =
            showMore ? all.take(showMoreThreshold - 1).toList() : all;

        final items = <Widget>[
          for (final c in visible)
            _CategoryTile(
              label: c.name,
              icon: _iconForCategory(c.name),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => c.hasChildren
                      ? CategoryTabsPage(parent: c)
                      : VendorsPage(category: c),
                ),
              ),
            ),
          if (showMore)
            _CategoryTile(
              label: 'المزيد',
              icon: Icons.apps_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesPage()),
              ),
            ),
        ];

        const tileSize = 84.0;
        const spacing = 10.0;

        return SizedBox(
          height: tileSize,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is UserScrollNotification) {
                _userInteracted = true;
                _hintTimer?.cancel();
              }
              return false;
            },
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: spacing),
              itemBuilder: (_, i) => SizedBox(
                width: tileSize,
                height: tileSize,
                child: items[i],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// SECTION HEADER
// ===========================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.emoji,
    this.onSeeAll,
  });
  final String title;
  final String? emoji;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    // RTL: first child = start = right. We want title on the RIGHT
    // (first thing read in Arabic) and "عرض الكل" action on the LEFT.
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
        if (emoji != null) ...[
          const SizedBox(width: 6),
          Text(emoji!, style: const TextStyle(fontSize: 17)),
        ],
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Row(
              children: const [
                Text(
                  'عرض الكل',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                Icon(Icons.chevron_left,
                    color: AppColors.primary, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// OFFERS ROW
// ===========================================================================

class _OffersRow extends StatelessWidget {
  const _OffersRow({required this.future});
  final Future<List<PromotionModel>> future;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: FutureBuilder<List<PromotionModel>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5),
              ),
            );
          }
          final items = snap.data ?? const <PromotionModel>[];
          if (items.isEmpty) {
            return _EmptyMini(text: 'لا توجد عروض حالياً');
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _OfferCard(promo: items[i]),
          );
        },
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.promo});
  final PromotionModel promo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (promo.vendorId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VendorDetailsPage(vendorId: promo.vendorId!),
            ),
          );
        }
      },
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AppNetworkImage(
                      url: promo.image,
                      fallbackIcon: Icons.local_offer,
                    ),
                  ),
                  if (promo.discountPercent != null)
                    PositionedDirectional(
                      top: 10,
                      end: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.discount,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'خصم ${promo.discountPercent!.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          promo.vendor?.city?.name ??
                              promo.vendor?.name ??
                              'متوفر',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// FEATURED VENDORS CAROUSEL (controlled from admin panel via is_featured)
// ===========================================================================

class _FeaturedVendorsCarousel extends StatelessWidget {
  const _FeaturedVendorsCarousel({required this.future, this.userPos});
  final Future<List<VendorModel>> future;
  final Position? userPos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: FutureBuilder<List<VendorModel>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5),
              ),
            );
          }
          final items = (snap.data ?? const <VendorModel>[])
              .where((v) => v.isFeatured)
              .toList();
          _sortByProximity(items, userPos);
          if (items.isEmpty) {
            return _EmptyMini(text: 'لا توجد شركات مميّزة حالياً');
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _FeaturedVendorCard(vendor: items[i]),
          );
        },
      ),
    );
  }
}

/// Cover area for vendor cards. Shows the cover photo cropped to fill, or—when
/// there is no cover—a warm gradient with the logo centered and shown in full
/// (BoxFit.contain) so it is never cropped at the edges.
class _CardCover extends StatelessWidget {
  const _CardCover({required this.vendor});
  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    final hasCover = (vendor.cover ?? '').isNotEmpty;
    if (hasCover) {
      return AppNetworkImage(
        url: vendor.cover,
        fallbackIcon: Icons.storefront,
      );
    }
    final hasLogo = (vendor.logo ?? '').isNotEmpty;
    if (hasLogo) {
      return AppNetworkImage(
        url: vendor.logo,
        fit: BoxFit.cover,
        fallbackIcon: Icons.storefront,
      );
    }
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD9B68A),
            Color(0xFFB8835A),
            Color(0xFF8B5A3C),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.storefront, color: Colors.white, size: 40),
      ),
    );
  }
}

class _FeaturedVendorCard extends StatelessWidget {
  const _FeaturedVendorCard({required this.vendor});
  final VendorModel vendor;

  String? get _priceLabel {
    final min = vendor.minPrice;
    final max = vendor.maxPrice;
    if (min == null && max == null) return null;
    String fmt(double v) => v % 1 == 0
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(0);
    if (min != null && max != null && max > min) {
      return 'يبدأ من ${fmt(min)} ₪';
    }
    return 'يبدأ من ${fmt(min ?? max!)} ₪';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDetailsPage(vendorId: vendor.id),
        ),
      ),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          boxShadow: const [
            BoxShadow(
              color: Color(0x338B5A3C),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- COVER + OVERLAY ----------
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CardCover(vendor: vendor),
                  // gradient overlay for legibility
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00000000),
                          Color(0x99000000),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Featured badge (top start)
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: _FeaturedBadge(),
                  ),
                  // Verified mark (top end)
                  if (vendor.isVerified)
                    const PositionedDirectional(
                      top: 10,
                      end: 10,
                      child: _VerifiedBadge(),
                    ),
                  // Logo + name pinned to bottom
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                                color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: AppNetworkImage(
                              url: vendor.logo,
                              fit: BoxFit.contain,
                              fallbackIcon: Icons.storefront,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                vendor.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x99000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                              if (vendor.city != null)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 12,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        vendor.city!.nameAr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ---------- INFO ROW ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Rating pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6E0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFFD66B), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Color(0xFFE6A800)),
                            const SizedBox(width: 3),
                            Text(
                              (vendor.rating ?? 0).toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: AppColors.textDark,
                              ),
                            ),
                            if ((vendor.reviewsCount ?? 0) > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '(${vendor.reviewsCount})',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Category chip
                      if (vendor.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            vendor.category!.nameAr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_priceLabel != null) ...[
                        const Icon(Icons.local_offer_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _priceLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ] else
                        const Expanded(
                          child: Text(
                            'تواصل لمعرفة الأسعار',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFD4A373),
                              Color(0xFFB8835A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'عرض',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 11),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE6B450), Color(0xFFB8835A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 14),
          SizedBox(width: 4),
          Text(
            'مميَّز',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.95),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.verified_rounded,
        color: Color(0xFF1DA1F2),
        size: 20,
      ),
    );
  }
}

// ===========================================================================
// TOP RATED ROW
// ===========================================================================

/// Sorts vendors so that, when the user's location is known, nearer vendors
/// come first (those without coordinates fall to the end), then by rating.
/// Without a location it falls back to rating only.
void _sortByProximity(List<VendorModel> items, Position? userPos) {
  if (userPos == null) {
    items.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return;
  }
  items.sort((a, b) {
    final da = LocationService.distanceMeters(userPos, a.latitude, a.longitude);
    final db = LocationService.distanceMeters(userPos, b.latitude, b.longitude);
    if (da == null && db == null) {
      return (b.rating ?? 0).compareTo(a.rating ?? 0);
    }
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
}

class _TopRatedRow extends StatelessWidget {
  const _TopRatedRow({required this.future, this.userPos});
  final Future<List<VendorModel>> future;
  final Position? userPos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: FutureBuilder<List<VendorModel>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5),
              ),
            );
          }
          final items = [...(snap.data ?? const <VendorModel>[])];
          _sortByProximity(items, userPos);
          final top = items.take(8).toList();
          if (top.isEmpty) {
            return _EmptyMini(text: 'لا يوجد مزوّدون بعد');
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: top.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _TopRatedCard(vendor: top[i]),
          );
        },
      ),
    );
  }
}

class _TopRatedCard extends StatelessWidget {
  const _TopRatedCard({required this.vendor});
  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDetailsPage(vendorId: vendor.id),
        ),
      ),
      child: Container(
        width: 195,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: _CardCover(vendor: vendor),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        (vendor.rating ?? 0).toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFC107), size: 17),
                      const Spacer(),
                      if ((vendor.reviewsCount ?? 0) > 0)
                        Text(
                          '(${vendor.reviewsCount})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// QUICK ACTIONS
// ===========================================================================

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final items = <_QuickAction>[
      _QuickAction(
        icon: Icons.checklist_rtl_rounded,
        label: 'قائمة المهام',
        builder: (_) => const TasksPage(),
      ),
      _QuickAction(
        icon: Icons.calendar_month,
        label: 'التقويم الذكي',
        builder: (_) => const CalendarPage(),
      ),
      _QuickAction(
        icon: Icons.assignment_rounded,
        label: 'منسق المناسبة',
        builder: (_) => const CoordinatorPage(),
      ),
      _QuickAction(
        icon: Icons.mail_rounded,
        label: 'دعوات إلكترونية',
        builder: (_) => const InvitationsPage(),
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final a in items) _QuickActionTile(action: a),
        ],
      ),
    );
  }
}

class _QuickAction {
  _QuickAction({required this.icon, required this.label, this.builder});
  final IconData icon;
  final String label;
  final WidgetBuilder? builder;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (action.builder != null) {
            Navigator.of(context).push(MaterialPageRoute(builder: action.builder!));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('قريباً ✨'),
              backgroundColor: AppColors.primary,
            ));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(action.icon,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// EMPTY MINI
// ===========================================================================

class _EmptyMini extends StatelessWidget {
  const _EmptyMini({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text,
            style: const TextStyle(color: AppColors.textMuted)),
      ),
    );
  }
}

// ===========================================================================
// SEARCH TAB
// ===========================================================================

class _SearchTab extends StatefulWidget {
  const _SearchTab();
  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _controller = TextEditingController();
  Future<List<VendorModel>>? _future;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String q) {
    if (q.trim().isEmpty) {
      setState(() => _future = null);
      return;
    }
    setState(() => _future = VendorService().list(query: q.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'البحث',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن خدمات، محلات، عروض...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    prefixIcon:
                        Icon(Icons.search, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _future == null
                    ? const Center(
                        child: Text(
                          'ابدأ بكتابة ما تبحث عنه',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : FutureBuilder<List<VendorModel>>(
                        future: _future,
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const CenteredLoader();
                          }
                          if (snap.hasError) {
                            return ErrorState(
                                message: snap.error.toString());
                          }
                          final items = snap.data ?? const [];
                          if (items.isEmpty) {
                            return const EmptyState(
                              message: 'لا نتائج مطابقة',
                              icon: Icons.search_off,
                            );
                          }
                          return ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final v = items[i];
                              return _SearchResultTile(vendor: v);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.vendor});
  final VendorModel vendor;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDetailsPage(vendorId: vendor.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: AppNetworkImage(
                  url: vendor.logo ?? vendor.cover,
                  fallbackIcon: Icons.storefront,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vendor.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  if (vendor.category != null)
                    Text(vendor.category!.name,
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 12)),
                ],
              ),
            ),
            RatingRow(rating: vendor.rating ?? 0),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// BOTTOM NAV
// ===========================================================================
// The bottom navigation bar now lives in `widgets/app_bottom_nav.dart`
// (AppBottomNav) so it can be reused on full-screen pages such as the vendor
// profile.

// ===========================================================================
// API DEBUG PANEL (visible in debug builds only)
// ===========================================================================

class _ApiCallLog {
  _ApiCallLog({required this.url, required this.status, required this.body});
  final String url;
  final int? status;
  final String body;
}

class _ApiDebugPanel extends StatelessWidget {
  const _ApiDebugPanel({required this.logs});
  final List<_ApiCallLog> logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API DEBUG',
              style: TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              const Text(
                'Loading...',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              )
            else
              ...logs.map((log) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (log.status ?? 0) >= 200 &&
                                        (log.status ?? 0) < 300
                                    ? Colors.green
                                    : Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${log.status ?? 'ERR'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                log.url,
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.copy,
                                  size: 14, color: Colors.white54),
                              onPressed: () => Clipboard.setData(
                                  ClipboardData(text: log.body)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 160),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              log.body,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontFamily: 'monospace',
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}