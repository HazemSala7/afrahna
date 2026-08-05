import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/state/cart.dart';
import '../../core/state/session.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/login_required_dialog.dart';
import '../vendors/vendor_details_page.dart';
import 'marketplace.dart';

/// The cart and checkout. Everything here belongs to one shop — an order is
/// placed against a single `vendor_id`, and [CartController] keeps it that way.
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _note = TextEditingController();
  final _area = TextEditingController();
  final _landmark = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<CityModel> _cities = const [];
  int? _cityId;
  bool _loadingCities = true;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  /// Cities come from the API; the customer's saved city is preselected so the
  /// common case is one tap on «إتمام الطلب».
  Future<void> _loadCities() async {
    try {
      final cities = await CityService().list();
      if (!mounted) return;
      final saved = context.read<SessionController>().user?.cityId;
      setState(() {
        _cities = cities;
        _loadingCities = false;
        if (saved != null && cities.any((c) => c.id == saved)) _cityId = saved;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _area.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final session = context.read<SessionController>();
    if (!session.isSignedIn) {
      await showLoginRequiredDialog(context);
      return;
    }

    final cart = context.read<CartController>();
    final vendorId = cart.vendorId;
    if (vendorId == null || cart.isEmpty) return;

    // The shop can't deliver without an address, so this is a hard gate.
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _placing = true);
    try {
      await OrderService().create(
        vendorId: vendorId,
        quantities: cart.quantities,
        cityId: _cityId,
        area: _area.text.trim(),
        landmark:
            _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      cart.clear();
      setState(() => _placing = false);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('تم إرسال طلبك'),
          content: const Text(
              'وصلت طلبيتك إلى المتجر كفاتورة. سيتواصل معك المتجر لتأكيدها.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إفراغ السلة'),
        content: const Text('سيتم حذف كل المنتجات من سلتك.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.discount),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إفراغ'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) context.read<CartController>().clear();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final lines = cart.lines;

    return AppScaffold(
      appBar: PinkAppBar(
        title: 'سلة المشتريات',
        subtitle: cart.vendorName,
        actions: [
          if (lines.isNotEmpty)
            IconButton(
              tooltip: 'إفراغ السلة',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: lines.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_cart_outlined,
              message: 'سلتك فارغة.\nتصفّح المتجر وأضف ما يعجبك.',
            )
          : Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      children: [
                        if (cart.vendorId != null) _ShopBar(cart: cart),
                        const SizedBox(height: 12),
                        for (final line in lines) ...[
                          _CartLineTile(line: line),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 10),
                        _SectionTitle(
                          icon: Icons.local_shipping_rounded,
                          title: 'عنوان التوصيل',
                        ),
                        const SizedBox(height: 10),
                        _CityField(
                          cities: _cities,
                          value: _cityId,
                          loading: _loadingCities,
                          onChanged: (id) => setState(() => _cityId = id),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _area,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'المنطقة / الحي',
                            hintText: 'مثال: وادي الهرية',
                            prefixIcon:
                                Icon(Icons.map_outlined, size: 20),
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'اكتب المنطقة أو الحي'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _landmark,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'بالقرب من (اختياري)',
                            hintText: 'مثال: بجانب مسجد الرحمة',
                            prefixIcon:
                                Icon(Icons.place_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionTitle(
                          icon: Icons.notes_rounded,
                          title: 'ملاحظات',
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _note,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظة للمتجر (اختياري)',
                            prefixIcon: Icon(Icons.notes_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _CheckoutBar(
                  total: cart.total,
                  count: cart.count,
                  busy: _placing,
                  onCheckout: _checkout,
                ),
              ],
            ),
    );
  }
}

/// Small heading that splits the checkout form into readable blocks.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

/// City picker. Falls back to a plain text note if the list can't be loaded,
/// so a network hiccup never blocks checkout entirely.
class _CityField extends StatelessWidget {
  const _CityField({
    required this.cities,
    required this.value,
    required this.loading,
    required this.onChanged,
  });

  final List<CityModel> cities;
  final int? value;
  final bool loading;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'المدينة',
          prefixIcon: Icon(Icons.location_city_rounded, size: 20),
        ),
        child: Text('جارٍ التحميل…',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }
    if (cities.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'المدينة',
          prefixIcon: Icon(Icons.location_city_rounded, size: 20),
        ),
        child: Text('تعذّر تحميل المدن — اكتبها ضمن المنطقة',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'المدينة',
        prefixIcon: Icon(Icons.location_city_rounded, size: 20),
      ),
      hint: const Text('اختر المدينة'),
      items: [
        for (final c in cities)
          DropdownMenuItem(value: c.id, child: Text(c.name)),
      ],
      onChanged: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
      validator: (v) => v == null ? 'اختر المدينة' : null,
    );
  }
}

/// Reminder of which shop this order belongs to, with a shortcut to it.
class _ShopBar extends StatelessWidget {
  const _ShopBar({required this.cart});
  final CartController cart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryLight.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VendorDetailsPage(vendorId: cart.vendorId!),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.storefront_rounded,
                  color: AppColors.primaryDark, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cart.vendorName ?? 'المتجر',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const Text(
                'الطلب من محل واحد',
                style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartController>();
    final p = line.product;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 62,
              height: 62,
              child: AppNetworkImage(
                url: p.image,
                fallbackIcon: Icons.shopping_bag_outlined,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  p.effectivePrice > 0
                      ? '₪${money(p.effectivePrice)} × ${line.quantity}'
                      : 'السعر عند الطلب × ${line.quantity}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
                if (p.effectivePrice > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '₪${money(line.total)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              _RoundStep(
                icon: Icons.add_rounded,
                onTap: () => setCartQuantity(cart, p.id, line.quantity + 1),
              ),
              const SizedBox(height: 6),
              _RoundStep(
                icon: line.quantity > 1
                    ? Icons.remove_rounded
                    : Icons.delete_outline_rounded,
                danger: line.quantity <= 1,
                onTap: () => setCartQuantity(cart, p.id, line.quantity - 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundStep extends StatelessWidget {
  const _RoundStep({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.discount : AppColors.primaryDark;
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.total,
    required this.count,
    required this.busy,
    required this.onCheckout,
  });

  final double total;
  final int count;
  final bool busy;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, 12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'الإجمالي ($count منتج)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                '₪${money(total)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: busy ? null : onCheckout,
              icon: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.receipt_long_rounded, size: 20),
              label: Text(
                busy ? 'جارٍ الإرسال...' : 'إتمام الطلب',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
