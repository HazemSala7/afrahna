import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/services/local_favorites.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../bookings/booking_create_page.dart';
import '../services/service_details_page.dart';
import 'story_viewer_page.dart';

class VendorDetailsPage extends StatefulWidget {
  const VendorDetailsPage({super.key, required this.vendorId});

  final int vendorId;

  @override
  State<VendorDetailsPage> createState() => _VendorDetailsPageState();
}

class _VendorDetailsPageState extends State<VendorDetailsPage> {
  static const double _coverHeight = 280;
  static const double _logoSize = 116;

  late Future<VendorModel> _vendorFuture;
  late Future<List<ServiceModel>> _servicesFuture;
  late Future<List<ReviewModel>> _reviewsFuture;
  late Future<List<StoryModel>> _storiesFuture;
  final ScrollController _scrollController = ScrollController();
  bool _favLoading = false;
  bool? _favLocal;

  @override
  void initState() {
    super.initState();
    _vendorFuture = VendorService().show(widget.vendorId);
    _servicesFuture = ServiceService().list(vendorId: widget.vendorId);
    _reviewsFuture = ReviewService().listForVendor(widget.vendorId);
    _storiesFuture = StoryService().listForVendor(widget.vendorId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر فتح: $uri')),
      );
    }
  }

  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

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
                        padding: const EdgeInsets.fromLTRB(18, 92, 18, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IdentityHeader(vendor: vendor),
                            const SizedBox(height: 18),
                            _StatsStrip(
                              vendor: vendor,
                              servicesFuture: _servicesFuture,
                            ),
                            const SizedBox(height: 18),
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
                          onWhatsApp: () {
                            final p = _digits(vendor.phone ?? '');
                            if (p.isEmpty) return;
                            _launch(Uri.parse('https://wa.me/$p'));
                          },
                          onMap: () {
                            final q = Uri.encodeComponent(
                                vendor.address ?? vendor.name);
                            _launch(Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=$q'));
                          },
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
                        const SizedBox(height: 18),
                        _Section(
                          icon: Icons.design_services_outlined,
                          title: 'الخدمات المقدّمة',
                          child: FutureBuilder<List<ServiceModel>>(
                            future: _servicesFuture,
                            builder: (context, sSnap) {
                              if (sSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CenteredLoader(),
                                );
                              }
                              final services = sSnap.data ?? const [];
                              if (services.isEmpty) {
                                return const _EmptyBox(
                                  icon: Icons.inventory_2_outlined,
                                  text: 'لا توجد خدمات معروضة بعد',
                                );
                              }
                              return Column(
                                children: [
                                  for (final s in services)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _ServiceTile(
                                        service: s,
                                        vendor: vendor,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Section(
                          icon: Icons.reviews_outlined,
                          title: 'التقييمات',
                          trailing: vendor.rating != null
                              ? _RatingChip(
                                  rating: vendor.rating!,
                                  count: vendor.reviewsCount ?? 0,
                                )
                              : null,
                          child: FutureBuilder<List<ReviewModel>>(
                            future: _reviewsFuture,
                            builder: (context, rSnap) {
                              if (rSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CenteredLoader(),
                                );
                              }
                              final reviews = rSnap.data ?? const [];
                              if (reviews.isEmpty) {
                                return const _EmptyBox(
                                  icon: Icons.rate_review_outlined,
                                  text: 'كن أول من يقيّم هذا المزوّد ✨',
                                );
                              }
                              return Column(
                                children: [
                                  for (final r in reviews.take(5))
                                    _ReviewCard(review: r),
                                ],
                              );
                            },
                          ),
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
            const SizedBox(width: 6),
            const Icon(Icons.verified_rounded,
                color: AppColors.primary, size: 22),
          ],
        ),
        const SizedBox(height: 8),
        if (vendor.category != null)
          Text(
            '${vendor.category!.name}'
            '${vendor.city != null ? ' · ${vendor.city!.name}' : ''}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        const SizedBox(height: 10),
        if (vendor.rating != null) _GoldStars(rating: vendor.rating!),
      ],
    );
  }
}

/// Floating gradient-ringed logo positioned over the hero/sheet boundary.
/// Tapping it opens the Instagram-style story viewer when stories exist.
class _FloatingLogo extends StatelessWidget {
  const _FloatingLogo({
    required this.vendor,
    this.stories = const <StoryModel>[],
  });
  final VendorModel vendor;
  final List<StoryModel> stories;

  void _openStories(BuildContext context) {
    if (stories.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerPage(
          vendor: vendor,
          stories: stories,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const size = 116.0;
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
          // Metallic gradient ring
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(3.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                startAngle: 0,
                endAngle: 6.2832,
                colors: [
                  Color(0xFFE6B450),
                  AppColors.primary,
                  Color(0xFFF3D9B1),
                  AppColors.primaryDark,
                  Color(0xFFE6B450),
                  AppColors.accent,
                  Color(0xFFE6B450),
                ],
                stops: [0.0, 0.18, 0.35, 0.55, 0.72, 0.88, 1.0],
              ),
            ),
            // Thin white separator for a "premium pearl" feel
            child: Container(
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
          // Stories badge: small "play" dot indicating tappable stories
          if (hasStories)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryDark,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${stories.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
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
  const _StatsStrip({required this.vendor, required this.servicesFuture});
  final VendorModel vendor;
  final Future<List<ServiceModel>> servicesFuture;

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
              child: _Stat(
                value: '${vendor.reviewsCount ?? 0}',
                label: 'مراجعة',
                icon: Icons.chat_bubble_outline_rounded,
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
    required this.onWhatsApp,
    required this.onMap,
  });
  final VendorModel vendor;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final hasPhone = (vendor.phone ?? '').isNotEmpty;
    final hasAddress = (vendor.address ?? '').isNotEmpty;
    return Row(
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
            icon: Icons.chat_rounded,
            label: 'واتساب',
            enabled: hasPhone,
            color: const Color(0xFF25D366),
            onTap: onWhatsApp,
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
    );
  }
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
            if (trailing != null) trailing!,
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
                        service.price!.toStringAsFixed(0),
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
                  (review.user?.name ?? '؟').characters.first,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.user?.name ?? 'مستخدم',
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
