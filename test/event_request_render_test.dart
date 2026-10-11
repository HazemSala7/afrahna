import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrahna/core/api/api_client.dart';
import 'package:afrahna/core/arabic_counts.dart';
import 'package:afrahna/features/event_request/event_request_home_card.dart';
import 'package:afrahna/features/event_request/event_request_models.dart';
import 'package:afrahna/features/event_request/event_request_page.dart';
import 'package:afrahna/features/event_request/event_request_status_page.dart';
import 'package:afrahna/features/event_request/event_request_storage.dart';
import 'package:afrahna/core/theme.dart';

import 'cosmic_harness.dart';

/// «نظّم مناسبتك» — the brief that replaced the old "أعلن معنا" card.
///
/// The screen is mostly selection state, and selection state is exactly what
/// reads wrong without being looked at: a chip that does not change when tapped,
/// a percentage that says 0% when three lines are done. So these render it.

/// Returns a small city list for /cities and an empty list for anything else,
/// so the city picker has something real in it.
class _Api implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final body = o.path.contains('/cities')
        ? jsonEncode([
            {'id': 8, 'name_ar': 'الخليل', 'name_en': 'Hebron'},
            {'id': 9, 'name_ar': 'نابلس', 'name_en': 'Nablus'},
            {'id': 10, 'name_ar': 'بيت لحم', 'name_en': 'Bethlehem'},
          ])
        : '[]';
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.cosmic(),
      builder: cosmicBuilder,
      locale: const Locale('ar'),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

EventRequest _sample() => EventRequest(
      kind: EventKind.wedding,
      level: BudgetLevel.high,
      cityId: 8,
      cityName: 'الخليل',
      date: DateTime(2027, 6, 12),
      guests: GuestRange.upTo400,
      fullName: 'حازم صلاح',
      phone: '0599252493',
      address: 'الخليل - عين سارة',
      contactTime: ContactTime.evening,
      createdAt: DateTime(2026, 9, 5, 2, 30),
    );

