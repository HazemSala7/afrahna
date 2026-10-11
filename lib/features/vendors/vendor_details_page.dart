import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/state/session.dart';
import '../../core/services/local_favorites.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../core/utils/link_launcher.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/follow_button.dart';
import '../../widgets/login_required_dialog.dart';
import '../bookings/booking_create_page.dart';
import '../home/home_page.dart';
import '../services/service_details_page.dart';
import 'package:latlong2/latlong.dart';

import '../posts/vendor_posts_feed.dart';
import 'highlight_viewer_page.dart';
import 'store_section.dart';
import 'story_viewer_page.dart';
import 'vendor_map_page.dart';
import '../../core/utils/held_future.dart';
import '../../core/services/accounts_services.dart';

class VendorDetailsPage extends StatefulWidget {
  const VendorDetailsPage({
    super.key,
    required this.vendorId,
    this.highlightProductId,
  });

  final int vendorId;

  /// When set (opened from a product notification), the store section scrolls
  /// to this product and highlights it.
  final int? highlightProductId;

  @override
  State<VendorDetailsPage> createState() => _VendorDetailsPageState();
}

class _VendorDetailsPageState extends State<VendorDetailsPage> {

  late Future<VendorModel> _vendorFuture;
  late Future<List<ServiceModel>> _servicesFuture;
  late Future<({List<ReviewModel> items, int total, bool hasMore})>
  _reviewsFuture;
  late Future<List<StoryModel>> _storiesFuture;
  late Future<List<HighlightModel>> _highlightsFuture;
  final ScrollController _scrollController = ScrollController();
  final VendorContactService _contacts = VendorContactService();
  bool _favLoading = false;
  bool? _favLocal;

  /// Live follower count once the user follows/unfollows (overrides the value
  /// loaded with the vendor so the stats strip updates instantly).
  int? _followersLive;

