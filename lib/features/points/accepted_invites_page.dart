import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../core/utils/held_future.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/invite_friends.dart';

/// «مين انضم من دعوتي» — the list behind the friend count on the points card.
///
/// The count alone ("٣ صديق") is a number with nothing behind it; a member who
/// sent twenty invitations cannot tell which three landed. Names and dates
/// make the count checkable, and seeing a friend's name next to the day they
/// joined is most of the reward.
///
/// No phone numbers: the server does not send them. See
/// `PointController::invitees`.
class AcceptedInvitesPage extends StatefulWidget {
  const AcceptedInvitesPage({super.key, required this.code});

  /// The member's own invite code, so the empty state can invite from here
  /// rather than sending them back a screen to do it.
  final String code;

  @override
  State<AcceptedInvitesPage> createState() => _AcceptedInvitesPageState();
}

class _AcceptedInvitesPageState extends State<AcceptedInvitesPage> {
  late Future<List<Invitee>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = held(PointsService().invitees());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PinkAppBar(title: 'أصدقاء انضموا'),
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<Invitee>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _Message(
                icon: Icons.wifi_off_rounded,
                title: 'تعذّر تحميل القائمة',
                body: 'تأكد من اتصالك وحاول مرة ثانية.',
                action: FilledButton(
                  onPressed: () => setState(_load),
                  child: const Text('إعادة المحاولة'),
                ),
              );
            }

            final rows = snap.data ?? const <Invitee>[];
            if (rows.isEmpty) {
              return _Message(
                icon: Icons.group_add_rounded,
                title: 'ما حدا انضم بعد',
                body:
                    'ابعت رابط الدعوة لأصحابك — أول ما يسجّل حدا منهم '
                    'بتلاقي اسمه هون.',
                action: widget.code.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: InviteActions(code: widget.code),
                      ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: rows.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      rows.length == 1
                          ? 'صديق واحد انضم من دعوتك'
                          : '${rows.length} أصدقاء انضموا من دعوتك',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                return StaggerIn(
                  index: i - 1,
                  id: 'invitees',
                  child: _Row(invitee: rows[i - 1]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.invitee});

  final Invitee invitee;

  @override
  Widget build(BuildContext context) {
    final joined = invitee.joinedAt;
    final initial = invitee.name.trim().isEmpty
        ? '؟'
        : invitee.name.trim().characters.first;

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(26)),
        boxShadow: AppDecor.lift,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitee.name.isEmpty ? 'عضو جديد' : invitee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (joined != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'انضم ${DateFormat('d MMMM y', 'ar').format(joined)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.verified_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The empty and the error state, which differ only in what they say and
/// what they offer to do about it.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 90, 26, 40),
      children: [
        Icon(icon, size: 56, color: AppColors.primary.withValues(alpha: .45)),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13.5,
            height: 1.6,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    );
  }
}
