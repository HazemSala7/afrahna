import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import 'vendor_details_page.dart';

class VendorsPage extends StatefulWidget {
  const VendorsPage({
    super.key,
    this.category,
    this.title,
    this.featuredOnly = false,
    this.initialQuery,
  });

  final CategoryModel? category;
  final String? title;
  final bool featuredOnly;

  /// Text to pre-fill the search box with (and filter by) when opening the
  /// page from a search action elsewhere.
  final String? initialQuery;

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  static const _pageSize = 20;
  final _service = VendorService();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  Timer? _debounce;

  final List<VendorModel> _items = [];
  final Set<int> _ids = {};
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _initialLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery?.trim() ?? '';
    _search.text = _query;
    _scroll.addListener(_onScroll);
    _loadInitial();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 320) {
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
        categoryId: widget.category?.id,
        query: _query.isEmpty ? null : _query,
        featured: widget.featuredOnly ? true : null,
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
        categoryId: widget.category?.id,
        query: _query.isEmpty ? null : _query,
        featured: widget.featuredOnly ? true : null,
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

  /// Live search: re-query shortly after the user stops typing so every
  /// keystroke updates the results without firing a request per character.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.trim();
      if (q == _query) return;
      _query = q;
      _loadInitial();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? widget.category?.name ?? 'مزوّدو الخدمات';
    return AppScaffold(
      appBar: PinkAppBar(title: title),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  _query = v.trim();
                  _loadInitial();
                },
                decoration: const InputDecoration(
                  hintText: 'ابحث بالاسم...',
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.primary),
                ),
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_initialLoading) return const CenteredLoader();
                if (_error != null && _items.isEmpty) {
                  return ErrorState(
                    message: _error.toString(),
                    onRetry: _loadInitial,
                  );
                }
                if (_items.isEmpty) {
                  return const EmptyState(
                      message: 'لا يوجد مزوّدون مطابقون');
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
              },
            ),
          ),
        ],
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
                                size: 14,
                                color: AppColors.textMuted),
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
