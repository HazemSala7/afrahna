import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/login_required_dialog.dart';

String _money(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Store front shown inside a vendor's page when the vendor is a store.
/// Lists products, keeps an in-page cart, and lets the customer place an order
/// (which reaches the shop owner as an invoice-style notification).
class StoreSection extends StatefulWidget {
  const StoreSection({super.key, required this.vendor, this.highlightProductId});
  final VendorModel vendor;

  /// When set (from a product notification), scroll to & highlight this product.
  final int? highlightProductId;

  @override
  State<StoreSection> createState() => _StoreSectionState();
}

class _StoreSectionState extends State<StoreSection>
    with TickerProviderStateMixin {
  final _service = ProductService();
  final _orders = OrderService();
  final _sectionService = ProductSectionService();
  late Future<List<ProductModel>> _future;
  final Map<int, int> _cart = {}; // productId -> quantity
  List<ProductModel> _products = const [];
  List<ProductSectionModel> _sections = const [];
  TabController? _tabs;
  int _tabIndex = 0;
  bool _placing = false;

  // Deep-link highlight state.
  final GlobalKey _highlightKey = GlobalKey();
  int? _highlightId;
  bool _didScrollHighlight = false;

  @override
  void initState() {
    super.initState();
    _highlightId = widget.highlightProductId;
    _future = _load();
  }

  /// Scroll the outer page to the highlighted product once it's laid out,
  /// then fade the highlight away after a moment.
  void _scheduleHighlightScroll() {
    if (_highlightId == null || _didScrollHighlight) return;
    _didScrollHighlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = _highlightKey.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.25,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
      }
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _highlightId = null);
    });
  }

  Future<List<ProductModel>> _load() async {
    final results = await Future.wait([
      _service.list(vendorId: widget.vendor.id, availableOnly: true),
      _sectionService.list(vendorId: widget.vendor.id),
    ]);
    _products = results[0] as List<ProductModel>;
    _sections = results[1] as List<ProductSectionModel>;
    // Keep only sections that actually have available products, so we never
    // show an empty tab.
    final withProducts = _products.map((p) => p.sectionId).toSet();
    _sections = _sections.where((s) => withProducts.contains(s.id)).toList();
    _buildTabs();
    return _products;
  }

  void _buildTabs() {
    _tabs?.dispose();
    // "الكل" tab + one per non-empty section.
    _tabs = TabController(length: _sections.length + 1, vsync: this)
      ..addListener(() {
        if (mounted) setState(() => _tabIndex = _tabs!.index);
      });
    _tabIndex = 0;
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  int get _count => _cart.values.fold(0, (a, b) => a + b);

  double get _total {
    double t = 0;
    for (final p in _products) {
      t += p.effectivePrice * (_cart[p.id] ?? 0);
    }
    return t;
  }

  void _inc(ProductModel p) =>
      setState(() => _cart[p.id] = (_cart[p.id] ?? 0) + 1);

  void _dec(ProductModel p) => setState(() {
        final q = (_cart[p.id] ?? 0) - 1;
        if (q <= 0) {
          _cart.remove(p.id);
        } else {
          _cart[p.id] = q;
        }
      });

  Future<void> _checkout() async {
    if (_count == 0) return;
    if (!context.read<SessionController>().isSignedIn) {
      await showLoginRequiredDialog(
        context,
        title: 'إتمام الطلب',
        message: 'سجّل الدخول بحساب لتتمكن من إرسال طلبك لهذا المتجر،'
            ' أو تابع التصفح كزائر.',
        icon: Icons.shopping_cart_outlined,
      );
      return;
    }

    final note = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(
        products: _products,
        cart: _cart,
        total: _total,
        note: note,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _placing = true);
    try {
      await _orders.create(
        vendorId: widget.vendor.id,
        quantities: Map.of(_cart),
        note: note.text.trim().isEmpty ? null : note.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _placing = false;
      });
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle,
              color: Colors.green, size: 48),
          title: const Text('تم إرسال طلبك'),
          content: const Text(
              'وصلت طلبيتك إلى المتجر كفاتورة. سيتواصل معك المتجر لتأكيدها.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً')),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _placing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.storefront_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text('منتجات المتجر',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.textDark)),
            const Spacer(),
            if (_count > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_count في السلة',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        FutureBuilder<List<ProductModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        color: AppColors.textMuted, size: 40),
                    SizedBox(height: 8),
                    Text('لا توجد منتجات معروضة حالياً',
                        style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              );
            }
            return _buildTabbed(items);
          },
        ),
        if (_count > 0) ...[
          const SizedBox(height: 14),
          _CartBar(
            total: _total,
            count: _count,
            busy: _placing,
            onCheckout: _checkout,
          ),
        ],
      ],
    );
  }

  /// A "الكل" tab plus one tab per section; the grid below shows the products
  /// of the selected tab. Falls back to a plain grid when there are no sections.
  Widget _buildTabbed(List<ProductModel> items) {
    if (_sections.isEmpty || _tabs == null) return _grid(items);

    final selectedSectionId =
        _tabIndex == 0 ? null : _sections[_tabIndex - 1].id;
    final shown = selectedSectionId == null
        ? items
        : items.where((p) => p.sectionId == selectedSectionId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          splashBorderRadius: BorderRadius.circular(20),
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textDark,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          tabs: [
            const Tab(height: 34, text: 'الكل'),
            for (final s in _sections) Tab(height: 34, text: s.name),
          ],
        ),
        const SizedBox(height: 4),
        _grid(shown),
      ],
    );
  }

  Widget _grid(List<ProductModel> items) {
    // If the highlighted product is in this grid, kick off the scroll.
    if (_highlightId != null && items.any((p) => p.id == _highlightId)) {
      _scheduleHighlightScroll();
    }
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.66,
      ),
      itemBuilder: (_, i) {
        final p = items[i];
        final hi = _highlightId != null && p.id == _highlightId;
        return _ProductCard(
          key: hi ? _highlightKey : null,
          product: p,
          qty: _cart[p.id] ?? 0,
          highlighted: hi,
          onAdd: () => _inc(p),
          onInc: () => _inc(p),
          onDec: () => _dec(p),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    super.key,
    required this.product,
    required this.qty,
    required this.onAdd,
    required this.onInc,
    required this.onDec,
    this.highlighted = false,
  });
  final ProductModel product;
  final int qty;
  final bool highlighted;
  final VoidCallback onAdd;
  final VoidCallback onInc;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    final selected = qty > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? AppColors.primary
              : selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.04),
          width: highlighted ? 2.4 : (selected ? 1.4 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.07),
            blurRadius: highlighted ? 20 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Image ----
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _CardGallery(images: product.gallery),
                ),
                if (product.hasDiscount)
                  PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5A5F), Color(0xFFE0353B)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE0353B)
                                .withValues(alpha: 0.45),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_offer,
                              size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text('خصم',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                if (!product.isAvailable)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      child: const Center(
                        child: Text('غير متوفر',
                            style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ---- Info ----
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.textDark)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (product.hasDiscount)
                            Text('${_money(product.price)} ₪',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10.5,
                                    decoration:
                                        TextDecoration.lineThrough)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(_money(product.effectivePrice),
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17)),
                              const SizedBox(width: 2),
                              const Text('₪',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    selected
                        ? _QtyStepper(
                            qty: qty, onInc: onInc, onDec: onDec)
                        : _AddButton(
                            enabled: product.isAvailable, onTap: onAdd),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Product image area — a single image, or a swipeable gallery with dots.
class _CardGallery extends StatefulWidget {
  const _CardGallery({required this.images});
  final List<String> images;

  @override
  State<_CardGallery> createState() => _CardGalleryState();
}

class _CardGalleryState extends State<_CardGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Container(
        color: const Color(0xFFF3EDE6),
        child: imgs.length <= 1
            ? AppNetworkImage(
                url: imgs.isNotEmpty ? imgs.first : null,
                fit: BoxFit.cover,
                fallbackIcon: Icons.inventory_2_outlined,
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: imgs.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (_, i) => AppNetworkImage(
                        url: imgs[i],
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.inventory_2_outlined,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(imgs.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: active ? 14 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 2),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Round gold "+" button used to add a product to the cart.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : AppColors.textMuted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Compact − qty + stepper shown once a product is in the cart.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper(
      {required this.qty, required this.onInc, required this.onDec});
  final int qty;
  final VoidCallback onInc;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(icon: Icons.remove, onTap: onDec),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text('$qty',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.primary)),
          ),
          _StepBtn(icon: Icons.add, onTap: onInc),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 30,
        height: 38,
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.total,
    required this.count,
    required this.busy,
    required this.onCheckout,
  });
  final double total;
  final int count;
  final bool busy;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count منتج',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${_money(total)} ₪',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
            ),
            onPressed: busy ? null : onCheckout,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.receipt_long),
            label: const Text('إتمام الطلب',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CHECKOUT CONFIRMATION SHEET
// ---------------------------------------------------------------------------

class _CheckoutSheet extends StatelessWidget {
  const _CheckoutSheet({
    required this.products,
    required this.cart,
    required this.total,
    required this.note,
  });
  final List<ProductModel> products;
  final Map<int, int> cart;
  final double total;
  final TextEditingController note;

  @override
  Widget build(BuildContext context) {
    final lines = products
        .where((p) => (cart[p.id] ?? 0) > 0)
        .map((p) => (product: p, qty: cart[p.id]!))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.receipt_long, color: AppColors.primary),
                SizedBox(width: 8),
                Text('ملخّص الطلب',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: lines.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 14),
                itemBuilder: (_, i) {
                  final l = lines[i];
                  return Row(
                    children: [
                      // Product thumbnail with a quantity badge.
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: AppNetworkImage(
                                url: l.product.image,
                                fit: BoxFit.cover,
                                fallbackIcon: Icons.inventory_2_outlined,
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            top: -6,
                            end: -6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                  minWidth: 20, minHeight: 20),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.background, width: 1.5),
                              ),
                              child: Text('${l.qty}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l.product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(
                                '${_money(l.product.effectivePrice)} ₪ × ${l.qty}',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.5)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                          '${_money(l.product.effectivePrice * l.qty)} ₪',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800)),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Text('الإجمالي',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
                const Spacer(),
                Text('${_money(total)} ₪',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظة للمتجر (اختياري)',
                hintText: 'مثال: التوصيل، اللون، الوقت المفضّل...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد الطلب',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}
