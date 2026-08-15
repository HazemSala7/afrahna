import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afrahna/core/services/push_notifications.dart';

/// Who draws the banner when a push lands while the app is open.
///
/// Getting this wrong on iPhone showed the same notification twice — once by
/// the system, once by the app — with each copy's tap taking a different route
/// into the app. There is no iPhone here to try it on, so the platform is
/// overridden and the decision checked directly.
void main() {
  final withAlert = const RemoteMessage(
    notification: RemoteNotification(title: 'حجز جديد', body: 'طلب حجز'),
    data: {'type': 'booking', 'link': 'booking:42'},
  );
  const dataOnly = RemoteMessage(data: {'type': 'booking', 'link': 'booking:42'});

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS lets the system present it — the app must not draw a second', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(PushNotificationService.drawInForeground(withAlert), isFalse);
    // A data-only message is not presented by iOS, so it is still ours to draw.
    expect(PushNotificationService.drawInForeground(dataOnly), isTrue);
  });

  test('Android shows nothing in the foreground, so the app draws it', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(PushNotificationService.drawInForeground(withAlert), isTrue);
    expect(PushNotificationService.drawInForeground(dataOnly), isTrue);
  });
}