  @override
  void initState() {
    super.initState();
    _vendorFuture = held(VendorService().show(widget.vendorId));
    _servicesFuture = held(ServiceService().list(vendorId: widget.vendorId));
    _servicesFuture.then((list) {
      if (mounted && list.isNotEmpty) setState(() => _hasServices = true);
    }, onError: (_) {});
    _reviewsFuture = held(ReviewService().listPagedForVendor(widget.vendorId));
    _storiesFuture = held(StoryService().listForVendor(widget.vendorId));
    _highlightsFuture = held(HighlightService().listForVendor(widget.vendorId));
    _postsFuture =
        held(PostService().list(vendorId: widget.vendorId, perPage: 12));
    _scrollController.addListener(_syncTab);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncTab);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _shareProfile(VendorModel vendor) async {
    final url = 'https://afrahna.co/v/${vendor.id}';
    final text = 'شاهد "${vendor.name}" على تطبيق أفراحنا:\n$url';
    try {
      await Share.share(text, subject: vendor.name);
    } catch (_) {
      // Fallback: copy the link so the user can still share it.
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم نسخ رابط المشاركة')));
      }
    }
  }

  Future<void> _toggleFavorite(VendorModel vendor) async {
    setState(() => _favLoading = true);
    try {
      final isFav = await LocalFavorites.instance.toggle(vendor.id);
      setState(() => _favLocal = isFav);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(
            isFav ? 'تمت الإضافة للمفضلة' : 'تمت الإزالة من المفضلة',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  /// Counts a tap on one of this shop's contact buttons. Fire-and-forget —
  /// see [VendorContactService].
  /// Dials the shop. Shared by the contact marks at the top of the page and
  /// the action block lower down, so the two can never drift apart.
  void _callShop(VendorModel vendor) {
    final p = _digits(vendor.phone ?? '');
    if (p.isEmpty) return;
    _countContact(vendor.id, VendorContactService.channelPhone);
    _launch(Uri.parse('tel:$p'));
  }

  /// Opens the map inside the app: the shop's coordinates when it set them,
  /// otherwise its address, geocoded.
  void _openMap(VendorModel vendor) {
    _countContact(vendor.id, VendorContactService.channelMap);
    final hasCoords = vendor.latitude != null && vendor.longitude != null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VendorMapPage(
          title: vendor.name,
          address: vendor.address,
          query: vendor.address ?? vendor.name,
          initialLocation: hasCoords
              ? LatLng(vendor.latitude!, vendor.longitude!)
              : null,
        ),
      ),
    );
  }

  /// The shop's own store is a section of this page; the verb at the top
  /// scrolls to it rather than opening a second screen showing the same
  /// products.
  final GlobalKey _storeKey = GlobalKey();

  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _offersKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _postsKey = GlobalKey();
  final GlobalKey _reviewsKey = GlobalKey();
  final GlobalKey _photosKey = GlobalKey();

  late final Future<List<PostModel>> _postsFuture;

  /// The cover's height and the logo that hangs over its lower edge. The logo
  /// lives in the page's own Stack rather than in the sheet, because a sliver
  /// clips whatever its child paints above itself.
  static const double _coverHeight = 280;
  static const double _logoSize = 84;

  /// The rail's tabs, in the order they appear down the page. Rebuilt with
  /// the page because a shop without a store has no store tab.
  List<_TabSpec> _tabs = const <_TabSpec>[];
  int _activeTab = 0;

  /// Whether the services section exists on this page; its tab follows it.
  bool _hasServices = false;

  List<_TabSpec> _tabsFor(VendorModel vendor) => [
    const _TabSpec('الرئيسية', Icons.grid_view_rounded, null),
    if (vendor.photosCount > 0)
      _TabSpec('الصور', Icons.photo_library_outlined, _photosKey),
    if (vendor.videosCount > 0)
      _TabSpec('الفيديوهات', Icons.play_circle_outline_rounded, _postsKey),
    if (_hasServices)
      _TabSpec('الخدمات', Icons.menu_book_outlined, _servicesKey),
    if (vendor.isStore) _TabSpec('المتجر', Icons.storefront_outlined, _storeKey),
    _TabSpec('العروض', Icons.local_offer_outlined, _offersKey),
    _TabSpec('التقييمات', Icons.star_outline_rounded, _reviewsKey),
    _TabSpec('معلومات', Icons.info_outline_rounded, _aboutKey),
  ];

  /// Marks the tab whose section the reader has reached: of the sections
  /// whose top has passed under the rail, the lowest one. The tabs are in
  /// the reference's order, not the page's, so this looks at positions
  /// rather than indices.
  void _syncTab() {
    if (_tabs.isEmpty || _travelling) return;
    const threshold = 220.0;
    var active = 0;
    var best = double.negativeInfinity;
    for (var i = 1; i < _tabs.length; i++) {
      final ctx = _tabs[i].key?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy <= threshold && dy > best) {
        best = dy;
        active = i;
      }
    }
    if (active != _activeTab && mounted) setState(() => _activeTab = active);
  }

  void _goToStore() => _scrollTo(_storeKey);

  void _goToServices() => _scrollTo(_servicesKey);

  void _scrollTo(GlobalKey? key) {
    if (key == null) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final ctx = key.currentContext;
    if (ctx == null) return;
    // While the page is on its way to a section, the rail keeps the tab
    // that was tapped; otherwise the position-based sync would flick it
    // back and forth as sections pass under the threshold.
    _travelling = true;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    ).whenComplete(() {
      _travelling = false;
      _syncTab();
    });
  }

  /// True while a tap on the rail is scrolling the page to a section.
  bool _travelling = false;

  void _countContact(int vendorId, String channel) =>
      _contacts.record(vendorId, channel);

  Future<void> _launch(Uri uri) async {
    final ok = await openExternal(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذّر فتح: $uri')));
    }
  }

  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// Leaves this profile and returns to the home shell on the chosen tab.
  void _goToTab(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomePage(initialTab: index)),
      (route) => false,
    );
  }

  Future<void> _openRatingSheet(VendorModel vendor) async {
    // Reviewing requires an account.
    if (!context.read<SessionController>().isSignedIn) {
      await showLoginRequiredDialog(
        context,
        title: 'أضف تقييمك',
        message:
            'سجّل الدخول بحساب لتتمكن من إضافة تقييم لهذا المزوّد،'
            ' أو تابع التصفح كزائر.',
        icon: Icons.star_rounded,
      );
      return;
    }
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingSheet(vendor: vendor),
    );
    if (submitted == true && mounted) {
      setState(() {
        _reviewsFuture = held(
          ReviewService().listPagedForVendor(widget.vendorId),
        );
        _vendorFuture = held(VendorService().show(widget.vendorId));
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('شكراً! تم نشر تقييمك ✓')));
    }
  }

  /// Open the full, paginated list of reviewers in a bottom-sheet dialog.
  Future<void> _openAllReviews(VendorModel vendor, int total) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllReviewsSheet(vendorId: vendor.id, total: total),
    );
  }

  static String _firstChar(String name) {
    final t = name.trim();
    if (t.isEmpty) return '★';
    return t.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Let content scroll *behind* the floating nav bar (same as the home
      // shell). Without this the Scaffold also reserves the bar's height, which
      // left an empty band around the floating card at the bottom of the page.
      extendBody: true,
      body: FutureBuilder<VendorModel>(
        future: _vendorFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
              message: snap.error.toString(),
              onRetry: () => setState(() {
                _vendorFuture = held(VendorService().show(widget.vendorId));
              }),
            );
          }
          final vendor = snap.data!;
          final isFav =
              _favLocal ?? LocalFavorites.instance.isFavorite(vendor.id);
          _tabs = _tabsFor(vendor);

          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  _buildHero(context, vendor),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -28),
                      child: Container(
                        // Solid where it covers the cover, then thinning to
                        // glass so the night sky shows through the long page.
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.background,
                              AppColors.background.withValues(alpha: 0.92),
                              AppColors.background.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.08, 0.3],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                        ),
                        // The cover paints over the sheet's first 28 px (it
                        // is lifted that far under the photograph for its
                        // corners), so the band begins 10 px below the edge
                        // that is actually seen — level with the logo.
                        padding: const EdgeInsets.fromLTRB(18, 38, 18, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // The logo floats over the cover's edge from the
                            // page's Stack; the band only leaves it room. Name,
                            // stars and place at the start, and beside them —
                            // in what was empty space — every way to reach
                            // the shop.
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: _logoSize + 10,
                              ),
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  // The name's column is whatever three
                                  // marks leave it, within reason: never so
                                  // narrow that «معجنات · الخليل» is cut,
                                  // never so wide that the marks drop to
                                  // two a row.
                                  final identityMax =
                                      (box.maxWidth - 8 - 3 * _Mark.cell)
                                          .clamp(104.0, 140.0);
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: identityMax,
                                        ),
                                        child: _IdentityHeader(vendor: vendor),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _ContactMarks(
                                          vendor: vendor,
                                          onCall: () => _callShop(vendor),
                                          onMap: () => _openMap(vendor),
                                          onOpen: (uri, channel) {
                                            _countContact(vendor.id, channel);
                                            _launch(uri);
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            _ActionRow(
                              vendor: vendor,
                              onBook: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BookingCreatePage(vendor: vendor),
                                ),
                              ),
                              onMessage: () {
                                final wa = vendorWhatsappUri(
                                  (vendor.whatsapp ?? '').isNotEmpty
                                      ? vendor.whatsapp!
                                      : (vendor.phone ?? ''),
                                );
                                if (wa == null) return;
                                _countContact(
                                  vendor.id,
                                  VendorContactService.channelWhatsapp,
                                );
                                _launch(wa);
                              },
                              onStore: vendor.isStore ? _goToStore : null,
                              onServices: _goToServices,
                            ),
                            const SizedBox(height: 12),
                            _StatsStrip(
                              vendor: vendor,
                              followers:
                                  _followersLive ?? vendor.followersCount,
                            ),
                            const SizedBox(height: 16),
                            _CategoryRail(
                              vendor: vendor,
                              future: _highlightsFuture,
                            ),
                            _TabRail(
                              tabs: _tabs,
                              active: _activeTab,
                              onTap: (i) {
                                setState(() => _activeTab = i);
                                _scrollTo(_tabs[i].key);
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(key: _photosKey, height: 1),
                            _PhotoRow(
                              future: _postsFuture,
                              onMore: () => _scrollTo(_postsKey),
                            ),
                            if (vendor.isStore) ...[
                              const SizedBox(height: 16),
                              _StoreBanner(vendor: vendor, onOpen: _goToStore),
                            ],
                            const SizedBox(height: 16),
                            // The discount banner and the points card are the
                            // same offer: the banner announces it, this card is
                            // where it's redeemed — so they sit together.
                            SizedBox(key: _offersKey, height: 1),
                            const _DiscountBanner(),
                            _PointsRedeemSection(vendor: vendor),
                            const SizedBox(height: 18),
                            _StoriesSection(
                              vendor: vendor,
                              future: _storiesFuture,
                            ),
                            SizedBox(key: _aboutKey, height: 22),
                            _Section(
                              icon: Icons.info_outline_rounded,
                              title: 'عن المزوّد',
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: _cardDecoration(),
                                child: Text(
                                  vendor.description.isNotEmpty
                                      ? vendor.description
                                      : 'لا يوجد وصف متاح حالياً.',
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    height: 1.7,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                            if (vendor.isStore) ...[
                              const SizedBox(height: 18),
                              StoreSection(
                                key: _storeKey,
                                vendor: vendor,
                                highlightProductId: widget.highlightProductId,
                              ),
                            ],
                            SizedBox(key: _postsKey, height: 18),
                            VendorPostsFeed(
                              vendorId: vendor.id,
                              showHeader: true,
                            ),
                            // Services section — hidden entirely when the vendor
                            // has no services (no empty placeholder shown).
                            FutureBuilder<List<ServiceModel>>(
                              future: _servicesFuture,
                              builder: (context, sSnap) {
                                final services =
                                    sSnap.data ?? const <ServiceModel>[];
                                if (services.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(key: _servicesKey, height: 18),
                                    _Section(
                                      icon: Icons.design_services_outlined,
                                      title: 'الخدمات المقدّمة',
                                      child: Column(
                                        children: [
                                          for (final s in services)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: _ServiceTile(
                                                service: s,
                                                vendor: vendor,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            SizedBox(key: _reviewsKey, height: 18),
                            FutureBuilder<
                              ({
                                List<ReviewModel> items,
                                int total,
                                bool hasMore,
                              })
                            >(
                              future: _reviewsFuture,
                              builder: (context, rSnap) {
                                final data = rSnap.data;
                                final reviews =
                                    data?.items ?? const <ReviewModel>[];
                                // Real reviewer count from the server paginator.
                                final total =
                                    data?.total ??
                                    (vendor.reviewsCount ?? reviews.length);
                                return _Section(
                                  icon: Icons.star_rounded,
                                  title: 'تقييمات العملاء',
                                  trailing: total > 0
                                      ? TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppColors.primaryDark,
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                          onPressed: () =>
                                              _openAllReviews(vendor, total),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'عرض الكل',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                              Icon(
                                                Icons.chevron_right_rounded,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        )
                                      : null,
                                  child: Builder(
                                    builder: (context) {
                                      if (rSnap.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: CenteredLoader(),
                                        );
                                      }
                                      return Column(
                                        children: [
                                          if (reviews.isEmpty)
                                            const _EmptyBox(
                                              icon: Icons.rate_review_outlined,
                                              text:
                                                  'كن أول من يقيّم هذا المزوّد ✨',
                                            )
                                          else
                                            SizedBox(
                                              height: 132,
                                              child: ListView.separated(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                physics:
                                                    const BouncingScrollPhysics(),
                                                padding: EdgeInsets.zero,
                                                itemCount:
                                                    reviews.take(5).length,
                                                separatorBuilder: (_, _) =>
                                                    const SizedBox(width: 10),
                                                itemBuilder: (_, i) => SizedBox(
                                                  width: 250,
                                                  child: _ReviewCard(
                                                    review: reviews[i],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.primary,
                                                side: const BorderSide(
                                                  color: AppColors.primary,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.star_rounded,
                                                size: 20,
                                              ),
                                              label: const Text('أضف تقييمك'),
                                              onPressed: () =>
                                                  _openRatingSheet(vendor),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            _InfoStrip(
                              vendor: vendor,
                              onMap: () => _openMap(vendor),
                            ),
                            // Clear the floating nav bar (and the system gesture
                            // inset) so the last section is never hidden under it.
                            SizedBox(
                              height:
                                  AppBottomNav.contentHeight +
                                  MediaQuery.of(context).padding.bottom +
                                  16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // The shop's mark, astride the cover's lower edge at the
              // start of the identity line. It scrolls with the page.
              AnimatedBuilder(
                animation: _scrollController,
                builder: (context, _) {
                  final offset = _scrollController.hasClients
                      ? _scrollController.offset
                      : 0.0;
                  // Its centre sits 16 below the cover's visible bottom
                  // edge, so about a third of it is over the photograph.
                  final top = _coverHeight +
                      MediaQuery.paddingOf(context).top +
                      16 -
                      _logoSize / 2 -
                      offset;
                  if (top < -_logoSize) return const SizedBox.shrink();
                  return PositionedDirectional(
                    top: top,
                    start: 18,
                    child: FutureBuilder<List<StoryModel>>(
                      future: _storiesFuture,
                      builder: (_, sSnap) => _FloatingLogo(
                        vendor: vendor,
                        size: _logoSize,
                        stories: sSnap.data ?? const <StoryModel>[],
                      ),
                    ),
                  );
                },
              ),
              // Fixed top action buttons that stay visible when scrolled.
              // Share and favourite at the start, back at the far end.
              Positioned(
                top: MediaQuery.of(context).padding.top + 6,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    _GlassIconButton(
                      icon: Icons.share_rounded,
                      onTap: () => _shareProfile(vendor),
                    ),
                    const SizedBox(width: 8),
                    _GlassIconButton(
                      icon: isFav
                          ? Icons.favorite
                          : Icons.favorite_border_rounded,
                      iconColor: isFav ? Colors.redAccent : Colors.white,
                      onTap: _favLoading ? null : () => _toggleFavorite(vendor),
                    ),
                    const SizedBox(width: 8),
                    FollowButton(
                      vendorId: vendor.id,
                      initiallyFollowing: vendor.isFollowing,
                      followersCount: _followersLive ?? vendor.followersCount,
                      compact: true,
                      onFollowersChanged: (c) =>
                          setState(() => _followersLive = c),
                    ),
                    const Spacer(),
                    _GlassIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: AppBottomNav(current: -1, onTap: _goToTab),
    );
  }

  Widget _buildHero(BuildContext context, VendorModel vendor) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: false,
      stretch: true,
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Base: image, or a nebula when there is no cover
            if ((vendor.cover ?? vendor.logo ?? '').isNotEmpty)
              AppNetworkImage(
                url: vendor.cover ?? vendor.logo,
                fallbackIcon: Icons.storefront,
              )
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF9C5F48),
                      Color(0xFF55322A),
                      Color(0xFF7E4440),
                    ],
                  ),
                ),
              ),
            // Decorative pattern of soft circles for visual richness
            const Positioned.fill(child: _CoverPattern()),
            // Vendor monogram watermark (only when no cover image)
            if ((vendor.cover ?? '').isEmpty)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    _firstChar(vendor.name),
                    style: TextStyle(
                      fontSize: 140,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: AppColors.accent.withValues(alpha: 0.13),
                      letterSpacing: -4,
                    ),
                  ),
                ),
              ),
            // Darken at bottom so the sheet/logo pop
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x00000000),
                    Color(0xE608070F),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DISCOUNT NUDGE — "tell them you're from Afrahna"
// ============================================================

/// Friendly banner on every vendor profile inviting the user to mention the
/// app when they visit, so they get the shop's Afrahna discount.
class _DiscountBanner extends StatelessWidget {
  const _DiscountBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.alphaBlend(
              AppColors.accent.withValues(alpha: 0.10),
              AppColors.surfaceHigh,
            ),
            AppColors.surface,
          ],
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.14),
            blurRadius: 24,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: [
          // Gift/discount badge
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppColors.ink,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'خصمك بانتظارك ',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      '🎁',
                      style: TextStyle(
                        fontSize: 14.5,
                        shadows: [
                          Shadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(text: 'عند زيارتك لنا، أخبرنا أنك من تطبيق '),
                      TextSpan(
                        text: 'أفراحنا',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(text: ' لتستفيد من الخصومات 💛'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER (centered logo + title + chips) — premium look
// ============================================================

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.vendor});

  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    final reviews = vendor.reviewsCount ?? 0;
    // A shop nobody has rated yet is new, not nought-point-nought.
    final unrated = reviews == 0 && (vendor.rating ?? 0) == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name, tier and rating read from the start of the line like
        // everything else. Centred, they floated with no relationship to the
        // text beneath them.
        Row(
          children: [
            Flexible(
              child: Text(
                vendor.name,
                maxLines: 2,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  color: AppColors.textDark,
                  height: 1.2,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            // One mark. [TierBadge] draws the verified check itself, so
            // adding another put two identical blue ticks beside the name.
            // A shop on a plan shows its plan; a plain verified shop still
            // gets its tick.
            if (vendor.isVip ||
                vendor.isPremium ||
                vendor.activePlan == 'featured') ...[
              const SizedBox(width: 6),
              TierBadge(
                vip: vendor.isVip,
                featured: vendor.isPremium || vendor.activePlan == 'featured',
                size: 24,
              ),
            ] else if (vendor.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.verified_rounded,
                size: 20,
                color: Color(0xFF2F9BF5),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        // Rating, then how many people gave it. A score with no count behind
        // it says nothing: 5.0 from one person and 5.0 from four hundred are
        // not the same claim.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                unrated ? 'جديد' : (vendor.rating ?? 0).toStringAsFixed(1),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: unrated ? AppColors.textMuted : AppColors.textDark,
                ),
              ),
              const SizedBox(width: 5),
              _GoldStars(rating: vendor.rating ?? 0),
            ],
          ),
        ),
        if (reviews > 0)
          Text(
            '($reviews تقييم)',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Icon(Icons.place_rounded,
                size: 13, color: AppColors.primary),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                [
                  vendor.category?.name,
                  vendor.city?.name,
                ].whereType<String>().join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The practical facts, at the foot of the page: when the shop is open,
/// where it is, whether it delivers. Three tiles across, each one acting
/// where it can — the address opens the map.
class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.vendor, required this.onMap});

  final VendorModel vendor;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final hasPlace = (vendor.address ?? '').isNotEmpty ||
        (vendor.latitude != null && vendor.longitude != null);

    final tiles = <Widget>[
      if ((vendor.deliveryNote ?? '').isNotEmpty)
        _InfoTile(
          icon: Icons.local_shipping_outlined,
          label: 'التوصيل',
          value: vendor.deliveryNote!,
        ),
      if (hasPlace)
        _InfoTile(
          icon: Icons.place_rounded,
          label: 'موقعنا',
          value: (vendor.city?.name ?? '').isNotEmpty
              ? '${vendor.city!.name} - عرض على الخريطة'
              : 'عرض على الخريطة',
          onTap: onMap,
        ),
      if ((vendor.workingHours ?? '').isNotEmpty)
        _InfoTile(
          icon: Icons.schedule_rounded,
          label: 'ساعات العمل',
          value: vendor.workingHours!,
        ),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: AppDecor.card(radius: 20),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  color: Color(0x22B8835A),
                  thickness: 1,
                  width: 1,
                ),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shop's highlights as a rail of circles, each a doorway into one
/// album: the way a visitor browses a shop by what it does rather than by
/// when it posted.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.vendor, required this.future});
  final VendorModel vendor;
  final Future<List<HighlightModel>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HighlightModel>>(
      future: future,
      builder: (context, snap) {
        final highlights = (snap.data ?? const <HighlightModel>[])
            .where((h) => h.items.isNotEmpty)
            .toList();
        if (highlights.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: highlights.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final h = highlights[i];
                final cover = (h.coverImage ?? '').isNotEmpty
                    ? h.coverImage
                    : h.items.first.mediaUrl;
                return SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HighlightViewerPage(
                              vendor: vendor,
                              highlight: h,
                            ),
                          ),
                        ),
                        child: Container(
                          width: 70,
                          height: 70,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2.2,
                            ),
                          ),
                          child: ClipOval(
                            child: AppNetworkImage(
                              url: cover,
                              fallbackIcon: Icons.auto_awesome_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        h.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// The shop's latest pictures in a row, a reel among them marked with a
/// play button. Tapping any of them goes to the posts they came from.
class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.future, required this.onMore});
  final Future<List<PostModel>> future;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PostModel>>(
      future: future,
      builder: (context, snap) {
        final tiles = <({String url, bool video})>[];
        for (final post in snap.data ?? const <PostModel>[]) {
          if (post.type == PostType.reel) {
            final thumb = post.thumbnail ?? post.mediaUrl;
            if ((thumb ?? '').isNotEmpty) {
              tiles.add((url: thumb!, video: true));
            }
          } else {
            for (final img in post.images) {
              tiles.add((url: img, video: false));
            }
          }
          if (tiles.length >= 8) break;
        }
        if (tiles.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: tiles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = tiles[i];
              return GestureDetector(
                onTap: onMore,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppNetworkImage(url: t.url),
                        if (t.video)
                          Center(
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Color(0xCCFFFFFF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.primaryDark,
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// A banner for the shop's store, for a shop that has one: it tells the
/// visitor there is something to order here before they have scrolled down
/// to the shelves.
class _StoreBanner extends StatelessWidget {
  const _StoreBanner({required this.vendor, required this.onOpen});
  final VendorModel vendor;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [AppColors.primary, AppColors.accent],
        ),
        boxShadow: AppDecor.lift,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0x3DFFFFFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'متجر ${vendor.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'اطلب منتجاتنا المميزة مباشرة عبر التطبيق',
                  maxLines: 2,
                  style: TextStyle(
                    color: Color(0xF2FFFFFF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onOpen,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_rounded,
                      size: 15,
                      color: AppColors.primaryDark,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'تصفح المتجر',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tab: what it is called, and the section it belongs to.
class _TabSpec {
  const _TabSpec(this.label, this.icon, this.key);
  final String label;
  final IconData icon;

  /// Null on the first tab, which means the top of the page.
  final GlobalKey? key;
}

/// The page's table of contents, as a rail you can scroll.
///
/// A shop page is long — offers, store, posts, services, reviews — and the
/// thing a visitor came for is rarely the first one. The rail names every
/// section and marks the one being read, so the page can be navigated instead
/// of waded through.
class _TabRail extends StatefulWidget {
  const _TabRail({
    required this.tabs,
    required this.active,
    required this.onTap,
  });

  final List<_TabSpec> tabs;
  final int active;
  final ValueChanged<int> onTap;

  @override
  State<_TabRail> createState() => _TabRailState();
}

class _TabRailState extends State<_TabRail> {
  final _keys = <int, GlobalKey>{};
  final _rail = ScrollController();

  @override
  void dispose() {
    _rail.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TabRail old) {
    super.didUpdateWidget(old);
    // Scrolling the page moves the mark; the rail follows it so the active
    // tab never ends up off its own edge. Only the rail's own position is
    // moved: Scrollable.ensureVisible would walk up to the page and scroll
    // that too, undoing the very jump the tap asked for.
    if (old.active != widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tab = _keys[widget.active]?.currentContext?.findRenderObject();
        if (tab == null || !_rail.hasClients) return;
        _rail.position.ensureVisible(
          tab,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.length < 2) return const SizedBox.shrink();

    return Container(
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: AppDecor.card(radius: 16),
      child: Row(
        children: [
          // The grid mark at the start says "sections" without a word.
          Container(
            width: 38,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.apps_rounded,
              size: 19,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ListView.separated(
              controller: _rail,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: widget.tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final tab = widget.tabs[i];
                final on = i == widget.active;
                final fg = on ? Colors.white : AppColors.textMuted;
                return Material(
                  key: _keys.putIfAbsent(i, GlobalKey.new),
                  color: on ? AppColors.primaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => widget.onTap(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tab.icon, size: 15, color: fg),
                          const SizedBox(width: 5),
                          Text(
                            tab.label,
                            style: TextStyle(
                              color: fg,
                              fontWeight: on
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The verbs: book, message, and — for a shop that has one — its store.
///
/// Booking leads because it is what the page is for; it is the only filled
/// button, so the row has one obvious answer rather than four equal ones.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.vendor,
    required this.onBook,
    required this.onMessage,
    this.onStore,
    this.onServices,
  });

  final VendorModel vendor;
  final VoidCallback onBook;
  final VoidCallback onMessage;

  /// Scrolls this page down to the shop's store section.
  final VoidCallback? onStore;

  /// Scrolls to the list of services. Null when the shop offers none.
  final VoidCallback? onServices;

  @override
  Widget build(BuildContext context) {
    final wa = vendorWhatsappUri(
      (vendor.whatsapp ?? '').isNotEmpty
          ? vendor.whatsapp!
          : (vendor.phone ?? ''),
    );

    // The menu opens the row in the dark tone and the store closes it in
    // the bright one; booking and messaging sit between them in the light
    // tone. A shop with nothing to sell gives booking the bright tone, so
    // the row always has one strongest answer.
    final hasStore = vendor.isStore && onStore != null;
    // A shop whose bookings are switched off has no booking button at all;
    // messaging then takes the bright tone when there is no store either.
    final books = vendor.allowBookings;

    return Row(
      children: [
        if (onServices != null) ...[
          Expanded(
            child: _Verb(
              icon: Icons.list_alt_rounded,
              label: 'عرض القائمة',
              tone: _Tone.dark,
              onTap: onServices!,
            ),
          ),
          const SizedBox(width: 6),
        ],
        if (books)
          Expanded(
            child: _Verb(
              icon: Icons.event_available_rounded,
              label: 'احجز الآن',
              tone: hasStore ? _Tone.light : _Tone.bright,
              onTap: onBook,
            ),
          ),
        if (wa != null) ...[
          if (books || onServices != null) const SizedBox(width: 6),
          Expanded(
            child: _Verb(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'مراسلة',
              tone: books || hasStore ? _Tone.light : _Tone.bright,
              onTap: onMessage,
            ),
          ),
        ],
        if (hasStore) ...[
          const SizedBox(width: 6),
          Expanded(
            child: _Verb(
              icon: Icons.shopping_cart_rounded,
              label: 'المتجر',
              tone: _Tone.bright,
              onTap: onStore!,
            ),
          ),
        ],
      ],
    );
  }
}

/// How strongly a verb is drawn: the light tone for the ordinary ones, the
/// bright for the one the page most wants, the dark for the menu.
enum _Tone { light, bright, dark }

class _Verb extends StatelessWidget {
  const _Verb({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = _Tone.light,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _Tone.light => (AppColors.primaryLight, AppColors.primaryDark),
      _Tone.bright => (AppColors.primary, Colors.white),
      _Tone.dark => (AppColors.primaryDark, Colors.white),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          // Four verbs across a phone leave each about 70 dp; a label that
          // does not fit scales down a little rather than losing its end.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 4),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
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

/// Every way to reach the shop, in one row of coloured marks.
///
/// Each channel keeps its own colour because that is how people find the one
/// they want — nobody reads a row of six identical grey circles. Only the
/// channels this shop actually filled in appear, so the row is never a set of
/// dead buttons.
class _ContactMarks extends StatelessWidget {
  const _ContactMarks({
    required this.vendor,
    required this.onOpen,
    required this.onCall,
    required this.onMap,
  });

  final VendorModel vendor;
  final void Function(Uri uri, String channel) onOpen;
  final VoidCallback onCall;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final marks = <Widget>[];

    void add(Widget icon, Color colour, String label, VoidCallback onTap) {
      marks.add(_Mark(icon: icon, colour: colour, label: label, onTap: onTap));
    }

    if ((vendor.phone ?? '').isNotEmpty) {
      add(
        const Icon(Icons.phone_rounded, size: 15, color: Colors.white),
        const Color(0xFF3E9C86),
        'اتصال',
        onCall,
      );
    }

    final wa = vendorWhatsappUri(
      (vendor.whatsapp ?? '').isNotEmpty
          ? vendor.whatsapp!
          : (vendor.phone ?? ''),
    );
    if (wa != null) {
      add(
        const Icon(Icons.chat_rounded, size: 15, color: Colors.white),
        const Color(0xFF25D366),
        'واتساب',
        () => onOpen(wa, VendorContactService.channelWhatsapp),
      );
    }

    void social(
      String? raw,
      Widget icon,
      Color colour,
      String label,
      String channel,
      String Function(String) toUrl,
    ) {
      final v = (raw ?? '').trim();
      if (v.isEmpty) return;
      final url = v.startsWith('http') ? v : toUrl(v);
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      add(icon, colour, label, () => onOpen(uri, channel));
    }

    social(
      vendor.instagram,
      const FaIcon(FontAwesomeIcons.instagram, size: 14, color: Colors.white),
      const Color(0xFFDD2A7B),
      'إنستغرام',
      VendorContactService.channelInstagram,
      (h) => 'https://www.instagram.com/${h.replaceFirst('@', '')}/',
    );
    social(
      vendor.facebook,
      const FaIcon(FontAwesomeIcons.facebookF, size: 14, color: Colors.white),
      const Color(0xFF1877F2),
      'فيسبوك',
      VendorContactService.channelFacebook,
      (h) => 'https://www.facebook.com/${h.replaceFirst('@', '')}',
    );
    social(
      vendor.tiktok,
      const FaIcon(FontAwesomeIcons.tiktok, size: 14, color: Colors.white),
      const Color(0xFF111111),
      'تيك توك',
      VendorContactService.channelTiktok,
      (h) => 'https://www.tiktok.com/@${h.replaceFirst('@', '')}',
    );
    social(
      vendor.snapchat,
      const FaIcon(FontAwesomeIcons.snapchat, size: 14, color: Colors.white),
      const Color(0xFFD9B300),
      'سناب شات',
      VendorContactService.channelSnapchat,
      (h) => 'https://www.snapchat.com/add/${h.replaceFirst('@', '')}',
    );
    social(
      vendor.website,
      const Icon(Icons.language_rounded, size: 15, color: Colors.white),
      const Color(0xFF6B4132),
      'الموقع',
      VendorContactService.channelWebsite,
      (h) => 'https://$h',
    );

    if ((vendor.address ?? '').isNotEmpty ||
        (vendor.latitude != null && vendor.longitude != null)) {
      add(
        const Icon(Icons.place_rounded, size: 15, color: Colors.white),
        const Color(0xFFE05B4B),
        'الخريطة',
        onMap,
      );
    }

    if (marks.isEmpty) return const SizedBox.shrink();

    // As many to a row as the space beside the name allows (three on a
    // phone), in the reference's order — the map nearest the name, the
    // telephone at the far end — each row starting beside the name so the
    // band has no hole in its middle.
    return Wrap(
      alignment: WrapAlignment.start,
      runSpacing: 6,
      children: marks.reversed.toList(),
    );
  }
}

class _Mark extends StatelessWidget {
  /// One mark's column: the circle, its label, and a little air.
  static const double cell = 38;

  const _Mark({
    required this.icon,
    required this.colour,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final Color colour;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cell,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: colour,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 31,
                height: 31,
                child: Center(child: icon),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating gradient-ringed logo positioned over the hero/sheet boundary.
/// Tapping it opens the Instagram-style story viewer when stories exist.
class _FloatingLogo extends StatefulWidget {
  const _FloatingLogo({
    required this.vendor,
    this.stories = const <StoryModel>[],
    this.size = 116,
  });
  final VendorModel vendor;
  final List<StoryModel> stories;
  final double size;

  @override
  State<_FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<_FloatingLogo>
    with SingleTickerProviderStateMixin {
  /// Only spins while the shop actually has stories to show.
  AnimationController? _spin;

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant _FloatingLogo old) {
    super.didUpdateWidget(old);
    _syncSpin();
  }

  void _syncSpin() {
    if (widget.stories.isNotEmpty) {
      _spin ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 6),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  void _openStories(BuildContext context) {
    if (widget.stories.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerPage(
          vendor: widget.vendor,
          stories: widget.stories,
          // Already on this shop's page.
          canOpenVendor: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final vendor = widget.vendor;
    final stories = widget.stories;
    final hasLogo = (vendor.logo ?? '').isNotEmpty;
    final hasStories = stories.isNotEmpty;

    final logo = SizedBox(
      width: size,
      height: size,
      child: Stack(
        // The stories pill hangs below the circle on purpose (bottom: -4) and
        // carries a white border and a shadow. A Stack clips to its bounds by
        // default, which sliced all three off and left the badge looking cut.
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Outer soft warm glow
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.22),
                  blurRadius: 28,
                  spreadRadius: 1,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          // Gradient ring. When the shop has stories it slowly rotates and
          // switches to a vivid "story" gradient, so it's obvious from the
          // outside that there's something to tap.
          Builder(
            builder: (_) {
              final ring = Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    startAngle: 0,
                    endAngle: 6.2832,
                    colors: hasStories
                        ? const [
                            Color(0xFFF4C64B),
                            Color(0xFFE1306C),
                            Color(0xFFC13584),
                            Color(0xFFF4C64B),
                            Color(0xFFFF7A45),
                            Color(0xFFF4C64B),
                          ]
                        : const [
                            Color(0xFFE6B450),
                            AppColors.primary,
                            Color(0xFFF3D9B1),
                            AppColors.primaryDark,
                            Color(0xFFE6B450),
                            AppColors.accent,
                            Color(0xFFE6B450),
                          ],
                    stops: hasStories
                        ? const [0.0, 0.22, 0.42, 0.62, 0.82, 1.0]
                        : const [0.0, 0.18, 0.35, 0.55, 0.72, 0.88, 1.0],
                  ),
                ),
              );
              if (!hasStories || _spin == null) return ring;
              return AnimatedBuilder(
                animation: _spin!,
                builder: (_, child) => Transform.rotate(
                  angle: _spin!.value * 6.2832,
                  child: child,
                ),
                child: ring,
              );
            },
          ),
          // Thin white separator for a "premium pearl" feel. Sits on top of the
          // ring so the logo never rotates with it.
          Container(
            width: size - 7,
            height: size - 7,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: ClipOval(
              child: hasLogo
                  ? AppNetworkImage(
                      url: vendor.logo,
                      fallbackIcon: Icons.storefront_rounded,
                    )
                  : _LogoFallback(name: vendor.name),
            ),
          ),
          // Subtle inner top highlight
          Positioned(
            top: 6,
            child: Container(
              width: size * 0.55,
              height: size * 0.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Stories pill: makes it unmistakable that there are stories to tap.
          if (hasStories)
            Positioned(
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1306C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.hairline, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'قصص ${stories.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (!hasStories) return logo;

    return Semantics(
      button: true,
      label: 'عرض القصص',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openStories(context),
        child: logo,
      ),
    );
  }
}

/// Fallback: a gold monogram on deep glass.
class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.name});
  final String name;

  String get _initial {
    final t = name.trim();
    if (t.isEmpty) return '★';
    final ch = t.characters.first;
    return ch.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8E5F4A), Color(0xFF4A2C24)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          color: AppColors.accent,
          letterSpacing: 0.5,
          height: 1,
        ),
      ),
    );
  }
}

/// Decorative soft-circle pattern painted over the cover hero.
class _CoverPattern extends StatelessWidget {
  const _CoverPattern();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CoverPatternPainter());
  }
}

class _CoverPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    // Concentric arcs on the right
    for (double r = 40; r < size.width; r += 38) {
      canvas.drawCircle(
        Offset(size.width * 0.92, size.height * 0.18),
        r,
        paint,
      );
    }
    // Soft dots scattered
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.10);
    const positions = [
      Offset(0.18, 0.30),
      Offset(0.32, 0.55),
      Offset(0.55, 0.20),
      Offset(0.72, 0.62),
      Offset(0.12, 0.72),
      Offset(0.46, 0.78),
      Offset(0.86, 0.40),
    ];
    for (final p in positions) {
      canvas.drawCircle(
        Offset(p.dx * size.width, p.dy * size.height),
        3.2,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoldStars extends StatelessWidget {
  const _GoldStars({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Icon(
            i < rating.round()
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            size: 15,
            color: const Color(0xFFE6B450),
          ),
      ],
    );
  }
}

// ============================================================
// ALL REVIEWS SHEET (paginated list of every reviewer)
// ============================================================
class _AllReviewsSheet extends StatefulWidget {
  const _AllReviewsSheet({required this.vendorId, required this.total});
  final int vendorId;
  final int total;

  @override
  State<_AllReviewsSheet> createState() => _AllReviewsSheetState();
}

class _AllReviewsSheetState extends State<_AllReviewsSheet> {
  final _service = ReviewService();
  final _scroll = ScrollController();
  final List<ReviewModel> _reviews = [];
  final Set<int> _ids = {};
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _initialLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final res = await _service.listPagedForVendor(
        widget.vendorId,
        page: _page + 1,
        perPage: 15,
      );
      _page += 1;
      _hasMore = res.hasMore;
      for (final r in res.items) {
        if (_ids.add(r.id)) _reviews.add(r);
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _initialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
          _initialLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, sheetScroll) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Grab handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 10, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.reviews_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'التقييمات (${widget.total})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textMuted,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x22B8835A)),
              Expanded(
                child: _initialLoading
                    ? const Center(child: CenteredLoader())
                    : (_error != null && _reviews.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '$_error'.replaceFirst('Exception: ', ''),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _reviews.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= _reviews.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CenteredLoader(),
                            );
                          }
                          return _ReviewCard(review: _reviews[i]);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// RATING SHEET (submit a review)
// ============================================================
class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.vendor});
  final VendorModel vendor;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _rating = 0;
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر عدد النجوم أولاً')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ReviewService().create(
        vendorId: widget.vendor.id,
        rating: _rating.toDouble(),
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'قيّم ${widget.vendor.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _rating = i),
                    icon: Icon(
                      i <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 38,
                      color: const Color(0xFFE6B450),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              maxLines: 3,
              enabled: !_saving,
              decoration: InputDecoration(
                hintText: 'اكتب تعليقك (اختياري)',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('إرسال التقييم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HIGHLIGHTS SECTION (دائمة، مثل انستجرام)
// ============================================================
class _StoriesSection extends StatelessWidget {
  const _StoriesSection({required this.vendor, required this.future});
  final VendorModel vendor;
  final Future<List<StoryModel>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StoryModel>>(
      future: future,
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final stories = snap.data!;
        if (stories.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 17,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'القصص',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${stories.length}',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            StoriesRing(vendor: vendor, stories: stories),
          ],
        );
      },
    );
  }
}

// ============================================================
// STATS STRIP (rating | reviews | services)
// ============================================================

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.vendor, required this.followers});
  final VendorModel vendor;
  final int followers;

  @override
  Widget build(BuildContext context) {
    // Six, in the reference's order. The review count is not among them: it
    // already stands beside the stars under the name.
    final stats = <_Stat>[
      _Stat(
        value: (vendor.reviewsCount ?? 0) > 0 && vendor.rating != null
            ? vendor.rating!.toStringAsFixed(1)
            : '—',
        label: 'التقييم',
        icon: Icons.star_rounded,
        iconColor: const Color(0xFFE6B450),
      ),
      _Stat(
        value: _formatCompact(followers),
        label: 'المتابعين',
        icon: Icons.groups_rounded,
        iconColor: const Color(0xFFC77DAE),
      ),
      _Stat(
        value: _formatCompact(vendor.viewsCount),
        label: 'المشاهدات',
        icon: Icons.visibility_outlined,
        iconColor: const Color(0xFF3E9C86),
      ),
      _Stat(
        value: _formatCompact(vendor.photosCount),
        label: 'الصور',
        icon: Icons.photo_library_outlined,
        iconColor: const Color(0xFF8E6BC9),
      ),
      _Stat(
        value: _formatCompact(vendor.videosCount),
        label: 'الفيديوهات',
        icon: Icons.videocam_outlined,
        iconColor: const Color(0xFFE05B4B),
      ),
      _Stat(
        value: vendor.city?.name ?? '—',
        label: 'الموقع',
        icon: Icons.location_on_rounded,
        iconColor: const Color(0xFFC9906B),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: AppDecor.card(radius: 20),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  color: Color(0x22B8835A),
                  thickness: 1,
                  width: 1,
                ),
              Expanded(child: stats[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Format an int like 1234 → "1.2K", 1_000_000 → "1M". Used for view counts.
String _formatCompact(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final v = n / 1000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}K';
  }
  final v = n / 1000000;
  return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    this.iconColor,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor ?? AppColors.primary, size: 19),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14.5,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// CONTACT ACTIONS
// ============================================================

/// "نقاط أفراحنا" card on a vendor profile: shows how many users have redeemed
/// points here, and lets a signed-in user redeem 50 points for an in-person
/// discount (once per 24h). The vendor's own owner sees the counter but not the
/// redeem button.
class _PointsRedeemSection extends StatefulWidget {
  const _PointsRedeemSection({required this.vendor});
  final VendorModel vendor;

  @override
  State<_PointsRedeemSection> createState() => _PointsRedeemSectionState();
}

class _PointsRedeemSectionState extends State<_PointsRedeemSection> {
  late int _beneficiaries = widget.vendor.beneficiariesCount;
  bool _busy = false;

  Future<void> _redeem() async {
    final session = context.read<SessionController>();
    if (!session.isSignedIn) {
      await showLoginRequiredDialog(
        context,
        title: 'استبدال النقاط',
        message: 'سجّل الدخول بحساب لتتمكن من استبدال نقاطك لدى هذا المعلن.',
        icon: Icons.stars_rounded,
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('استبدال النقاط'),
        content: const Text(
          'سيتم خصم 50 نقطة من رصيدك مقابل خصم مباشر عند الشراء.\n'
          'أظهر شاشة التأكيد للمعلن عند الشراء. (مرة واحدة كل 24 ساعة لكل معلن)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('استبدال'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final res = await PointsService().redeem(widget.vendor.id);
      if (!mounted) return;
      setState(() => _beneficiaries += 1);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم الاستبدال ✅'),
          content: Text(
            'حصلت على خصم مباشر لدى ${widget.vendor.name}.\n'
            'أظهر هذه الرسالة للمعلن.\nرصيدك المتبقّي: ${res.balance} نقطة.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تم'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isOwner =
        session.user != null &&
        widget.vendor.ownerId != null &&
        session.user!.id == widget.vendor.ownerId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'نقاط أفراحنا',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '$_beneficiaries مستفيد',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'استبدل 50 نقطة واحصل على خصم مباشرة',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (!isOwner) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _redeem,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.redeem_rounded, size: 18),
                label: Text(_busy ? 'جارٍ التحويل…' : 'تحويل 50 نقطة'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// SECTION
// ============================================================

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const Spacer(),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ============================================================
// SERVICE TILE
// ============================================================

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.vendor});
  final ServiceModel service;
  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ServiceDetailsPage(serviceId: service.id, vendor: vendor),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: AppDecor.lift,
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.surface],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: service.image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AppNetworkImage(
                          url: service.image,
                          fallbackIcon: Icons.design_services_rounded,
                        ),
                      )
                    : const Icon(
                        Icons.design_services_rounded,
                        color: AppColors.primaryDark,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (service.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        service.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (service.price != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (service.hasDiscount) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'خصم ${service.discountPercent}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${service.price!.toStringAsFixed(0)} ₪',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.goldDeep],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            service.effectivePrice!.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            '₪',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// REVIEW CARD
// ============================================================

/// How long ago a review was written, in words. An exact date tells you
/// nothing without doing the arithmetic yourself.
String _reviewAge(DateTime at) {
  final days = DateTime.now().difference(at).inDays;
  if (days <= 0) return 'اليوم';
  if (days == 1) return 'أمس';
  if (days < 7) return 'قبل $days أيام';
  if (days < 30) return 'قبل ${days ~/ 7} أسابيع';
  if (days < 365) return 'قبل ${days ~/ 30} أشهر';
  return 'قبل ${days ~/ 365} سنوات';
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final ReviewModel review;
  @override
  Widget build(BuildContext context) {
    final avatar = review.user?.avatar ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecor.card(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.surface],
                  ),
                ),
                alignment: Alignment.center,
                child: avatar.isNotEmpty
                    ? AppNetworkImage(url: avatar, fallbackIcon: Icons.person)
                    : Text(
                        review.displayName.characters.first,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w900,
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
                      review.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (review.createdAt != null)
                      Text(
                        _reviewAge(review.createdAt!),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              _GoldStars(rating: review.rating),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textDark,
                height: 1.55,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY BOX
// ============================================================

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// GLASS ICON BUTTON
// ============================================================

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, this.onTap, this.iconColor});
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: iconColor ?? Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ============================================================
// BOOK FAB
// ============================================================

BoxDecoration _cardDecoration() => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(24),
  boxShadow: AppDecor.lift,
);
