import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'festival.dart';

/// A section's title line.
///
/// A short bar of light — champagne through gold into lavender — marks where
/// the section begins; the title sits beside it in pearl with the faintest gold
/// glow; «عرض الكل» is a small glass capsule at the other end.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.emoji,
    this.onSeeAll,
    this.festive = false,
  });
  final String title;
  final String? emoji;
  final VoidCallback? onSeeAll;

  /// A constellation line under the title: for the home page, where every
  /// section is part of the festival.
  final bool festive;

  @override
  Widget build(BuildContext context) {
    final row = _row();
    if (!festive) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        const Padding(
          padding: EdgeInsetsDirectional.only(start: 14, top: 3),
          child: Starline(),
        ),
      ],
    );
  }

  Widget _row() {
    // RTL: first child = start = right. The title sits on the RIGHT (first
    // thing read in Arabic) and the "عرض الكل" action on the LEFT.
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.champagne,
                AppColors.primary,
                AppColors.holoLavender,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.6),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // The title takes all the room the capsule does not need, and only
        // truncates when there is genuinely none left.
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    letterSpacing: 0.2,
                    shadows: [
                      Shadow(
                        color: AppColors.accent.withValues(alpha: 0.28),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
              if (emoji != null) ...[
                const SizedBox(width: 6),
                Text(emoji!, style: const TextStyle(fontSize: 17)),
              ],
            ],
          ),
        ),
        if (onSeeAll != null) ...[
          const SizedBox(width: 8),
          _SeeAll(onTap: onSeeAll!),
        ],
      ],
    );
  }
}

class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        splashColor: AppColors.accent.withValues(alpha: 0.16),
        child: Container(
          padding: const EdgeInsetsDirectional.only(
              start: 12, end: 6, top: 5, bottom: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: AppColors.hairline),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'عرض الكل',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Icon(Icons.chevron_left, color: AppColors.accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
