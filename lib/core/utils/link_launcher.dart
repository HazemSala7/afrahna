import 'package:url_launcher/url_launcher.dart';

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
