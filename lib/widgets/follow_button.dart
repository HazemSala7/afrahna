import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/accounts_services.dart';
import '../../core/state/session.dart';

/// Drop-in follow/unfollow button for a vendor profile.
/// Customer accounts can follow an advertiser to receive notifications
/// and a personalized post feed.
class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.vendorId,
    this.initiallyFollowing = false,
    this.onChanged,
  });

  final int vendorId;
  final bool initiallyFollowing;
  final ValueChanged<bool>? onChanged;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  late bool _following = widget.initiallyFollowing;
  bool _busy = false;
  final _service = FollowService();

  Future<void> _toggle() async {
    final session = context.read<SessionController>();
    if (!session.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول لمتابعة المعلِن')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _service.toggle(widget.vendorId);
      setState(() => _following = res.following);
      widget.onChanged?.call(res.following);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: _following ? Colors.grey[200] : null,
        foregroundColor: _following ? Colors.black87 : null,
      ),
      onPressed: _busy ? null : _toggle,
      icon: Icon(_following ? Icons.notifications_active : Icons.notifications_none),
      label: Text(_following ? 'تتم المتابعة' : 'متابعة'),
    );
  }
}
