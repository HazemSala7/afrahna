/// Keeps a future's failure from escaping before anyone is listening.
///
/// The home screen — and the splash, which prefetches for it — start a dozen
/// requests and store the futures, and a `FutureBuilder` only attaches to them
/// on the next frame. Dart treats a future whose error arrives with no
/// listener as an *unhandled* error and reports it to the zone, which on a
/// release build is a crash log and on a debug build a red flash. So a phone
/// with no signal, where every request fails in under a millisecond, produced:
///
///     Unhandled Exception: خطأ غير متوقع
///     #0  PostService.list (…/accounts_services.dart:554)
///     #0  VendorService.list (…/services.dart:326)
///
/// Nothing was actually wrong with the error handling — the builders show
/// their error state perfectly well once they are attached. The failure simply
/// arrived first.
///
/// [held] attaches a silent listener at the moment the future is created,
/// which marks the error as observed. The future is returned unchanged and
/// still completes with that error, so whoever awaits it later — a
/// `FutureBuilder`, an `await` — sees it exactly as before.
library;

Future<T> held<T>(Future<T> future) {
  // Deliberately empty: the point is the listener existing, not what it does.
  future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  return future;
}
