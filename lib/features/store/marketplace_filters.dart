import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

/// The marketplace's active filters. Immutable so a screen can hold the old
/// value while the sheet edits a copy, and only apply it on confirm.
class MarketFilters {
  const MarketFilters({
    this.sort = 'random',
    this.vendorId,
    this.vendorName,
    this.categoryId,
    this.categoryName,
    this.cityId,
    this.cityName,
    this.minPrice,
    this.maxPrice,
    this.discountedOnly = false,
  });

  final String sort;
  final int? vendorId;
  final String? vendorName;
  final int? categoryId;
  final String? categoryName;
  final int? cityId;
  final String? cityName;
  final double? minPrice;
  final double? maxPrice;
  final bool discountedOnly;

  static const sortLabels = <String, String>{
    'random': 'مقترح',
    'newest': 'الأحدث',
    'price_asc': 'الأرخص أولاً',
    'price_desc': 'الأغلى أولاً',
  };

  bool get isDefault =>
      sort == 'random' &&
      vendorId == null &&
      categoryId == null &&
      cityId == null &&
      minPrice == null &&
      maxPrice == null &&
      !discountedOnly;

  /// How many filters are active — drives the badge on the filter button.
  int get activeCount =>
      (vendorId != null ? 1 : 0) +
      (categoryId != null ? 1 : 0) +
      (cityId != null ? 1 : 0) +
      ((minPrice != null || maxPrice != null) ? 1 : 0) +
      (discountedOnly ? 1 : 0) +
      (sort != 'random' ? 1 : 0);

  MarketFilters copyWith({
    String? sort,
    int? vendorId,
    String? vendorName,
    int? categoryId,
    String? categoryName,
    int? cityId,
    String? cityName,
    double? minPrice,
    double? maxPrice,
    bool? discountedOnly,
    bool clearVendor = false,
    bool clearCategory = false,
    bool clearCity = false,
    bool clearPrice = false,
  }) {
    return MarketFilters(
      sort: sort ?? this.sort,
      vendorId: clearVendor ? null : (vendorId ?? this.vendorId),
      vendorName: clearVendor ? null : (vendorName ?? this.vendorName),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      categoryName: clearCategory ? null : (categoryName ?? this.categoryName),
      cityId: clearCity ? null : (cityId ?? this.cityId),
      cityName: clearCity ? null : (cityName ?? this.cityName),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      discountedOnly: discountedOnly ?? this.discountedOnly,
    );
  }
}

