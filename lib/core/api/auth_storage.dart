import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  AuthStorage._();
  static final AuthStorage instance = AuthStorage._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _lastPhoneKey = 'last_login_phone';
  static const _lastPasswordKey = 'last_login_password';

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

  /// Remember the last credentials entered on the login screen (for the
  /// "تذكّرني" convenience — pre-fills the form on next launch).
  Future<void> writeLastLogin(String phone, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPhoneKey, phone);
    await prefs.setString(_lastPasswordKey, password);
  }

  Future<({String phone, String password})?> readLastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_lastPhoneKey);
    if (phone == null || phone.isEmpty) return null;
    return (phone: phone, password: prefs.getString(_lastPasswordKey) ?? '');
  }

  Future<void> clearLastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPhoneKey);
    await prefs.remove(_lastPasswordKey);
  }
}
