import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../services/create_service_page.dart';
import '../vendors/edit_vendor_page.dart';
import '../vendors/manage_highlights_page.dart';
import '../vendors/manage_promotions_page.dart';
import '../vendors/manage_stories_page.dart';
import '../vendors/vendor_followers_page.dart';
import 'reel_studio_page.dart';

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
  final _vendorService = VendorService();

  int _reloadKey = 0;

  /// The vendor whose content is shown — used for the header (name + image).
  VendorModel? _vendor;

  @override
  void initState() {
    super.initState();
    _loadVendor();
  }

  Future<void> _loadVendor() async {
    try {
      final v = widget.vendorId == null
          ? await _vendorService.mine()
          : await _vendorService.show(widget.vendorId!);
      if (mounted) setState(() => _vendor = v);
    } on ApiException {
      // Header is optional; ignore load failures and keep the page usable.
    }
  }

  Future<List<PostModel>> _loadPosts(PostType t) {
    return _postService.list(
      vendorId: widget.vendorId,
      mine: widget.vendorId == null,
      type: t,
    );
  }

  Future<List<ServiceModel>> _loadServices() {
    return _serviceService.list(
      vendorId: widget.vendorId,
      mine: widget.vendorId == null,
    );
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
          builder: (_) => ReelStudioPage(vendorId: widget.vendorId),
        ),
      );
      if (ok == true && mounted) setState(() => _reloadKey++);
    }
  }

  Future<void> _notifyFollowers(VendorModel vendor) async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final sent = await showDialog<int>(
      context: context,
      builder: (ctx) => _NotifyFollowersDialog(
        vendor: vendor,
        titleCtrl: titleCtrl,
        bodyCtrl: bodyCtrl,
      ),
    );
    titleCtrl.dispose();
    bodyCtrl.dispose();
    if (sent != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent > 0
              ? 'تم إرسال الإشعار إلى $sent متابع'
              : 'لا يوجد متابعون بعد'),
        ),
      );
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
        title: Text(_vendor?.name ?? 'المحتوى'),
        actions: [
          if (widget.canCreate && _vendor != null)
            PopupMenuButton<String>(
              tooltip: 'إدارة',
              icon: const Icon(Icons.tune),
              onSelected: (value) {
                final vid = _vendor!.id;
                switch (value) {
                  case 'promotions':
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ManagePromotionsPage(vendorId: vid)));
                    break;
                  case 'highlights':
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ManageHighlightsPage(vendorId: vid)));
                    break;
                  case 'stories':
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ManageStoriesPage(vendorId: vid)));
                    break;
                  case 'followers':
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => VendorFollowersPage(vendorId: vid)));
                    break;
                  case 'notify':
                    _notifyFollowers(_vendor!);
                    break;
                  case 'edit':
                    _editProfile();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'promotions',
                  child: ListTile(
                      leading: Icon(Icons.local_offer_outlined),
                      title: Text('عروضي'),
                      contentPadding: EdgeInsets.zero),
                ),
                const PopupMenuItem(
                  value: 'highlights',
                  child: ListTile(
                      leading: Icon(Icons.auto_awesome_outlined),
                      title: Text('إدارة الهايلايت'),
                      contentPadding: EdgeInsets.zero),
                ),
                const PopupMenuItem(
                  value: 'stories',
                  child: ListTile(
                      leading: Icon(Icons.amp_stories_outlined),
                      title: Text('إدارة الستوريز'),
                      contentPadding: EdgeInsets.zero),
                ),
                const PopupMenuItem(
                  value: 'followers',
                  child: ListTile(
                      leading: Icon(Icons.group_outlined),
                      title: Text('المتابعون'),
                      contentPadding: EdgeInsets.zero),
                ),
                const PopupMenuItem(
                  value: 'notify',
                  child: ListTile(
                      leading: Icon(Icons.campaign_outlined),
                      title: Text('إشعار للمتابعين'),
                      contentPadding: EdgeInsets.zero),
                ),
                if (widget.vendorId == null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                        leading: Icon(Icons.edit_note),
                        title: Text('تعديل بيانات المعلن'),
                        contentPadding: EdgeInsets.zero),
                  ),
              ],
            ),
        ],
      ),
      floatingActionButton: widget.canCreate
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(_tabs.index == 0 ? 'إضافة خدمة' : 'إضافة ريلز'),
              onPressed: _createForCurrentTab,
            )
          : null,
      body: Column(
        children: [
          if (_vendor != null) _VendorHeader(vendor: _vendor!),
          TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'خدماتي'),
              Tab(text: 'ريلز'),
            ],
          ),
          Expanded(
            child: TabBarView(
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
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VENDOR HEADER (name + logo over the cover image)
// ---------------------------------------------------------------------------

class _VendorHeader extends StatelessWidget {
  const _VendorHeader({required this.vendor});
  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    final cover = vendor.cover;
    final logo = vendor.logo;
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image (or a solid brand-colored fallback).
          if (cover != null && cover.isNotEmpty)
            Image.network(
              cover,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.primaryLight),
            )
          else
            Container(color: AppColors.primaryLight),
          // Dark gradient so the name stays readable over any image.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.surface,
                  backgroundImage: (logo != null && logo.isNotEmpty)
                      ? NetworkImage(logo)
                      : null,
                  child: (logo == null || logo.isEmpty)
                      ? const Icon(Icons.storefront_outlined,
                          color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    vendor.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
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
                    if (service.price != null) _ServicePriceTag(service: service),
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

/// Price tag that clearly shows a discount when the service has one:
/// the old price struck through, the new price, and a "-NN%" badge.
class _ServicePriceTag extends StatelessWidget {
  const _ServicePriceTag({required this.service});
  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    if (!service.hasDiscount) {
      return Chip(
        label: Text('السعر: ${_fmt(service.price)} ₪'),
        backgroundColor: AppColors.primaryLight,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Discount percentage badge.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'خصم ${service.discountPercent}%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Old price (struck through).
        Text(
          '${_fmt(service.price)} ₪',
          style: const TextStyle(
            color: AppColors.textMuted,
            decoration: TextDecoration.lineThrough,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 6),
        // New (discounted) price.
        Text(
          '${_fmt(service.discountPrice)} ₪',
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  static String _fmt(double? v) {
    if (v == null) return '0';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
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

// ---------------------------------------------------------------------------
// NOTIFY FOLLOWERS DIALOG
// ---------------------------------------------------------------------------

class _NotifyFollowersDialog extends StatefulWidget {
  const _NotifyFollowersDialog({
    required this.vendor,
    required this.titleCtrl,
    required this.bodyCtrl,
  });
  final VendorModel vendor;
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;

  @override
  State<_NotifyFollowersDialog> createState() => _NotifyFollowersDialogState();
}

class _NotifyFollowersDialogState extends State<_NotifyFollowersDialog> {
  bool _sending = false;

  Future<void> _send() async {
    if (widget.titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب عنوان الإشعار')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final sent = await VendorService().notifyFollowers(
        widget.vendor.id,
        title: widget.titleCtrl.text.trim(),
        body: widget.bodyCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, sent);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إشعار للمتابعين'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'سيصل هذا الإشعار لكل من يتابع "${widget.vendor.name}"',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.titleCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.bodyCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'النص (اختياري)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send),
          label: const Text('إرسال'),
        ),
      ],
    );
  }
}