/// Bottom sheet for choosing marketplace filters. Returns the new [MarketFilters]
/// on apply, or null when dismissed.
Future<MarketFilters?> showMarketFilterSheet(
  BuildContext context,
  MarketFilters current,
) {
  return showModalBottomSheet<MarketFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final MarketFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late MarketFilters _f = widget.initial;

  final _min = TextEditingController();
  final _max = TextEditingController();

  /// Top-level categories only; a parent's branches load on demand when it is
  /// expanded. Flattening the whole tree meant pulling every branch of every
  /// section into the sheet before the user had picked anything.
  List<CategoryModel> _categories = const [];
  List<CityModel> _cities = const [];
  bool _loading = true;

  /// Parent whose branches are currently shown.
  int? _expandedParent;

  @override
  void initState() {
    super.initState();
    if (widget.initial.minPrice != null) {
      _min.text = widget.initial.minPrice!.toStringAsFixed(0);
    }
    if (widget.initial.maxPrice != null) {
      _max.text = widget.initial.maxPrice!.toStringAsFixed(0);
    }
    _load();
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Only the two small, bounded lists. Vendors are fetched a page at a
      // time inside the picker instead of all at once here.
      final results = await Future.wait([
        CategoryService().list(tree: true),
        CityService().list(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<CategoryModel>;
        _cities = results[1] as List<CityModel>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickVendor() async {
    final picked = await showModalBottomSheet<VendorModel?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VendorPicker(),
    );
    if (picked == null || !mounted) return;
    setState(() => _f = _f.copyWith(vendorId: picked.id, vendorName: picked.name));
  }

  void _apply() {
    final min = double.tryParse(_min.text.trim());
    final max = double.tryParse(_max.text.trim());
    Navigator.pop(
      context,
      _f.copyWith(clearPrice: true).copyWith(minPrice: min, maxPrice: max),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'تصفية المتجر',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      _min.clear();
                      _max.clear();
                      setState(() => _f = const MarketFilters());
                    },
                    child: const Text(
                      'إعادة تعيين',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2.4))
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      children: [
                        const _GroupTitle('الترتيب'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: MarketFilters.sortLabels.entries
                              .map((e) => _Chip(
                                    label: e.value,
                                    selected: _f.sort == e.key,
                                    onTap: () =>
                                        setState(() => _f = _f.copyWith(sort: e.key)),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 20),

                        const _GroupTitle('العروض'),
                        _Chip(
                          label: '🔥 المخفّضة فقط',
                          selected: _f.discountedOnly,
                          onTap: () => setState(() =>
                              _f = _f.copyWith(discountedOnly: !_f.discountedOnly)),
                        ),
                        const SizedBox(height: 20),

                        const _GroupTitle('السعر (₪)'),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _min,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'من',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _max,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'إلى',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (_categories.isNotEmpty) ...[
                          const _GroupTitle('القسم'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in _categories)
                                _Chip(
                                  label: c.hasChildren ? '${c.name} ▾' : c.name,
                                  selected: _f.categoryId == c.id ||
                                      c.children.any((k) => k.id == _f.categoryId),
                                  onTap: () => setState(() {
                                    // A parent with branches expands them first;
                                    // tapping it again selects the parent itself
                                    // (which the server widens to its branches).
                                    if (c.hasChildren && _expandedParent != c.id) {
                                      _expandedParent = c.id;
                                      return;
                                    }
                                    _f = _f.categoryId == c.id
                                        ? _f.copyWith(clearCategory: true)
                                        : _f.copyWith(
                                            categoryId: c.id, categoryName: c.name);
                                  }),
                                ),
                            ],
                          ),
                          if (_expandedParent != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: AppColors.primaryLight),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final k in _categories
                                      .firstWhere((c) => c.id == _expandedParent)
                                      .children)
                                    _Chip(
                                      label: k.name,
                                      selected: _f.categoryId == k.id,
                                      onTap: () => setState(() {
                                        _f = _f.categoryId == k.id
                                            ? _f.copyWith(clearCategory: true)
                                            : _f.copyWith(
                                                categoryId: k.id,
                                                categoryName: k.name);
                                      }),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],

                        if (_cities.isNotEmpty) ...[
                          const _GroupTitle('المدينة'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in _cities)
                                _Chip(
                                  label: c.name,
                                  selected: _f.cityId == c.id,
                                  onTap: () => setState(() {
                                    _f = _f.cityId == c.id
                                        ? _f.copyWith(clearCity: true)
                                        : _f.copyWith(cityId: c.id, cityName: c.name);
                                  }),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        const _GroupTitle('المحل'),
                        // A searchable, paged picker — there are hundreds of
                        // shops, far too many to render as chips.
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _pickVendor,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: AppColors.primaryLight),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.storefront_rounded,
                                      size: 19, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _f.vendorName ?? 'كل المحلات',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: _f.vendorId == null
                                            ? AppColors.textMuted
                                            : AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                  if (_f.vendorId != null)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18),
                                      color: AppColors.textMuted,
                                      onPressed: () => setState(
                                          () => _f = _f.copyWith(clearVendor: true)),
                                    )
                                  else
                                    const Icon(Icons.chevron_left_rounded,
                                        color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                18, 10, 18, 12 + MediaQuery.of(context).viewPadding.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _apply,
                  child: const Text(
                    'تطبيق',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shop picker: server-side search, one page at a time, more as you scroll.
class _VendorPicker extends StatefulWidget {
  const _VendorPicker();

  @override
  State<_VendorPicker> createState() => _VendorPickerState();
}

class _VendorPickerState extends State<_VendorPicker> {
  static const _pageSize = 20;

  final _service = VendorService();
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  final List<VendorModel> _items = [];
  final Set<int> _ids = {};
  String _query = '';
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _initial = true;

  /// Debounce so typing doesn't fire a request per keystroke.
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _loadMore();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = v.trim();
        _items.clear();
        _ids.clear();
        _page = 0;
        _hasMore = true;
        _initial = true;
      });
      _loadMore();
    });
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    try {
      final res = await _service.listPaged(
        query: _query.isEmpty ? null : _query,
        page: _page + 1,
        perPage: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page += 1;
        _hasMore = res.hasMore;
        for (final v in res.items) {
          if (_ids.add(v.id)) _items.add(v);
        }
        _initial = false;
      });
    } catch (_) {
      if (mounted) setState(() => _initial = false);
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ابحث عن محل بالاسم...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: _initial
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2.4))
                  : _items.isEmpty
                      ? const Center(
                          child: Text(
                            'لا يوجد محل بهذا الاسم',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700),
                          ),
                        )
                      : ListView.separated(
                          // The sheet's own controller drives the drag; this
                          // list scrolls with ours so paging can hook into it.
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            if (i >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: AppColors.primary),
                                  ),
                                ),
                              );
                            }
                            final v = _items[i];
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.pop(context, v),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 42,
                                          height: 42,
                                          child: AppNetworkImage(
                                            url: v.logo,
                                            fallbackIcon:
                                                Icons.storefront_rounded,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              v.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13.5,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                            if (v.category != null ||
                                                v.city != null)
                                              Text(
                                                [
                                                  v.category?.name,
                                                  v.city?.name,
                                                ]
                                                    .whereType<String>()
                                                    .join(' • '),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textMuted,
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
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13.5,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.primaryLight,
              width: 1.3,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
