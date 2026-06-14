import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/services/accounts_services.dart';

class MyCommissionsPage extends StatefulWidget {
  const MyCommissionsPage({super.key});

  @override
  State<MyCommissionsPage> createState() => _MyCommissionsPageState();
}

class _MyCommissionsPageState extends State<MyCommissionsPage> {
  final _service = DelegateService();
  late Future<CommissionsResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.myCommissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عمولاتي'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _future = _service.myCommissions()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<CommissionsResponse>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final e = snap.error;
            return Center(child: Text(e is ApiException ? e.message : e.toString()));
          }
          final data = snap.data!;
          final t = data.totals;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _StatCard(label: 'إجمالي المحصّل', value: t.totalCollected, color: Colors.blue),
                  _StatCard(label: 'إجمالي العمولات', value: t.totalCommission, color: Colors.deepPurple),
                  _StatCard(label: 'مدفوعة لك', value: t.paidCommission, color: Colors.green),
                  _StatCard(label: 'مستحقة بعد', value: t.unpaidCommission, color: Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              Text('عدد الاشتراكات: ${t.count}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Divider(height: 24),
              ...data.subscriptions.map((s) => Card(
                    child: ListTile(
                      title: Text(s.clientName),
                      subtitle: Text(
                        'باقة: ${s.planName} • '
                        'مدفوع: ${s.amountPaid} • '
                        'عمولة: ${s.commissionAmount} '
                        '${s.commissionPaid ? "(مدفوعة)" : "(معلّقة)"}',
                      ),
                      trailing: _statusChip(s.status),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _statusChip(String s) {
    Color c;
    String label;
    switch (s) {
      case 'active':    c = Colors.green;   label = 'فعّال';   break;
      case 'expired':   c = Colors.grey;    label = 'منتهي';   break;
      case 'cancelled': c = Colors.red;     label = 'ملغى';    break;
      default:          c = Colors.orange;  label = 'قيد الانتظار';
    }
    return Chip(label: Text(label), backgroundColor: c.withOpacity(0.15));
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
