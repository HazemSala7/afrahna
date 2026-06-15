import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';

/// Background / terminated-state message handler.
///
/// Must be a top-level (or static) function so the OS can invoke it in an
/// isolated background isolate. Data-only messages are surfaced as a local
/// notification here; messages carrying a `notification` payload are already
/// shown by the system tray automatically.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushNotificationService.instance._showFromMessage(message);
}

/// Centralised Firebase Cloud Messaging + local-notification handling so the
/// app receives pushes in every state: foreground, background and terminated,
/// on both Android and iOS.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  // Lazily resolved so we never touch Firebase before initializeApp() runs.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'إشعارات مهمة',
    description: 'إشعارات الحجوزات والتحديثات المهمة',
    importance: Importance.high,
  );

  bool _initialised = false;

  /// Called once at startup (before the user is necessarily signed in).
  /// Any failure (e.g. missing native Firebase config) is swallowed so it can
  /// never block app startup.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    try {
      await Firebase.initializeApp();

      // Register the background handler as early as possible.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _initLocalNotifications();

      // Ask the user for notification permission (iOS + Android 13+).
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      // On iOS, show banners while the app is in the foreground.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground messages: render them ourselves via a local notification.
      FirebaseMessaging.onMessage.listen(_showFromMessage);

      // App opened from a notification while it was in the background.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);

      // App launched from terminated state by tapping a notification.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleOpened(initial);

      // Keep the backend in sync when Firebase rotates the token.
      _messaging.onTokenRefresh.listen(_syncToken);

      // On Apple platforms an FCM token cannot be fetched until the device has
      // received an APNS token. The iOS Simulator usually never provides one,
      // so guard the fetch to avoid the `apns-token-not-set` error.
      final isApple =
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;
      if (isApple && (await _messaging.getAPNSToken()) == null) {
        if (kDebugMode) {
          debugPrint(
            'APNS token unavailable (simulator?) — '
            'skipping FCM token fetch.',
          );
        }
        return;
      }

      // Print the FCM token so we can send a test notification.
      final token = await _messaging.getToken();
      if (kDebugMode) {
        debugPrint('================ FCM TOKEN ================');
        debugPrint(token);
        debugPrint('==========================================');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Push init failed: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );

    // Create the Android channel referenced by the manifest meta-data.
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  /// Builds and displays a heads-up local notification from a [RemoteMessage].
  Future<void> _showFromMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['body'];
    if (title == null && body == null) return;

    await _local.show(
      id: notification?.hashCode ?? message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  }

  void _handleOpened(RemoteMessage message) {
    // Hook for deep-linking based on message.data; navigation handled elsewhere.
    if (kDebugMode) {
      debugPrint('Notification opened: ${message.data}');
    }
  }

  /// Retrieves the FCM token and registers it with the backend. Call after a
  /// successful sign-in so notifications can be targeted to the user.
  Future<String?> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _syncToken(token);
      }
      return token;
    } catch (e) {
      if (kDebugMode) debugPrint('FCM getToken failed: $e');
      return null;
    }
  }

  Future<void> _syncToken(String token) async {
    try {
      await ApiClient.instance.dio.post(
        '/auth/device-token',
        data: {
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      );
    } catch (_) {
      // Best-effort: ignore if the endpoint isn't available yet.
    }
  }

  /// Remove the token server-side on logout (best-effort).
  Future<void> unregisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await ApiClient.instance.dio.delete(
        '/auth/device-token',
        data: {'token': token},
      );
    } catch (_) {
      // ignore
    }
  }
}
