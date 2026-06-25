import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../vendors/edit_vendor_page.dart';

/// Admin: searchable, lazily-paginated list of all advertisers (vendors),
/// including inactive ones. Tap to edit the shop profile; toggle to
/// activate/deactivate the shop.
class AdminVendorsPage extends StatefulWidget {
  const AdminVendorsPage({super.key});

  @override
  State<AdminVendorsPage> createState() => _AdminVendorsPageState();
}

class _AdminVendorsPageState extends State<AdminVendorsPage> {
  final _service = VendorService();
  final _scroll = ScrollController();
  final _searchCtl = TextEditingController();
  final List<VendorModel> _items = [];

  String _search = '';
  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  bool _initialLoaded = false;
  String? _error;
  Timer? _debounce;

  bool get _hasMore => _page < _lastPage;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadNext();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    if (_loading || (_initialLoaded && !_hasMore)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _service.adminList(search: _search, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _page = res.currentPage;
        _lastPage = res.lastPage;
        _initialLoaded = true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 0;
      _lastPage = 1;
      _initialLoaded = false;
    });
    await _loadNext();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _search = v.trim();
        _items.clear();
        _page = 0;
        _lastPage = 1;
        _initialLoaded = false;
      });
      _loadNext();
    });
  }

  Future<void> _toggleActive(int index) async {
    final v = _items[index];
    try {
      final updated = await _service.update(v.id, {'is_active': !v.isActive});
      if (!mounted) return;
      setState(() => _items[index] = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _edit(int index) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditVendorPage(vendor: _items[index])),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المعلنون')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث عن معلن بالاسم',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtl.clear();
                          _onSearchChanged('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _loadNext, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    if (!_initialLoaded && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('لا يوجد معلنون'));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final v = _items[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              backgroundImage: (v.logo != null && v.logo!.isNotEmpty)
                  ? NetworkImage(v.logo!)
                  : null,
              child: (v.logo == null || v.logo!.isEmpty)
                  ? const Icon(Icons.store, color: AppColors.primary)
                  : null,
            ),
            title: Text(v.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (v.city != null) v.city!.name,
                if (v.phone != null && v.phone!.isNotEmpty) v.phone!,
                if (v.delegateName != null && v.delegateName!.isNotEmpty)
                  'المندوب: ${v.delegateName}',
              ].join(' • '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: v.isActive,
                  onChanged: (_) => _toggleActive(i),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  tooltip: 'تعديل',
                  onPressed: () => _edit(i),
                ),
              ],
            ),
            onTap: () => _edit(i),
          );
        },
      ),
    );
  }
}
