import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/services/event_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../core/utils/category_icon.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_widgets.dart';
import '../account/account_page.dart';
import '../assistant/assistant_page.dart';
import '../auth/login_page.dart';
import '../categories/categories_page.dart';
import '../categories/category_tabs_page.dart';
import '../coordinator/coordinator_page.dart';
import '../invitation/invitation_designer_page.dart';
import 'home_feed_cache.dart';
import '../favorites/favorites_page.dart';
import '../planning/planning_hub_page.dart';
import '../notifications/notifications_page.dart';
import '../competition/competition_dialog.dart';
import '../offers/offer_details_page.dart';
import '../offers/offers_page.dart';
import '../posts/post_details_page.dart';
import '../reels/reels_page.dart';
import '../stories/all_stories_page.dart';
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
    // Guest encouragement banner: pinned above the bottom nav on the home tab.
    // It stays visible for as long as the user has no account (not dismissible).
    final isGuest = !context.watch<SessionController>().isSignedIn;
    final showGuestBanner = isGuest && _currentTab == 2;
    // In an RTL Row, the first child is rendered at the start (visual RIGHT).
    // For natural Arabic UX we want: حسابي (account) on the RIGHT
    // and القصص (stories) on the LEFT, with الرئيسية in the centre.
    // Children order (start→end / right→left): حسابي، خطّطي، الرئيسية، ريلز، القصص.
    final pages = <Widget>[
      const AccountPage(),          // 0 - حسابي (rightmost)
      const PlanningHubPage(),      // 1 - خطّطي (planning tools hub)
      const _HomeTab(),             // 2 - الرئيسية (centre)
      const ReelsPage(),            // 3 - ريلز
      const AllStoriesPage(),       // 4 - القصص (leftmost)
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _currentTab, children: pages),
      // AI companion floats on its own when logged in; for guests it sits
      // inline next to the "join" banner (below) so the space is used nicely.
      floatingActionButton: (_currentTab == 2 && !showGuestBanner)
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showGuestBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  // AI companion beside the join banner — fills the space nicely.
                  AiCompanionFab(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AssistantPage()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GuestPromoBanner(
                      onLogin: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          AppBottomNav(
            current: _currentTab,
            onTap: (i) {
              setState(() => _currentTab = i);
              // Re-show the competition popup whenever the user returns to home
              // (until they've predicted).
              if (i == 2) maybeShowCompetition(context);
            },
          ),
        ],
      ),
    );
  }
}

/// Approximate rendered height of [_GuestPromoBanner] including its margins.
/// Used to reserve scroll padding under the extend-body home list.
const double _kGuestBannerHeight = 96;