void main() {
  setUpAll(preloadCosmic);
  // The status screen counts the days left until the event, so without a fixed
  // "today" these goldens drift by one digit every midnight.
  setUp(() => debugEventRequestToday = DateTime(2026, 10, 6));
  tearDown(() => debugEventRequestToday = null);
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/tahoma.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(font.readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
    // Without the icon font every Icon renders as an empty box, which hides
    // exactly what these goldens exist to check: whether the right glyph sits
    // on the right chip. Skipped silently if the SDK moves.
    final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
    if (emoji.existsSync()) {
      final loader = FontLoader('Segoe UI Emoji')
        ..addFont(Future.value(emoji.readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
    final icons = File(
        'C:/Users/User/Downloads/flutter_windows_3.41.7-stable/flutter/bin/'
        'cache/artifacts/material_fonts/materialicons-regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(icons.readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = _Api();
  });

  testWidgets('the brief shows all six numbered steps', (tester) async {
    await EventRequestStorage.instance.clear();
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const EventRequestPage()));
    await _settle(tester);

    // Every question the team would otherwise have to ask by hand.
    expect(find.text('اختر نوع المناسبة'), findsOneWidget);
    expect(find.text('تحديد المستوى'), findsOneWidget);
    expect(find.text('تحديد المدينة'), findsOneWidget);
    expect(find.text('تحديد تاريخ المناسبة'), findsOneWidget);
    expect(find.text('تحديد عدد المدعوين'), findsOneWidget);
    expect(find.text('بيانات التواصل'), findsOneWidget);

    // Nothing answered yet.
    expect(find.text('0 من 6'), findsOneWidget);

    await expectLater(
      find.byType(EventRequestPage),
      matchesGoldenFile('goldens/event_request_form.png'),
    );
  });

  testWidgets('choosing an option marks it and moves the counter',
      (tester) async {
    await EventRequestStorage.instance.clear();
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const EventRequestPage()));
    await _settle(tester);

    await tester.tap(find.text('زفاف'));
    await _settle(tester);
    expect(find.text('1 من 6'), findsOneWidget);

    await tester.tap(find.text('مرتفعة'));
    await _settle(tester);
    expect(find.text('2 من 6'), findsOneWidget);

    await expectLater(
      find.byType(EventRequestPage),
      matchesGoldenFile('goldens/event_request_form_selected.png'),
    );
  });

  testWidgets('submitting nothing does not silently do nothing',
      (tester) async {
    await EventRequestStorage.instance.clear();
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const EventRequestPage()));
    await _settle(tester);

    await tester.tap(find.text('تقديم الطلب'));
    await _settle(tester);

    // The empty required choices now say so, rather than the button appearing
    // broken.
    expect(find.text('لازم تختار نوع المناسبة'), findsOneWidget);
    expect(await EventRequestStorage.instance.load(), isNull);
  });

  testWidgets('the status screen shows the review banner and the map',
      (tester) async {
    await EventRequestStorage.instance.save(_sample());
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const EventRequestStatusPage()));
    await _settle(tester);

    expect(find.text('جاري متابعة طلبك'), findsOneWidget);
    expect(find.text('تقدّم إنجاز طلبك'), findsOneWidget);
    expect(find.text('قاعة الأفراح'), findsOneWidget);

    await expectLater(
      find.byType(EventRequestStatusPage),
      matchesGoldenFile('goldens/event_request_status.png'),
    );
  });

  testWidgets('progress counts a half for work in hand', (tester) async {
    final r = _sample();
    // Two finished, one under way, out of ten: 2.5/10.
    r.steps[0].status = StepStatus.done;
    r.steps[0].vendorName = 'قاعة الأصالة';
    r.steps[1].status = StepStatus.done;
    r.steps[1].vendorName = 'أزهار فرح';
    r.steps[2].status = StepStatus.inProgress;
    r.steps[2].vendorName = 'استوديو لمسة';
    r.stage = RequestStage.accepted;
    expect(r.progress, 25);

    await EventRequestStorage.instance.save(r);
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const EventRequestStatusPage()));
    await _settle(tester);

    // Accepted, so the review banner is gone and the map leads.
    expect(find.text('جاري متابعة طلبك'), findsNothing);
    expect(find.text('استوديو لمسة · قيد المتابعة'), findsOneWidget);

    // Ten services takes the plural in Arabic, not the singular: «10 خدمات».
    expect(find.text('خلصت 2 من 10 خدمات'), findsOneWidget);

    await expectLater(
      find.byType(EventRequestStatusPage),
      matchesGoldenFile('goldens/event_request_progress.png'),
    );
  });

  testWidgets('the home card invites, then tracks once a request exists',
      (tester) async {
    await EventRequestStorage.instance.clear();
    tester.view.physicalSize = const Size(1080, 700);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // A distinct key per pump: without one the element is reused, initState
    // never runs again, and the card would still be showing the first state.
    Future<void> pumpCard(String key) async {
      await tester.pumpWidget(_wrap(Scaffold(
        backgroundColor: Colors.transparent,
        // A ListView child, as on the home page: vertical space unbounded.
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [EventRequestHomeCard(key: ValueKey(key))],
        ),
      )));
      await _settle(tester);
    }

    await pumpCard('empty');
    expect(find.text('نظّم مناسبتك معنا 🎉'), findsOneWidget);
    expect(find.text('ابدأ'), findsOneWidget);
    await expectLater(
      find.byType(EventRequestHomeCard),
      matchesGoldenFile('goldens/event_request_home_card.png'),
    );

    // Once a request exists the same card becomes the way back into it, so the
    // home page carries the customer's own progress.
    final r = _sample();
    r.steps[0].status = StepStatus.done;
    r.steps[1].status = StepStatus.inProgress;
    await EventRequestStorage.instance.save(r);

    await pumpCard('tracking');
    expect(find.text('طلب زفاف — 15%'), findsOneWidget);
    expect(find.text('تابع'), findsOneWidget);
    await expectLater(
      find.byType(EventRequestHomeCard),
      matchesGoldenFile('goldens/event_request_home_card_tracking.png'),
    );
  });

  test('counted nouns follow the Arabic rule, not an English one', () {
    // 1 / 2 / 3-10 / 11+ are four different forms.
    expect(arabicServices(1), 'خدمة واحدة');
    expect(arabicServices(2), 'خدمتان');
    expect(arabicServices(10), '10 خدمات');
    expect(arabicServices(15), '15 خدمة');
  });

  test('a saved request survives a round trip through storage', () {
    final r = _sample();
    r.steps[0].status = StepStatus.done;
    r.steps[0].vendorName = 'قاعة الأصالة';

    final back = EventRequest.decode(r.encode())!;
    expect(back.kind, EventKind.wedding);
    expect(back.level, BudgetLevel.high);
    expect(back.cityName, 'الخليل');
    expect(back.guests, GuestRange.upTo400);
    expect(back.steps[0].status, StepStatus.done);
    expect(back.steps[0].vendorName, 'قاعة الأصالة');
    expect(back.reference, r.reference);
  });
}
