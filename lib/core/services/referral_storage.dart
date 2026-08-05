import 'package:shared_preferences/shared_preferences.dart';

/// Holds an invite code captured from a deep link until the invited friend
/// actually creates an account — the point is only credited to the inviter at
/// registration, and that can happen minutes (or a restart) after the tap.
///
/// Persisted rather than kept in memory so the flow survives:
///   tap link → store → install → open app → register.
class ReferralStorage {
  static const _key = 'pending_referral_code';

  /// Codes are short alphanumeric strings; anything else came from a malformed
  /// or tampered link and is ignored.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final code = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (code.length < 3 || code.length > 16) return null;
    return code;
  }

  /// Remembers [raw] as the pending invite code. Ignores junk and never
  /// overwrites a code that is already waiting.
  static Future<void> save(String? raw) async {
    final code = normalize(raw);
    if (code == null) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return;
    await prefs.setString(_key, code);
  }

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Called once the code has been sent with a successful registration.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
