import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/auth_storage.dart';
import '../models/models.dart';
import '../services/push_notifications.dart';
import '../services/services.dart';

enum AuthStatus { unknown, signedIn, signedOut }

class SessionController extends ChangeNotifier {
  SessionController({AuthService? auth}) : _auth = auth ?? AuthService() {
    // When any authenticated request returns 401 (token revoked because the
    // account was stopped), drop the session immediately so the app returns to
    // the login screen and the user can't keep using a dead session.
    ApiClient.instance.onUnauthorized = _onUnauthorized;
  }

  final AuthService _auth;
  bool _forcingLogout = false;

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
      unawaited(PushNotificationService.instance.registerToken());
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
      unawaited(PushNotificationService.instance.registerToken());
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
  }) async {
    _error = null;
    try {
      final result = await _auth.register(
        name: name,
        phone: phone,
        password: password,
        email: email,
      );
      _user = result.user;
      _status = AuthStatus.signedIn;
      unawaited(PushNotificationService.instance.registerToken());
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
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

  /// Permanently deletes the user's account, then signs out locally.
  Future<bool> deleteAccount() async {
    try {
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
