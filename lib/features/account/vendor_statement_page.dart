import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/shell_bottom_nav.dart';

/// Account statement (كشف حساب) for a vendor: their subscriptions, payments
/// made, and outstanding balances.
class VendorStatementPage extends StatefulWidget {
  const VendorStatementPage({super.key});

  @override
  State<VendorStatementPage> createState() => _VendorStatementPageState();
}

class _VendorStatementPageState extends State<VendorStatementPage> {
  final _service = SubscriptionService();
  late Future<List<SubscriptionModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.list(perPage: 100);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.list(perPage: 100);
    });
    await _future;
  }

  static String _money(double v) {
    final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '${parts.length > 1 ? '$intPart.${parts[1]}' : intPart} ₪';
  }

  static const _planLabels = {
    'normal': 'عادي',
    'standard': 'عادي',
    'featured': 'مميّز',
    'vip': 'VIP',
  };

  static String _date(DateTime? d) => d == null
      ? '—'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const ShellBottomNav(),
      backgroundColor: const Color(0xFFFCF8F3),
      appBar: PinkAppBar(title: 'كشف حساب'),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: FutureBuilder<List<SubscriptionModel>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const CenteredLoader();
              }
              if (snap.hasError) {
                return ErrorState(message: snap.error.toString(), onRetry: _refresh);
              }
              final subs = snap.data ?? const <SubscriptionModel>[];
              if (subs.isEmpty) {
                return ListView(children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    message: 'لا توجد اشتراكات بعد',
                    icon: Icons.receipt_long_outlined,
                  ),
                ]);
              }

              final total = subs.fold<double>(0, (s, x) => s + x.totalAmount);
              final paid = subs.fold<double>(0, (s, x) => s + x.amountPaid);
              final remaining = subs.fold<double>(0, (s, x) => s + x.remaining);

              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  _SummaryCard(total: total, paid: paid, remaining: remaining),
                  const SizedBox(height: 16),
                  const Text('الاشتراكات',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  ...subs.map(_subCard),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _subCard(SubscriptionModel s) {
    final plan = _planLabels[s.planName] ?? s.planName;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x11000000)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('باقة $plan',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.primaryDark)),
              ),
              const Spacer(),
              _statusChip(s),
            ],
          ),
          const SizedBox(height: 8),
          Text('${_date(s.startDate)} → ${_date(s.endDate)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniStat('السعر', _money(s.totalAmount), AppColors.textDark),
              _miniStat('المدفوع', _money(s.amountPaid), const Color(0xFF2E7D5B)),
              _miniStat('المتبقّي', _money(s.remaining),
                  s.remaining > 0 ? const Color(0xFFC1452B) : const Color(0xFF2E7D5B)),
            ],
          ),
          if (s.payments.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('الدفعات:',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: AppColors.textDark)),
            const SizedBox(height: 6),
            ...s.payments.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 15, color: Color(0xFF2E7D5B)),
                      const SizedBox(width: 6),
                      Text(_money(p.amount),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              fontSize: 12.5)),
                      const Spacer(),
                      Text(_date(p.paidAt),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11.5)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 13.5, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statusChip(SubscriptionModel s) {
    final (label, color) = switch (s.status) {
      'active' => ('فعّال', const Color(0xFF2E7D5B)),
      'expired' => ('منتهٍ', const Color(0xFFC1452B)),
      'cancelled' => ('ملغى', AppColors.textMuted),
      'pending' => ('معلّق', const Color(0xFFB8835A)),
      _ => (s.status, AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.total, required this.paid, required this.remaining});
  final double total;
  final double paid;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _cell('إجمالي الاشتراكات', total),
          _divider(),
          _cell('إجمالي المدفوع', paid),
          _divider(),
          _cell('إجمالي المتبقّي', remaining),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 40, color: Colors.white.withValues(alpha: 0.25));

  Widget _cell(String label, double v) {
    return Expanded(
      child: Column(
        children: [
          Text(_VendorStatementPageState._money(v),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
