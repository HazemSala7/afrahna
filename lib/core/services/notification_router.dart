import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../features/account/vendor_statement_page.dart';
import '../../features/bookings/bookings_page.dart';
import '../../features/invitation/invitation_view_page.dart';
import '../../features/invitations/invitations_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/posts/post_details_page.dart';
import '../../features/reels/reels_page.dart';
import '../../features/store/my_orders_page.dart';
import '../../features/vendors/vendor_details_page.dart';
import 'accounts_services.dart';
import 'invitation_service.dart';
import 'referral_storage.dart';
import 'services.dart';

/// Listens for incoming deep links (custom scheme `afrahna://…` and the web
/// share link `https://afrahna.co/v/…`) and routes them into the app.
Future<void> initDeepLinks() async {
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) => NotificationRouter.handleUri(uri));
  try {
    final initial = await appLinks.getInitialLink();
    if (initial != null) {
      // Queue it rather than firing on a timer: the splash replaces the whole
      // route after its own delay, so anything pushed before that handover is
      // silently thrown away. The shell drains this once it is on screen.
      NotificationRouter.pendingUri = initial;
    }
  } catch (_) {}
}

/// Root navigator key so push handlers (which have no BuildContext) can still
/// navigate when a notification is tapped.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Turns a notification `link` into a navigation to the exact screen the
/// notification is about. Used by the in-app notifications list, the FCM push
/// open handlers and incoming deep links.
///
/// The link is always `entity:handle`, e.g. `booking:42`, `vendor:313`,
/// `invitation:9mlzsonr`. Everything the backend can notify about has an
/// entry here; anything unrecognised still opens the notifications list rather
/// than leaving the tap dead.
class NotificationRouter {
  /// Pushes [builder], or holds it until there is a navigator to push onto.
  ///
  /// A notification tapped while the app is dead runs before `runApp`, so the
  /// navigator does not exist yet and pushing is a silent no-op — which is why
  /// cold-start taps used to land on the home screen. Queued routes are
  /// drained by the shell in [drainPending].
  static void _open(WidgetBuilder builder) {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) {
      _pendingRoute = builder;
      return;
    }
    nav.push(MaterialPageRoute(builder: builder));
  }

  static WidgetBuilder? _pendingRoute;

  /// The route a tap produced while no navigator existed. Tests read it to
  /// check where a link leads without standing up the whole app.
  @visibleForTesting
  static WidgetBuilder? get pendingRoute => _pendingRoute;

  @visibleForTesting
  static void clearPending() => _pendingRoute = null;

  /// Resolves something by id first, then opens the screen it belongs to. A
  /// failed lookup (deleted row, no network) leaves the app where it is.
  static void _openAsync(Future<WidgetBuilder?> resolve) {
    resolve.then((builder) {
      if (builder != null) _open(builder);
    }).catchError((_) {});
  }

  static void handle(String? link, {String? type, bool fromList = false}) {
    final parsed = _parse(link);
    if (parsed == null) {
      // No usable link. The kind of notification is still enough to pick the
      // screen it belongs to, which beats dropping the reader on a list of
      // notifications they just came from.
      final byType = _screenForType(type);
      if (byType != null) {
        _open(byType);
      } else if (!fromList) {
        _open((_) => const NotificationsPage());
      }
      return;
    }

    final (entity, handle) = parsed;
    final id = int.tryParse(handle.split(':').first.trim());

    switch (entity) {
      // Everything that lives on a shop's page: the shop itself, a new offer,
      // a new service, a follow, a review, a post or course it published.
      case 'vendor':
      case 'shop':
      case 'promo':
      case 'offer':
      case 'service':
      case 'follow':
      case 'review':
        if (id != null) {
          _open((_) => VendorDetailsPage(vendorId: id));
        }
        break;

      case 'reel':
        // Open the reels feed positioned on this reel.
        if (id != null) _open((_) => ReelsPage(initialPostId: id));
        break;

      case 'post':
      case 'comment':
        // `comment:{postId}` opens the post with the comment sheet up, which
        // is where the notification is actually pointing.
        if (id != null) {
          _openAsync(PostService().show(id).then(
                (p) => (_) => PostDetailsPage(
                      post: p,
                      focusComment: entity == 'comment',
                    ),
              ));
        }
        break;

      case 'product':
        // Resolve the product's shop, open it and scroll to the product.
        if (id != null) {
          _openAsync(ProductService().show(id).then(
                (p) => (_) => VendorDetailsPage(
                      vendorId: p.vendorId,
                      highlightProductId: p.id,
                    ),
              ));
        }
        break;

      case 'booking':
        // One link serves both sides: the shop that received the request and
        // the customer whose booking changed. The page finds it in whichever
        // of the two lists holds it.
        if (id != null) _open((_) => BookingsPage(highlightId: id));
        break;

      case 'order':
        if (id != null) _open((_) => MyOrdersPage(highlightId: id));
        break;

      case 'subscription':
      case 'payment':
        // Payments and invoices all read off the account statement.
        _open((_) => const VendorStatementPage());
        break;

      case 'invitation':
        _openInvitation(handle);
        break;

      default:
        if (!fromList) _open((_) => const NotificationsPage());
    }
  }

  /// The screen a kind of notification belongs to, for the ones sent without
  /// a link (mostly the admin fan-outs). Only screens that need no id.
  static WidgetBuilder? _screenForType(String? type) {
    switch (type) {
      case 'booking':
        return (_) => const BookingsPage();
      case 'order':
        return (_) => const MyOrdersPage();
      case 'payment':
      case 'subscription':
        return (_) => const VendorStatementPage();
      case 'invitation':
        return (_) => const InvitationsPage();
      default:
        return null;
    }
  }

  /// The invitation screen is keyed by share code, but older notifications
  /// (and their rows still sitting in the database) carry the numeric id —
  /// sometimes with a trailing guest token, e.g. `invitation:12:web:abc`. Take
  /// whichever was sent and turn it into a code.
  static void _openInvitation(String rawHandle) {
    final first = rawHandle.split(':').first.trim();
    if (first.isEmpty) return;

    final id = int.tryParse(first);
    if (id == null) {
      _open((_) => InvitationViewPage(code: first));
      return;
    }
    // Numeric: the recipient of an invitation notification is its owner, so
    // the owner-only endpoint can trade the id for the code.
    _openAsync(InvitationService().show(id).then(
          (inv) => inv.code.isEmpty
              ? null
              : (_) => InvitationViewPage(code: inv.code),
        ));
  }

  /// Maps an incoming deep-link URI to a navigation.
  ///  - afrahna://vendor/313  ·  afrahna://reel/45  ·  afrahna://product/12
  ///  - afrahna://invite/AB12CD  ·  https://afrahna.co/r/AB12CD
  ///  - https://afrahna.co/v/313
  static void handleUri(Uri uri) {
    if (uri.scheme == 'afrahna') {
      final first = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (uri.host == 'invite') {
        _handleInvite(first);
        return;
      }
      // afrahna://i/{CODE} — a wedding invitation.
      if (uri.host == 'i' && first.isNotEmpty) {
        onInvitation?.call(first);
        return;
      }
      handle('${uri.host}:$first', fromList: true);
      return;
    }
    final segs = uri.pathSegments;
    if (segs.length >= 2 && segs[0] == 'v') {
      handle('vendor:${segs[1]}', fromList: true);
      return;
    }
    // Wedding invitation shared from the app: https://afrahna.co/i/{CODE}
    if (segs.length >= 2 && segs[0] == 'i') {
      onInvitation?.call(segs[1]);
      return;
    }
    // Invite link shared from the app: https://afrahna.co/r/{CODE}
    if (segs.length >= 2 && segs[0] == 'r') {
      _handleInvite(segs[1]);
    }
  }

  /// Set by the app shell so an invitation link opens the invitation itself.
  /// Kept as a callback so this router stays free of widget dependencies.
  static void Function(String code)? onInvitation;

  /// A link the app was launched with, held until the first real screen is
  /// mounted. Cold start replaces the route stack, so acting immediately loses
  /// the navigation.
  static Uri? pendingUri;

  /// Called by the shell once it is on screen. Safe to call more than once.
  static void drainPending() {
    final uri = pendingUri;
    if (uri != null) {
      pendingUri = null;
      handleUri(uri);
    }
    final route = _pendingRoute;
    if (route != null) {
      _pendingRoute = null;
      rootNavigatorKey.currentState?.push(MaterialPageRoute(builder: route));
    }
  }

  /// Stores the invite code and, for a signed-out visitor, opens registration
  /// with it filled in — the inviter's point is only credited when the friend
  /// actually creates an account.
  static Future<void> _handleInvite(String rawCode) async {
    final code = ReferralStorage.normalize(rawCode);
    if (code == null) return;
    await ReferralStorage.save(code);
    onInvite?.call(code);
  }

  /// Set by the app shell so an incoming invite can reach the UI. Kept as a
  /// callback so this router stays free of widget/session dependencies.
  static void Function(String code)? onInvite;

  /// Splits `entity:handle` on the first colon only — the handle may itself
  /// contain colons (see [_openInvitation]).
  static (String, String)? _parse(String? link) {
    if (link == null || !link.contains(':')) return null;
    final i = link.indexOf(':');
    final entity = link.substring(0, i).trim();
    final handle = link.substring(i + 1).trim();
    if (entity.isEmpty || handle.isEmpty) return null;
    return (entity, handle);
  }
}
