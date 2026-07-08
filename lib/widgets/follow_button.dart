import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/accounts_services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';

/// Drop-in follow/unfollow button for a vendor profile.
/// Customer accounts can follow an advertiser to receive notifications
/// and a personalized post feed.
///
/// Set [compact] for a small Facebook/Twitter-style pill that fits inside a
/// top action bar (doesn't take a full row).
class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.vendorId,
    this.initiallyFollowing = false,
    this.followersCount = 0,
    this.onChanged,
    this.onFollowersChanged,
    this.compact = false,
  });

  final int vendorId;
  final bool initiallyFollowing;
  final int followersCount;
  final ValueChanged<bool>? onChanged;

  /// Called with the up-to-date follower count so the surrounding UI (e.g. a
  /// stats strip) can reflect the change immediately.
  final ValueChanged<int>? onFollowersChanged;
  final bool compact;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  late bool _following = widget.initiallyFollowing;
  late int _followers = widget.followersCount;
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
    // Optimistic update: bump the count and flip the state immediately so the
    // UI reacts the instant the user taps, then reconcile with the server.
    final willFollow = !_following;
    setState(() {
      _busy = true;
      _following = willFollow;
      _followers = (_followers + (willFollow ? 1 : -1)).clamp(0, 1 << 31);
    });
    widget.onChanged?.call(willFollow);
    widget.onFollowersChanged?.call(_followers);
    try {
      final res = await _service.toggle(widget.vendorId);
      if (!mounted) return;
      setState(() {
        _following = res.following;
        _followers = res.followers;
      });
      widget.onChanged?.call(res.following);
      widget.onFollowersChanged?.call(res.followers);
    } catch (e) {
      if (!mounted) return;
      // Revert the optimistic change on failure.
      setState(() {
        _following = !willFollow;
        _followers = (_followers + (willFollow ? -1 : 1)).clamp(0, 1 << 31);
      });
      widget.onChanged?.call(_following);
      widget.onFollowersChanged?.call(_followers);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildCompact();
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: _following ? Colors.grey[200] : null,
        foregroundColor: _following ? Colors.black87 : null,
      ),
      onPressed: _busy ? null : _toggle,
      icon: Icon(_following ? Icons.notifications_active : Icons.notifications_none),
      label: Text(
        _followers > 0
            ? (_following ? 'تتم المتابعة · $_followers' : 'متابعة · $_followers')
            : (_following ? 'تتم المتابعة' : 'متابعة'),
      ),
    );
  }

  /// Compact Facebook/Twitter-style pill: filled when not following,
  /// outlined/subtle when already following. Sits inline in a top bar.
  Widget _buildCompact() {
    final following = _following;
    final bg = following ? Colors.white.withValues(alpha: 0.9) : AppColors.primary;
    final fg = following ? AppColors.primaryDark : Colors.white;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _busy ? null : _toggle,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: following
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Icon(
                  following ? Icons.check_rounded : Icons.add_rounded,
                  size: 17,
                  color: fg,
                ),
              const SizedBox(width: 4),
              Text(
                following ? 'متابَع' : 'متابعة',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
