import 'package:url_launcher/url_launcher.dart';

/// Message pre-filled in WhatsApp when a user contacts a vendor from their
/// profile, so the vendor immediately knows where the enquiry came from.
const String kVendorWhatsappMessage =
    'رأيت إعلانك في تطبيق أفراحنا. هل يمكننا التواصل؟';

/// Builds a WhatsApp deep link for [raw] — either a phone number or an already
/// complete wa.me/api.whatsapp link — with [message] pre-filled in the chat.
///
/// Returns null when [raw] holds no usable number/link.
Uri? vendorWhatsappUri(String raw, {String message = kVendorWhatsappMessage}) {
  final v = raw.trim();
  if (v.isEmpty) return null;

  // Already a full link: keep it, just add/override the prefilled text.
  if (v.startsWith('http://') || v.startsWith('https://')) {
    final parsed = Uri.tryParse(v);
    if (parsed == null) return null;
    return parsed.replace(
      queryParameters: {...parsed.queryParameters, 'text': message},
    );
  }

  final digits = v.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  return Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
}

/// Opens [uri] outside the app and reports whether it worked.
///
/// Deliberately does NOT gate on `canLaunchUrl()`. On Android 11+ that call
/// returns false unless every target scheme is declared under `<queries>` in
/// AndroidManifest.xml — which silently turned every link tap into a no-op.
/// Trying the launch directly (with a platform-default fallback) is both more
/// reliable and lets callers surface a real error instead of doing nothing.
Future<bool> openExternal(Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
  } catch (_) {
    // fall through to the platform default below
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}