/// Pinned bottom banner encouraging guests to create an account / log in.
class _GuestPromoBanner extends StatelessWidget {
  const _GuestPromoBanner({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'انضم إلى أفراحنا! ✨',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'سجّل حسابك لتتابع، تقيّم، وتحفظ مفضّلاتك',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onLogin,
              child: const Text(
                'تسجيل الدخول',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
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
  late Future<List<PostModel>> _latestPostsFuture;
  late Future<HomeStats> _statsFuture;
  Future<EventModel?> _mainEventFuture = Future.value(null);

  Position? _userPos;

  @override
  void initState() {
    super.initState();
    _load(useCache: true);
    _loadLocation();
    // Show the active prediction competition once per app launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowCompetition(context);
    });
  }

  void _load({bool useCache = false}) {
    final cache = HomeFeedCache.instance;
    // On first show, consume the data prefetched during the splash screen so
    // the home tab appears instantly. Refreshes always fetch fresh data.
    if (useCache && cache.isReady) {
      _categoriesFuture = cache.categories!;
      _promosFuture = cache.promos!;
      _topVendorsFuture = cache.topVendors!;
      _featuredVendorsFuture = cache.featuredVendors!;
      _slidersFuture = cache.sliders!;
      _statsFuture = cache.stats!;
      cache.clear();
    } else {
      _categoriesFuture = CategoryService().list(tree: true);
      _promosFuture = PromotionService().list();
      _topVendorsFuture = VendorService().list();
      // Featured: fresh random order on each load.
      _featuredVendorsFuture = VendorService()
          .list(featured: true, perPage: 1000)
          .then((l) => l..shuffle());
      // Hero slider = admin slides + VIP vendors, shuffled fresh each load.
      _slidersFuture = HomeFeedCache.loadSliders();
      _statsFuture = StatsService().get();
    }
    // Latest posts (newest first) for the home "آخر المنشورات" row.
    _latestPostsFuture = PostService().list(type: PostType.post, perPage: 15);
    _mainEventFuture = _loadMainEvent();
  }

  /// Only signed-in users have a personal event; guests get nothing.
  Future<EventModel?> _loadMainEvent() async {
    if (!context.read<SessionController>().isSignedIn) return null;
    try {
      return await EventService().main();
    } catch (_) {
      return null;
    }
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
      _mainEventFuture,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // The shell uses `extendBody: true`, so this list scrolls *behind* the
    // bottom nav (and, for guests, the "join" banner). Reserve exactly their
    // combined height so the last sections are never hidden underneath them.
    final isGuest = !context.watch<SessionController>().isSignedIn;
    final bottomReserve = AppBottomNav.contentHeight +
        MediaQuery.of(context).padding.bottom +
        (isGuest ? _kGuestBannerHeight : 0) +
        16;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, 8, 0, bottomReserve),
            children: [
              _hpad(const _TopBar()),
              const SizedBox(height: 16),
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: const _SearchBar(),
              )),
              const SizedBox(height: 18),
              // Full-width auto-scrolling categories (no side gaps).
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: _CategoriesGrid(future: _categoriesFuture),
              ),
              const SizedBox(height: 22),
              // Hero slider with side margins (aligned with the rest of the page).
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _HeroBanner(future: _slidersFuture),
              )),
              const SizedBox(height: 20),
              // Featured companies — placed right below the hero slider/ads.
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 320),
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
              )),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 360),
                child: _FeaturedVendorsCarousel(
                    future: _featuredVendorsFuture, userPos: _userPos),
              ),
              FutureBuilder<EventModel?>(
                future: _mainEventFuture,
                builder: (context, snap) {
                  final event = snap.data;
                  if (event == null ||
                      event.startsAt.isBefore(DateTime.now())) {
                    return const SizedBox.shrink();
                  }
                  return _hpad(Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 380),
                      child: CountdownCard(
                        title: event.title,
                        target: event.startsAt,
                      ),
                    ),
                  ));
                },
              ),
              const SizedBox(height: 22),
              // Planning tools: prominent coordinator banner + a row of 3 tools.
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 320),
                child: Column(
                  children: [
                    const _SectionHeader(title: 'خطّطي فرحك', emoji: '✨'),
                    const SizedBox(height: 12),
                    // Coordinator + card designer side by side.
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _PlanCompactCard(
                              colors: const [
                                Color(0xFF57B3A8),
                                Color(0xFF4FA69C),
                                Color(0xFF2F7C74),
                              ],
                              icon: Icons.assignment_rounded,
                              title: 'منسق المناسبة',
                              subtitle: 'خطّطي تفاصيل يومك خطوة بخطوة',
                              badge: 'مميّز',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CoordinatorPage()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PlanCompactCard(
                              colors: const [
                                Color(0xFF8B5A3C),
                                Color(0xFFB8835A),
                                Color(0xFFD4A373),
                              ],
                              icon: Icons.card_giftcard_rounded,
                              title: 'صمّم كرت فرحك',
                              subtitle: 'اختر قالبك واطلبه من أفراحنا',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const InvitationDesignerPage()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const PlanningToolsRow(),
                  ],
                ),
              )),
              const SizedBox(height: 20),
              // Stats band with side margins.
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 340),
                child: _StatsBand(future: _statsFuture),
              )),
              const SizedBox(height: 15),
              // "Advertise with us" call-to-action aimed at business owners:
              // placed right after the reach stats so the numbers prime them.
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 360),
                child: const _AdvertiseCta(),
              )),
              const SizedBox(height: 22),
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 480),
                child: _SectionHeader(
                  title: 'عروض اليوم',
                  emoji: '🔥',
                  onSeeAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OffersPage()),
                  ),
                ),
              )),
              const SizedBox(height: 12),
              // Full-width offers row.
              FadeSlideIn(
                delay: const Duration(milliseconds: 540),
                child: _OffersRow(future: _promosFuture),
              ),
              const SizedBox(height: 22),
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 520),
                child: _SectionHeader(
                  title: 'الأكثر تقييماً',
                  emoji: '⭐',
                  onSeeAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VendorsPage()),
                  ),
                ),
              )),
              const SizedBox(height: 12),
              // Full-width top-rated row.
              FadeSlideIn(
                delay: const Duration(milliseconds: 580),
                child: _TopRatedRow(future: _topVendorsFuture, userPos: _userPos),
              ),
              const SizedBox(height: 26),
              // Latest posts — horizontal scroll of the newest vendor posts.
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 600),
                child: const _SectionHeader(
                  title: 'آخر المنشورات',
                  emoji: '📝',
                ),
              )),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 640),
                child: _LatestPostsRow(future: _latestPostsFuture),
              ),
              const SizedBox(height: 28),
              // Wedding-planning tips (full-width horizontal cards).
              FadeSlideIn(
                delay: const Duration(milliseconds: 620),
                child: const _TipsSection(),
              ),
              const SizedBox(height: 26),
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 640),
                child: const _WhyAfrahnaSection(),
              )),
              const SizedBox(height: 26),
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 660),
                child: const _AppFooter(),
              )),
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
        // start (right in RTL) → favorites shortcut (moved here from the nav).
        _CircleIconButton(
          icon: Icons.favorite_border_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FavoritesPage()),
          ),
        ),
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

