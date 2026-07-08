import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';
import 'admin_user_edit_page.dart';

/// Admin: searchable, lazily-paginated list of users for a single [role]
/// (e.g. delegate / customer). Tap to edit; toggle to activate/deactivate.
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, required this.role, required this.title});

  final String role;
  final String title;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _service = AdminUserService();
  final _scroll = ScrollController();
  final _searchCtl = TextEditingController();
  final List<UserModel> _items = [];

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
      final res = await _service.list(
        role: widget.role,
        search: _search,
        page: _page + 1,
      );
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
    final u = _items[index];
    try {
      final updated = await _service.toggleActive(u.id);
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
    final updated = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(builder: (_) => AdminUserEditPage(user: _items[index])),
    );
    if (updated != null && mounted) {
      setState(() => _items[index] = updated);
    }
  }

  Future<void> _delete(int index) async {
    final u = _items[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: Text(
            'سيتم حذف حساب "${u.name}" وكل بياناته نهائيًا. لا يمكن التراجع. متأكد؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(u.id);
      if (!mounted) return;
      setState(() => _items.removeAt(index));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف الحساب')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الهاتف أو البريد',
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
      return const Center(child: Text('لا توجد حسابات'));
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
          final u = _items[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                u.name.isNotEmpty ? u.name.characters.first : '؟',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w800),
              ),
            ),
            title: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (u.phone.isNotEmpty) u.phone,
                if (u.email != null && u.email!.isNotEmpty) u.email!,
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!u.isActive)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('موقوف',
                        style: TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                Switch(value: u.isActive, onChanged: (_) => _toggleActive(i)),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  tooltip: 'تعديل',
                  onPressed: () => _edit(i),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'حذف',
                  onPressed: () => _delete(i),
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
