import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/core/services/guest_invitations.dart';
import 'package:afrahna/core/services/invitation_service.dart';

/// Making a wedding invitation without an account.
///
/// Signed out there is no owner and no list endpoint, so two things have to
/// hold or the invitation is gone the moment the screen closes: it must be
/// created through the public route, and its code must be kept on the device.
class _RecordingAdapter implements HttpClientAdapter {
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    paths.add(options.path);

    final body = options.path.contains('/code/')
        ? {
            'invitation': {'id': 7, 'code': 'ABC12345', 'bride_name': 'لمار',
                'groom_name': 'عبدالرحمن', 'event_date': '2026-10-19T19:00:00Z'},
            'confirmed_count': 0,
          }
        : {'id': 7, 'code': 'ABC12345', 'bride_name': 'لمار',
            'groom_name': 'عبدالرحمن', 'event_date': '2026-10-19T19:00:00Z'};

    return ResponseBody.fromString(
      jsonEncode(body),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingAdapter adapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = _RecordingAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;
  });

  test('signed out, the invitation is created and its code kept', () async {
    final inv = await InvitationService().create(
      brideName: 'لمار',
      groomName: 'عبدالرحمن',
      eventDate: DateTime(2026, 10, 19, 19),
      asGuest: true,
    );

    expect(adapter.paths.single, '/invitations/public');
    expect(inv.code, 'ABC12345');
    // Without this the invitation exists on the server and nowhere else.
    expect(await GuestInvitations.all(), ['ABC12345']);
  });

  test('signed in, it goes to the owned route and nothing is kept locally',
      () async {
    await InvitationService().create(
      brideName: 'لمار',
      groomName: 'عبدالرحمن',
      eventDate: DateTime(2026, 10, 19, 19),
    );

    expect(adapter.paths.single, '/invitations');
    expect(await GuestInvitations.all(), isEmpty);
  });

  test('the guest list is read back by the codes on the device', () async {
    await GuestInvitations.add('ABC12345');

    final items = await InvitationService().listGuest();

    expect(adapter.paths.single, '/invitations/code/ABC12345');
    expect(items.single.code, 'ABC12345');
  });

  test('a code that no longer resolves is skipped, not fatal', () async {
    await GuestInvitations.add('ABC12345');
    ApiClient.instance.dio.httpClientAdapter = _FailingAdapter();

    expect(await InvitationService().listGuest(), isEmpty);
    // Kept: a network blip must not erase the only thread to an invitation.
    expect(await GuestInvitations.all(), ['ABC12345']);
  });
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
          Future<void>? cancelFuture) async =>
      throw DioException(requestOptions: options, message: 'offline');

  @override
  void close({bool force = false}) {}
}