class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    // Always drop focus so the keyboard closes after a search action.
    FocusScope.of(context).unfocus();
    if (v.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VendorsPage(title: 'نتائج: $v', initialQuery: v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
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
          suffixIcon: GestureDetector(
            onTap: _submit,
            child: Container(
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
      ),
    );
  }
}

// ===========================================================================
// STATS BAND (homepage counts — real, admin-overridable)
// ===========================================================================

class _StatsBand extends StatelessWidget {
  const _StatsBand({required this.future});
  final Future<HomeStats> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeStats>(
      future: future,
      builder: (_, snap) {
        final s = snap.data;
        if (s == null) return const SizedBox.shrink();
        // Coordinated warm pastel palette that harmonizes with the gold band.
        final items =
            <({IconData icon, int value, String label, Color color, VoidCallback? onTap, bool pulse, bool compact})>[
          (icon: Icons.store_mall_directory_rounded, value: s.vendors, label: 'شركة',
              color: Color(0xFFF6B25C), onTap: null, pulse: false, compact: false),
          (icon: Icons.visibility_rounded, value: s.visitors, label: 'زائر',
              color: Color(0xFFF48CA0), onTap: null, pulse: false, compact: false),
          // Users is the only tile shown abbreviated (e.g. 21.2K).
          (icon: Icons.groups_rounded, value: s.users, label: 'مستخدم',
              color: Color(0xFF7FC6C0), onTap: null, pulse: false, compact: true),
          // "عروض" is highlighted + animated + tappable → opens all offers.
          (icon: Icons.local_fire_department_rounded, value: s.offers, label: 'عروض',
              color: Color(0xFFF6A93B),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const OffersPage())),
              pulse: true, compact: false),
          (icon: Icons.holiday_village_rounded, value: s.cities, label: 'مدينة',
              color: Color(0xFFC7A9E0), onTap: null, pulse: false, compact: false),
        ];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5A3C), AppColors.primary, Color(0xFFC79A6A)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                Expanded(
                  child: _StatCell(
                    icon: items[i].icon,
                    value: items[i].value,
                    label: items[i].label,
                    accent: items[i].color,
                    delay: i * 160,
                    onTap: items[i].onTap,
                    pulse: items[i].pulse,
                    compact: items[i].compact,
                  ),
                ),
                if (i != items.length - 1)
                  Container(
                    width: 1,
                    height: 48,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.delay = 0,
    this.onTap,
    this.pulse = false,
    this.compact = false,
  });
  final IconData icon;
  final int value;
  final String label;
  final Color accent;
  final int delay;
  final VoidCallback? onTap;
  final bool pulse;

  /// Show the number abbreviated (K/M) instead of fully grouped.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget circle = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Glossy two-tone accent badge.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.white, 0.28)!,
            accent,
            Color.lerp(accent, Colors.black, 0.12)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft glossy highlight near the top.
          Positioned(
            top: 6,
            child: Container(
              width: 22,
              height: 9,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Icon(icon, color: Colors.white, size: 23),
        ],
      ),
    );
    if (pulse) circle = _Pulse(child: circle);

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 8),
        _CountUp(value: value, delay: delay, compact: compact),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Icon(Icons.chevron_left,
                    color: Colors.white70, size: 14),
              ),
          ],
        ),
      ],
    );

    if (onTap == null) return column;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: column,
    );
  }
}

