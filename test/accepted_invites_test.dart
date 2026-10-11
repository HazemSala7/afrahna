import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afrahna/features/points/accepted_invites_page.dart';

import 'cosmic_harness.dart';

/// «أصدقاء انضموا» — the list behind the friend count on the points card.
///
/// Two states worth a picture: the list with friends in it, and the state a
/// member sees before anyone has joined, which has to offer the invitation
/// rather than simply say there is nothing here.
void main() {
  cosmicSetUp();
  setUpAll(preloadCosmic);

  testWidgets('the friends who joined', (tester) async {
    serve(const {
      '/points/invitees': {
        'data': [
          {'id': 9, 'name': 'رنا قاسم', 'joined_at': '2026-09-28T10:00:00Z'},
          {'id': 8, 'name': 'سامي خليل', 'joined_at': '2026-09-14T10:00:00Z'},
          {'id': 7, 'name': 'لمى عبد', 'joined_at': '2026-08-30T10:00:00Z'},
        ],
      },
    });
    await shoot(
      tester,
      cosmicApp(const AcceptedInvitesPage(code: 'HZM4K9')),
      'accepted_invites',
      size: const Size(1080, 1800),
    );
  });

  testWidgets('before anyone has joined, it invites', (tester) async {
    serve(const {
      '/points/invitees': {'data': []},
    });
    await shoot(
      tester,
      cosmicApp(const AcceptedInvitesPage(code: 'HZM4K9')),
      'accepted_invites_empty',
      size: const Size(1080, 1800),
    );
  });
}
