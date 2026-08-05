import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_widgets.dart';
import 'marketplace.dart';
import 'marketplace_filters.dart';

/// Filter button with a badge showing how many filters are on.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Material(
      color: active ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 54,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryLight, width: 1.2),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(Icons.tune_rounded,
                  color: active ? Colors.white : AppColors.primaryDark),
              if (active)
                PositionedDirectional(
                  top: -2,
                  start: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.discount,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One active filter, tap the ✕ to drop it.
class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: AppColors.primaryLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onRemove,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.primaryDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "المتجر" — every shop's products in one grid, shuffled. Paginates as you
/// scroll, reusing one seed so the shuffle stays consistent while paging.
class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final _service = ProductService();
  final _scroll = ScrollController();

  final List<ProductModel> _items = [];
  final Set<int> _ids = {};
  late int _seed;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _initial = true;
  Object? _error;
  String _query = '';

  /// Advanced filters (shop / category / city / price / sort).
  MarketFilters _filters = const MarketFilters();

  @override
  void initState() {
    super.initState();
    _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final nearEnd =
        _scroll.position.pixels > _scroll.position.maxScrollExtent - 600;
    if (nearEnd) _loadMore();
  }

  /// Page size kept modest so scrolling actually pulls new products in rather
  /// than the whole catalogue arriving at once.
  static const _pageSize = 12;

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    try {
      final res = await _service.marketplace(
        seed: _seed,
        page: _page + 1,
        perPage: _pageSize,
        sort: _filters.sort,
        vendorId: _filters.vendorId,
        categoryId: _filters.categoryId,
        cityId: _filters.cityId,
        minPrice: _filters.minPrice,
        maxPrice: _filters.maxPrice,
        discountedOnly: _filters.discountedOnly,
      );
      if (!mounted) return;
      setState(() {
        _page += 1;
        _hasMore = res.hasMore;
        for (final p in res.items) {
          if (_ids.add(p.id)) _items.add(p);
        }
        _initial = false;
        _error = null;
      });
      // A first page shorter than the viewport leaves nothing to scroll, so
      // the scroll listener would never fire — keep pulling until it can.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_hasMore || !_scroll.hasClients) return;
        if (_scroll.position.maxScrollExtent <= 0) _loadMore();
      });
    } catch (e) {
      if (mounted) setState(() { _error = e; _initial = false; });
    } finally {
      _loading = false;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
      _items.clear();
      _ids.clear();
      _page = 0;
      _hasMore = true;
      _initial = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _openFilters() async {
    final next = await showMarketFilterSheet(context, _filters);
    if (next == null || !mounted) return;
    setState(() => _filters = next);
    // Filters change the whole result set, so the list restarts from page 1.
    await _refresh();
  }

  /// Removes one filter and reloads — the chips under the search bar.
  Future<void> _clearFilter(MarketFilters next) async {
    setState(() => _filters = next);
    await _refresh();
  }

  List<Widget> _activeChips() {
    final chips = <Widget>[];

    void add(String label, MarketFilters cleared) {
      chips.add(_ActiveChip(
        label: label,
        onRemove: () => _clearFilter(cleared),
      ));
    }

    if (_filters.sort != 'random') {
      add(MarketFilters.sortLabels[_filters.sort] ?? _filters.sort,
          _filters.copyWith(sort: 'random'));
    }
    if (_filters.discountedOnly) {
      add('المخفّضة فقط', _filters.copyWith(discountedOnly: false));
    }
    if (_filters.categoryId != null) {
      add(_filters.categoryName ?? 'قسم', _filters.copyWith(clearCategory: true));
    }
    if (_filters.cityId != null) {
      add(_filters.cityName ?? 'مدينة', _filters.copyWith(clearCity: true));
    }
    if (_filters.vendorId != null) {
      add(_filters.vendorName ?? 'محل', _filters.copyWith(clearVendor: true));
    }
    if (_filters.minPrice != null || _filters.maxPrice != null) {
      final from = _filters.minPrice?.toStringAsFixed(0);
      final to = _filters.maxPrice?.toStringAsFixed(0);
      final label = from != null && to != null
          ? '₪$from – ₪$to'
          : (from != null ? 'من ₪$from' : 'حتى ₪$to');
      add(label, _filters.copyWith(clearPrice: true));
    }

    return chips;
  }

  List<ProductModel> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.vendorName ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;

    return AppScaffold(
      appBar: const PinkAppBar(
        title: 'المتجر',
        subtitle: 'منتجات كل المحلات',
        actions: [CartIconButton()],
      ),
      // The cart bar lives inside the body: this screen sits under the app-wide
      // bottom nav, which draws over a real Scaffold FAB.
      body: Stack(
        children: [
          Positioned.fill(child: _content(items)),
          PositionedDirectional(
            bottom: 0,
            start: 0,
            end: 0,
            child: const CartFab(bottomPadding: AppBottomNav.contentHeight),
          ),
        ],
      ),
    );
  }

  Widget _content(List<ProductModel> items) {
    return _initial
          ? const CenteredLoader()
          : (_error != null && _items.isEmpty)
              ? ErrorState(
                  message: _error is ApiException
                      ? (_error as ApiException).message
                      : 'تعذّر تحميل المنتجات',
                  onRetry: _refresh,
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (v) => setState(() => _query = v),
                                  decoration: const InputDecoration(
                                    hintText: 'ابحث عن منتج أو محل...',
                                    prefixIcon: Icon(Icons.search_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _FilterButton(
                                count: _filters.activeCount,
                                onTap: _openFilters,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!_filters.isDefault)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 42,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                for (final chip in _activeChips()) ...[
                                  chip,
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const EmptyState(
                                icon: Icons.shopping_bag_outlined,
                                message: 'لا توجد منتجات مطابقة',
                              ),
                              // Filtering down to nothing is easy to do and
                              // hard to undo without a way back.
                              if (!_filters.isDefault)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _clearFilter(const MarketFilters()),
                                    icon: const Icon(Icons.filter_alt_off_rounded,
                                        size: 18),
                                    label: const Text(
                                      'مسح كل الفلاتر',
                                      style:
                                          TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        SliverPadding(
                          // Clears the bottom nav *and* the floating cart bar,
                          // so the last row is never hidden behind them.
                          padding: const EdgeInsets.fromLTRB(
                              16, 8, 16, AppBottomNav.contentHeight + 80),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 190,
                              mainAxisExtent: 262,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => MarketProductCard(
                                product: items[i],
                                width: double.infinity,
                              ),
                              childCount: items.length,
                            ),
                          ),
                        ),
                      if (_hasMore && _query.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 90),
                            child: Center(child: AfrahnaLoader(size: 36)),
                          ),
                        ),
                    ],
                  ),
                );
  }
}