/// Gentle repeating pulse to draw attention (used on the tappable offers stat).
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);
  late final Animation<double> _a =
      Tween(begin: 1.0, end: 1.14).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _a, child: widget.child);
}

/// Animated count-up number (animates 0 → value once on first appearance,
/// with an optional stagger [delay] so cells fire one after another).
class _CountUp extends StatefulWidget {
  const _CountUp({required this.value, this.delay = 0, this.compact = false});
  final int value;
  final int delay;

  /// Abbreviate as K/M instead of showing the full grouped number.
  final bool compact;

  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, _) {
        final v = (widget.value * _a.value).round();
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.compact ? _formatK(v) : _formatCompact(v),
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              height: 1.0,
              letterSpacing: 0.2,
              shadows: [
                Shadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Wraps a widget with the standard horizontal page padding (16). Used so the
/// home list can be edge-to-edge for full-width sections (slider, categories,
/// featured) while normal sections keep their side margins.
Widget _hpad(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

/// Drives a horizontal [ScrollController] in a slow, continuous ping-pong
/// motion (marquee-like). Pauses when the user drags, then resumes shortly
/// after. Used by the categories and featured rows.
class _AutoScroller {
  _AutoScroller({this.speed = 0.4});
  final double speed; // pixels per tick (~33 ticks/sec)

  ScrollController? _c;
  Timer? _timer;
  Timer? _resume;
  double _dir = 1;

  void attach(ScrollController c) {
    _c = c;
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      final c = _c;
      if (c == null || !c.hasClients) return;
      final max = c.position.maxScrollExtent;
      if (max <= 0) return;
      var next = c.offset + _dir * speed;
      if (next >= max) {
        next = max;
        _dir = -1;
      } else if (next <= 0) {
        next = 0;
        _dir = 1;
      }
      c.jumpTo(next);
    });
  }

  /// Pause auto-scroll (e.g. while the user is dragging) and resume after 3s.
  void pause() {
    _timer?.cancel();
    _timer = null;
    _resume?.cancel();
    _resume = Timer(const Duration(seconds: 3), _start);
  }

  void dispose() {
    _timer?.cancel();
    _resume?.cancel();
    _c = null;
  }
}

/// Full number with thousands grouping for the stats band (e.g. 21000 →
/// "21,000") so users can watch the exact count grow — no K/M abbreviation.
String _formatCompact(int n) {
  final neg = n < 0;
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return (neg ? '-' : '') + buf.toString();
}

/// Abbreviated number for the "مستخدم" tile only (e.g. 21241 → "21.2K").
String _formatK(int n) {
  final neg = n < 0;
  final a = n.abs();
  String out;
  if (a >= 1000000) {
    final v = a / 1000000;
    out = '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
  } else if (a >= 1000) {
    final v = a / 1000;
    out = '${v.toStringAsFixed(v >= 100 ? 0 : 1)}K';
  } else {
    out = '$a';
  }
  return (neg ? '-' : '') + out;
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
          // Rounded card that sits within the page's side margins.
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: double.infinity,
            height: 240,
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
                    child: Builder(builder: (_) {
                      // Never render more than 10 dots — with many VIP slides a
                      // full row becomes a cramped, unreadable line. Slides past
                      // the 10th keep the last dot active so there's always an
                      // indicator lit.
                      const maxDots = 10;
                      final dotCount = _slides.length > maxDots
                          ? maxDots
                          : _slides.length;
                      final activeDot =
                          _index >= dotCount ? dotCount - 1 : _index;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(dotCount, (i) {
                          final active = i == activeDot;
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
                      );
                    }),
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
        MaterialPageRoute(
          builder: (_) => slide.vendorId != null
              ? VendorDetailsPage(vendorId: slide.vendorId!)
              : const OffersPage(),
        ),
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


/// Harmonious warm tints rotated across category tiles so the row feels lively
/// and distinctive instead of a repeating block of monochrome brown. All hues
/// sit in the same warm/earthy family as the app theme.
const List<Color> _categoryTints = [
  Color(0xFFDD8A6A), // terracotta
  Color(0xFFCB9A3E), // warm gold
  Color(0xFF8FA97E), // sage
  Color(0xFFD98CA0), // blush rose
  Color(0xFFAF8FC4), // soft mauve
  Color(0xFF5FA9A0), // dusty teal
  Color(0xFFC58256), // caramel
];

class _CategoriesGrid extends StatefulWidget {
  const _CategoriesGrid({required this.future});
  final Future<List<CategoryModel>> future;

  @override
  State<_CategoriesGrid> createState() => _CategoriesGridState();
}

class _CategoriesGridState extends State<_CategoriesGrid> {
  final ScrollController _controller = ScrollController();
  final _auto = _AutoScroller(speed: 0.35);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _auto.attach(_controller));
  }

  @override
  void dispose() {
    _auto.dispose();
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
              child: AfrahnaLoader(size: 42),
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
          for (final (i, c) in visible.indexed)
            _CategoryTile(
              label: c.name,
              icon: categoryIcon(c.name),
              tint: _categoryTints[i % _categoryTints.length],
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
              tint: AppColors.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesPage()),
              ),
            ),
        ];

        const tileWidth = 78.0;
        const tileHeight = 96.0;
        const spacing = 8.0;

        return SizedBox(
          height: tileHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is UserScrollNotification) _auto.pause();
              return false;
            },
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: spacing),
              itemBuilder: (_, i) => SizedBox(
                width: tileWidth,
                height: tileHeight,
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
    required this.tint,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Soft gradient "squircle" badge with a tinted glow — gives each
          // category its own colour so the row reads lively, not repetitive.
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(tint.withValues(alpha: 0.20), Colors.white),
                  Color.alphaBlend(tint.withValues(alpha: 0.42), Colors.white),
                ],
              ),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: tint.withValues(alpha: 0.30),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: tint.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle glossy highlight in the top corner.
                Positioned(
                  top: 8,
                  right: 10,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Icon(icon, color: tint, size: 27),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              height: 1.15,
            ),
          ),
        ],
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
              child: AfrahnaLoader(size: 42),
            );
          }
          final items = snap.data ?? const <PromotionModel>[];
          if (items.isEmpty) {
            return _EmptyMini(text: 'لا توجد عروض حالياً');
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
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
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfferDetailsPage(promo: promo),
        ),
      ),
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

