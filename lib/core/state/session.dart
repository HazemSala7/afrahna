import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../api/api_client.dart';
import '../api/auth_storage.dart';
import '../models/models.dart';
import '../services/invitation_service.dart';
import '../services/push_notifications.dart';
import '../services/services.dart';

enum AuthStatus { unknown, signedIn, signedOut }

class SessionController extends ChangeNotifier with WidgetsBindingObserver {
  SessionController({AuthService? auth}) : _auth = auth ?? AuthService() {
    // When any authenticated request returns 401 (token revoked because the
    // account was stopped), drop the session immediately so the app returns to
    // the login screen and the user can't keep using a dead session.
    ApiClient.instance.onUnauthorized = _onUnauthorized;
    // Observe app lifecycle so we can re-verify the session when the app is
    // brought back to the foreground.
    WidgetsBinding.instance.addObserver(this);
  }

  final AuthService _auth;
  bool _forcingLogout = false;

  /// Proactively re-checks the session on a timer so a stopped account is
  /// forced out promptly even while the app sits idle (no other requests).
  Timer? _heartbeat;
  static const _heartbeatInterval = Duration(seconds: 45);

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _error;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  Future<void> bootstrap() async {
    final token = await AuthStorage.instance.readToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    // hydrate cached user first
    final cached = await AuthStorage.instance.readUserJson();
    if (cached != null) {
      try {
        _user = UserModel.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {}
    }
    try {
      _user = await _auth.me();
      _status = AuthStatus.signedIn;
      _startHeartbeat();
      unawaited(PushNotificationService.instance.registerToken());
      // Invitations made on this device before signing in have no owner.
      // Hand their codes over so they land in this account.
      unawaited(InvitationService().claimGuest());
    } catch (_) {
      await AuthStorage.instance.clear();
      _user = null;
      _status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<bool> login(String phone, String password) async {
    _error = null;
    try {
      final result = await _auth.login(phone: phone, password: password);
      _user = result.user;
      _status = AuthStatus.signedIn;
      _startHeartbeat();
      unawaited(PushNotificationService.instance.registerToken());
      // Invitations made on this device before signing in have no owner.
      // Hand their codes over so they land in this account.
      unawaited(InvitationService().claimGuest());
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? referralCode,
  }) async {
    _error = null;
    try {
      final result = await _auth.register(
        name: name,
        phone: phone,
        password: password,
        email: email,
        referralCode: referralCode,
      );
      _user = result.user;
      _status = AuthStatus.signedIn;
      _startHeartbeat();
      unawaited(PushNotificationService.instance.registerToken());
      // Invitations made on this device before signing in have no owner.
      // Hand their codes over so they land in this account.
      unawaited(InvitationService().claimGuest());
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Replaces the cached user after a profile edit, so every screen watching
  /// the session (header, account page, drawer) redraws with the new details.
  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  /// Re-reads the signed-in user from the server.
  Future<void> refreshUser() async {
    try {
      final u = await _auth.me();
      _user = u;
      notifyListeners();
    } catch (_) {
      // Keep the cached user — a failed refresh must not sign anyone out.
    }
  }

  /// Enables/disables notifications for the signed-in user (offer alerts, etc.).
  Future<void> setNotificationsEnabled(bool enabled) async {
    final v = await _auth.updateNotifications(enabled);
    if (_user != null) {
      _user = _user!.copyWith(notificationsEnabled: v);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _stopHeartbeat();
    await PushNotificationService.instance.unregisterToken();
    await _auth.logout();
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Called by the API client when a 401 hits an authenticated request — the
  /// token was revoked server-side (e.g. the admin stopped this account).
  /// Clears the local session without calling the server (the token is dead).
  void _onUnauthorized() {
    if (_status != AuthStatus.signedIn || _forcingLogout) return;
    _forcingLogout = true;
    _stopHeartbeat();
    () async {
      try {
        await AuthStorage.instance.clear();
      } finally {
        _user = null;
        _status = AuthStatus.signedOut;
        _forcingLogout = false;
        notifyListeners();
      }
    }();
  }

  // --- Proactive session verification -------------------------------------

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _verifySession());
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  /// Re-fetches the current user. If the account was stopped (token revoked →
  /// 401, or the account comes back `is_active = false`), forces a logout.
  Future<void> _verifySession() async {
    if (_status != AuthStatus.signedIn || _forcingLogout) return;
    try {
      final u = await _auth.me();
      if (!u.isActive) {
        _onUnauthorized();
        return;
      }
      _user = u;
      notifyListeners();
    } on ApiException catch (e) {
      // 401 → the interceptor already triggered _onUnauthorized; other codes
      // (offline / server hiccup) are transient and must not sign the user out.
      if (e.statusCode == 401) _onUnauthorized();
    } catch (_) {
      // Network error — ignore; we only force logout on an explicit 401 / stop.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_verifySession());
    }
  }

  @override
  void dispose() {
    _stopHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Permanently deletes the user's account, then signs out locally.
  Future<bool> deleteAccount() async {
    try {
      _stopHeartbeat();
      await PushNotificationService.instance.unregisterToken();
      await _auth.deleteAccount();
      _user = null;
      _status = AuthStatus.signedOut;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
