import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../services/create_service_page.dart';
import '../vendors/edit_vendor_page.dart';
import '../vendors/manage_highlights_page.dart';
import '../vendors/manage_products_page.dart';
import '../vendors/manage_sections_page.dart';
import '../vendors/manage_promotions_page.dart';
import '../vendors/manage_stories_page.dart';
import '../subscriptions/subscription_plans.dart';
import 'create_vendor_post_page.dart';
import 'reel_studio_page.dart';
import 'vendor_posts_feed.dart';

/// Vendor's content page — tabs: خدماتي / ريلز / دورات.
/// Pass [vendorId] to view a specific vendor (read-only); omit for current vendor.
class VendorPostsPage extends StatefulWidget {
  const VendorPostsPage({super.key, this.vendorId, this.canCreate = true});

  final int? vendorId;
  final bool canCreate;

  @override
  State<VendorPostsPage> createState() => _VendorPostsPageState();
}

/// Tabs shown on a vendor's content page. "products" appears only for stores.
enum _VendorTab { products, sections, posts, services, reels }

class _VendorPostsPageState extends State<VendorPostsPage>
    with TickerProviderStateMixin {
  TabController? _tabs;
  List<_VendorTab> _tabKinds = const [_VendorTab.services, _VendorTab.reels];

  /// Rebuilds the tab set from the loaded vendor (adds "منتجاتي" for stores).
  void _rebuildTabs() {
    final kinds = <_VendorTab>[
      if (_vendor?.isStore == true) _VendorTab.products,
      if (_vendor?.isStore == true) _VendorTab.sections,
      _VendorTab.posts,
      _VendorTab.services,
      _VendorTab.reels,
    ];
    if (_tabs == null || _tabs!.length != kinds.length) {
      final oldIndex = _tabs?.index ?? 0;
      _tabs?.dispose();
      _tabs = TabController(length: kinds.length, vsync: this)
        ..addListener(() {
          if (mounted) setState(() {});
        });
      if (oldIndex > 0 && oldIndex < kinds.length) _tabs!.index = oldIndex;
    }
    _tabKinds = kinds;
  }

  final _postService = PostService();
  final _serviceService = ServiceService();
  final _vendorService = VendorService();

  int _reloadKey = 0;

  /// The vendor whose content is shown — used for the header (name + image).
  VendorModel? _vendor;

  @override
  void initState() {
    super.initState();
    _rebuildTabs();
    _loadVendor();
  }

  Future<void> _loadVendor() async {
    try {
      final v = widget.vendorId == null
          ? await _vendorService.mine()
          : await _vendorService.show(widget.vendorId!);
      if (mounted) {
        setState(() {
          _vendor = v;
          _rebuildTabs();
        });
      }
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
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _createForCurrentTab() async {
    final kind = _tabKinds[_tabs!.index];
    // Sections has its own in-list add button — no FAB action.
    if (kind == _VendorTab.sections) return;
    final vid = widget.vendorId ?? _vendor?.id;
    // Products/posts need a resolved vendor id.
    if ((kind == _VendorTab.products || kind == _VendorTab.posts) &&
        vid == null) {
      return;
    }
    Widget page;
    switch (kind) {
      case _VendorTab.products:
        page = EditProductPage(vendorId: vid!);
        break;
      case _VendorTab.sections:
        return; // handled above
      case _VendorTab.posts:
        page = CreateVendorPostPage(vendorId: vid!);
        break;
      case _VendorTab.services:
        page = CreateServicePage(vendorId: widget.vendorId);
        break;
      case _VendorTab.reels:
        page = ReelStudioPage(vendorId: widget.vendorId);
        break;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (ok == true && mounted) setState(() => _reloadKey++);
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
                  case 'notify':
                    _notifyFollowers(_vendor!);
                    break;
                  case 'plans':
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SubscriptionPlansPage(
                            currentPlan: _vendor!.activePlan)));
                    break;
                  case 'edit':
                    _editProfile();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'plans',
                  child: ListTile(
                      leading: Icon(Icons.workspace_premium_outlined),
                      title: Text('باقات الاشتراك'),
                      contentPadding: EdgeInsets.zero),
                ),
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
      floatingActionButton: (widget.canCreate &&
              _tabs != null &&
              _tabKinds[_tabs!.index] != _VendorTab.sections)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(_fabLabel(_tabKinds[_tabs!.index])),
              onPressed: _createForCurrentTab,
            )
          : null,
      body: Column(
        children: [
          if (_vendor != null) _VendorHeader(vendor: _vendor!),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              isScrollable: _tabKinds.length > 3,
              tabAlignment:
                  _tabKinds.length > 3 ? TabAlignment.start : TabAlignment.fill,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: const Color(0x11000000),
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              labelPadding:
                  const EdgeInsetsDirectional.symmetric(horizontal: 16),
              tabs: [for (final k in _tabKinds) Tab(text: _tabLabel(k))],
            ),
          ),
          Expanded(
            child: Container(
              color: AppColors.background,
              child: TabBarView(
                controller: _tabs,
                children: [for (final k in _tabKinds) _tabBody(k)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _tabLabel(_VendorTab k) => switch (k) {
        _VendorTab.products => 'منتجاتي',
        _VendorTab.sections => 'الأقسام',
        _VendorTab.posts => 'منشورات',
        _VendorTab.services => 'خدماتي',
        _VendorTab.reels => 'ريلز',
      };

  String _fabLabel(_VendorTab k) => switch (k) {
        _VendorTab.products => 'إضافة منتج',
        _VendorTab.sections => 'إضافة قسم',
        _VendorTab.posts => 'منشور جديد',
        _VendorTab.services => 'إضافة خدمة',
        _VendorTab.reels => 'إضافة ريلز',
      };

  Widget _tabBody(_VendorTab k) {
    // Resolve the vendor id: explicit (viewing another vendor) or the loaded
    // "mine" vendor. Null while the vendor is still loading.
    final vid = widget.vendorId ?? _vendor?.id;
    switch (k) {
      case _VendorTab.products:
        if (vid == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return StoreProductsList(
          key: ValueKey('prod-$_reloadKey'),
          vendorId: vid,
          canManage: widget.canCreate,
          refreshSignal: _reloadKey,
        );
      case _VendorTab.sections:
        if (vid == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SectionsManagerList(
          key: ValueKey('sections-$_reloadKey'),
          vendorId: vid,
          refreshSignal: _reloadKey,
        );
      case _VendorTab.posts:
        if (vid == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return VendorPostsFeed(
          key: ValueKey('posts-$_reloadKey'),
          vendorId: vid,
          canManage: widget.canCreate,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        );
      case _VendorTab.services:
        return _ServicesList(
          key: ValueKey('svc-$_reloadKey'),
          loader: _loadServices,
          vendorId: widget.vendorId,
          canManage: widget.canCreate,
          onChanged: () => setState(() => _reloadKey++),
        );
      case _VendorTab.reels:
        return _PostList(
          key: ValueKey('reel-$_reloadKey'),
          loader: () => _loadPosts(PostType.reel),
          type: PostType.reel,
        );
    }
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
    final subscribed = vendor.isVip || vendor.isPremium;

    return SizedBox(
      height: 172,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image (or a warm brand gradient fallback).
          if (cover != null && cover.isNotEmpty)
            Image.network(
              cover,
              fit: BoxFit.cover,
              // Cap decode resolution so an oversized (4K) cover can't OOM.
              cacheWidth: 1080,
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration:
                    BoxDecoration(gradient: AppColors.brandDeepGradient),
              ),
            )
          else
            const DecoratedBox(
              decoration:
                  BoxDecoration(gradient: AppColors.brandDeepGradient),
            ),
          // Brand-tinted darkening so text pops on any image.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  const Color(0xFF3A2415).withValues(alpha: 0.30),
                  const Color(0xFF2A1B10).withValues(alpha: 0.82),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          // Subscription pill (gold when subscribed, glass when not).
          PositionedDirectional(
            top: 12,
            end: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: subscribed
                    ? const LinearGradient(
                        colors: [Color(0xFFF4C64B), Color(0xFFC8901E)])
                    : null,
                color: subscribed ? null : Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35)),
                boxShadow: subscribed
                    ? [
                        BoxShadow(
                          color: const Color(0xFFC8901E)
                              .withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium,
                      color: subscribed
                          ? Colors.white
                          : const Color(0xFFF3C969),
                      size: 16),
                  const SizedBox(width: 5),
                  Text(
                    vendor.subscriptionLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Logo + name + meta.
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: (logo != null && logo.isNotEmpty)
                        ? NetworkImage(logo)
                        : null,
                    child: (logo == null || logo.isEmpty)
                        ? const Icon(Icons.storefront_rounded,
                            color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vendor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black54)
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.groups_rounded,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${vendor.followersCount} متابع',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600),
                          ),
                          if (vendor.isStore) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('🛍️ متجر',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                    ],
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
      setState(() {
        _f = widget.loader();
      });
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
      setState(() {
        _f = widget.loader();
      });
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async => setState(() {
        _f = widget.loader();
      }),
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
                cacheWidth: 1080,
                errorBuilder: (_, _, _) => Container(
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
  final _service = PostService();
  late Future<List<PostModel>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.loader();
  }

  @override
  bool get wantKeepAlive => true;

  void _reload() {
    // Block body required: `setState(() => _f = ...)` returns the assigned
    // Future, which Flutter rejects.
    setState(() {
      _f = widget.loader();
    });
  }

  Future<void> _delete(PostModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف'),
        content: const Text('هل تريد حذف هذا العنصر نهائيًا؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم الحذف')));
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذّر الحذف: $e')));
      }
    }
  }

  Future<void> _edit(PostModel p) async {
    final titleCtrl = TextEditingController(text: p.title ?? '');
    final bodyCtrl = TextEditingController(text: p.body ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              minLines: 1,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    titleCtrl.dispose();
    bodyCtrl.dispose();
    if (saved != true) return;
    try {
      await _service.update(p.id,
          title: titleCtrl.text.trim(), body: bodyCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم الحفظ')));
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّر الحفظ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<PostModel>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: AfrahnaLoader(size: 46));
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
              SizedBox(height: 100),
              Icon(Icons.movie_filter_outlined,
                  size: 56, color: AppColors.primaryLight),
              SizedBox(height: 12),
              Center(child: Text('لا يوجد محتوى بعد')),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) => _PostCard(
              post: items[i],
              onEdit: () => _edit(items[i]),
              onDelete: () => _delete(items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, this.onEdit, this.onDelete});
  final PostModel post;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  bool get _isReel => post.type == PostType.reel;

  Widget _thumb() {
    // Reels are videos — never try to render the video URL as an image.
    final url = post.thumbnail ?? (_isReel ? null : post.mediaUrl);
    Widget placeholder() => Container(
          color: Colors.black87,
          child: Center(
            child: Icon(
              _isReel ? Icons.play_circle_fill_rounded : Icons.image_outlined,
              color: Colors.white70,
              size: 30,
            ),
          ),
        );
    if (url == null || url.isEmpty) return placeholder();
    return Image.network(url,
        fit: BoxFit.cover,
        cacheWidth: 1080,
        errorBuilder: (_, _, _) => placeholder());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact portrait thumbnail (reel) / landscape (course).
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: _isReel ? 82 : 112,
                height: _isReel ? 116 : 82,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _thumb(),
                    if (_isReel)
                      const Center(
                        child: Icon(Icons.play_circle_fill_rounded,
                            color: Colors.white, size: 30),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (post.title?.trim().isNotEmpty ?? false)
                        ? post.title!.trim()
                        : (post.body?.trim().isNotEmpty ?? false)
                            ? post.body!.trim()
                            : (_isReel ? 'ريلز' : 'منشور'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye,
                          size: 15, color: Colors.grey[600]),
                      const SizedBox(width: 3),
                      Text('${post.viewsCount}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(Icons.favorite, size: 15, color: Colors.grey[600]),
                      const SizedBox(width: 3),
                      Text('${post.likesCount}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onEdit,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('تعديل',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Icon(Icons.delete_outline, size: 18),
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