class _FeaturedVendorsCarousel extends StatefulWidget {
  const _FeaturedVendorsCarousel({required this.future, this.userPos});
  final Future<List<VendorModel>> future;
  final Position? userPos;

  @override
  State<_FeaturedVendorsCarousel> createState() =>
      _FeaturedVendorsCarouselState();
}

class _FeaturedVendorsCarouselState extends State<_FeaturedVendorsCarousel> {
  final ScrollController _controller = ScrollController();
  final _auto = _AutoScroller(speed: 0.45);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _auto.attach(_controller));
  }

  @override
  void dispose() {
    _auto.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final future = widget.future;
    final userPos = widget.userPos;
    return SizedBox(
      // Prominent circular row of featured shops.
      height: 150,
      child: FutureBuilder<List<VendorModel>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: AfrahnaLoader(size: 42),
            );
          }
          if (snap.hasError) {
            return _EmptyMini(text: 'تعذّر تحميل الشركات المميّزة');
          }
          // Trust the server's `featured=1` filter (avoid double-filtering,
          // which hid vendors when the boolean wasn't parsed as expected).
          final items = List<VendorModel>.from(snap.data ?? const <VendorModel>[]);
          _sortByProximity(items, userPos);
          if (items.isEmpty) {
            return _EmptyMini(text: 'لا توجد شركات مميّزة حالياً');
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is UserScrollNotification) _auto.pause();
              return false;
            },
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(
                  start: 16, end: 16, top: 4, bottom: 4),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _FeaturedVendorCard(vendor: items[i]),
            ),
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

