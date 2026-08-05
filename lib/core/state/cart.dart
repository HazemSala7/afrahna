import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// One line in the cart. The product details are stored alongside the quantity
/// so the cart can render (and total) without re-fetching every product.
class CartLine {
  const CartLine({required this.product, required this.quantity});

  final ProductModel product;
  final int quantity;

  double get total => product.effectivePrice * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);

  Map<String, dynamic> toJson() => {
        'quantity': quantity,
        'product': {
          'id': product.id,
          'vendor_id': product.vendorId,
          'name_ar': product.nameAr,
          'name_en': product.nameEn,
          'image': product.image,
          'price': product.price,
          'discount_price': product.discountPrice,
          'vendor': product.vendorName == null
              ? null
              : {'name_ar': product.vendorName},
        },
      };

  static CartLine? fromJson(Map<String, dynamic> j) {
    final p = j['product'];
    if (p is! Map) return null;
    return CartLine(
      product: ProductModel.fromJson(Map<String, dynamic>.from(p)),
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Result of trying to add a product whose shop differs from the cart's.
enum CartAddResult { added, otherVendor }

/// The shopping cart, shared across the whole app.
///
/// An order is placed against a single `vendor_id`, so the cart is deliberately
/// **single-shop**: adding a product from another shop is refused and reported
/// back, letting the UI ask whether to start a new cart instead of silently
/// dropping items or building an order the server would reject.
class CartController extends ChangeNotifier {
  static const _key = 'cart_v1';

  final Map<int, CartLine> _lines = {}; // productId -> line
  int? _vendorId;
  String? _vendorName;
  bool _loaded = false;

  List<CartLine> get lines => _lines.values.toList(growable: false);
  int? get vendorId => _vendorId;
  String? get vendorName => _vendorName;
  bool get isEmpty => _lines.isEmpty;

  /// Total number of items (not lines) — drives the cart badge.
  int get count => _lines.values.fold(0, (a, l) => a + l.quantity);

  double get total => _lines.values.fold(0.0, (a, l) => a + l.total);

  int quantityOf(int productId) => _lines[productId]?.quantity ?? 0;

  /// Restores the cart saved on this device. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;

      _vendorId = (data['vendor_id'] as num?)?.toInt();
      _vendorName = data['vendor_name'] as String?;
      for (final item in (data['lines'] as List? ?? const [])) {
        if (item is! Map) continue;
        final line = CartLine.fromJson(Map<String, dynamic>.from(item));
        if (line != null) _lines[line.product.id] = line;
      }
      if (_lines.isEmpty) _clearVendor();
      notifyListeners();
    } catch (_) {
      // A corrupt cart must not block the app — start empty.
      _lines.clear();
      _clearVendor();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lines.isEmpty) {
        await prefs.remove(_key);
        return;
      }
      await prefs.setString(_key, jsonEncode({
        'vendor_id': _vendorId,
        'vendor_name': _vendorName,
        'lines': _lines.values.map((l) => l.toJson()).toList(),
      }));
    } catch (_) {
      // Persistence is a convenience; the in-memory cart still works.
    }
  }

  void _clearVendor() {
    _vendorId = null;
    _vendorName = null;
  }

  /// Adds one unit of [product].
  ///
  /// Returns [CartAddResult.otherVendor] (changing nothing) when the cart
  /// already holds items from a different shop — call [startNewCart] to
  /// replace it once the customer confirms.
  CartAddResult add(ProductModel product, {int quantity = 1}) {
    if (_lines.isNotEmpty && _vendorId != null && _vendorId != product.vendorId) {
      return CartAddResult.otherVendor;
    }
    _vendorId = product.vendorId;
    _vendorName ??= product.vendorName;
    if (product.vendorName != null) _vendorName = product.vendorName;

    final existing = _lines[product.id];
    _lines[product.id] = existing == null
        ? CartLine(product: product, quantity: quantity)
        : existing.copyWith(quantity: existing.quantity + quantity);

    notifyListeners();
    _persist();
    return CartAddResult.added;
  }

  /// Empties the cart and adds [product] — used after the customer agrees to
  /// abandon the other shop's items.
  void startNewCart(ProductModel product, {int quantity = 1}) {
    _lines.clear();
    _clearVendor();
    add(product, quantity: quantity);
  }

  void setQuantity(int productId, int quantity) {
    final line = _lines[productId];
    if (line == null) return;
    if (quantity <= 0) {
      _lines.remove(productId);
      if (_lines.isEmpty) _clearVendor();
    } else {
      _lines[productId] = line.copyWith(quantity: quantity);
    }
    notifyListeners();
    _persist();
  }

  void remove(int productId) => setQuantity(productId, 0);

  void clear() {
    _lines.clear();
    _clearVendor();
    notifyListeners();
    _persist();
  }

  /// productId → quantity, the shape [OrderService.create] expects.
  Map<int, int> get quantities =>
      {for (final l in _lines.values) l.product.id: l.quantity};
}
