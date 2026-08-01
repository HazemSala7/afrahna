import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../vendors/vendor_details_page.dart';

/// Shows a parent category with all its subcategories rendered as tabs.
/// Each tab loads vendors filtered by that subcategory.
///
/// The first tab ("الكل") shows vendors from the parent category itself
/// AND all of its subcategories (via `parent_category_id` on the API).
class CategoryTabsPage extends StatefulWidget {
  const CategoryTabsPage({super.key, required this.parent});

  final CategoryModel parent;

  @override
  State<CategoryTabsPage> createState() => _CategoryTabsPageState();
}

class _CategoryTabsPageState extends State<CategoryTabsPage> {
  late Future<List<CategoryModel>> _futureChildren;
  late Future<List<CityModel>> _futureCities;

  /// City filter applied to every tab (null = all cities).
  int? _selectedCityId;

  @override
  void initState() {
    super.initState();
    // Use children embedded in the parent if available, otherwise fetch.
    _futureChildren = widget.parent.children.isNotEmpty
        ? Future.value(widget.parent.children)
        : CategoryService().children(widget.parent.id);
    _futureCities = CityService().list();
  }

  Widget _cityFilter() {
    return FutureBuilder<List<CityModel>>(
      future: _futureCities,
      builder: (context, snap) {
        final cities = snap.data ?? const <CityModel>[];
        if (cities.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _cityChip(null, 'كل المدن'),
              ...cities.map((c) => _cityChip(c.id, c.name)),
            ],
          ),
        );
      },
    );
  }

  Widget _cityChip(int? id, String label) {
    final selected = _selectedCityId == id;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        avatar: Icon(
          Icons.location_on,
          size: 16,
          color: selected ? Colors.white : AppColors.primary,
        ),
        onSelected: (_) => setState(() => _selectedCityId = id),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textDark,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.primaryLight,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: PinkAppBar(title: widget.parent.name),
      body: FutureBuilder<List<CategoryModel>>(
        future: _futureChildren,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
              message: snap.error.toString(),
              onRetry: () => setState(() {
                _futureChildren = CategoryService().children(widget.parent.id);
              }),
            );
          }
          final subs = snap.data ?? const <CategoryModel>[];

          // If no subcategories at all, just show vendors of the parent.
          if (subs.isEmpty) {
            return Column(
              children: [
                const SizedBox(height: 4),
                _cityFilter(),
                const SizedBox(height: 4),
                Expanded(
                  child: _VendorsList(
                    categoryId: widget.parent.id,
                    cityId: _selectedCityId,
                  ),
                ),
              ],
            );
          }

          final tabs = <CategoryModel>[
            // Synthetic "All" tab — uses parent id, list combines parent + children.
            CategoryModel(
              id: widget.parent.id,
              nameAr: 'الكل',
              nameEn: 'All',
            ),
            ...subs,
          ];

          return DefaultTabController(
            length: tabs.length,
            child: Column(
              children: [
                const SizedBox(height: 4),
                _cityFilter(),
                const SizedBox(height: 4),
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    isScrollable: true,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textDark,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                    tabs: tabs
                        .map((c) => Tab(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6),
                                child: Text(c.name),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // First tab uses parent_category_id so vendors of the
                      // parent itself AND every child show up together.
                      _VendorsList(
                        parentCategoryId: widget.parent.id,
                        cityId: _selectedCityId,
                      ),
                      ...subs.map((c) => _VendorsList(
                            categoryId: c.id,
                            cityId: _selectedCityId,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VendorsList extends StatefulWidget {
  const _VendorsList({this.categoryId, this.parentCategoryId, this.cityId});

  final int? categoryId;
  final int? parentCategoryId;
  final int? cityId;

  @override
  State<_VendorsList> createState() => _VendorsListState();
}

class _VendorsListState extends State<_VendorsList>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 20;
  final _service = VendorService();
  final _scroll = ScrollController();

  final List<VendorModel> _items = [];
  final Set<int> _ids = {};
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _initialLoading = true;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void didUpdateWidget(_VendorsList old) {
    super.didUpdateWidget(old);
    if (old.cityId != widget.cityId) _loadInitial();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _items.clear();
      _ids.clear();
      _page = 0;
      _hasMore = true;
    });
    try {
      final res = await _service.listPaged(
        categoryId: widget.categoryId,
        parentCategoryId: widget.parentCategoryId,
        cityId: widget.cityId,
        page: 1,
        perPage: _pageSize,
      );
      _page = 1;
      _hasMore = res.hasMore;
      _addAll(res.items);
      if (mounted) setState(() => _initialLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _initialLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _initialLoading) return;
    _loadingMore = true;
    setState(() {});
    try {
      final res = await _service.listPaged(
        categoryId: widget.categoryId,
        parentCategoryId: widget.parentCategoryId,
        cityId: widget.cityId,
        page: _page + 1,
        perPage: _pageSize,
      );
      _page += 1;
      _hasMore = res.hasMore;
      _addAll(res.items);
    } catch (_) {
      // keep what we have; a later scroll retries
    } finally {
      _loadingMore = false;
      if (mounted) setState(() {});
    }
  }

  void _addAll(Iterable<VendorModel> vs) {
    for (final v in vs) {
      if (_ids.add(v.id)) _items.add(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_initialLoading) return const CenteredLoader();
    if (_error != null && _items.isEmpty) {
      return ErrorState(message: _error.toString(), onRetry: _loadInitial);
    }
    if (_items.isEmpty) {
      return const EmptyState(message: 'لا يوجد مزوّدون في هذه الفئة بعد');
    }
    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: AfrahnaLoader(size: 38)),
            );
          }
          return _VendorTile(vendor: _items[i]);
        },
      ),
    );
  }
}

class _VendorTile extends StatelessWidget {
  const _VendorTile({required this.vendor});
  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 80,
                height: 80,
                child: AppNetworkImage(
                  url: vendor.logo ?? vendor.cover,
                  fallbackIcon: Icons.storefront,
                ),
              ),
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
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (vendor.isVip ||
                          vendor.isPremium ||
                          vendor.activePlan == 'featured') ...[
                        const SizedBox(width: 4),
                        TierBadge(
                          vip: vendor.isVip,
                          featured: vendor.isPremium ||
                              vendor.activePlan == 'featured',
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (vendor.category != null)
                    Text(
                      vendor.category!.name,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (vendor.rating != null)
                        RatingRow(
                          rating: vendor.rating!,
                          reviewsCount: vendor.reviewsCount,
                        ),
                      const Spacer(),
                      if (vendor.city != null)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 2),
                            Text(
                              vendor.city!.name,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
