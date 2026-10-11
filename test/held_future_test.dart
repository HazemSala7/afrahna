import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:afrahna/core/utils/held_future.dart';

/// The home screen starts its requests and stores the futures; a FutureBuilder
/// only attaches on the next frame. On a phone with no signal every request
/// fails before that, and Dart reports a future that fails with nobody
/// listening as an unhandled error — which is what reached the crash log as
/// `Unhandled Exception: خطأ غير متوقع` out of `PostService.list`.
void main() {
  test('a failure with nobody listening yet escapes to the zone', () async {
    Object? escaped;
    await runZonedGuarded(
      () async {
        // Exactly the shape the home page had: create, store, look later.
        final stored = Future<int>.error(StateError('no signal'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await stored.catchError((Object _) => 0);
      },
      (e, _) => escaped = e,
    );

    expect(escaped, isA<StateError>(),
        reason: 'this is the bug the crash log showed');
  });

  test('held() keeps it in, and still hands it to whoever asks', () async {
    Object? escaped;
    Object? caught;

    await runZonedGuarded(
      () async {
        final stored = held(Future<int>.error(StateError('no signal')));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        try {
          await stored;
        } catch (e) {
          caught = e;
        }
      },
      (e, _) => escaped = e,
    );

    expect(escaped, isNull, reason: 'nothing should reach the zone');
    expect(caught, isA<StateError>(),
        reason: 'the consumer must still see the failure and show its error '
            'state — swallowing it would be worse than the crash');
  });

  test('held() leaves a successful future alone', () async {
    expect(await held(Future<int>.value(7)), 7);
  });
}
