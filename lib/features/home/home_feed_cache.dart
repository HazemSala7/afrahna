import '../../core/models/models.dart';
import '../../core/services/services.dart';

/// Prefetches the home page's data during the splash screen so the home tab
/// renders instantly (no spinners) on first show. The futures are handed to the
/// home page exactly once via [isReady] + [clear]; refreshes load fresh data.
class HomeFeedCache {
  HomeFeedCache._();
  static final HomeFeedCache instance = HomeFeedCache._();

  Future<List<CategoryModel>>? categories;
  Future<List<PromotionModel>>? promos;
  Future<List<VendorModel>>? topVendors;
  Future<List<VendorModel>>? featuredVendors;
  Future<List<SliderModel>>? sliders;
  Future<HomeStats>? stats;

  /// True when a prefetch is available for the home page to consume.
  bool get isReady => categories != null;

  /// Kicks off all home network requests. Idempotent: safe to call repeatedly;
  /// only the first call per launch actually starts the requests.
  void prefetch() {
    if (isReady) return;
    categories = CategoryService().list(tree: true);
    promos = PromotionService().list();
    topVendors = VendorService().list();
    featuredVendors =
        VendorService().list(featured: true, perPage: 1000).then((l) => l..shuffle());
    sliders = loadSliders();
    stats = StatsService().get();
  }

  /// Drops the cached futures so the next home load fetches fresh data.
  void clear() {
    categories = null;
    promos = null;
    topVendors = null;
    featuredVendors = null;
    sliders = null;
    stats = null;
  }

  /// Hero slider content = admin-created slides + VIP vendors (as slides),
  /// shuffled so the order is fresh on every load.
  static Future<List<SliderModel>> loadSliders() async {
    List<SliderModel> sliders = const [];
    List<VendorModel> vips = const [];
    try {
      sliders = await SliderService().list();
    } catch (_) {}
    try {
      vips = await VendorService().list(vip: true, perPage: 10);
    } catch (_) {}
    final vipSlides = vips
        .where((v) => (v.cover ?? v.logo ?? '').isNotEmpty)
        .map((v) => SliderModel(
              id: -v.id, // negative id to avoid clashing with real slides
              image: v.cover ?? v.logo ?? '',
              titleAr: v.name,
              subtitleAr: v.category?.name,
              badgeAr: 'VIP ⭐',
              vendorId: v.id,
            ))
        .toList();
    final all = [...vipSlides, ...sliders]..shuffle();
    return all;
  }
}
