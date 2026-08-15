import 'package:shared_preferences/shared_preferences.dart';

/// The share codes of invitations made on this device before signing in.
///
/// An invitation created without an account belongs to nobody, so the server
/// has no list to hand back — the only thread to it is its code. Keeping the
/// codes here is what lets «دعواتي» still show them, and what the app hands
/// over at sign-in so they become the new account's own.
class GuestInvitations {
  static const _key = 'guest_invitation_codes';

  /// Codes are short alphanumeric strings; anything else came from a bad
  /// response and would only fail on the next request.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final code = raw.trim();
    if (!RegExp(r'^[A-Za-z0-9]{4,24}$').hasMatch(code)) return null;
    return code;
  }

  static Future<List<String>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  /// Newest first, so «دعواتي» reads the way the rest of the app does.
  static Future<void> add(String? raw) async {
    final code = normalize(raw);
    if (code == null) return;
    final prefs = await SharedPreferences.getInstance();
    final codes = [...(prefs.getStringList(_key) ?? const <String>[])]
      ..remove(code)
      ..insert(0, code);
    await prefs.setStringList(_key, codes.take(50).toList());
  }

  static Future<void> remove(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final codes = [...(prefs.getStringList(_key) ?? const <String>[])]
      ..remove(code);
    await prefs.setStringList(_key, codes);
  }

  /// Called once the server has attached these to the signed-in account.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
