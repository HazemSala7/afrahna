import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Static definition of the 3 subscription tiers (prices + features) shown both
/// as a selectable picker (delegate/admin) and a read-only view (vendor).
class PlanInfo {
  const PlanInfo({
    required this.key,
    required this.name,
    required this.color,
    required this.icon,
    this.monthly,
    required this.yearly,
    required this.features,
  });

  final String key; // normal | featured | vip
  final String name; // عادي | مميز | VIP
  final Color color;
  final IconData icon;
  final int? monthly; // null = no monthly option
  final int yearly;
  final List<String> features;
}

const List<PlanInfo> kSubscriptionPlans = [
  PlanInfo(
    key: 'normal',
    name: 'عادي',
    color: Color(0xFF4FB39C),
    icon: Icons.workspace_premium_outlined,
    monthly: 50,
    yearly: 200,
    features: [
      'شهر مجاني عند أول اشتراك',
      'ريلز + ستوريز + منشورات',
      'إظهار العروض على الصفحة الرئيسية',
      'وصول إشعارات إلى المتابعين',
    ],
  ),
  PlanInfo(
    key: 'featured',
    name: 'مميز',
    color: Color(0xFFE0A43B),
    icon: Icons.star_rounded,
    yearly: 400,
    features: [
      'شهر مجاني عند أول اشتراك',
      'ريلز + ستوريز + منشورات',
      'يظهر ضمن قائمة الشركات المميّزة',
      'إظهار العروض على الصفحة الرئيسية',
      'وصول إشعارات إلى المتابعين',
    ],
  ),
  PlanInfo(
    key: 'vip',
    name: 'VIP',
    color: Color(0xFFE0566B),
    icon: Icons.diamond_rounded,
    yearly: 600,
    features: [
      'شهر مجاني عند أول اشتراك',
      'ريلز + ستوريز + منشورات',
      'يظهر في الصفحة الرئيسية (عرض الشرائح)',
      'يظهر ضمن قائمة الشركات المميّزة',
      'إظهار علامة التوثيق',
      'إظهار العروض على الصفحة الرئيسية',
      'وصول إشعارات إلى كافة المستخدمين',
    ],
  ),
];

PlanInfo planByKey(String? key) =>
    kSubscriptionPlans.firstWhere((p) => p.key == key,
        orElse: () => kSubscriptionPlans.first);

/// Vertical list of subscription cards. When [onSelected] is provided the cards
/// are tappable (picker mode) and [selected] is highlighted; otherwise it is a
/// read-only showcase.
class SubscriptionPlansView extends StatelessWidget {
  const SubscriptionPlansView({
    super.key,
    this.selected,
    this.onSelected,
    this.shrinkWrap = true,
    this.physics,
    this.compact = false,
  });

  final String? selected;
  final ValueChanged<String>? onSelected;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  /// Smaller, denser cards (used inside forms/sheets).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: physics ?? (shrinkWrap ? const NeverScrollableScrollPhysics() : null),
      padding: EdgeInsets.zero,
      itemCount: kSubscriptionPlans.length,
      separatorBuilder: (_, _) => SizedBox(height: compact ? 10 : 14),
      itemBuilder: (_, i) => _PlanCard(
        plan: kSubscriptionPlans[i],
        selected: selected == kSubscriptionPlans[i].key,
        compact: compact,
        onTap: onSelected == null
            ? null
            : () => onSelected!(kSubscriptionPlans[i].key),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    this.onTap,
    this.compact = false,
  });
  final PlanInfo plan;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final nameSize = compact ? 15.0 : 18.0;
    final iconSize = compact ? 18.0 : 22.0;
    final featSize = compact ? 11.0 : 12.5;
    final featGap = compact ? 3.0 : 6.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 16 : 20),
          border: Border.all(
            color: selected ? plan.color : plan.color.withValues(alpha: 0.25),
            width: selected ? 2.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: plan.color.withValues(alpha: selected ? 0.30 : 0.12),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  vertical: compact ? 8 : 12, horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [plan.color, plan.color.withValues(alpha: 0.82)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Row(
                children: [
                  Icon(plan.icon, color: Colors.white, size: iconSize),
                  const SizedBox(width: 8),
                  Text(
                    plan.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: nameSize,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      color: Colors.white,
                      size: compact ? 20 : 22,
                    ),
                ],
              ),
            ),
            // Prices
            Padding(
              padding: EdgeInsets.fromLTRB(14, compact ? 8 : 12, 14, compact ? 4 : 8),
              child: Row(
                children: [
                  _PricePill(
                    label: 'سنة',
                    value: plan.yearly,
                    color: plan.color,
                    big: !compact,
                  ),
                  if (plan.monthly != null) ...[
                    const SizedBox(width: 10),
                    _PricePill(
                      label: 'شهر',
                      value: plan.monthly!,
                      color: plan.color,
                    ),
                  ],
                ],
              ),
            ),
            // Features
            Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, compact ? 10 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final f in plan.features)
                    Padding(
                      padding: EdgeInsets.only(top: featGap),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle,
                              color: plan.color, size: compact ? 13 : 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: featSize,
                                color: AppColors.textDark,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({
    required this.label,
    required this.value,
    required this.color,
    this.big = false,
  });
  final String label;
  final int value;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: big ? 22 : 16,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('شيكل',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textMuted, height: 1)),
              Text('/$label',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      height: 1.3)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Read-only full page showing the 3 plans (optionally highlighting the
/// vendor's current plan). Used from the vendor account.
class SubscriptionPlansPage extends StatelessWidget {
  const SubscriptionPlansPage({super.key, this.currentPlan});
  final String? currentPlan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أسعار الاشتراكات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (currentPlan != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded,
                      color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Text(
                    'اشتراكك الحالي: ${planByKey(currentPlan).name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark),
                  ),
                ],
              ),
            ),
          SubscriptionPlansView(selected: currentPlan),
          const SizedBox(height: 12),
          const Text(
            'للاشتراك أو الترقية، تواصل مع مندوبك أو إدارة أفراحنا.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
