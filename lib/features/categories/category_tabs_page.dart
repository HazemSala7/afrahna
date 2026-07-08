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

  @override
  void initState() {
    super.initState();
    // Use children embedded in the parent if available, otherwise fetch.
    _futureChildren = widget.parent.children.isNotEmpty
        ? Future.value(widget.parent.children)
        : CategoryService().children(widget.parent.id);
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
            return _VendorsList(categoryId: widget.parent.id);
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
                      _VendorsList(parentCategoryId: widget.parent.id),
                      ...subs.map((c) => _VendorsList(categoryId: c.id)),
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
  const _VendorsList({this.categoryId, this.parentCategoryId});

  final int? categoryId;
  final int? parentCategoryId;

  @override
  State<_VendorsList> createState() => _VendorsListState();
}

class _VendorsListState extends State<_VendorsList>
    with AutomaticKeepAliveClientMixin {
  late Future<List<VendorModel>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = VendorService().list(
      categoryId: widget.categoryId,
      parentCategoryId: widget.parentCategoryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<VendorModel>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const CenteredLoader();
        }
        if (snap.hasError) {
          return ErrorState(
            message: snap.error.toString(),
            onRetry: () => setState(_load),
          );
        }
        final items = snap.data ?? const <VendorModel>[];
        if (items.isEmpty) {
          return const EmptyState(message: 'لا يوجد مزوّدون في هذه الفئة بعد');
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_load),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _VendorTile(vendor: items[i]),
          ),
        );
      },
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
