import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/feature_flags.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/services/event_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../core/utils/category_icon.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/animated_invitation_bg.dart';
import '../../widgets/animations.dart';
import '../../widgets/invite_friends.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/cosmos.dart';
import '../../widgets/section_header.dart';
import '../../widgets/festival.dart';
import '../account/account_page.dart';
import '../account/customer_header.dart';
import '../account/edit_profile_page.dart';
import '../account/followed_vendors_page.dart';
import '../assistant/assistant_page.dart';
import '../event_request/event_request_home_card.dart';
import '../bookings/bookings_page.dart';
import '../invitations/invitations_page.dart';
import '../auth/login_page.dart';
import '../categories/categories_page.dart';
import '../categories/category_tabs_page.dart';
import 'home_feed_cache.dart';
import '../favorites/favorites_page.dart';
import '../planning/planning_hub_page.dart';
import '../notifications/notifications_page.dart';
import '../competition/competition_dialog.dart';
import '../offers/offer_details_page.dart';
import '../offers/offers_page.dart';
import '../points/points_page.dart';
import '../posts/post_details_page.dart';
import '../reels/reels_page.dart';
import '../stories/all_stories_page.dart';
import '../store/marketplace.dart';
import '../store/marketplace_page.dart';
import '../store/my_orders_page.dart';
import '../vendors/story_viewer_page.dart';
import '../vendors/vendor_details_page.dart';
import '../vendors/vendors_page.dart';
import '../../core/utils/held_future.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialTab = 2});

  /// Tab to show when the shell is first built (2 = الرئيسية).
  final int initialTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _currentTab = widget.initialTab; // الرئيسية = الوسط (افتراضي)

  /// Tabs the user has actually opened. [IndexedStack] builds every child
  /// eagerly, which used to start the reels feed (and its video preloading)
  /// during app launch even for users who never open it. We keep the stack —
  /// so a visited tab keeps its scroll position and state — but hold back the
  /// unvisited ones behind an empty placeholder until they're first selected.
  late final Set<int> _visited = {widget.initialTab};

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
      const AccountPage(), // 0 - حسابي (rightmost)
      const PlanningHubPage(), // 1 - خطّطي (planning tools hub)
      const _HomeTab(), // 2 - الرئيسية (centre)
      const ReelsPage(), // 3 - ريلز
      const MarketplacePage(), // 4 - المتجر (leftmost)
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _currentTab,
        children: [
          for (var i = 0; i < pages.length; i++)
            if (_visited.contains(i)) pages[i] else const SizedBox.shrink(),
        ],
      ),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              setState(() {
                _visited.add(i);
                _currentTab = i;
              });
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
            colors: [AppColors.primary, AppColors.goldDeep],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.24),
              blurRadius: 16,
              offset: const Offset(0, 2),
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
              child: const Icon(
                Icons.celebration_rounded,
                color: Colors.white,
                size: 22,
              ),
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
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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

  /// Shops that joined most recently — "انضم مؤخراً".
  late Future<List<VendorModel>> _newVendorsFuture;

  /// Marketplace row: products from every shop, shuffled.
  late Future<List<ProductModel>> _marketFuture;

  /// Active stories grouped per shop, for the rail near the top.
  late Future<List<VendorStoriesGroup>> _storiesFuture;
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
      // All held: they are stored now and read by a FutureBuilder on the
      // next frame, and a request that fails in between would otherwise
      // escape as an unhandled error. See [held].
      _categoriesFuture = held(CategoryService().list(tree: true));
      _promosFuture = held(PromotionService().list());
      _topVendorsFuture = held(VendorService().list());
      // Featured: fresh random order on each load.
      _featuredVendorsFuture = held(
        VendorService()
            .list(featured: true, perPage: 1000)
            .then((l) => l..shuffle()),
      );
      // Hero slider = admin slides + VIP vendors, shuffled fresh each load.
      _slidersFuture = held(HomeFeedCache.loadSliders());
      _statsFuture = held(StatsService().get());
    }
    // Newest shops — the API already returns vendors newest-first, so the
    // first page is exactly the ones that just joined.
    _newVendorsFuture = held(VendorService().list(perPage: 12));
    _storiesFuture = held(_loadStories());
    // Marketplace: a fresh shuffle of everyone's products on each load.
    _marketFuture = held(
      ProductService()
          .marketplace(
            seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
            perPage: 14,
          )
          .then((r) => r.items),
    );
    // Latest posts (newest first) for the home "آخر المنشورات" row.
    _latestPostsFuture = held(
      PostService().list(type: PostType.post, perPage: 15),
    );
    _mainEventFuture = held(_loadMainEvent());
  }

  /// Groups active stories by shop, newest shop first, so the rail shows one
  /// ring per shop rather than one per story.
  Future<List<VendorStoriesGroup>> _loadStories() async {
    try {
      final stories = await StoryService().listAll();
      final order = <int>[];
      final byVendor = <int, List<StoryModel>>{};
      final vendors = <int, VendorModel>{};

      for (final s in stories) {
        final v = s.vendor;
        final vid = v?.id ?? s.vendorId;
        if (v == null || vid == null || s.image.isEmpty) continue;
        if (!byVendor.containsKey(vid)) {
          order.add(vid);
          vendors[vid] = v;
          byVendor[vid] = [];
        }
        byVendor[vid]!.add(s);
      }

      // Shuffled, the way the slider rotates its advertisers: the shop that
      // happens to be first in the server's order would otherwise be first
      // every single time the app opened, and the ones past the screen edge
      // would never be seen at all. Once per load, not per rebuild — the rail
      // must not reshuffle under a finger reaching for it.
      return order
          .map(
            (id) => VendorStoriesGroup(
              vendor: vendors[id]!,
              stories: byVendor[id]!,
            ),
          )
          .toList()
        ..shuffle();
    } catch (_) {
      // The rail is optional decoration — never fail the whole home tab for it.
      return const [];
    }
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
      _storiesFuture,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // The shell uses `extendBody: true`, so this list scrolls *behind* the
    // bottom nav (and, for guests, the "join" banner). Reserve exactly their
    // combined height so the last sections are never hidden underneath them.
    final isGuest = !context.watch<SessionController>().isSignedIn;
    final bottomReserve =
        AppBottomNav.contentHeight +
        MediaQuery.of(context).padding.bottom +
        (isGuest ? _kGuestBannerHeight : 0) +
        16;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // One clock for everything on the page that moves with the festival;
      // the burst of confetti lies over the whole page, once, on arrival.
      body: FestivalClock(
        child: Stack(
          children: [
      SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, 4, 0, bottomReserve),
            children: [
              // The crown: the aurora breathes behind the mark, the search
              // and the stories, and fades into the page below them.
              Stack(
                children: [
                  const Positioned.fill(child: AuroraCrown()),
                  Column(
                    children: [
                      _hpad(const _TopBar()),
                      const SizedBox(height: 10),
                      _hpad(
                        FadeSlideIn(
                          id: 'home.0',
                          delay: const Duration(milliseconds: 60),
                          child: const GlintSweep(child: _SearchBar()),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ---- 1. الستوريز ----------------------------------
                      // Moved here from its own bottom-nav tab, where it was
                      // a whole screen away from the content it belongs
                      // with. They sit on an orbit.
                      FadeSlideIn(
                        id: 'home.1',
                        delay: const Duration(milliseconds: 120),
                        child: OrbitPath(
                          child: _StoriesRail(future: _storiesFuture),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ---- 2. التصنيفات ---------------------------------
                      // Full-width categories (no side gaps), cut as
                      // crystals, under the same aurora.
                      FadeSlideIn(
                        id: 'home.2',
                        delay: const Duration(milliseconds: 200),
                        child: _CategoriesGrid(future: _categoriesFuture),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ],
              ),

              // ---- 3. السلايدات -----------------------------------------
              _hpad(
                FadeSlideIn(
                  id: 'home.3',
                  delay: const Duration(milliseconds: 260),
                  child: _HeroBanner(future: _slidersFuture),
                ),
              ),
              const SizedBox(height: 20),

              // ---- 4. الشركات المميّزة ----------------------------------
              _hpad(
                FadeSlideIn(
                  id: 'home.4',
                  delay: const Duration(milliseconds: 300),
                  child: SectionHeader(
                    festive: true,
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
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                id: 'home.5',
                delay: const Duration(milliseconds: 320),
                child: _FeaturedVendorsCarousel(
                  future: _featuredVendorsFuture,
                  userPos: _userPos,
                ),
              ),
              const SizedBox(height: 24),

              // ---- 5. المتجر --------------------------------------------
              // Products from every shop, shuffled.
              _hpad(
                FadeSlideIn(
                  id: 'home.6',
                  delay: const Duration(milliseconds: 340),
                  child: SectionHeader(
                    festive: true,
                    title: 'المتجر',
                    emoji: '🛍️',
                    onSeeAll: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MarketplacePage(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                id: 'home.7',
                delay: const Duration(milliseconds: 360),
                child: _MarketRow(future: _marketFuture),
              ),
              const SizedBox(height: 22),

              // ---- 6. عروض اليوم ----------------------------------------
              _hpad(
                FadeSlideIn(
                  id: 'home.8',
                  delay: const Duration(milliseconds: 380),
                  child: SectionHeader(
                    festive: true,
                    title: 'عروض اليوم',
                    emoji: '🔥',
                    onSeeAll: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OffersPage()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                id: 'home.9',
                delay: const Duration(milliseconds: 400),
                child: _OffersRow(future: _promosFuture),
              ),
              const SizedBox(height: 26),

              // ---- 7. آخر المنشورات -------------------------------------
              _hpad(
                FadeSlideIn(
                  id: 'home.10',
                  delay: const Duration(milliseconds: 420),
                  child: const SectionHeader(
                    festive: true,
                    title: 'آخر المنشورات',
                    emoji: '📝',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                id: 'home.11',
                delay: const Duration(milliseconds: 440),
                child: _LatestPostsRow(future: _latestPostsFuture),
              ),
              const SizedBox(height: 24),

              // ---- 8. انضم مؤخراً ------------------------------------
              // Gives a just-joined advertiser immediate exposure instead of
              // waiting to earn a spot in the other rows.
              _hpad(
                FadeSlideIn(
                  id: 'home.12',
                  delay: const Duration(milliseconds: 460),
                  child: SectionHeader(
                    festive: true,
                    title: 'انضم مؤخراً',
                    emoji: '✨',
                    onSeeAll: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VendorsPage(title: 'انضم مؤخراً'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                id: 'home.13',
                delay: const Duration(milliseconds: 480),
                child: _NewVendorsRow(future: _newVendorsFuture),
              ),
              const SizedBox(height: 22),

              // ---- 9. الأعلى تقييماً ------------------------------------
              _hpad(
                FadeSlideIn(
                  id: 'home.14',
                  delay: const Duration(milliseconds: 500),
                  child: SectionHeader(
                    festive: true,
                    title: 'الأعلى تقييماً',
                    emoji: '⭐',
                    onSeeAll: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VendorsPage()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                id: 'home.15',
                delay: const Duration(milliseconds: 520),
                child: _TopRatedRow(
                  future: _topVendorsFuture,
                  userPos: _userPos,
                ),
              ),
              const SizedBox(height: 22),

              // ---- 10. دعوات إلكترونية ----------------------------------
              // The showpiece feature, so it gets a living card rather than
              // another row of tiles.
              _hpad(
                FadeSlideIn(
                  id: 'home.16',
                  delay: const Duration(milliseconds: 540),
                  child: const _InvitationPromoCard(),
                ),
              ),
              const SizedBox(height: 22),

              // ---- 11. نظّم مناسبتك -------------------------------------
              // Opens the six-question brief, or the customer's existing
              // request once one has been submitted.
              _hpad(
                FadeSlideIn(
                  id: 'home.17',
                  delay: const Duration(milliseconds: 560),
                  child: const EventRequestHomeCard(),
                ),
              ),
              const SizedBox(height: 26),

              // ---- 12. نصائح لتخطيط فرحك --------------------------------
              FadeSlideIn(
                id: 'home.18',
                delay: const Duration(milliseconds: 580),
                child: const _TipsSection(),
              ),
              const SizedBox(height: 26),

              // ---- 13. ليش أفراحنا؟ -------------------------------------
              _hpad(
                FadeSlideIn(
                  id: 'home.19',
                  delay: const Duration(milliseconds: 600),
                  child: const _WhyAfrahnaSection(),
                ),
              ),
              const SizedBox(height: 24),

              // ---- Below the numbered order ------------------------------
              // What is left of the sections that were not in the requested
              // sequence. «حجوزاتي» and «خطّطي فرحك» have moved to the profile,
              // and the statistics band is behind [kShowHomeStats].

              // The member's own card — who they are, what their points are
              // worth, and the shortcuts they use most. Guests get the sign-in
              // call to action in the same slot.
              _hpad(
                FadeSlideIn(
                  id: 'home.20',
                  delay: const Duration(milliseconds: 620),
                  child: const _HomeAccountBlock(),
                ),
              ),
              const SizedBox(height: 20),
              // The next event's countdown, when one is scheduled.
              FutureBuilder<EventModel?>(
                future: _mainEventFuture,
                builder: (context, snap) {
                  final event = snap.data;
                  if (event == null ||
                      event.startsAt.isBefore(DateTime.now())) {
                    return const SizedBox.shrink();
                  }
                  return _hpad(
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: FadeSlideIn(
                        id: 'home.22',
                        delay: const Duration(milliseconds: 640),
                        child: CountdownCard(
                          title: event.title,
                          target: event.startsAt,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              // Invite-a-friend rewards card. Its reward is points, so it is
              // hidden together with the rest of the points system.
              if (kShowPointsSystem) ...[
                const SizedBox(height: 22),
                _hpad(
                  FadeSlideIn(
                    id: 'home.24',
                    delay: const Duration(milliseconds: 660),
                    child: const _InviteFriendsCard(),
                  ),
                ),
              ],
              // The reach-statistics band, hidden by default.
              if (kShowHomeStats) ...[
                const SizedBox(height: 20),
                _hpad(
                  FadeSlideIn(
                    id: 'home.25',
                    delay: const Duration(milliseconds: 670),
                    child: _StatsBand(future: _statsFuture),
                  ),
                ),
              ],
              const SizedBox(height: 26),
              _hpad(
                FadeSlideIn(
                  id: 'home.26',
                  delay: const Duration(milliseconds: 680),
                  child: const _AppFooter(),
                ),
              ),
            ],
          ),
        ),
      ),
            const Positioned.fill(child: ConfettiBurst()),
          ],
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
        const SizedBox(width: 8),
        // Inviting a friend used to be two screens away: the points tab, then
        // a scroll. It is the one action that grows the app, so it sits where
        // the eye already is.
        _InviteButton(onTap: () => openInvite(context)),
        const Spacer(),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The mark, lit from behind.
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      AppAssets.logo,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GoldFoilText('أفراحنا', style: AppTheme.wordmark(20)),
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
                  border: Border.all(color: AppColors.ink, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.discount.withValues(alpha: 0.8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A gold pill with a gift in it.
///
/// Not another glass orb: three identical circles across the top read as a
/// toolbar, and nothing in a toolbar gets pressed. This is the one warm thing
/// on the bar, and it breathes very slightly so the eye catches it once.
class _InviteButton extends StatefulWidget {
  const _InviteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_InviteButton> createState() => _InviteButtonState();
}

class _InviteButtonState extends State<_InviteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _c,
          // A circle, the same 44 the other two are: a pill with a word in
          // it pushed the wordmark off the end of the bar. The colour alone
          // is enough to separate it from the glass orbs beside it.
          builder: (context, child) => Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: 0.26 + 0.16 * _c.value,
                  ),
                  blurRadius: 16 + 6 * _c.value,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: child,
          ),
          child: const Icon(
            Icons.card_giftcard_rounded,
            size: 21,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A glass orb with a gold edge.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        splashColor: AppColors.accent.withValues(alpha: 0.18),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceHigh.withValues(alpha: 0.95),
                AppColors.surface.withValues(alpha: 0.9),
              ],
            ),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.14),
                blurRadius: 14,
              ),
              const BoxShadow(
                color: Color(0x66000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.accent, size: 22),
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
    // A capsule of glass with a hairline edge and a faint gold glow.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            AppColors.surfaceHigh.withValues(alpha: 0.92),
            AppColors.surface.withValues(alpha: 0.85),
          ],
        ),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.1),
            blurRadius: 18,
          ),
          const BoxShadow(
            color: Color(0x59000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
        cursorColor: AppColors.accent,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'ابحث عن خدمات، محلات، عروض والمزيد...',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          suffixIcon: GestureDetector(
            onTap: _submit,
            child: Container(
              margin: const EdgeInsetsDirectional.only(end: 6),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.goldGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.44),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                Icons.search_rounded,
                color: AppColors.ink,
                size: 19,
              ),
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
            <
              ({
                IconData icon,
                int value,
                String label,
                Color color,
                VoidCallback? onTap,
                bool pulse,
                bool compact,
              })
            >[
              (
                icon: Icons.store_mall_directory_rounded,
                value: s.vendors,
                label: 'شركة',
                color: Color(0xFFF6B25C),
                onTap: null,
                pulse: false,
                compact: false,
              ),
              (
                icon: Icons.visibility_rounded,
                value: s.visitors,
                label: 'زائر',
                color: Color(0xFFF48CA0),
                onTap: null,
                pulse: false,
                compact: false,
              ),
              // Users is the only tile shown abbreviated (e.g. 21.2K).
              (
                icon: Icons.groups_rounded,
                value: s.users,
                label: 'مستخدم',
                color: Color(0xFF7FC6C0),
                onTap: null,
                pulse: false,
                compact: true,
              ),
              // "عروض" is highlighted + animated + tappable → opens all offers.
              (
                icon: Icons.local_fire_department_rounded,
                value: s.offers,
                label: 'عروض',
                color: Color(0xFFF6A93B),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OffersPage()),
                ),
                pulse: true,
                compact: false,
              ),
              (
                icon: Icons.holiday_village_rounded,
                value: s.cities,
                label: 'مدينة',
                color: Color(0xFFC7A9E0),
                onTap: null,
                pulse: false,
                compact: false,
              ),
            ];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          // A panel of warm glass with a wash of light inside it.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF8E5F4A), Color(0xFF55322A), Color(0xFF7E4440)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.13),
                blurRadius: 24,
              ),
              const BoxShadow(
                color: Color(0x73000000),
                blurRadius: 20,
                offset: Offset(0, 8),
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
                  // A thread of light between two stats.
                  Container(
                    width: 1,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.accent.withValues(alpha: 0),
                          AppColors.accent.withValues(alpha: 0.45),
                          AppColors.accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
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
    // A glass orb glowing in the stat's own colour.
    Widget circle = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: 0.34),
            accent.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.38), blurRadius: 16),
        ],
      ),
      child: Icon(
        icon,
        color: Color.lerp(accent, Colors.white, 0.25),
        size: 23,
        shadows: [Shadow(color: accent, blurRadius: 12)],
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
                child: Icon(
                  Icons.chevron_left,
                  color: Colors.white70,
                  size: 14,
                ),
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
  late final Animation<double> _a = Tween(
    begin: 1.0,
    end: 1.14,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

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
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

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
                Shadow(
                  color: Color(0x55000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
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
/// Home-page "invite a friend" rewards card. Signed-in users see their share
/// code with copy + share actions; guests get a gentle sign-in prompt. The
/// design leans festive (rose-gold gradient + sparkles) to stand out from the
/// warm brown/teal sections above it.
class _InviteFriendsCard extends StatelessWidget {
  const _InviteFriendsCard();

  static const _gradient = LinearGradient(
    colors: [Color(0xFF8E3B60), Color(0xFFB65A80), Color(0xFFD98BA6)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final code = session.user?.referralCode ?? '';
    final signedIn = session.isSignedIn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E3B60).withValues(alpha: .35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative sparkles in the corners.
          Positioned(
            top: -4,
            left: -2,
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white.withValues(alpha: .25),
              size: 22,
            ),
          ),
          Positioned(
            bottom: -6,
            left: 40,
            child: Icon(
              Icons.celebration_rounded,
              color: Colors.white.withValues(alpha: .18),
              size: 30,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .35),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ادعُ أصدقاءك 🎁',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          signedIn
                              ? 'شارك كودك واكسب 3 نقاط عن كل صديق ينضمّ — بلا حدّ يومي'
                              : 'سجّل الدخول لتحصل على كود دعوة وتكسب النقاط',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .9),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // The same component the points card uses, on the dark
              // panel: a link, WhatsApp, and the system sheet. This block
              // used to share the CODE ALONE, with no link at all, so a
              // friend who received it had to be told what to do with it.
              // A member whose code has not arrived yet gets a button that
              // fetches it, not the sign-in button.
              if (code.isNotEmpty)
                InviteActions(code: code, onDark: true)
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => openInvite(context),
                    icon: Icon(
                      signedIn ? Icons.link_rounded : Icons.login_rounded,
                      size: 18,
                    ),
                    label: Text(signedIn ? 'احصل على رابط الدعوة' : 'سجّل الدخول وابدأ الدعوة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: const Color(0xFFDB9FB9),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              if (signedIn) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PointsPage()),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'كل صديق = 3 نقاط · اعرض نقاطي',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .95),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Home-page rewards card: a signed-in user sees their points balance in a
/// premium gold card (tap → full points screen); a guest sees an enticing
/// sign-in call-to-action ("earn points"). Distinct gold theme so it reads as
/// the "rewards" moment, separate from the rose invite card below.
/// The account block on the home tab: for a signed-in user their profile card
/// plus shortcuts; for a guest the original points teaser, which doubles as the
/// sign-in call to action.
class _HomeAccountBlock extends StatelessWidget {
  const _HomeAccountBlock();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    if (!session.isSignedIn || user == null) return const _PointsHomeCard();
    return _HomeAccountCard(user: user);
  }
}

class _HomeAccountCard extends StatefulWidget {
  const _HomeAccountCard({required this.user});
  final UserModel user;

  @override
  State<_HomeAccountCard> createState() => _HomeAccountCardState();
}

class _HomeAccountCardState extends State<_HomeAccountCard> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    final n = await NotificationService().unreadCount();
    if (mounted) setState(() => _unread = n);
  }

  void _go(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomerHeroCard(
          user: widget.user,
          // The ladder belongs on حسابي; here it is detail nobody came for.
          showLevel: false,
          onEditProfile: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfilePage()),
            );
            if (mounted) setState(() {});
          },
          onOpenPoints: () => _go(const PointsPage()),
        ),
        const SizedBox(height: 12),
        CustomerQuickActions(
          actions: [
            CustomerQuickAction(
              icon: Icons.favorite_rounded,
              label: 'المفضلة',
              onTap: () => _go(const FavoritesPage()),
            ),
            CustomerQuickAction(
              icon: Icons.calendar_month_rounded,
              label: 'مناسباتي',
              onTap: () => _go(const BookingsPage(initialMine: true)),
            ),
            CustomerQuickAction(
              icon: Icons.receipt_long_rounded,
              label: 'طلباتي',
              onTap: () => _go(const MyOrdersPage()),
            ),
            CustomerQuickAction(
              icon: Icons.notifications_rounded,
              label: 'الإشعارات',
              badge: _unread,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
                _loadUnread();
              },
            ),
            CustomerQuickAction(
              icon: Icons.local_offer_rounded,
              label: 'العروض',
              onTap: () => _go(const OffersPage()),
            ),
            CustomerQuickAction(
              icon: Icons.storefront_rounded,
              label: 'متابَعاتي',
              onTap: () => _go(const FollowedVendorsPage()),
            ),
            CustomerQuickAction(
              icon: Icons.mail_rounded,
              label: 'دعواتي',
              onTap: () => _go(const InvitationsPage()),
            ),
          ],
        ),
      ],
    );
  }
}

/// Guest-only rewards teaser + sign-in call to action. Signed-in users get
/// [_HomeAccountCard] in this slot instead.
class _PointsHomeCard extends StatelessWidget {
  const _PointsHomeCard();

  static const _gradient = LinearGradient(
    colors: [Color(0xFFE3AC44), Color(0xFFC4882F), Color(0xFF95611E)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC4882F).withValues(alpha: .38),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _guest(context),
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon) => Container(
    width: 54,
    height: 54,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .18),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: .4), width: 1.2),
    ),
    child: Icon(icon, color: Colors.white, size: 28),
  );

  Widget _guest(BuildContext context) {
    return Row(
      children: [
        _badge(Icons.card_giftcard_rounded),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اكسب نقاط أفراحنا 🎁',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'سجّل الدخول واجمع النقاط مع كل تفاعل ودعوة صديق — كل 100 نقطة'
                ' تساوي 50 شيكل، وكلما صعدت مستوى زادت مكافآتك.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 9,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.hairline, width: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.login_rounded,
                      color: Color(0xFFE9C291),
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        color: Color(0xFFE9C291),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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

  /// How long a slide is held before the next one comes.
  static const _dwell = Duration(seconds: 7);

  /// How long the rotation waits after a touch, so reading or tapping a slide
  /// is not interrupted by it sliding away mid-gesture.
  static const _pauseAfterTouch = Duration(seconds: 4);

  Timer? _resume;

  void _startTimer() {
    _timer?.cancel();
    if (_slides.length < 2) return;
    _timer = Timer.periodic(_dwell, (_) {
      if (!_controller.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
  }

  /// Stop rotating, and pick it up again [_pauseAfterTouch] after the last
  /// touch — each new touch pushes the restart further out.
  void _holdForTouch() {
    _timer?.cancel();
    _resume?.cancel();
    _resume = Timer(_pauseAfterTouch, () {
      if (mounted) _startTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resume?.cancel();
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
        // A portal: a bead of light circles the frame while the slides pass
        // behind it.
        return PortalFrame(
          radius: 18,
          child: CustomPaint(
          // A holographic edge round the banner.
          foregroundPainter: const HoloBorderPainter(radius: 18, width: 1.2),
          child: ClipRRect(
            // Rounded card that sits within the page's side margins.
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: double.infinity,
              height: 240,
              child: Stack(
                children: [
                  // Listener, not GestureDetector: the slide itself already
                  // claims the tap to open the advertiser, and a competing
                  // recogniser would have to win an arena fight to see it. A
                  // raw pointer-down is seen either way.
                  Listener(
                    onPointerDown: (_) => _holdForTouch(),
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _slides.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (_, i) => _HeroSlideView(slide: _slides[i]),
                    ),
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(child: SparkleOverlay(count: 14)),
                  ),
                  if (_slides.length > 1)
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: 10,
                      child: Builder(
                        builder: (_) {
                          // Never render more than 10 dots — with many VIP slides a
                          // full row becomes a cramped, unreadable line. Slides past
                          // the 10th keep the last dot active so there's always an
                          // indicator lit.
                          const maxDots = 10;
                          final dotCount = _slides.length > maxDots
                              ? maxDots
                              : _slides.length;
                          final activeDot = _index >= dotCount
                              ? dotCount - 1
                              : _index;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(dotCount, (i) {
                              final active = i == activeDot;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: active ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: active
                                      ? const LinearGradient(
                                          colors: AppColors.holoStops,
                                        )
                                      : null,
                                  color: active
                                      ? null
                                      : AppColors.pearl.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: active
                                      ? [
                                          BoxShadow(
                                            color: AppColors.accent.withValues(
                                              alpha: 0.7,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
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
          // It breathes: a slow zoom in and out, so the slide is a window on
          // something alive rather than a poster.
          if (slide.image.isNotEmpty)
            ListenableBuilder(
              listenable: FestivalClock.of(context),
              builder: (context, _) => Transform.scale(
                scale: 1.05 + 0.035 * math.sin(FestivalClock.of(context).value * 0.21),
                child: RepaintBoundary(
                  child: AppNetworkImage(
                    url: slide.image,
                    fallbackIcon: Icons.celebration,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.brandDeepGradient,
              ),
            ),
          // Dark overlay so text stays readable.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  AppColors.ink.withValues(alpha: 0.35),
                  AppColors.ink.withValues(alpha: 0.85),
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
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  slide.badge,
                  style: const TextStyle(
                    color: AppColors.accent,
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
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
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
                      MaterialPageRoute(builder: (_) => const OffersPage()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
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

  // No auto-scroll here any more. A row that slides while you are reaching for
  // it is a row you cannot hit: the tile moves out from under the finger
  // between deciding and touching. The slider below still rotates — it is one
  // big target and nothing is lost by missing it — but these are 72 pixels
  // wide and exist to be tapped.

  @override
  void dispose() {
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
            height: 84,
            child: Center(child: AfrahnaLoader(size: 42)),
          );
        }
        final all = snap.data ?? const <CategoryModel>[];
        if (all.isEmpty) return const SizedBox.shrink();

        const showMoreThreshold = 12;
        final showMore = all.length > showMoreThreshold;
        final visible = showMore
            ? all.take(showMoreThreshold - 1).toList()
            : all;

        final items = <Widget>[
          for (final (i, c) in visible.indexed)
            _CategoryTile(
              label: c.name,
              icon: categoryIcon(c.name),
              tint: _categoryTints[i % _categoryTints.length],
              phase: i * 0.7,
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

        const tileWidth = 72.0;
        const tileHeight = 84.0;
        const spacing = 8.0;

        return SizedBox(
          height: tileHeight,
          child: Builder(
            builder: (context) => ListView.separated(
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
    this.phase = 0,
  });
  final String label;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  /// Where in its shimmer this tile starts, so a row of them does not blink
  /// in step.
  final double phase;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A crystal cut in the category's own colour: a sheen turning
          // slowly through it, an edge of light turning the other way, so the
          // row shimmers rather than repeats.
          CrystalTile(
            tint: tint,
            phase: phase,
            child: Icon(
              icon,
              // Deepened, not lightened: the tile is pale, so the icon reads
              // by being darker than it rather than brighter.
              color: Color.lerp(tint, AppColors.ink, 0.34),
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
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
            return const Center(child: AfrahnaLoader(size: 42));
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
        MaterialPageRoute(builder: (_) => OfferDetailsPage(promo: promo)),
      ),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: AppDecor.lift,
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
                          horizontal: 10,
                          vertical: 5,
                        ),
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                      const Icon(
                        Icons.location_on,
                        size: 13,
                        color: AppColors.primary,
                      ),
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _auto.attach(_controller),
    );
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
            return const Center(child: AfrahnaLoader(size: 42));
          }
          if (snap.hasError) {
            return _EmptyMini(text: 'تعذّر تحميل الشركات المميّزة');
          }
          // Trust the server's `featured=1` filter (avoid double-filtering,
          // which hid vendors when the boolean wasn't parsed as expected).
          final items = List<VendorModel>.from(
            snap.data ?? const <VendorModel>[],
          );
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
                start: 16,
                end: 16,
                top: 4,
                bottom: 4,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) =>
                  Levitate(index: i, child: _FeaturedVendorCard(vendor: items[i])),
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
      return AppNetworkImage(url: vendor.cover, fallbackIcon: Icons.storefront);
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
          colors: [Color(0xFFD9B68A), Color(0xFFB8835A), Color(0xFF8B5A3C)],
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
                        AppColors.goldDeep,
                        Color(0xFFE6B450),
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
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
                    featured:
                        vendor.isPremium || vendor.activePlan == 'featured',
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
                  const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: Color(0xFFE6A800),
                  ),
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
            return const Center(child: AfrahnaLoader(size: 42));
          }
          // "الأعلى تقييماً" — show only vendors with a full 5/5 rating.
          final items = [
            ...(snap.data ?? const <VendorModel>[]).where(
              (v) => (v.rating ?? 0) >= 5.0,
            ),
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
              .where(
                (p) =>
                    p.gallery.isNotEmpty ||
                    (p.mediaUrl?.isNotEmpty ?? false) ||
                    ((p.body ?? '').trim().isNotEmpty) ||
                    ((p.title ?? '').trim().isNotEmpty),
              )
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppDecor.lift,
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
                        child: Icon(
                          Icons.article_rounded,
                          color: AppColors.primary,
                          size: 34,
                        ),
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
                              ? const Icon(
                                  Icons.storefront_rounded,
                                  size: 12,
                                  color: AppColors.primaryDark,
                                )
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: AppDecor.lift,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: _CardCover(vendor: vendor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFC107),
                        size: 17,
                      ),
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
          child: SectionHeader(title: 'نصائح لتخطيط فرحك', emoji: '💡'),
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: t.tint.withValues(alpha: 0.25)),
                  boxShadow: AppDecor.lift,
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
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.primaryLight),
        boxShadow: AppDecor.lift,
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
    final raw = (value == null || value.isEmpty)
        ? _kFooterSupportWhatsapp
        : value;
    if (raw.startsWith('http')) return openExternal(Uri.parse(raw));
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return openExternal(Uri.parse('https://wa.me/$digits'));
  }

  void _soon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('قريباً ✨'),
        backgroundColor: AppColors.primary,
      ),
    );
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
          colors: [AppColors.primary, AppColors.goldDeep],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 3),
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
  final FaIconData icon;
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

/// Instagram-style stories rail at the top of the home tab: one gradient ring
/// per shop with active stories. Hides itself entirely when there are none, so
/// it never leaves an empty band.
class _StoriesRail extends StatelessWidget {
  const _StoriesRail({required this.future});
  final Future<List<VendorStoriesGroup>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VendorStoriesGroup>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 78);
        }
        final groups = snap.data ?? const <VendorStoriesGroup>[];
        if (groups.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: groups.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              if (i == groups.length) return const _AllStoriesTile();
              return _StoryRailTile(group: groups[i]);
            },
          ),
        );
      },
    );
  }
}

class _StoryRailTile extends StatelessWidget {
  const _StoryRailTile({required this.group});
  final VendorStoriesGroup group;

  @override
  Widget build(BuildContext context) {
    final vendor = group.vendor;
    return SizedBox(
      width: 58,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StoryViewerPage(vendor: vendor, stories: group.stories),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(2.5),
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
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                ),
                child: ClipOval(
                  child: AppNetworkImage(
                    url: vendor.logo ?? group.stories.first.image,
                    fallbackIcon: Icons.storefront_rounded,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              vendor.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trailing tile that opens the full stories screen.
class _AllStoriesTile extends StatelessWidget {
  const _AllStoriesTile();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllStoriesPage()),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.primaryLight, width: 2),
                boxShadow: AppDecor.lift,
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'كل القصص',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marketplace row on the home tab: a shuffled sample of products from every
/// shop, with add-to-cart on each card.
class _MarketRow extends StatelessWidget {
  const _MarketRow({required this.future});
  final Future<List<ProductModel>> future;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 262,
      child: FutureBuilder<List<ProductModel>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: AfrahnaLoader(size: 42));
          }
          if (snap.hasError) {
            return const _EmptyMini(text: 'تعذّر تحميل منتجات المتجر');
          }
          final items = snap.data ?? const <ProductModel>[];
          if (items.isEmpty) {
            return const _EmptyMini(text: 'لا توجد منتجات معروضة بعد');
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            // The row itself scrolls horizontally, so the cards' image strips
            // stay fixed here — swiping anywhere keeps moving the row.
            itemBuilder: (_, i) =>
                MarketProductCard(product: items[i], swipeableGallery: false),
          );
        },
      ),
    );
  }
}

/// Horizontal row of the most recently joined shops. Each card carries a
/// "جديد" ribbon plus how long ago the shop joined, so the row reads as news
/// rather than just another vendor list.
class _NewVendorsRow extends StatelessWidget {
  const _NewVendorsRow({required this.future});
  final Future<List<VendorModel>> future;

  static const double _height = 196;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: FutureBuilder<List<VendorModel>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: AfrahnaLoader(size: 42));
          }
          if (snap.hasError) {
            return const _EmptyMini(text: 'تعذّر تحميل المحلات الجديدة');
          }
          final items = snap.data ?? const <VendorModel>[];
          if (items.isEmpty) {
            return const _EmptyMini(text: 'لا توجد محلات جديدة بعد');
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _NewVendorCard(vendor: items[i]),
          );
        },
      ),
    );
  }
}

class _NewVendorCard extends StatelessWidget {
  const _NewVendorCard({required this.vendor});
  final VendorModel vendor;

  /// "انضمّ اليوم" / "قبل 3 أيام" — null when the join date is unknown.
  static String? _joinedLabel(DateTime? d) {
    if (d == null) return null;
    final days = DateTime.now().difference(d).inDays;
    if (days <= 0) return 'انضمّ اليوم';
    if (days == 1) return 'انضمّ أمس';
    if (days < 30) return 'انضمّ قبل $days يوم';
    final months = (days / 30).floor();
    return months == 1 ? 'انضمّ قبل شهر' : 'انضمّ قبل $months أشهر';
  }

  @override
  Widget build(BuildContext context) {
    final joined = _joinedLabel(vendor.createdAt);
    final subtitle = [
      vendor.category?.name,
      vendor.city?.name,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' • ');

    return SizedBox(
      width: 150,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          boxShadow: AppDecor.lift,
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VendorDetailsPage(vendorId: vendor.id),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: SizedBox(
                        height: 92,
                        width: double.infinity,
                        child: AppNetworkImage(
                          url: vendor.cover ?? vendor.logo,
                          fallbackIcon: Icons.storefront_rounded,
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF34C77B), Color(0xFF1B9C5A)],
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'جديد',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              vendor.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          if (vendor.isVerified) ...[
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                      if (joined != null) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: Color(0xFF1B9C5A),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                joined,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B9C5A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMini extends StatelessWidget {
  const _EmptyMini({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline, width: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
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
      _future = held(VendorService().list(query: query));
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
      backgroundColor: Colors.transparent,
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
                      horizontal: 18,
                      vertical: 14,
                    ),
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
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
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const CenteredLoader();
                          }
                          if (snap.hasError) {
                            return ErrorState(message: snap.error.toString());
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
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFC107),
                  size: 20,
                ),
                const SizedBox(width: 6),
                const Text(
                  'المحلات الأعلى تقييماً',
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
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline, width: 0.8),
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
                      width: 1.5,
                    ),
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
                      featured:
                          vendor.isPremium || vendor.activePlan == 'featured',
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
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (vendor.isStore) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'متجر',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (vendor.city != null) ...[
                        const Text(
                          '  ·  ',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const Icon(
                          Icons.location_on,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            vendor.city!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
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
                        text:
                            (vendor.rating ?? 0).toStringAsFixed(1) +
                            ((vendor.reviewsCount ?? 0) > 0
                                ? ' (${vendor.reviewsCount})'
                                : ''),
                      ),
                      _Stat(
                        icon: Icons.groups_rounded,
                        text: _compact(vendor.followersCount),
                      ),
                      if (priceRange != null)
                        _Stat(icon: Icons.sell_outlined, text: priceRange),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 14,
                color: AppColors.textMuted,
              ),
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
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
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

/// «حجوزاتي» on the home page: the services this customer booked, and what the
/// shop answered. Hidden entirely for guests and for customers with no
/// bookings, so it never shows as an empty band.
class _InvitationPromoCard extends StatefulWidget {
  const _InvitationPromoCard();

  @override
  State<_InvitationPromoCard> createState() => _InvitationPromoCardState();
}

class _InvitationPromoCardState extends State<_InvitationPromoCard> {
  // Rotate through a few themes so the card isn't the same picture every day.
  static const _themes = [
    (InvitationAnim.goldDust, Color(0xFF1A1526), Color(0xFFE6C36B)),
    (InvitationAnim.silk, Color(0xFF101A2E), Color(0xFFD8B45F)),
    (InvitationAnim.arabesque, Color(0xFF0F2020), Color(0xFFC9A24D)),
    (InvitationAnim.candles, Color(0xFF1E1410), Color(0xFFF0B876)),
  ];

  late final (InvitationAnim, Color, Color) _theme =
      _themes[DateTime.now().day % _themes.length];

  @override
  Widget build(BuildContext context) {
    final (anim, bg, accent) = _theme;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InvitationsPage()),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedInvitationBg(anim: anim, accent: accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: accent.withValues(alpha: .45),
                          ),
                        ),
                        child: Text(
                          'جديد',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.auto_awesome_rounded, size: 15, color: accent),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'دعوتك الإلكترونية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تصاميم متحركة فخمة، عدّ تنازلي، خريطة،\nوتأكيد حضور — جاهزة خلال دقيقة.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                      fontSize: 12.5,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent,
                              Color.lerp(accent, Colors.white, .35) ?? accent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mail_outline_rounded,
                              size: 16,
                              color: bg,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'أنشئ دعوتك',
                              style: TextStyle(
                                color: bg,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // A hint at the range of looks on offer.
                      for (final t in _themes.take(4))
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.$3.withValues(
                              alpha: t.$1 == anim ? 1 : .35,
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
