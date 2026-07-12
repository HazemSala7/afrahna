import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/services/event_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_widgets.dart';
import '../account/account_page.dart';
import '../assistant/assistant_page.dart';
import '../auth/login_page.dart';
import '../calendar/calendar_page.dart';
import '../categories/categories_page.dart';
import '../categories/category_tabs_page.dart';
import 'home_feed_cache.dart';
import '../coordinator/coordinator_page.dart';
import '../favorites/favorites_page.dart';
import '../invitations/invitations_page.dart';
import '../notifications/notifications_page.dart';
import '../offers/offer_details_page.dart';
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
    // Guest encouragement banner: pinned above the bottom nav on the home tab.
    // It stays visible for as long as the user has no account (not dismissible).
    final isGuest = !context.watch<SessionController>().isSignedIn;
    final showGuestBanner = isGuest && _currentTab == 2;
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showGuestBanner)
            _GuestPromoBanner(
              onLogin: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
            ),
          AppBottomNav(
            current: _currentTab,
            onTap: (i) => setState(() => _currentTab = i),
          ),
        ],
      ),
    );
  }
}

/// Pinned bottom banner encouraging guests to create an account / log in.
class _GuestPromoBanner extends StatelessWidget {
  const _GuestPromoBanner({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
  late Future<HomeStats> _statsFuture;
  Future<EventModel?> _mainEventFuture = Future.value(null);

  Position? _userPos;

  @override
  void initState() {
    super.initState();
    _load(useCache: true);
    _loadLocation();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 130),
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
              const SizedBox(height: 15),
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
              const SizedBox(height: 15),
              _hpad(FadeSlideIn(
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
              )),
              const SizedBox(height: 12),
              // Full-width auto-scrolling featured row.
              FadeSlideIn(
                delay: const Duration(milliseconds: 440),
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
                      delay: const Duration(milliseconds: 460),
                      child: CountdownCard(
                        title: event.title,
                        target: event.startsAt,
                      ),
                    ),
                  ));
                },
              ),
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
              const SizedBox(height: 22),
              _hpad(FadeSlideIn(
                delay: const Duration(milliseconds: 660),
                child: const _QuickActionsRow(),
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
            <({IconData icon, int value, String label, Color color, VoidCallback? onTap, bool pulse})>[
          (icon: Icons.store_mall_directory_rounded, value: s.vendors, label: 'شركة',
              color: Color(0xFFF6B25C), onTap: null, pulse: false),
          (icon: Icons.visibility_rounded, value: s.visitors, label: 'زائر',
              color: Color(0xFFF48CA0), onTap: null, pulse: false),
          (icon: Icons.groups_rounded, value: s.users, label: 'مستخدم',
              color: Color(0xFF7FC6C0), onTap: null, pulse: false),
          // "عرض خاص" is highlighted + animated + tappable → opens all offers.
          (icon: Icons.local_fire_department_rounded, value: s.offers, label: 'عرض خاص',
              color: Color(0xFFF6A93B),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const OffersPage())),
              pulse: true),
          (icon: Icons.holiday_village_rounded, value: s.cities, label: 'مدينة',
              color: Color(0xFFC7A9E0), onTap: null, pulse: false),
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
  });
  final IconData icon;
  final int value;
  final String label;
  final Color accent;
  final int delay;
  final VoidCallback? onTap;
  final bool pulse;

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
        _CountUp(value: value, delay: delay),
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
  const _CountUp({required this.value, this.delay = 0});
  final int value;
  final int delay;

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
        return Text(
          _formatCompact(v),
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

/// Compact number formatting for the stats band: 1234 → "1.2K", 1e6 → "1M".
String _formatCompact(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final v = n / 1000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}K';
  }
  final v = n / 1000000;
  return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
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
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5),
              ),
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
                PositionedDirectional(
                  bottom: -2,
                  end: -2,
                  child: TierBadge(
                    vip: vendor.isVip,
                    featured: vendor.isPremium ||
                        vendor.activePlan == 'featured',
                    size: 26,
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
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5),
              ),
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
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عندك محل أو خدمة؟ 📣',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'أعلن في أفراحنا ووصّل لآلاف العرسان',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
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
                label: const Text(
                  'تواصل معنا',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
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
    setState(() => _future = VendorService().list(query: query));
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
