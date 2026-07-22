import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../bookings/booking_create_page.dart';

class ServiceDetailsPage extends StatefulWidget {
  const ServiceDetailsPage({
    super.key,
    required this.serviceId,
    this.vendor,
  });

  final int serviceId;
  final VendorModel? vendor;

  @override
  State<ServiceDetailsPage> createState() => _ServiceDetailsPageState();
}

class _ServiceDetailsPageState extends State<ServiceDetailsPage> {
  late Future<ServiceModel> _future;

  @override
  void initState() {
    super.initState();
    _future = ServiceService().show(widget.serviceId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<ServiceModel>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
              message: snap.error.toString(),
              onRetry: () => setState(() {
                _future = ServiceService().show(widget.serviceId);
              }),
            );
          }
          final s = snap.data!;
          final vendor = widget.vendor ?? s.vendor;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: AppNetworkImage(
                    url: s.image,
                    fallbackIcon: Icons.design_services,
                  ),
                  title: Text(s.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black54)
                        ],
                      )),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (s.price != null)
                        Row(
                          children: [
                            const Icon(Icons.local_offer_outlined,
                                color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              '${s.effectivePrice!.toStringAsFixed(0)} ₪',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            if (s.hasDiscount) ...[
                              const SizedBox(width: 10),
                              Text(
                                '${s.price!.toStringAsFixed(0)} ₪',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'خصم ${s.discountPercent}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 14),
                      if (vendor != null)
                        Container(
                          padding: const EdgeInsets.all(12),
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
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: AppNetworkImage(
                                    url: vendor.logo,
                                    fallbackIcon: Icons.storefront,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('المزوّد',
                                        style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12)),
                                    Text(vendor.name,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w700)),
                                  ],
                                ),
                              ),
                              if (vendor.rating != null)
                                RatingRow(rating: vendor.rating!),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text('وصف الخدمة',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        s.description.isNotEmpty
                            ? s.description
                            : 'لا يوجد وصف.',
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<ServiceModel>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          final s = snap.data!;
          final vendor = widget.vendor ?? s.vendor;
          if (vendor == null) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.calendar_month),
            label: const Text('احجز هذه الخدمة'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    BookingCreatePage(vendor: vendor, service: s),
              ),
            ),
          );
        },
      ),
    );
  }
}
