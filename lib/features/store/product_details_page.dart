import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/state/cart.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../vendors/vendor_details_page.dart';
import 'marketplace.dart';

/// Full product view: swipeable gallery that opens fullscreen and zooms,
/// the shop it belongs to, price, description, and the buy actions.
class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({super.key, required this.product});
  final ProductModel product;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final _pageController = PageController();
  final _scroll = ScrollController();
  int _page = 0;
  bool _collapsed = false;

  static const _expandedHeight = 340.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  /// The bar only carries the product name once the photo has scrolled away —
  /// over the image the name would fight with the gallery controls.
  void _onScroll() {
    final top = MediaQuery.of(context).viewPadding.top;
    final collapsed = _scroll.offset > _expandedHeight - kToolbarHeight - top;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ProductModel get p => widget.product;

  void _openFullscreen(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _GalleryViewer(
          images: p.gallery,
          initialIndex: index,
          heroPrefix: 'product-${p.id}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = p.gallery;
    final qty = context.select<CartController, int>((c) => c.quantityOf(p.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            expandedHeight: _expandedHeight,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            // A plain white arrow disappears on pale photos, so it rides in a
            // dark chip until the bar collapses onto its solid colour.
            leading: Center(
              child: _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                translucent: !_collapsed,
                onTap: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Center(
                  child: _RoundIconButton(
                    icon: Icons.shopping_cart_rounded,
                    translucent: !_collapsed,
                    badge: context.select<CartController, int>((c) => c.count),
                    onTap: () => openCart(context),
                  ),
                ),
              ),
            ],
            title: AnimatedOpacity(
              opacity: _collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.isEmpty)
                    Container(
                      color: AppColors.primaryLight,
                      child: const Icon(Icons.shopping_bag_outlined,
                          size: 72, color: AppColors.primary),
                    )
                  else
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemCount: images.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _openFullscreen(i),
                        child: Hero(
                          tag: 'product-${p.id}-$i',
                          child: AppNetworkImage(
                            url: images[i],
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.shopping_bag_outlined,
                          ),
                        ),
                      ),
                    ),
                  // Scrim so the back button stays visible over pale photos.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 90,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    PositionedDirectional(
                      bottom: 14,
                      start: 0,
                      end: 0,
                      child: _Dots(count: images.length, index: _page),
                    ),
                  if (images.length > 1)
                    PositionedDirectional(
                      bottom: 12,
                      end: 14,
                      child: _Pill(text: '${_page + 1}/${images.length}'),
                    ),
                  if (images.isNotEmpty)
                    PositionedDirectional(
                      bottom: 12,
                      start: 14,
                      child: _Pill(
                        icon: Icons.zoom_out_map_rounded,
                        text: 'اضغط للتكبير',
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PriceRow(product: p),
                  const SizedBox(height: 16),
                  _ShopRow(product: p),
                  if (p.description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'الوصف',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.description,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.8,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                  if (images.length > 1) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'كل الصور',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 74,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                            );
                          },
                          child: Container(
                            width: 74,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: i == _page
                                    ? AppColors.primary
                                    : AppColors.primaryLight,
                                width: i == _page ? 2.2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AppNetworkImage(
                                url: images[i],
                                fallbackIcon: Icons.image_outlined,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BuyBar(product: p, qty: qty),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.translucent,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final bool translucent;
  final VoidCallback onTap;

  /// Draws a count bubble on the icon when greater than zero.
  final int badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: translucent ? 0.38 : 0),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          PositionedDirectional(
            top: -1,
            end: -3,
            child: AnimatedScale(
              scale: badge > 0 ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 17),
                decoration: BoxDecoration(
                  color: AppColors.discount,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Long galleries would run off the screen as dots, so cap the strip.
    final shown = count > 8 ? 8 : count;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(shown, (i) {
        final active = i == (index < shown ? index : shown - 1);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white54,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    if (product.effectivePrice <= 0) {
      return const Text(
        'السعر عند الطلب',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: AppColors.primaryDark,
        ),
      );
    }
    return Row(
      children: [
        Text(
          '₪${money(product.effectivePrice)}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryDark,
          ),
        ),
        if (product.hasDiscount) ...[
          const SizedBox(width: 10),
          Text(
            '₪${money(product.price)}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.discount,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              'وفّر ${(100 - (product.effectivePrice / product.price * 100)).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.product});
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VendorDetailsPage(vendorId: product.vendorId),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryLight),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: AppNetworkImage(
                    url: product.vendorLogo,
                    fallbackIcon: Icons.storefront_rounded,
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
                      product.vendorName ?? 'المتجر',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (product.vendorRating != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFE0AE44)),
                          const SizedBox(width: 3),
                          Text(
                            '${product.vendorRating!.toStringAsFixed(1)} '
                            '(${product.vendorReviewsCount ?? 0})',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Text(
                'زيارة المتجر',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const Icon(Icons.chevron_left_rounded,
                  color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuyBar extends StatelessWidget {
  const _BuyBar({required this.product, required this.qty});
  final ProductModel product;
  final int qty;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartController>();

    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, 12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (qty > 0) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    color: AppColors.primaryDark,
                    onPressed: () => setCartQuantity(cart, product.id, qty - 1),
                  ),
                  Text(
                    '$qty',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    color: AppColors.primaryDark,
                    onPressed: () => setCartQuantity(cart, product.id, qty + 1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: product.isAvailable
                    ? () => qty > 0
                        ? buyNow(context, product)
                        : addToCart(context, product)
                    : null,
                icon: Icon(
                  qty > 0
                      ? Icons.shopping_cart_checkout_rounded
                      : Icons.add_shopping_cart_rounded,
                  size: 19,
                ),
                label: Text(
                  !product.isAvailable
                      ? 'غير متوفر'
                      : (qty > 0 ? 'إتمام الطلب' : 'أضف إلى السلة'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fullscreen, pinch-to-zoom gallery.
class _GalleryViewer extends StatefulWidget {
  const _GalleryViewer({
    required this.images,
    required this.initialIndex,
    required this.heroPrefix,
  });
  final List<String> images;
  final int initialIndex;

  /// Must match the tags used on the page below, or the image won't fly.
  final String heroPrefix;

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.images.length,
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Hero(
                  tag: '${widget.heroPrefix}-$i',
                  child: AppNetworkImage(
                    url: widget.images[i],
                    fit: BoxFit.contain,
                    fallbackIcon: Icons.broken_image_outlined,
                    fallbackColor: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (widget.images.length > 1)
                    _Pill(text: '${_index + 1}/${widget.images.length}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
