import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../features/reels/reels_page.dart';
import '../../features/vendors/vendor_details_page.dart';
import 'services.dart';

/// Listens for incoming deep links (custom scheme `afrahna://…` and the web
/// share link `https://afrahna.co/v/…`) and routes them into the app.
Future<void> initDeepLinks() async {
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) => NotificationRouter.handleUri(uri));
  try {
    final initial = await appLinks.getInitialLink();
    if (initial != null) {
      // Delay so the home screen is ready before we push the target page.
      Future.delayed(const Duration(milliseconds: 1600),
          () => NotificationRouter.handleUri(initial));
    }
  } catch (_) {}
}

/// Root navigator key so push handlers (which have no BuildContext) can still
/// navigate when a notification is tapped.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Turns a notification `link` (e.g. "vendor:123", "reel:45") into a navigation
/// to the relevant screen. Used by both the in-app notifications list and the
/// FCM push open handlers.
class NotificationRouter {
  static void handle(String? link, {String? type}) {
    final parsed = _parse(link);
    if (parsed == null) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;

    final (entity, id) = parsed;
    switch (entity) {
      case 'vendor':
      case 'shop':
        // Shop page — covers new offers/services/posts/follows for a vendor.
        nav.push(MaterialPageRoute(
          builder: (_) => VendorDetailsPage(vendorId: id),
        ));
        break;
      case 'reel':
        // Open the reels feed positioned on this reel.
        nav.push(MaterialPageRoute(
          builder: (_) => ReelsPage(initialPostId: id),
        ));
        break;
      case 'product':
        // Resolve the product's shop, open it and scroll to the product.
        ProductService().show(id).then((p) {
          rootNavigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => VendorDetailsPage(
              vendorId: p.vendorId,
              highlightProductId: p.id,
            ),
          ));
        }).catchError((_) {});
        break;
    }
  }

  /// Maps an incoming deep-link URI to a navigation.
  ///  - afrahna://vendor/313  ·  afrahna://reel/45  ·  afrahna://product/12
  ///  - https://afrahna.co/v/313
  static void handleUri(Uri uri) {
    if (uri.scheme == 'afrahna') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      handle('${uri.host}:$id');
      return;
    }
    final segs = uri.pathSegments;
    if (segs.length >= 2 && segs[0] == 'v') {
      handle('vendor:${segs[1]}');
    }
  }

  static (String, int)? _parse(String? link) {
    if (link == null || !link.contains(':')) return null;
    final i = link.indexOf(':');
    final entity = link.substring(0, i).trim();
    final id = int.tryParse(link.substring(i + 1).trim());
    if (entity.isEmpty || id == null) return null;
    return (entity, id);
  }
}
