import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:afrahna/features/auth/register_page.dart';
import 'cosmic_harness.dart';

const _taken = 'رقم الجوال هذا مسجّل مسبقًا. سجّل الدخول به أو استخدم رقمًا آخر.';

void main() {
  cosmicSetUp();

  // The server's complaint about a field is shown under that field, in
  // Arabic, with the cursor put there. Not in a banner, not in English.
  testWidgets('a taken phone is said under the phone field', (tester) async {
    serve({
      '/auth/register': {
        '__status': 422,
        'message': _taken,
        'errors': {
          'phone': [_taken],
        },
      },
    });
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(cosmicApp(const RegisterPage()));
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'حازم');
    await tester.enterText(fields.at(1), '0595324689');
    await tester.enterText(fields.at(4), 'secret1');
    await tester.enterText(fields.at(5), 'secret1');
    await tester.ensureVisible(find.text('إنشاء الحساب'));
    await tester.tap(find.text('إنشاء الحساب'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    // once, under the field
    expect(find.text(_taken), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // and the cursor is in that field
    expect(
      find.descendant(
        of: fields.at(1),
        matching: find.byWidgetPredicate(
          (w) => w is EditableText && w.focusNode.hasFocus,
        ),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 8));
  });
}
