import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'admin_subscriptions_page.dart';
import 'admin_users_page.dart';
import 'admin_vendors_page.dart';

/// Admin control center — reachable from the account page when the signed-in
/// user has the `admin` role. Gives full management over advertisers,
/// delegates, customers and subscriptions.
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة الإدارة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminTile(
            icon: Icons.storefront,
            color: const Color(0xFF7B61FF),
            title: 'المعلنون',
            subtitle: 'تعديل بيانات المحلات وتفعيل/إيقاف الحسابات',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminVendorsPage()),
            ),
          ),
          _AdminTile(
            icon: Icons.badge,
            color: const Color(0xFF00A3A3),
            title: 'المندوبون',
            subtitle: 'الصلاحيات والعمولة وتفعيل/إيقاف الحسابات',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminUsersPage(
                  role: 'delegate',
                  title: 'المندوبون',
                ),
              ),
            ),
          ),
          _AdminTile(
            icon: Icons.people_alt,
            color: const Color(0xFFEA8C00),
            title: 'العملاء',
            subtitle: 'إدارة حسابات الزبائن',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminUsersPage(
                  role: 'customer',
                  title: 'العملاء',
                ),
              ),
            ),
          ),
          _AdminTile(
            icon: Icons.card_membership,
            color: const Color(0xFFD81B60),
            title: 'الاشتراكات',
            subtitle: 'تعديل وتمديد الاشتراكات وتعليم العمولة كمدفوعة',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminSubscriptionsPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
