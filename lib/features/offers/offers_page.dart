import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../vendors/vendor_details_page.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  late Future<List<PromotionModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = PromotionService().list();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const PinkAppBar(title: 'العروض', showBack: false),
      body: FutureBuilder<List<PromotionModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
              message: snap.error.toString(),
              onRetry: () => setState(
                  () => _future = PromotionService().list()),
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const EmptyState(
                message: 'لا توجد عروض حالياً',
                icon: Icons.local_offer_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (_, i) => _PromoCard(promo: items[i]),
          );
        },
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo});
  final PromotionModel promo;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (promo.vendorId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VendorDetailsPage(vendorId: promo.vendorId!),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AppNetworkImage(
                    url: promo.image,
                    fallbackIcon: Icons.local_offer,
                  ),
                ),
                if (promo.discountPercent != null)
                  PositionedDirectional(
                    top: 12,
                    start: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.discount,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '-${promo.discountPercent!.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promo.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (promo.vendor != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      promo.vendor!.name,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ],
                  if (promo.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      promo.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
