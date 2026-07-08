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
  late Future<List<VendorModel>> _future;
  final _search = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery?.trim() ?? '';
    _search.text = _query;
    _load();
  }

  void _load() {
    _future = VendorService().list(
      categoryId: widget.category?.id,
      query: _query.isEmpty ? null : _query,
      featured: widget.featuredOnly ? true : null,
    );
  }

  /// Live search: re-query shortly after the user stops typing so every
  /// keystroke updates the results without firing a request per character.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.trim();
      if (q == _query) return;
      setState(() {
        _query = q;
        _load();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
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
                  setState(() {
                    _query = v.trim();
                    _load();
                  });
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
            child: FutureBuilder<List<VendorModel>>(
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
                final items = snap.data ?? const [];
                if (items.isEmpty) {
                  return const EmptyState(
                      message: 'لا يوجد مزوّدون مطابقون');
                }
                return ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: 12),
                  itemBuilder: (_, i) =>
                      _VendorTile(vendor: items[i]),
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
