import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/state/cart.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import 'cart_page.dart';
import 'product_details_page.dart';

String money(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Adds [product] to the shared cart, asking first when the cart already holds
/// another shop's items — an order belongs to exactly one shop, so this is the
/// single place that decision is made for the whole app.
Future<void> addToCart(BuildContext context, ProductModel product) async {
  final cart = context.read<CartController>();
  final result = cart.add(product);

  if (result == CartAddResult.otherVendor) {
    // A distinct buzz for "that didn't just work" — the dialog is a stop, not
    // a confirmation.
    HapticFeedback.heavyImpact();
    final current = cart.vendorName ?? 'محل آخر';
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سلة من محل واحد'),
        content: Text(
          'سلتك تحتوي منتجات من «$current».\n'
          'الطلب يكون من محل واحد فقط — هل تريد إفراغ السلة والبدء بمنتجات '
          '«${product.vendorName ?? 'هذا المحل'}»؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إبقاء سلتي'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ابدأ سلة جديدة'),
          ),
        ],
      ),
    );
    if (replace != true) return;
    cart.startNewCart(product);
  }

  // No snackbar: it used to sit across the bottom and cover the cart bar —
  // the very thing the customer needs to reach next. The buzz, the button
  // turning into a stepper and the cart badge pulsing already confirm the add.
  HapticFeedback.mediumImpact();
}

/// "اشترِ الآن" — puts just this product in the cart and goes to checkout.
Future<void> buyNow(BuildContext context, ProductModel product) async {
  final cart = context.read<CartController>();
  if (cart.add(product) == CartAddResult.otherVendor) {
    HapticFeedback.heavyImpact();
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سلة من محل واحد'),
        content: Text(
          'سلتك تحتوي منتجات من «${cart.vendorName ?? 'محل آخر'}». '
          'الشراء الآن سيُفرغها ويبدأ طلبًا جديدًا. متابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    if (replace != true) return;
    cart.startNewCart(product);
  }
  HapticFeedback.mediumImpact();
  if (!context.mounted) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()));
}

/// Opens the full product view.
void openProduct(BuildContext context, ProductModel product) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
  );
}

/// Product tile used by the marketplace row and grid.
class MarketProductCard extends StatelessWidget {
  const MarketProductCard({
    super.key,
    required this.product,
    this.width = 160,
    this.swipeableGallery = true,
  });

  final ProductModel product;
  final double width;

  /// Whether the image strip can be swiped in place. Turned off inside
  /// horizontally scrolling rows, where a page view on every card would
  /// swallow the drags that scroll the row itself.
  final bool swipeableGallery;

  @override
  Widget build(BuildContext context) {
    final qty = context.select<CartController, int>(
      (c) => c.quantityOf(product.id),
    );

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => openProduct(context, product),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
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
                // Fixed-ratio image keeps every card the same height, so the
                // grid has no ragged gaps.
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: SizedBox(
                        height: 146,
                        width: double.infinity,
                        child: _CardGallery(
                          product: product,
                          swipeable: swipeableGallery,
                        ),
                      ),
                    ),
                    if (product.hasDiscount)
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.discount,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.discount.withValues(alpha: .4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '-${(100 - (product.effectivePrice / product.price * 100)).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    // Shop rating sits on the image so the body stays compact.
                    // Shown even at 0.0 — the vendor lists elsewhere in the app
                    // do the same, and hiding it made the badge look broken.
                    if (product.vendorRating != null)
                      PositionedDirectional(
                        bottom: 8,
                        start: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 12, color: Color(0xFFFFC961)),
                              const SizedBox(width: 2),
                              Text(
                                product.vendorRating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '(${product.vendorReviewsCount ?? 0})',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                // Expanded + spaceBetween: the button is pinned to the bottom
                // and any spare height is absorbed here instead of showing as
                // an empty band under the card.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                height: 1.25,
                                color: AppColors.textDark,
                              ),
                            ),
                            if ((product.vendorName ?? '').isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.storefront_rounded,
                                      size: 11, color: AppColors.textMuted),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      product.vendorName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Fixed height so a priced card and a
                            // "price on request" card are exactly as tall —
                            // otherwise the bigger price font overflows the
                            // grid tile by a few pixels.
                            SizedBox(
                              height: 22,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // A shop that left the price at 0 hasn't set
                                  // one — showing "₪0" would read as free.
                                  Text(
                                    product.effectivePrice > 0
                                        ? '₪${money(product.effectivePrice)}'
                                        : 'السعر عند الطلب',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: product.effectivePrice > 0
                                          ? 15
                                          : 11.5,
                                      height: 1.1,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  if (product.hasDiscount) ...[
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        '₪${money(product.price)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          height: 1.1,
                                          color: AppColors.textMuted,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 7),
                            SizedBox(
                              height: 32,
                              width: double.infinity,
                              // «أضف» morphs into the −/+ stepper instead of
                              // snapping, so the tap reads as a change.
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                switchInCurve: Curves.easeOutBack,
                                // The default layout centres children at their
                                // intrinsic size, which shrank the full-width
                                // button; expand them instead.
                                layoutBuilder: (current, previous) => Stack(
                                  fit: StackFit.expand,
                                  children: [...previous, ?current],
                                ),
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(
                                  opacity: anim,
                                  child: ScaleTransition(
                                      scale: anim, child: child),
                                ),
                                child: qty > 0
                                    ? _QtyStepper(
                                        key: const ValueKey('qty'),
                                        product: product,
                                        qty: qty,
                                      )
                                    : FilledButton.icon(
                                        key: const ValueKey('add'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: product.isAvailable
                                            ? () => addToCart(context, product)
                                            : null,
                                        icon: const Icon(
                                            Icons.add_shopping_cart_rounded,
                                            size: 15),
                                        label: Text(
                                          product.isAvailable
                                              ? 'أضف'
                                              : 'غير متوفر',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

/// −/qty/+ control shown once a product is in the cart.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({super.key, required this.product, required this.qty});
  final ProductModel product;
  final int qty;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartController>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: () => setCartQuantity(cart, product.id, qty - 1),
          ),
          Text(
            '$qty',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: AppColors.primaryDark,
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: () => setCartQuantity(cart, product.id, qty + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 32,
          child: Icon(icon, size: 17, color: AppColors.primaryDark),
        ),
      ),
    );
  }
}

/// Changes a line's quantity with a light tick, so +/- feels like a real
/// button. Removing the last one gets the heavier buzz a destructive step
/// deserves.
void setCartQuantity(CartController cart, int productId, int quantity) {
  if (quantity <= 0) {
    HapticFeedback.mediumImpact();
  } else {
    HapticFeedback.selectionClick();
  }
  cart.setQuantity(productId, quantity);
}

/// Opens the cart, with a tap tick so the button feels physical.
void openCart(BuildContext context) {
  HapticFeedback.selectionClick();
  Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()));
}

/// Floating cart bar with a live item count and total — shown on marketplace
/// screens. It slides up when the first item lands and pulses on every change,
/// so the cart is always visibly there and obviously tappable.
///
/// It is placed inside the page body rather than as a Scaffold FAB: these
/// screens sit under the app-wide bottom nav, which would cover a real FAB.
class CartFab extends StatefulWidget {
  const CartFab({super.key, this.bottomPadding = 0});

