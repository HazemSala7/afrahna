import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../auth/login_page.dart';

class BookingCreatePage extends StatefulWidget {
  const BookingCreatePage({super.key, required this.vendor, this.service});

  final VendorModel vendor;
  final ServiceModel? service;

  @override
  State<BookingCreatePage> createState() => _BookingCreatePageState();
}

class _BookingCreatePageState extends State<BookingCreatePage> {
  Future<List<ServiceModel>>? _servicesFuture;
  ServiceModel? _selected;
  DateTime? _date;
  final _notes = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.service;
    if (_selected == null) {
      _servicesFuture =
          ServiceService().list(vendorId: widget.vendor.id);
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final session = context.read<SessionController>();
    if (!session.isSignedIn) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (result != true && !session.isSignedIn) return;
    }
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اختر الخدمة أولاً'),
      ));
      return;
    }
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اختر تاريخ المناسبة'),
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      await BookingService().create(
        serviceId: _selected!.id,
        vendorId: widget.vendor.id,
        eventDate: _date!,
        notes: _notes.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: AppColors.primary,
        content: Text('تم إرسال الحجز بنجاح'),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const PinkAppBar(title: 'حجز جديد'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: AppNetworkImage(
                        url: widget.vendor.logo,
                        fallbackIcon: Icons.storefront,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.vendor.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                        if (widget.vendor.category != null)
                          Text(widget.vendor.category!.name,
                              style: const TextStyle(
                                  color: AppColors.primary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('الخدمة',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (_servicesFuture == null)
              _SelectedServiceCard(service: _selected!)
            else
              FutureBuilder<List<ServiceModel>>(
                future: _servicesFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const CenteredLoader();
                  }
                  final list = snap.data ?? const <ServiceModel>[];
                  if (list.isEmpty) {
                    return const Text('لا توجد خدمات متاحة',
                        style: TextStyle(color: AppColors.textMuted));
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ServiceModel>(
                        isExpanded: true,
                        value: _selected,
                        hint: const Text('اختر خدمة'),
                        items: [
                          for (final s in list)
                            DropdownMenuItem(
                              value: s,
                              child: Text(
                                '${s.title}${s.price != null ? '  •  ${s.price!.toStringAsFixed(0)} ₪' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _selected = v),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 18),
            const Text('تاريخ المناسبة',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      _date == null
                          ? 'اختر التاريخ'
                          : DateFormat('EEEE، d MMMM y', 'ar')
                              .format(_date!),
                      style: TextStyle(
                        color: _date == null
                            ? AppColors.textMuted
                            : AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('ملاحظات (اختياري)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'أضف أي تفاصيل تريد إخبار المزوّد بها...',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('تأكيد الحجز'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedServiceCard extends StatelessWidget {
  const _SelectedServiceCard({required this.service});
  final ServiceModel service;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.design_services, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(service.title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (service.price != null)
            Text('${service.price!.toStringAsFixed(0)} ₪',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
