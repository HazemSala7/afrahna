import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/core/models/models.dart';
import 'package:afrahna/core/state/session.dart';
import 'package:afrahna/features/account/edit_profile_page.dart';
import 'package:afrahna/widgets/image_upload_field.dart';
import 'package:afrahna/widgets/shell_bottom_nav.dart';

/// «تعديل الملف الشخصي»: the avatar must read as an avatar, and the screen
/// must not be a dead end.
class _Empty implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s,
          Future<void>? c) async =>
      ResponseBody.fromString('[]', 200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}

class _Signed extends SessionController {
  _Signed(this._u);
  final UserModel _u;

  @override
  bool get isSignedIn => true;

  @override
  UserModel? get user => _u;
}

void main() {
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/tahoma.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(font.readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
  });

  testWidgets('the profile picture is a whole circle, and there is a way out',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Empty();
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final session = _Signed(UserModel(
      id: 1,
      name: 'فؤاد - مسؤول المندوبين',
      phone: '0595679605',
    ));

    await tester.pumpWidget(ChangeNotifierProvider<SessionController>.value(
      value: session,
      child: const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: EditProfilePage(),
        ),
      ),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Round, and fitted whole rather than cropped to fill.
    final avatar = tester.widget<ImageUploadField>(
      find.byWidgetPredicate(
          (w) => w is ImageUploadField && w.label == 'صورة البروفايل'),
    );
    expect(avatar.circular, isTrue);

    // The screen used to end at the last text field.
    expect(find.byType(ShellBottomNav), findsOneWidget);

    await expectLater(
      find.byType(EditProfilePage),
      matchesGoldenFile('goldens/edit_profile.png'),
    );
  });
}
