/// Inviting a friend, in one tap.
///
/// It used to take several. The card showed a CODE, the copy button copied
/// that code, and the words asked the inviter to explain to their friend that
/// they must type it in during sign-up. Sharing meant opening the system sheet
/// and hunting for WhatsApp — which is where almost every one of these
/// invitations actually goes.
///
/// So: a link, shown, with WhatsApp as its own button. The friend taps the
/// link and the code travels with it; nobody types anything. The code is still
/// printed underneath for the one person who wants to read it out loud.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:provider/provider.dart';

import '../core/state/session.dart';
import '../core/theme.dart';
import '../core/utils/link_launcher.dart';
import '../features/auth/login_page.dart';

/// The page a friend lands on. Opens the app straight to sign-up when it is
/// installed, and otherwise sends them to the right store with the code
/// already on their clipboard.
String inviteLink(String code) => 'https://afrahna.co/r/$code';

/// One wording, everywhere. Two places used to say different things, and the
/// one on the home screen did not even carry the link.
String inviteMessage(String code) =>
    'انضم إلى تطبيق أفراحنا 🎉\n'
    'اضغط الرابط وسجّل، وبيوصلنا نقاط إحنا الاثنين:\n'
    '${inviteLink(code)}\n\n'
    'أو أدخل الكود عند التسجيل: $code';

/// Opens WhatsApp with the invitation already written.
Future<void> inviteOnWhatsApp(String code) async {
  final uri = Uri.parse(
    'https://wa.me/?text=${Uri.encodeComponent(inviteMessage(code))}',
  );
  await openExternal(uri);
}

/// Hands the invitation to the system share sheet.
Future<void> inviteViaShare(String code) =>
    Share.share(inviteMessage(code), subject: 'دعوة أفراحنا');

/// Copies the LINK — not the code. A code on the clipboard is of no use to
/// the friend who receives it; a link is the whole invitation.
Future<void> copyInviteLink(BuildContext context, String code) async {
  await Clipboard.setData(ClipboardData(text: inviteLink(code)));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      duration: Duration(seconds: 2),
      content: Text('تم نسخ رابط الدعوة'),
    ),
  );
}

/// The invitation as a sheet, for the places with no room to show it inline —
/// the home screen's top bar, where it is one small button.
///
/// A sheet rather than a page: inviting a friend is a thirty-second errand,
/// and sending someone to a new screen for it loses as many people as the
/// typing used to.
/// What every "invite a friend" button does.
///
/// A member with a share code gets the sheet. A member whose session has no
/// code yet — accounts made from the admin panel were created without one —
/// gets it fetched first: the server now mints the code on `/auth/me`. Only
/// a guest is sent to sign in; a signed-in member never is.
Future<void> openInvite(BuildContext context) async {
  final session = context.read<SessionController>();
  if (!session.isSignedIn) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    return;
  }
  var code = session.user?.referralCode ?? '';
  if (code.isEmpty) {
    await session.refreshUser();
    code = session.user?.referralCode ?? '';
  }
  if (!context.mounted) return;
  if (code.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'تعذّر جلب رابط الدعوة الآن. تأكد من الاتصال وحاول مجدداً.',
          ),
        ),
      );
    return;
  }
  await showInviteSheet(context, code);
}

Future<void> showInviteSheet(BuildContext context, String code) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'ادعُ أصدقاءك',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'ابعت الرابط — بيضغطوا عليه وبيسجّلوا، وبتوصلك نقاط.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          InviteActions(code: code),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// The link, and the three ways to send it.
///
/// WhatsApp is given its own button rather than being one icon inside the
/// system sheet: it is where these invitations go, and the sheet costs two
/// extra taps and a hunt through a grid of apps.
class InviteActions extends StatelessWidget {
  const InviteActions({super.key, required this.code, this.onDark = false});

  final String code;

  /// Set on a coloured panel, where the link box has to be glass rather than
  /// a tinted card and the type has to be white.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (code.isEmpty) return const SizedBox.shrink();

    final ink = onDark ? Colors.white : AppColors.textDark;
    final soft = onDark
        ? Colors.white.withValues(alpha: .75)
        : AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The link itself, visible. Tapping anywhere on it copies it.
        InkWell(
          onTap: () => copyInviteLink(context, code),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: onDark
                  ? Colors.white.withValues(alpha: .14)
                  : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: onDark
                    ? Colors.white.withValues(alpha: .28)
                    : AppColors.primary.withValues(alpha: .28),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    inviteLink(code),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.copy_rounded, size: 18, color: soft),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _Action(
                label: 'واتساب',
                icon: Icons.chat_rounded,
                // WhatsApp's own green, on purpose: people find this button by
                // its colour before they read it.
                background: const Color(0xFF25D366),
                foreground: Colors.white,
                onTap: () => inviteOnWhatsApp(code),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _Action(
                label: 'مشاركة',
                icon: Icons.ios_share_rounded,
                background: onDark
                    ? Colors.white.withValues(alpha: .16)
                    : AppColors.primaryLight,
                foreground: onDark ? Colors.white : AppColors.primaryDark,
                onTap: () => inviteViaShare(code),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'أو الكود: $code',
          textAlign: TextAlign.center,
          style: TextStyle(color: soft, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