  /// Space to leave under the bar, e.g. the height of the bottom nav.
  final double bottomPadding;

  @override
  State<CartFab> createState() => _CartFabState();
}

class _CartFabState extends State<CartFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.14), weight: 40),
    TweenSequenceItem(
      tween: Tween(begin: 1.14, end: 1.0)
          .chain(CurveTween(curve: Curves.elasticOut)),
      weight: 60,
    ),
  ]).animate(_pulse);

  int _lastCount = 0;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final count = cart.count;

    if (count != _lastCount) {
      _lastCount = count;
      if (count > 0) {
        // Fired after the frame — the controller can't be driven mid-build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pulse.forward(from: 0);
        });
      }
    }

    final visible = count > 0;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1.6),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomPadding + 10),
            child: ScaleTransition(
              scale: _scale,
              child: Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
                elevation: 8,
                shadowColor: AppColors.primaryDark.withValues(alpha: .5),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => openCart(context),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.shopping_cart_rounded,
                                color: Colors.white, size: 23),
                            PositionedDirectional(
                              top: -6,
                              end: -7,
                              child: _CountDot(count: count),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'عرض السلة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        if (cart.total > 0)
                          Text(
                            '₪${money(cart.total)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_left_rounded,
                            color: Colors.white, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cart button for an app bar — always present, so the cart never looks
/// missing, with a badge that pops in when items are added.
class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartController, int>((c) => c.count);
    return IconButton(
      tooltip: 'السلة',
      onPressed: () => openCart(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.shopping_cart_rounded, color: color, size: 23),
          PositionedDirectional(
            top: -6,
            end: -7,
            child: AnimatedScale(
              scale: count > 0 ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: _CountDot(count: count),
            ),
          ),
        ],
      ),
    );
  }
}

/// The little number badge that rides on a cart icon.
class _CountDot extends StatelessWidget {
  const _CountDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(
        color: AppColors.discount,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1.2,
        ),
      ),
    );
  }
}

/// The card's image area. When a product has more than one photo it becomes a
/// swipeable strip with page dots, so the extra images are visible without
/// opening the product. Tapping anywhere on it opens the full product view.
class _CardGallery extends StatefulWidget {
  const _CardGallery({required this.product, required this.swipeable});

  final ProductModel product;
  final bool swipeable;

  @override
  State<_CardGallery> createState() => _CardGalleryState();
}

class _CardGalleryState extends State<_CardGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product.gallery;
    final multi = images.length > 1;

    return GestureDetector(
      onTap: () => openProduct(context, widget.product),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            const AppNetworkImage(fallbackIcon: Icons.shopping_bag_outlined)
          else if (!multi)
            AppNetworkImage(
              url: images.first,
              fallbackIcon: Icons.shopping_bag_outlined,
            )
          else
            PageView.builder(
              controller: _controller,
              physics: widget.swipeable
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: images.length,
              itemBuilder: (_, i) => AppNetworkImage(
                url: images[i],
                fallbackIcon: Icons.shopping_bag_outlined,
              ),
            ),
          if (multi) ...[
            // Count badge — tells you there are more photos even on the
            // rows where swiping in place is disabled.
            PositionedDirectional(
              top: 8,
              start: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.collections_rounded,
                        size: 10, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      '${_page + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              bottom: 7,
              start: 0,
              end: 0,
              child: _CardDots(count: images.length, index: _page),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardDots extends StatelessWidget {
  const _CardDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    // A product with 11 photos would otherwise draw a dot strip wider than
    // the card, so cap it and keep the last dot active past the cap.
    const max = 5;
    final shown = count > max ? max : count;
    final active = index < shown ? index : shown - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(shown, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: on ? 12 : 5,
          height: 5,
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.white60,
            borderRadius: BorderRadius.circular(99),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 3),
            ],
          ),
        );
      }),
    );
  }
}
