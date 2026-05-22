import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  AuthStorage._();
  static final AuthStorage instance = AuthStorage._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> writeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<void> writeUserJson(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json);
  }

  Future<String?> readUserJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey);
  }
}
