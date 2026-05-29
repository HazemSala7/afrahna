import 'package:flutter/material.dart';

import '../../core/services/accounts_services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import 'new_client_page.dart';
import 'my_clients_page.dart';
import 'my_commissions_page.dart';
import 'package:provider/provider.dart';

/// Landing screen for users whose role is `delegate`.
/// Provides quick access to: register a new client, list own clients,
/// and view commission totals.
class DelegateDashboardPage extends StatelessWidget {
  const DelegateDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة المندوب')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user.name),
                subtitle: Text('هاتف: ${user.phone}'),
                trailing: const Chip(label: Text('مندوب')),
              ),
            ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.person_add_alt_1,
            color: AppColors.primary,
            title: 'تسجيل عميل جديد',
            subtitle: 'إنشاء حساب عميل واشتراك جديد',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NewClientPage())),
          ),
          _ActionTile(
            icon: Icons.people_alt,
            color: Colors.teal,
            title: 'عملائي',
            subtitle: 'الحسابات التي سجّلتها',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyClientsPage())),
          ),
          _ActionTile(
            icon: Icons.payments,
            color: Colors.orange,
            title: 'العمولات والاشتراكات',
            subtitle: 'مجموع العمولات المستحقة والمدفوعة',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyCommissionsPage())),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
      ),
    );
  }
}
