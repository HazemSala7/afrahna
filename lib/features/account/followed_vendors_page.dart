import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../vendors/vendor_details_page.dart';

/// "المحلات المتابَعة" — the shops this user follows. The follow data already
/// existed on the server; this is the first screen to surface it.
class FollowedVendorsPage extends StatefulWidget {
  const FollowedVendorsPage({super.key});

  @override
  State<FollowedVendorsPage> createState() => _FollowedVendorsPageState();
}

class _FollowedVendorsPageState extends State<FollowedVendorsPage> {
  late Future<List<VendorModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = FollowService().myFollows(perPage: 100);
  }

  Future<void> _reload() async {
    setState(() => _future = FollowService().myFollows(perPage: 100));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const PinkAppBar(title: 'المحلات المتابَعة'),
      body: FutureBuilder<List<VendorModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CenteredLoader();
          }
          if (snap.hasError) {
            return ErrorState(
              message: snap.error is ApiException
                  ? (snap.error as ApiException).message
                  : 'تعذّر تحميل المتابعات',
              onRetry: _reload,
            );
          }
          final items = snap.data ?? const <VendorModel>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.storefront_rounded,
              message: 'لا تتابع أي محل بعد.\nتابع محلاتك المفضّلة لتصلك جديدها.',
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _VendorRow(vendor: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _VendorRow extends StatelessWidget {
  const _VendorRow({required this.vendor});
  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      vendor.category?.name,
      vendor.city?.name,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' • ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VendorDetailsPage(vendorId: vendor.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
                    fallbackIcon: Icons.storefront_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vendor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (vendor.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 15, color: AppColors.primary),
                        ],
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if ((vendor.rating ?? 0) > 0) ...[
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFE0AE44)),
                          const SizedBox(width: 3),
                          Text(
                            vendor.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        const Icon(Icons.groups_rounded,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          '${vendor.followersCount} متابع',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded,
                  color: AppColors.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
