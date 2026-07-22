import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

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

  /// True while the offer's date window includes today.
  bool get _isActive {
    final now = DateTime.now();
    final okStart = promo.startDate == null || !now.isBefore(promo.startDate!);
    final okEnd = promo.endDate == null ||
        !now.isAfter(promo.endDate!.add(const Duration(days: 1)));
    return okStart && okEnd;
  }

  @override
  Widget build(BuildContext context) {
    final images = promo.gallery;
    final vendor = promo.vendor;
    final topInset = MediaQuery.of(context).padding.top;
    // Hero extends up under the status bar; give it room + the visible height.
    final heroHeight = topInset + 250;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                // ---- Full-bleed hero (edge-to-edge, under the status bar) ----
                Stack(
                  children: [
                    _OfferGallery(images: images, height: heroHeight),
                    // Top scrim so the back button + status bar icons stay legible.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: topInset + 60,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Bottom scrim for a soft blend into the sheet.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 90,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.25),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Discount badge (below the status bar).
                    if (promo.discountLabel.isNotEmpty)
                      PositionedDirectional(
                        top: topInset + 10,
                        end: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF5A5F), Color(0xFFE0353B)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE0353B)
                                    .withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_offer_rounded,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 5),
                              Text('خصم ${promo.discountLabel}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                // ---- Content sheet overlapping the hero ----
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(26)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF6A93B), AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.local_fire_department_rounded,
                            color: Colors.white, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(promo.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    height: 1.25,
                                    color: AppColors.textDark)),
                            const SizedBox(height: 4),
                            _StatusChip(active: _isActive),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (promo.startDate != null || promo.endDate != null) ...[
                    const SizedBox(height: 16),
                    _InfoTile(
                      icon: Icons.event_available_rounded,
                      label: 'مدة العرض',
                      value:
                          'من ${_fmt(promo.startDate)} إلى ${_fmt(promo.endDate)}',
                    ),
                  ],

                  if (promo.description.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text('تفاصيل العرض',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                                color: AppColors.textDark)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
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
                      child: Text(promo.description,
                          style: const TextStyle(
                              color: AppColors.textDark,
                              height: 1.85,
                              fontSize: 14)),
                    ),
                  ],

                  if (vendor != null) ...[
                    const SizedBox(height: 20),
                    _VendorRow(vendor: vendor),
                  ] else if (promo.vendorId != null) ...[
                    const SizedBox(height: 20),
                    _VisitShopButton(vendorId: promo.vendorId!),
                  ],
                ],
              ),
            ),
          ),
              ],
            ),
            // Floating glass back button — RTL: start = the right side.
            PositionedDirectional(
              top: topInset + 6,
              start: 8,
              child: _GlassBackButton(onTap: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round translucent back button placed over the hero image.
class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// "ساري / منتهي" status pill.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = active ? const Color(0xFF2E9E5B) : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 13, color: c),
          const SizedBox(width: 4),
          Text(active ? 'ساري الآن' : 'منتهي',
              style: TextStyle(
                  color: c, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// A soft info row (icon badge + label + value).
class _InfoTile extends StatelessWidget {
  const _InfoTile(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
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
  const _OfferGallery({required this.images, this.height = 280});
  final List<String> images;
  final double height;

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
      height: widget.height,
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
                  bottom: 36,
                  end: 12,
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
                  bottom: 36,
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
