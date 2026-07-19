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
  static const double _coverHeight = 280;
  static const double _logoSize = 116;

  late Future<VendorModel> _vendorFuture;
  late Future<List<ServiceModel>> _servicesFuture;
  late Future<({List<ReviewModel> items, int total, bool hasMore})>
      _reviewsFuture;
  late Future<List<StoryModel>> _storiesFuture;
  late Future<List<HighlightModel>> _highlightsFuture;
  final ScrollController _scrollController = ScrollController();
  bool _favLoading = false;
  bool? _favLocal;

  /// Live follower count once the user follows/unfollows (overrides the value
  /// loaded with the vendor so the stats strip updates instantly).
  int? _followersLive;

  @override
  void initState() {
    super.initState();
    _vendorFuture = VendorService().show(widget.vendorId);
    _servicesFuture = ServiceService().list(vendorId: widget.vendorId);
    _reviewsFuture = ReviewService().listPagedForVendor(widget.vendorId);
    _storiesFuture = StoryService().listForVendor(widget.vendorId);
    _highlightsFuture = HighlightService().listForVendor(widget.vendorId);
  }

  @override
  void dispose() {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نسخ رابط المشاركة')),
        );
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
          content: Text(isFav ? 'تمت الإضافة للمفضلة' : 'تمت الإزالة من المفضلة'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Future<void> _launch(Uri uri) async {
    final ok = await openExternal(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر فتح: $uri')),
      );
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
        message: 'سجّل الدخول بحساب لتتمكن من إضافة تقييم لهذا المزوّد،'
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
        _reviewsFuture = ReviewService().listPagedForVendor(widget.vendorId);
        _vendorFuture = VendorService().show(widget.vendorId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شكراً! سيظهر تقييمك بعد موافقة الإدارة'),
        ),
      );
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
      backgroundColor: AppColors.background,
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
                _vendorFuture = VendorService().show(widget.vendorId);
              }),
            );
          }
          final vendor = snap.data!;
          final isFav = _favLocal ??
              LocalFavorites.instance.isFavorite(vendor.id);

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
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                        ),
                        // top padding leaves room for the floating logo
                        padding: const EdgeInsets.fromLTRB(18, 60, 18, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IdentityHeader(vendor: vendor),
                            const SizedBox(height: 18),
                            _StatsStrip(
                              vendor: vendor,
                              servicesFuture: _servicesFuture,
                              reviewsFuture: _reviewsFuture,
                              followers: _followersLive ?? vendor.followersCount,
                            ),
                            const SizedBox(height: 18),
                            const _DiscountBanner(),
                            _HighlightsSection(
                              vendor: vendor,
                              future: _highlightsFuture,
                            ),
                            _StoriesSection(
                              vendor: vendor,
                              future: _storiesFuture,
                        ),
                        const SizedBox(height: 16),
                        _ContactActions(
                          vendor: vendor,
                          onCall: () {
                            final p = _digits(vendor.phone ?? '');
                            if (p.isEmpty) return;
                            _launch(Uri.parse('tel:$p'));
                          },
                          onMap: () {
                            // Always show the map inside the app. Use the shop's
                            // coordinates when set; otherwise geocode its address.
                            final hasCoords = vendor.latitude != null &&
                                vendor.longitude != null;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VendorMapPage(
                                  title: vendor.name,
                                  address: vendor.address,
                                  query: vendor.address ?? vendor.name,
                                  initialLocation: hasCoords
                                      ? LatLng(vendor.latitude!,
                                          vendor.longitude!)
                                      : null,
                                ),
                              ),
                            );
                          },
                          onOpenSocial: _launch,
                        ),
                        const SizedBox(height: 22),
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
                            vendor: vendor,
                            highlightProductId: widget.highlightProductId,
                          ),
                        ],
                        const SizedBox(height: 18),
                        VendorPostsFeed(
                          vendorId: vendor.id,
                          showHeader: true,
                        ),
                        // Services section — hidden entirely when the vendor
                        // has no services (no empty placeholder shown).
                        FutureBuilder<List<ServiceModel>>(
                          future: _servicesFuture,
                          builder: (context, sSnap) {
                            final services = sSnap.data ?? const <ServiceModel>[];
                            if (services.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 18),
                                _Section(
                                  icon: Icons.design_services_outlined,
                                  title: 'الخدمات المقدّمة',
                                  child: Column(
                                    children: [
                                      for (final s in services)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 10),
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
                        const SizedBox(height: 18),
                        FutureBuilder<
                            ({
                              List<ReviewModel> items,
                              int total,
                              bool hasMore
                            })>(
                          future: _reviewsFuture,
                          builder: (context, rSnap) {
                            final data = rSnap.data;
                            final reviews = data?.items ?? const <ReviewModel>[];
                            // Real reviewer count from the server paginator.
                            final total = data?.total ??
                                (vendor.reviewsCount ?? reviews.length);
                            return _Section(
                              icon: Icons.reviews_outlined,
                              title: 'التقييمات',
                              trailing: vendor.rating != null
                                  ? _RatingChip(
                                      rating: vendor.rating!,
                                      count: total,
                                    )
                                  : null,
                              child: Builder(builder: (context) {
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
                                        text: 'كن أول من يقيّم هذا المزوّد ✨',
                                      )
                                    else
                                      for (final r in reviews.take(5))
                                        _ReviewCard(review: r),
                                    // More than the preview → open the full,
                                    // paginated list in a dialog sheet.
                                    if (total > 5) ...[
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: double.infinity,
                                        child: TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                          ),
                                          icon: const Icon(
                                              Icons.expand_more_rounded,
                                              size: 20),
                                          label: Text(
                                              'عرض كل التقييمات ($total)'),
                                          onPressed: () => _openAllReviews(
                                              vendor, total),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(
                                              color: AppColors.primary),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        icon: const Icon(
                                            Icons.star_rounded, size: 20),
                                        label: const Text('أضف تقييمك'),
                                        onPressed: () =>
                                            _openRatingSheet(vendor),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            );
                          },
                        ),
                        const SizedBox(height: 110),
                      ],
                    ),
                  ),
                    ),
                  ),
                ],
              ),
              // Floating logo overlapping the cover/sheet boundary; follows scroll.
              AnimatedBuilder(
                animation: _scrollController,
                builder: (context, _) {
                  final offset = _scrollController.hasClients
                      ? _scrollController.offset
                      : 0.0;
                  // logo center at cover bottom; shrink/fade as user scrolls
                  final top = _coverHeight - _logoSize / 2 - offset;
                  final progress = (offset / (_coverHeight - 80)).clamp(0.0, 1.0);
                  if (progress >= 1.0) return const SizedBox.shrink();
                  return Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: 1 - progress,
                      child: Center(
                        child: Transform.scale(
                          scale: 1 - progress * 0.3,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              IgnorePointer(
                                child: FutureBuilder<List<ServiceModel>>(
                                  future: _servicesFuture,
                                  builder: (_, snap) => _WingPill(
                                    icon: Icons.design_services_rounded,
                                    iconColor: AppColors.primaryDark,
                                    value: snap.hasData
                                        ? '${snap.data!.length}'
                                        : '—',
                                    label: 'خدمة',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              FutureBuilder<List<StoryModel>>(
                                future: _storiesFuture,
                                builder: (_, sSnap) {
                                  final stories =
                                      sSnap.data ?? const <StoryModel>[];
                                  return _FloatingLogo(
                                    vendor: vendor,
                                    stories: stories,
                                  );
                                },
                              ),
                              const SizedBox(width: 14),
                              IgnorePointer(
                                child: _WingPill(
                                  icon: Icons.star_rounded,
                                  iconColor: const Color(0xFFE6B450),
                                  value: vendor.rating != null
                                      ? vendor.rating!.toStringAsFixed(1)
                                      : '—',
                                  label: 'تقييم',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Fixed top action buttons that stay visible when scrolled
              Positioned(
                top: MediaQuery.of(context).padding.top + 6,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    _GlassIconButton(
                      icon: Icons.arrow_forward_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    FollowButton(
                      vendorId: vendor.id,
                      initiallyFollowing: vendor.isFollowing,
                      followersCount: _followersLive ?? vendor.followersCount,
                      compact: true,
                      onFollowersChanged: (c) =>
                          setState(() => _followersLive = c),
                    ),
                    const SizedBox(width: 8),
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
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<VendorModel>(
        future: _vendorFuture,
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          return _BookFab(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingCreatePage(vendor: snap.data!),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: AppBottomNav(
        current: -1,
        onTap: _goToTab,
      ),
    );
  }

  Widget _buildHero(BuildContext context, VendorModel vendor) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: false,
      stretch: true,
      backgroundColor: AppColors.primaryDark,
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
            // Base: image, or warm gradient fallback if no cover
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
                      Color(0xFFD9B68A),
                      Color(0xFFB8835A),
                      Color(0xFF8B5A3C),
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
                      color: Colors.white.withValues(alpha: 0.14),
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
                    Color(0xCC2D1810),
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
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFFF6E6), Color(0xFFF6E3CC)],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, AppColors.primaryDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
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
                RichText(
                  text: const TextSpan(
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
                          color: AppColors.primary,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                vendor.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: AppColors.textDark,
                  height: 1.2,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (vendor.isVip ||
                vendor.isPremium ||
                vendor.activePlan == 'featured') ...[
              const SizedBox(width: 6),
              TierBadge(
                vip: vendor.isVip,
                featured:
                    vendor.isPremium || vendor.activePlan == 'featured',
                size: 24,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (vendor.category != null)
              Flexible(
                child: Text(
                  '${vendor.category!.name}'
                  '${vendor.city != null ? ' · ${vendor.city!.name}' : ''}',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            if (vendor.category != null && vendor.rating != null) ...[
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 14,
                color: AppColors.textMuted.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 10),
            ],
            if (vendor.rating != null) _GoldStars(rating: vendor.rating!),
          ],
        ),
      ],
    );
  }
}

/// Floating gradient-ringed logo positioned over the hero/sheet boundary.
/// Tapping it opens the Instagram-style story viewer when stories exist.
class _FloatingLogo extends StatefulWidget {
  const _FloatingLogo({
    required this.vendor,
    this.stories = const <StoryModel>[],
  });
  final VendorModel vendor;
  final List<StoryModel> stories;

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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const size = 116.0;
    final vendor = widget.vendor;
    final stories = widget.stories;
    final hasLogo = (vendor.logo ?? '').isNotEmpty;
    final hasStories = stories.isNotEmpty;

    final logo = SizedBox(
      width: size,
      height: size,
      child: Stack(
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
                  color: AppColors.primaryDark.withValues(alpha: 0.28),
                  blurRadius: 28,
                  spreadRadius: 1,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          // Gradient ring. When the shop has stories it slowly rotates and
          // switches to a vivid "story" gradient, so it's obvious from the
          // outside that there's something to tap.
          Builder(builder: (_) {
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
          }),
          // Thin white separator for a "premium pearl" feel. Sits on top of the
          // ring so the logo never rotates with it.
          Container(
            width: size - 7,
            height: size - 7,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1306C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
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
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 13),
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

/// Premium fallback: monogram on a cream/gold gradient.
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
          colors: [
            AppColors.primaryLight,
            Color(0xFFEFD4B0),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          color: AppColors.primaryDark,
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
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    // Concentric arcs on the right
    for (double r = 40; r < size.width; r += 38) {
      canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.18), r, paint);
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

/// Two small floating stat pills that flank the floating logo.
class _WingPill extends StatelessWidget {
  const _WingPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.8), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: AppColors.textDark,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
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
            size: 18,
            color: const Color(0xFFE6B450),
          ),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            fontSize: 13,
          ),
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
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final res = await _service.listPagedForVendor(
          widget.vendorId, page: _page + 1, perPage: 15);
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
                    const Icon(Icons.reviews_outlined,
                        color: AppColors.primary, size: 22),
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
                                '$_error'
                                    .replaceFirst('Exception: ', ''),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textMuted),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر عدد النجوم أولاً')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
                fillColor: Colors.white,
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
                            strokeWidth: 2, color: Colors.white),
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
class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.vendor, required this.future});
  final VendorModel vendor;
  final Future<List<HighlightModel>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HighlightModel>>(
      future: future,
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final highlights =
            snap.data!.where((h) => h.items.isNotEmpty).toList();
        if (highlights.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HighlightsRail(vendor: vendor, highlights: highlights),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

// ============================================================
// STORIES SECTION
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
                  child: const Icon(Icons.auto_awesome_rounded,
                      size: 17, color: AppColors.primaryDark),
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
                      horizontal: 8, vertical: 2),
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
  const _StatsStrip({
    required this.vendor,
    required this.servicesFuture,
    required this.reviewsFuture,
    required this.followers,
  });
  final VendorModel vendor;
  final Future<List<ServiceModel>> servicesFuture;
  final Future<({List<ReviewModel> items, int total, bool hasMore})>
      reviewsFuture;
  final int followers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFCF6EE), Color(0xFFF3E3CC)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                value: vendor.rating != null
                    ? vendor.rating!.toStringAsFixed(1)
                    : '—',
                label: 'التقييم',
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFE6B450),
              ),
            ),
            const VerticalDivider(
                color: Color(0x22B8835A), thickness: 1, width: 1),
            Expanded(
              child: FutureBuilder<
                  ({List<ReviewModel> items, int total, bool hasMore})>(
                future: reviewsFuture,
                builder: (_, snap) => _Stat(
                  value: '${snap.data?.total ?? vendor.reviewsCount ?? 0}',
                  label: 'مراجعة',
                  icon: Icons.chat_bubble_outline_rounded,
                ),
              ),
            ),
            const VerticalDivider(
                color: Color(0x22B8835A), thickness: 1, width: 1),
            Expanded(
              child: _Stat(
                value: _formatCompact(vendor.viewsCount),
                label: 'مشاهدة',
                icon: Icons.visibility_outlined,
                iconColor: const Color(0xFF6B8E7F),
              ),
            ),
            const VerticalDivider(
                color: Color(0x22B8835A), thickness: 1, width: 1),
            Expanded(
              child: _Stat(
                value: _formatCompact(followers),
                label: 'متابع',
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFFC77DAE),
              ),
            ),
            const VerticalDivider(
                color: Color(0x22B8835A), thickness: 1, width: 1),
            Expanded(
              child: FutureBuilder<List<ServiceModel>>(
                future: servicesFuture,
                builder: (_, snap) => _Stat(
                  value: snap.hasData ? '${snap.data!.length}' : '—',
                  label: 'خدمة',
                  icon: Icons.design_services_outlined,
                ),
              ),
            ),
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
        Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
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

class _ContactActions extends StatelessWidget {
  const _ContactActions({
    required this.vendor,
    required this.onCall,
    required this.onMap,
    required this.onOpenSocial,
  });
  final VendorModel vendor;
  final VoidCallback onCall;
  final VoidCallback onMap;
  final void Function(Uri uri) onOpenSocial;

  @override
  Widget build(BuildContext context) {
    final hasPhone = (vendor.phone ?? '').isNotEmpty;
    final hasAddress = (vendor.address ?? '').isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: .6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.phone_rounded,
                  label: 'اتصال',
                  enabled: hasPhone,
                  color: AppColors.primary,
                  onTap: onCall,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.location_on_rounded,
                  label: 'الموقع',
                  enabled: hasAddress || vendor.name.isNotEmpty,
                  color: const Color(0xFFE57373),
                  onTap: onMap,
                ),
              ),
            ],
          ),
          _SocialRow(vendor: vendor, onOpen: onOpenSocial),
        ],
      ),
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.vendor, required this.onOpen});

  final VendorModel vendor;
  final void Function(Uri uri) onOpen;

  static String _handle(String v) {
    var s = v.trim();
    if (s.startsWith('@')) s = s.substring(1);
    return s;
  }

  Uri? _instagramUri(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return Uri.parse(s);
    return Uri.parse('https://www.instagram.com/${_handle(s)}/');
  }

  Uri? _tiktokUri(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return Uri.parse(s);
    return Uri.parse('https://www.tiktok.com/@${_handle(s)}');
  }

  Uri? _snapchatUri(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return Uri.parse(s);
    return Uri.parse('https://www.snapchat.com/add/${_handle(s)}');
  }

  Uri? _facebookUri(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return Uri.parse(s);
    return Uri.parse('https://www.facebook.com/${_handle(s)}');
  }

  // Opens the chat with a prefilled message so the vendor knows the enquiry
  // came from the app.
  Uri? _whatsappUri(String v) => vendorWhatsappUri(v);

  @override
  Widget build(BuildContext context) {
    final items = <_SocialItem>[];

    final wa = vendor.whatsapp ?? '';
    if (wa.isNotEmpty) {
      final uri = _whatsappUri(wa);
      if (uri != null) {
        items.add(_SocialItem(
          icon: FontAwesomeIcons.whatsapp,
          label: 'واتساب',
          gradient: const LinearGradient(
            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          glow: const Color(0xFF25D366),
          uri: uri,
        ));
      }
    }

    final ig = vendor.instagram ?? '';
    if (ig.isNotEmpty) {
      final uri = _instagramUri(ig);
      if (uri != null) {
        items.add(_SocialItem(
          icon: FontAwesomeIcons.instagram,
          label: 'إنستغرام',
          gradient: const LinearGradient(
            colors: [
              Color(0xFFF58529),
              Color(0xFFDD2A7B),
              Color(0xFF8134AF),
              Color(0xFF515BD4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          glow: const Color(0xFFDD2A7B),
          uri: uri,
        ));
      }
    }

    final tt = vendor.tiktok ?? '';
    if (tt.isNotEmpty) {
      final uri = _tiktokUri(tt);
      if (uri != null) {
        items.add(_SocialItem(
          icon: FontAwesomeIcons.tiktok,
          label: 'تيك توك',
          gradient: const LinearGradient(
            colors: [Color(0xFF010101), Color(0xFF222222)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          glow: const Color(0xFF25F4EE),
          uri: uri,
        ));
      }
    }

    final sc = vendor.snapchat ?? '';
    if (sc.isNotEmpty) {
      final uri = _snapchatUri(sc);
      if (uri != null) {
        items.add(_SocialItem(
          icon: FontAwesomeIcons.snapchat,
          label: 'سناب شات',
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFC00), Color(0xFFFFE600)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          iconColor: Colors.black,
          glow: const Color(0xFFFFFC00),
          uri: uri,
        ));
      }
    }

    final fb = vendor.facebook ?? '';
    if (fb.isNotEmpty) {
      final uri = _facebookUri(fb);
      if (uri != null) {
        items.add(_SocialItem(
          icon: FontAwesomeIcons.facebookF,
          label: 'فيسبوك',
          gradient: const LinearGradient(
            colors: [Color(0xFF1877F2), Color(0xFF0A5BCB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          glow: const Color(0xFF1877F2),
          uri: uri,
        ));
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.primaryLight.withValues(alpha: .7),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.share_rounded,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'تابعنا على',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.primaryLight.withValues(alpha: .7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final it in items)
                Expanded(
                  child: Center(
                    child: _SocialTile(
                        item: it, onTap: () => onOpen(it.uri)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialTile extends StatefulWidget {
  const _SocialTile({required this.item, required this.onTap});
  final _SocialItem item;
  final VoidCallback onTap;

  @override
  State<_SocialTile> createState() => _SocialTileState();
}

class _SocialTileState extends State<_SocialTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: 58,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: it.gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: it.glow.withValues(alpha: .35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(it.icon, color: it.iconColor, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                it.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialItem {
  _SocialItem({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.glow,
    required this.uri,
    this.iconColor = Colors.white,
  });
  final IconData icon;
  final String label;
  final Gradient gradient;
  final Color glow;
  final Color iconColor;
  final Uri uri;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : AppColors.textMuted;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withValues(alpha: 0.22), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: c, size: 19),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
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

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFE6B450), size: 16),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              fontSize: 12.5,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
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
      color: Colors.white,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, Color(0xFFE7CDA9)],
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
                    : const Icon(Icons.design_services_rounded,
                        color: AppColors.primaryDark, size: 26),
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
                            horizontal: 7, vertical: 3),
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
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final ReviewModel review;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primaryLight, Color(0xFFE7CDA9)],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  review.displayName.characters.first,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              _RatingChip(rating: review.rating, count: 0),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: const TextStyle(
                color: AppColors.textDark,
                height: 1.6,
                fontSize: 13,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.12), width: 1),
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
  const _GlassIconButton({
    required this.icon,
    this.onTap,
    this.iconColor,
  });
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

class _BookFab extends StatelessWidget {
  const _BookFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'احجز الآن',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
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

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColors.cardShadow,
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