/// Compact circular featured-vendor avatar — intentionally smaller and less
/// prominent than the hero slider above the section.
class _FeaturedVendorCard extends StatelessWidget {
  const _FeaturedVendorCard({required this.vendor});
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
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Thin gold ring around the logo.
                Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFFE6B450),
                        AppColors.primary,
                        Color(0xFFF3D9B1),
                        AppColors.primaryDark,
                        Color(0xFFE6B450),
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
                        url: vendor.logo ?? vendor.cover,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.storefront,
                      ),
                    ),
                  ),
                ),
                // Sits just inside the gold ring so it doesn't break the
                // circle's outline.
                PositionedDirectional(
                  bottom: 2,
                  end: 2,
                  child: TierBadge(
                    vip: vendor.isVip,
                    featured: vendor.isPremium ||
                        vendor.activePlan == 'featured',
                    size: 19,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              vendor.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            if (vendor.rating != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded,
                      size: 13, color: Color(0xFFE6A800)),
                  const SizedBox(width: 2),
                  Text(
                    vendor.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
          ],
        ),
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
              child: AfrahnaLoader(size: 42),
            );
          }
          // "الأكثر تقييماً" — show only vendors with a full 5/5 rating.
          final items = [
            ...(snap.data ?? const <VendorModel>[])
                .where((v) => (v.rating ?? 0) >= 5.0),
          ];
          _sortByProximity(items, userPos);
          final top = items.take(8).toList();
          if (top.isEmpty) {
            return _EmptyMini(text: 'لا يوجد مزوّدون بتقييم 5/5 بعد');
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            itemCount: top.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _TopRatedCard(vendor: top[i]),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// COMPACT PLANNING CARD — coordinator / card-designer, side by side
// ===========================================================================

class _PlanCompactCard extends StatelessWidget {
  const _PlanCompactCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final List<Color> colors; // [light, base, dark]
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final dark = Color.alphaBlend(
        Colors.black.withValues(alpha: 0.35), colors[1]);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors[1].withValues(alpha: 0.42),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.2),
                  ),
                  child: Icon(icon, color: Colors.white, size: 23),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 9.5)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
            const SizedBox(height: 5),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1.35)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ابدأ الآن',
                      style: TextStyle(
                          color: dark,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_back_rounded, color: dark, size: 15),
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
// LATEST POSTS ROW
// ===========================================================================

class _LatestPostsRow extends StatelessWidget {
  const _LatestPostsRow({required this.future});
  final Future<List<PostModel>> future;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 234,
      child: FutureBuilder<List<PostModel>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: AfrahnaLoader(size: 42));
          }
          final items = (snap.data ?? const <PostModel>[])
              .where((p) =>
                  p.gallery.isNotEmpty ||
                  (p.mediaUrl?.isNotEmpty ?? false) ||
                  ((p.body ?? '').trim().isNotEmpty) ||
                  ((p.title ?? '').trim().isNotEmpty))
              .take(12)
              .toList();
          if (items.isEmpty) {
            return _EmptyMini(text: 'لا توجد منشورات بعد');
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _LatestPostCard(post: items[i]),
          );
        },
      ),
    );
  }
}

class _LatestPostCard extends StatelessWidget {
  const _LatestPostCard({required this.post});
  final PostModel post;

