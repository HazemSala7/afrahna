import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';

/// Gets the reels feed ready while the splash is still on screen.
///
/// Opening reels used to start from nothing: fetch the first page, then start
/// downloading the first video, and only then show a picture. Both of those
/// can happen during the three seconds the intro is playing instead, so the
/// tab opens on a reel that is already there.
///
/// Two things are warmed, and they only help if they are the *same* ones the
/// feed later uses:
///   * the first page of reels, handed over once via [takeFirstPage];
///   * their video files, in [videos] — the cache the feed reads from, which
///     is why the manager lives here rather than privately inside the page.
class ReelsCache {
  ReelsCache._();
  static final ReelsCache instance = ReelsCache._();

  /// Disk cache dedicated to reel videos, so an already-seen (or prefetched)
  /// reel plays instantly from a local file instead of re-streaming.
  static final CacheManager videos = CacheManager(
    Config(
      'afrahna_reels_v1',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 60,
    ),
  );

  static const pageSize = 10;

  /// How many of the first page's videos to pull down during the splash. The
  /// first two are what the user actually sees before they can swipe; the rest
  /// keep going in the background after the app has opened.
  static const _warmDuringSplash = 3;

  ({List<PostModel> items, bool hasMore})? _firstPage;
  Future<void>? _running;

  /// The shuffle seed page 1 was fetched with. Later pages must use the same
  /// one or the feed would repeat or skip reels.
  int? seed;

  bool get isReady => _firstPage != null;

  /// Fetch page one and start warming its videos. Idempotent — calling it
  /// again while it runs, or after it finished, does nothing.
  ///
  /// [warm] is how many of the page's videos to pull onto disk; pass 0 to
  /// fetch the list alone (tests, where there is no disk cache to write to).
  Future<void> prefetch({int warm = _warmDuringSplash}) {
    return _running ??= _run(warm);
  }

  Future<void> _run(int warm) async {
    try {
      final s = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
      final res = await PostService()
          .listPaged(type: PostType.reel, page: 1, perPage: pageSize, seed: s);
      seed = s;
      _firstPage = res;
      // Deliberately not awaited: the splash must not wait on video bytes.
      if (warm > 0) _warm(res.items, warm);
    } catch (_) {
      // The feed will simply load the usual way.
    }
  }

  Future<void> _warm(List<PostModel> items, int count) async {
    for (final r in items.take(count)) {
      final url = r.mediaUrl;
      if (url == null || url.isEmpty) continue;
      try {
        await videos.getSingleFile(url);
      } catch (_) {
        // One failed prefetch must not stop the others.
      }
    }
  }

  /// Hands the prefetched page to the feed, once. Returns null if there is
  /// nothing ready, in which case the feed fetches as before.
  ({List<PostModel> items, bool hasMore})? takeFirstPage() {
    final p = _firstPage;
    _firstPage = null;
    return p;
  }
}
