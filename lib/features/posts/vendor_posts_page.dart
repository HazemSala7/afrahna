import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/services/services.dart';
import '../services/create_service_page.dart';
import '../vendors/edit_vendor_page.dart';
import 'create_post_page.dart';

/// Vendor's content page — tabs: خدماتي / ريلز / دورات.
/// Pass [vendorId] to view a specific vendor (read-only); omit for current vendor.
class VendorPostsPage extends StatefulWidget {
  const VendorPostsPage({super.key, this.vendorId, this.canCreate = true});

  final int? vendorId;
  final bool canCreate;

  @override
  State<VendorPostsPage> createState() => _VendorPostsPageState();
}

class _VendorPostsPageState extends State<VendorPostsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  final _postService = PostService();
  final _serviceService = ServiceService();

  int _reloadKey = 0;

  Future<List<PostModel>> _loadPosts(PostType t) {
    return _postService.list(
      vendorId: widget.vendorId,
      mine: widget.vendorId == null,
      type: t,
    );
  }

  Future<List<ServiceModel>> _loadServices() {
    return _serviceService.list(vendorId: widget.vendorId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _createForCurrentTab() async {
    final idx = _tabs.index;
    if (idx == 0) {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CreateServicePage(vendorId: widget.vendorId),
        ),
      );
      if (ok == true && mounted) setState(() => _reloadKey++);
    } else {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePostPage(vendorId: widget.vendorId),
        ),
      );
      if (ok == true && mounted) setState(() => _reloadKey++);
    }
  }

  Future<void> _editProfile() async {
    try {
      final v = await VendorService().mine();
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => EditVendorPage(vendor: v)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحتوى'),
        actions: [
          if (widget.canCreate && widget.vendorId == null)
            IconButton(
              tooltip: 'تعديل بيانات المعلن',
              icon: const Icon(Icons.edit_note),
              onPressed: _editProfile,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'خدماتي'),
            Tab(text: 'ريلز'),
          ],
        ),
      ),
      floatingActionButton: widget.canCreate
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(_tabs.index == 0 ? 'إضافة خدمة' : 'إنشاء جديد'),
              onPressed: _createForCurrentTab,
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _ServicesList(
            key: ValueKey('svc-$_reloadKey'),
            loader: _loadServices,
            vendorId: widget.vendorId,
            canManage: widget.canCreate,
            onChanged: () => setState(() => _reloadKey++),
          ),
          _PostList(
            key: ValueKey('reel-$_reloadKey'),
            loader: () => _loadPosts(PostType.reel),
            type: PostType.reel,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SERVICES TAB
// ---------------------------------------------------------------------------

class _ServicesList extends StatefulWidget {
  const _ServicesList({
    super.key,
    required this.loader,
    required this.vendorId,
    required this.canManage,
    required this.onChanged,
  });

  final Future<List<ServiceModel>> Function() loader;
  final int? vendorId;
  final bool canManage;
  final VoidCallback onChanged;

  @override
  State<_ServicesList> createState() => _ServicesListState();
}

class _ServicesListState extends State<_ServicesList>
    with AutomaticKeepAliveClientMixin {
  late Future<List<ServiceModel>> _f;
  final _service = ServiceService();

  @override
  void initState() {
    super.initState();
    _f = widget.loader();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _delete(ServiceModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الخدمة'),
        content: Text('هل تريد فعلاً حذف "${s.title}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(s.id);
      if (!mounted) return;
      setState(() => _f = widget.loader());
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _edit(ServiceModel s) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateServicePage(vendorId: widget.vendorId, existing: s),
      ),
    );
    if (ok == true && mounted) {
      setState(() => _f = widget.loader());
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async => setState(() => _f = widget.loader()),
      child: FutureBuilder<List<ServiceModel>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final e = snap.error;
            return ListView(children: [
              const SizedBox(height: 80),
              Center(child: Text(e is ApiException ? e.message : e.toString())),
            ]);
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              Center(child: Text('لا توجد خدمات بعد')),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) => _ServiceCard(
              service: items[i],
              canManage: widget.canManage,
              onEdit: () => _edit(items[i]),
              onDelete: () => _delete(items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final ServiceModel service;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (service.image != null && service.image!.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                service.image!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black12,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (service.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(service.description, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (service.price != null)
                      Chip(label: Text('السعر: ${service.price}')),
                    const Spacer(),
                    if (canManage) ...[
                      IconButton(
                        tooltip: 'تعديل',
                        icon: const Icon(Icons.edit),
                        onPressed: onEdit,
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: onDelete,
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// POSTS (reels / courses) TAB
// ---------------------------------------------------------------------------

class _PostList extends StatefulWidget {
  const _PostList({super.key, required this.loader, required this.type});
  final Future<List<PostModel>> Function() loader;
  final PostType type;

  @override
  State<_PostList> createState() => _PostListState();
}

class _PostListState extends State<_PostList>
    with AutomaticKeepAliveClientMixin {
  late Future<List<PostModel>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.loader();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async => setState(() => _f = widget.loader()),
      child: FutureBuilder<List<PostModel>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final e = snap.error;
            return ListView(children: [
              const SizedBox(height: 80),
              Center(child: Text(e is ApiException ? e.message : e.toString())),
            ]);
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              Center(child: Text('لا يوجد محتوى بعد')),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) => _PostCard(post: items[i]),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final PostModel post;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.thumbnail != null || post.mediaUrl != null)
            AspectRatio(
              aspectRatio: post.type == PostType.reel ? 9 / 16 : 16 / 9,
              child: Image.network(
                post.thumbnail ?? post.mediaUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: Colors.black12, child: const Icon(Icons.broken_image)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.title != null && post.title!.isNotEmpty)
                  Text(post.title!,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (post.body != null && post.body!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(post.body!, maxLines: 4, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (post.type == PostType.course && post.price != null)
                      Chip(label: Text('السعر: ${post.price}')),
                    const Spacer(),
                    Icon(Icons.remove_red_eye, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${post.viewsCount}'),
                    const SizedBox(width: 12),
                    Icon(Icons.favorite, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${post.likesCount}'),
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
