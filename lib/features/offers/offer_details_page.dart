import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../vendors/vendor_details_page.dart';

/// Full details of a single offer — image gallery, title, discount, validity,
/// description and the offering vendor (with a shortcut to the shop page).
class OfferDetailsPage extends StatelessWidget {
  const OfferDetailsPage({super.key, required this.promo});
  final PromotionModel promo;

  static String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final images = promo.gallery;
    final vendor = promo.vendor;

    return AppScaffold(
      appBar: const PinkAppBar(title: 'تفاصيل العرض'),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---- Gallery ----
          Stack(
            children: [
              _OfferGallery(images: images),
              if (promo.discountLabel.isNotEmpty)
                PositionedDirectional(
                  top: 14,
                  start: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5A5F), Color(0xFFE0353B)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE0353B).withValues(alpha: 0.45),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text('خصم ${promo.discountLabel}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(promo.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: AppColors.textDark)),
                if (promo.startDate != null || promo.endDate != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('ساري من ${_fmt(promo.startDate)} إلى ${_fmt(promo.endDate)}',
                            style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
                if (promo.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('تفاصيل العرض',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  Text(promo.description,
                      style: const TextStyle(
                          color: AppColors.textDark,
                          height: 1.7,
                          fontSize: 14)),
                ],
                if (vendor != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  _VendorRow(vendor: vendor),
                ] else if (promo.vendorId != null) ...[
                  const SizedBox(height: 20),
                  _VisitShopButton(vendorId: promo.vendorId!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorRow extends StatelessWidget {
  const _VendorRow({required this.vendor});
  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDetailsPage(vendorId: vendor.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 56,
                height: 56,
                child: AppNetworkImage(
                  url: vendor.logo ?? vendor.cover,
                  fallbackIcon: Icons.storefront,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('العرض مقدَّم من',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11.5)),
                  const SizedBox(height: 2),
                  Text(vendor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: AppColors.textDark)),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_ios_new,
                size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _VisitShopButton extends StatelessWidget {
  const _VisitShopButton({required this.vendorId});
  final int vendorId;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDetailsPage(vendorId: vendorId),
        ),
      ),
      icon: const Icon(Icons.storefront),
      label: const Text('زيارة صفحة المعلن',
          style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

/// Full-width swipeable gallery header for the offer.
class _OfferGallery extends StatefulWidget {
  const _OfferGallery({required this.images});
  final List<String> images;

  @override
  State<_OfferGallery> createState() => _OfferGalleryState();
}

class _OfferGalleryState extends State<_OfferGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: imgs.length <= 1
          ? AppNetworkImage(
              url: imgs.isNotEmpty ? imgs.first : null,
              fit: BoxFit.cover,
              fallbackIcon: Icons.local_offer,
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: imgs.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => AppNetworkImage(
                      url: imgs[i],
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.local_offer,
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 14,
                  end: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_index + 1}/${imgs.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(imgs.length, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
    );
  }
}
