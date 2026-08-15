import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afrahna/core/services/notification_router.dart';
import 'package:afrahna/features/account/vendor_statement_page.dart';
import 'package:afrahna/features/bookings/bookings_page.dart';
import 'package:afrahna/features/invitation/invitation_view_page.dart';
import 'package:afrahna/features/invitations/invitations_page.dart';
import 'package:afrahna/features/notifications/notifications_page.dart';
import 'package:afrahna/features/reels/reels_page.dart';
import 'package:afrahna/features/store/my_orders_page.dart';
import 'package:afrahna/features/vendors/vendor_details_page.dart';

/// Where each notification link leads.
///
/// With no navigator mounted the router queues the destination instead of
/// pushing it — the cold-start path — so these read the queued route and build
/// the widget without mounting it. No navigator, no network, no providers.
void main() {
  late BuildContext ctx;

  Widget? destinationOf(String? link) {
    NotificationRouter.clearPending();
    NotificationRouter.handle(link);
    final builder = NotificationRouter.pendingRoute;
    return builder == null ? null : builder(ctx);
  }

  setUp(() => NotificationRouter.clearPending());

  testWidgets('every notification link lands on its own screen',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    ctx = tester.element(find.byType(SizedBox));

    // A shop, and everything that lives on a shop's page.
    for (final link in [
      'vendor:313',
      'shop:313',
      'promo:313',
      'offer:313',
      'service:313',
      'follow:313',
      'review:313',
    ]) {
      final page = destinationOf(link);
      expect(page, isA<VendorDetailsPage>(), reason: link);
      expect((page as VendorDetailsPage).vendorId, 313, reason: link);
    }

    final reel = destinationOf('reel:45');
    expect(reel, isA<ReelsPage>());
    expect((reel as ReelsPage).initialPostId, 45);

    // Bookings and orders open their list positioned on the row in question.
    final booking = destinationOf('booking:42');
    expect(booking, isA<BookingsPage>());
    expect((booking as BookingsPage).highlightId, 42);

    final order = destinationOf('order:7');
    expect(order, isA<MyOrdersPage>());
    expect((order as MyOrdersPage).highlightId, 7);

    expect(destinationOf('subscription:9'), isA<VendorStatementPage>());
    expect(destinationOf('payment:9'), isA<VendorStatementPage>());

    // An invitation is keyed by its share code.
    final inv = destinationOf('invitation:9mlzsonr');
    expect(inv, isA<InvitationViewPage>());
    expect((inv as InvitationViewPage).code, '9mlzsonr');
  });

  testWidgets('a link that leads nowhere still opens the notifications list',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    ctx = tester.element(find.byType(SizedBox));

    expect(destinationOf(null), isA<NotificationsPage>());
    expect(destinationOf(''), isA<NotificationsPage>());
    expect(destinationOf('something-unknown:1'), isA<NotificationsPage>());

    // ...unless the tap came from that list, where it would be a dead end.
    NotificationRouter.clearPending();
    NotificationRouter.handle(null, fromList: true);
    expect(NotificationRouter.pendingRoute, isNull);
  });

  testWidgets('a tap before the app has a navigator is not lost',
      (tester) async {
    // Exactly the cold-start case: the tap is handled before runApp, then the
    // shell drains it once it is on screen.
    NotificationRouter.clearPending();
    NotificationRouter.handle('vendor:313');
    expect(NotificationRouter.pendingRoute, isNotNull);

    await tester.pumpWidget(MaterialApp(
      navigatorKey: rootNavigatorKey,
      home: const Scaffold(body: Text('shell')),
    ));
    NotificationRouter.drainPending();
    expect(NotificationRouter.pendingRoute, isNull);
  });

  testWidgets('a notification with no link falls back on its own kind',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    ctx = tester.element(find.byType(SizedBox));

    Widget? byType(String type) {
      NotificationRouter.clearPending();
      NotificationRouter.handle(null, type: type, fromList: true);
      final builder = NotificationRouter.pendingRoute;
      return builder == null ? null : builder(ctx);
    }

    expect(byType('booking'), isA<BookingsPage>());
    expect(byType('order'), isA<MyOrdersPage>());
    expect(byType('payment'), isA<VendorStatementPage>());
    expect(byType('invitation'), isA<InvitationsPage>());
    expect(byType('user'), isNull);
  });
}