  @override
  Widget build(BuildContext context) {
    final img = post.gallery.isNotEmpty ? post.gallery.first : post.mediaUrl;
    final vendor = post.vendor;
    final logo = vendor?.logo;
    final text = (post.title?.trim().isNotEmpty ?? false)
        ? post.title!.trim()
        : (post.body?.trim() ?? '');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailsPage(post: post)),
      ),
      child: Container(
        width: 172,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 118,
              width: double.infinity,
              child: (img != null && img.isNotEmpty)
                  ? AppNetworkImage(
                      url: img,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.image_outlined,
                    )
                  : Container(
                      color: AppColors.primaryLight,
                      child: const Center(
                        child: Icon(Icons.article_rounded,
                            color: AppColors.primary, size: 34),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: (logo != null && logo.isNotEmpty)
                              ? NetworkImage(logo)
                              : null,
                          child: (logo == null || logo.isEmpty)
                              ? const Icon(Icons.storefront_rounded,
                                  size: 12, color: AppColors.primaryDark)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            vendor?.name ?? 'معلن',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        text.isNotEmpty ? text : 'منشور جديد',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          borderRadius: BorderRadius.circular(18),
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
// ADVERTISE-WITH-US CTA (direct WhatsApp contact for business owners)
// ===========================================================================

/// WhatsApp number business owners reach out to when they want to advertise.
/// Same line the app uses for support elsewhere.
const String _kAdvertisePhone = '+972599252493';

/// Eye-catching card inviting shop/service owners to advertise on Afrahna,
/// with a one-tap WhatsApp button that opens a pre-filled message.
class _AdvertiseCta extends StatelessWidget {
  const _AdvertiseCta();

  Future<void> _contact() async {
    final digits = _kAdvertisePhone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent(
        'مرحباً، عندي محل/خدمة وأرغب بالإعلان في تطبيق أفراحنا. ممكن التفاصيل؟');
    final uri = Uri.parse('https://wa.me/$digits?text=$msg');
    await openExternal(uri);
  }

  @override
  Widget build(BuildContext context) {
    // Scale the text relative to the screen width so it reads correctly on
    // every device — small phones (iPhone SE) through tablets — instead of the
    // fixed sizes that only looked right on one screen. 375 = baseline width.
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 375).clamp(0.9, 1.25);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _contact,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عندك محل أو خدمة؟ 📣',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5 * scale,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'أعلن في أفراحنا ووصّل لآلاف العرسان',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5 * scale,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _contact,
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: Text(
                  'تواصل معنا',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5 * scale),
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
// TIPS SECTION
// ===========================================================================

/// Horizontal row of bite-sized wedding-planning tips.
class _TipsSection extends StatelessWidget {
  const _TipsSection();

  static const _tips =
      <({IconData icon, String title, String body, Color tint})>[
    (
      icon: Icons.savings_rounded,
      title: 'حدّدي ميزانيتك',
      body: 'ابدئي التخطيط بميزانية واضحة قبل أي حجز.',
      tint: Color(0xFFCB9A3E),
    ),
    (
      icon: Icons.event_available_rounded,
      title: 'احجزي مبكراً',
      body: 'القاعات والمصوّرون المميّزون بينحجزوا بسرعة.',
      tint: Color(0xFFDD8A6A),
    ),
    (
      icon: Icons.checklist_rtl_rounded,
      title: 'نظّمي مهامك',
      body: 'استخدمي قائمة المهام حتى لا تفوتك أي تفصيلة.',
      tint: Color(0xFF8FA97E),
    ),
    (
      icon: Icons.reviews_rounded,
      title: 'قارني وقيّمي',
      body: 'اقرئي تقييمات العملاء قبل أن تقرّري.',
      tint: Color(0xFFAF8FC4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SectionHeader(title: 'نصائح لتخطيط فرحك', emoji: '💡'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 138,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            itemCount: _tips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final t = _tips[i];
              return Container(
                width: 212,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.tint.withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: t.tint.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(t.icon, color: t.tint, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(
                        t.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// WHY AFRAHNA (trust highlights)
// ===========================================================================

class _WhyAfrahnaSection extends StatelessWidget {
  const _WhyAfrahnaSection();

  static const _features = <({IconData icon, String label, Color tint})>[
    (
      icon: Icons.verified_rounded,
      label: 'شركات موثّقة',
      tint: Color(0xFF5FA9A0),
    ),
    (
      icon: Icons.groups_rounded,
      label: 'آلاف العرسان',
      tint: Color(0xFFDD8A6A),
    ),
    (
      icon: Icons.celebration_rounded,
      label: 'كل مناسباتك بمكان',
      tint: Color(0xFFAF8FC4),
    ),
    (
      icon: Icons.support_agent_rounded,
      label: 'دعم دائم',
      tint: Color(0xFFCB9A3E),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primaryLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'ليش أفراحنا؟',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'كل اللي بتحتاجيه لفرحك بمكان واحد',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in _features)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: f.tint.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(f.icon, color: f.tint, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        f.label,
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
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// FOOTER
// ===========================================================================

/// WhatsApp fallback used when no number is configured from the admin panel.
const String _kFooterSupportWhatsapp = '+972595679605';

class _AppFooter extends StatefulWidget {
  const _AppFooter();

  @override
  State<_AppFooter> createState() => _AppFooterState();
}

class _AppFooterState extends State<_AppFooter> {
  // Social links are configured from the admin panel (settings → social).
  late final Future<SocialLinks> _future = SettingsService().social();

  Future<void> _openUrl(String url) => openExternal(Uri.parse(url));

  Future<void> _openWhatsapp(String? value) {
    final raw = (value == null || value.isEmpty) ? _kFooterSupportWhatsapp : value;
    if (raw.startsWith('http')) return openExternal(Uri.parse(raw));
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return openExternal(Uri.parse('https://wa.me/$digits'));
  }

  void _soon() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('قريباً ✨'),
      backgroundColor: AppColors.primary,
    ));
  }

  void _tap(String? link) {
    if (link != null && link.isNotEmpty) {
      _openUrl(link);
    } else {
      _soon();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              AppAssets.logo,
              width: 46,
              height: 46,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'أفراحنا',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'كل مناسباتك في مكان واحد',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<SocialLinks>(
            future: _future,
            builder: (context, snap) {
              final s = snap.data ?? const SocialLinks();
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FooterSocial(
                    icon: FontAwesomeIcons.instagram,
                    onTap: () => _tap(s.instagram),
                  ),
                  const SizedBox(width: 12),
                  _FooterSocial(
                    icon: FontAwesomeIcons.facebookF,
                    onTap: () => _tap(s.facebook),
                  ),
                  const SizedBox(width: 12),
                  _FooterSocial(
                    icon: FontAwesomeIcons.tiktok,
                    onTap: () => _tap(s.tiktok),
                  ),
                  const SizedBox(width: 12),
                  _FooterSocial(
                    icon: FontAwesomeIcons.whatsapp,
                    onTap: () => _openWhatsapp(s.whatsapp),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            '© 2026 أفراحنا — صُنع بحب 💛',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterSocial extends StatelessWidget {
  const _FooterSocial({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: FaIcon(icon, color: Colors.white, size: 18),
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
  late Future<List<VendorModel>> _topRated;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _topRated = _loadTopRated();
  }

  Future<List<VendorModel>> _loadTopRated() async {
    final all = await VendorService().list(perPage: 60);
    all.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return all.where((v) => (v.rating ?? 0) > 0).take(20).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _runSearch(String q) {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() => _future = null);
      return;
    }
    setState(() {
      _future = VendorService().list(query: query);
    });
  }

  /// Live search as the user types (debounced), keeping the keyboard open.
  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(q));
  }

  void _search(String q) {
    // Submit action: run immediately and close the keyboard.
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    _runSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                  onChanged: _onChanged,
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
                    ? _buildTopRated()
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
                            padding: const EdgeInsets.only(bottom: 110),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
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

  /// Default view (empty search): the top-rated shops, so the page looks lively.
  Widget _buildTopRated() {
    return FutureBuilder<List<VendorModel>>(
      future: _topRated,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const CenteredLoader();
        }
        final items = snap.data ?? const <VendorModel>[];
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'ابدأ بكتابة ما تبحث عنه',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFC107), size: 20),
                const SizedBox(width: 6),
                const Text(
                  'المحلات الأكثر تقييماً',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 110),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _SearchResultTile(vendor: items[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.vendor});
  final VendorModel vendor;
  String _money(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final showBadge =
        vendor.isVip || vendor.isPremium || vendor.activePlan == 'featured';
    final priceRange = (vendor.minPrice != null && vendor.minPrice! > 0)
        ? (vendor.maxPrice != null && vendor.maxPrice! > vendor.minPrice!
            ? '${_money(vendor.minPrice!)}–${_money(vendor.maxPrice!)} ₪'
            : '${_money(vendor.minPrice!)} ₪')
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDetailsPage(vendorId: vendor.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo with a subtle ring + tier badge.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.6),
                        width: 1.5),
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: AppNetworkImage(
                        url: vendor.logo ?? vendor.cover,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.storefront,
                      ),
                    ),
                  ),
                ),
                if (showBadge)
                  PositionedDirectional(
                    bottom: -2,
                    end: -2,
                    child: TierBadge(
                      vip: vendor.isVip,
                      featured: vendor.isPremium ||
                          vendor.activePlan == 'featured',
                      size: 18,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          vendor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppColors.textDark),
                        ),
                      ),
                      if (vendor.isStore) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('متجر',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (vendor.category != null)
                        Flexible(
                          child: Text(
                            vendor.category!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      if (vendor.city != null) ...[
                        const Text('  ·  ',
                            style: TextStyle(color: AppColors.textMuted)),
                        const Icon(Icons.location_on,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            vendor.city!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Stats row.
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Stat(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFFFC107),
                        text: (vendor.rating ?? 0).toStringAsFixed(1) +
                            ((vendor.reviewsCount ?? 0) > 0
                                ? ' (${vendor.reviewsCount})'
                                : ''),
                      ),
                      _Stat(
                        icon: Icons.groups_rounded,
                        text: _compact(vendor.followersCount),
                      ),
                      if (priceRange != null)
                        _Stat(
                          icon: Icons.sell_outlined,
                          text: priceRange,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Icon(Icons.arrow_back_ios_new,
                  size: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text, this.iconColor});
  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor ?? AppColors.textMuted),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
      ],
    );
  }
}

// ===========================================================================
// BOTTOM NAV
// ===========================================================================
// The bottom navigation bar now lives in `widgets/app_bottom_nav.dart`
// (AppBottomNav) so it can be reused on full-screen pages such as the vendor
// profile.
