import 'package:flutter/material.dart';

import '../core/theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.emoji,
    this.onSeeAll,
  });
  final String title;
  final String? emoji;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    // RTL: first child = start = right. We want title on the RIGHT
    // (first thing read in Arabic) and "عرض الكل" action on the LEFT.
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
        if (emoji != null) ...[
          const SizedBox(width: 6),
          Text(emoji!, style: const TextStyle(fontSize: 17)),
        ],
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Row(
              children: const [
                Text(
                  'عرض الكل',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                Icon(Icons.chevron_left,
                    color: AppColors.primary, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}
