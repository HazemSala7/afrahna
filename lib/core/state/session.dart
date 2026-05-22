import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/auth_storage.dart';
import '../models/models.dart';
import '../services/services.dart';

enum AuthStatus { unknown, signedIn, signedOut }

class SessionController extends ChangeNotifier {
  SessionController({AuthService? auth}) : _auth = auth ?? AuthService();

  final AuthService _auth;

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
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }
}
