import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/services/local_favorites.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../vendors/vendor_details_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  Future<List<VendorModel>>? _future;
  Set<int> _loadedFor = const {};

  Future<List<VendorModel>> _fetch(Set<int> ids) async {
    if (ids.isEmpty) return const <VendorModel>[];
    final svc = VendorService();
    final results = <VendorModel>[];
    for (final id in ids) {
      try {
        results.add(await svc.show(id));
      } catch (_) {
        // Skip vendors that no longer exist or fail for one item.
      }
    }
    return results;
  }

  void _ensureFuture(Set<int> ids) {
    if (_future == null ||
        _loadedFor.length != ids.length ||
        !_loadedFor.containsAll(ids)) {
      _loadedFor = {...ids};
      _future = _fetch(_loadedFor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favs = context.watch<LocalFavorites>();
    _ensureFuture(favs.ids);

    return AppScaffold(

      appBar: const PinkAppBar(title: 'المفضلة', showBack: true),
      body: favs.ids.isEmpty
          ? const EmptyState(
              message: 'لا توجد مفضلة بعد\nأضف ما يعجبك ليظهر هنا',
              icon: Icons.favorite_border,
            )
          : FutureBuilder<List<VendorModel>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const CenteredLoader();
                }
                if (snap.hasError) {
                  return ErrorState(
                    message: snap.error.toString(),
                    onRetry: () => setState(() {
                      _loadedFor = const {};
                      _future = null;
                    }),
                  );
                }
                final items = snap.data ?? const <VendorModel>[];
                if (items.isEmpty) {
                  return const EmptyState(
                    message: 'لا توجد مفضلة بعد\nأضف ما يعجبك ليظهر هنا',
                    icon: Icons.favorite_border,
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    setState(() {
                      _loadedFor = const {};
                      _future = null;
                    });
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _FavTile(vendor: items[i]),
                  ),
                );
              },
            ),
    );
  }
}

class _FavTile extends StatelessWidget {
  const _FavTile({required this.vendor});
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
                width: 70,
                height: 70,
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
                  Text(
                    vendor.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (vendor.category != null)
                    Text(
                      vendor.category!.name,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.favorite, color: AppColors.primary),
              tooltip: 'إزالة من المفضلة',
              onPressed: () => LocalFavorites.instance.remove(vendor.id),
            ),
          ],
        ),
      ),
    );
  }
}
