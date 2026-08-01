import 'package:dio/dio.dart';

import '../api/api_client.dart';

/// The shared Dio client accepts any status < 500 without throwing, so a 4xx
/// (e.g. 401 for a guest) would otherwise be parsed as a fake success. Call
/// this after every request so those surface as real errors instead.
void _ensureOk(Response res) {
  final code = res.statusCode ?? 0;
  if (code >= 300) {
    final data = res.data;
    final msg = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : (code == 401 ? 'يجب تسجيل الدخول أولاً' : 'تعذّر تنفيذ الطلب');
    throw ApiException(msg, statusCode: code);
  }
}

// ---------------------------------------------------------------------------
// Budget
// ---------------------------------------------------------------------------

class BudgetItemModel {
  BudgetItemModel({
    required this.id,
    required this.name,
    this.category,
    this.estimatedAmount = 0,
    this.actualAmount = 0,
    this.paid = false,
    this.notes,
  });

  final int id;
  final String name;
  final String? category;
  final double estimatedAmount;
  final double actualAmount;
  final bool paid;
  final String? notes;

  factory BudgetItemModel.fromJson(Map<String, dynamic> j) => BudgetItemModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        category: j['category']?.toString(),
        estimatedAmount: double.tryParse(j['estimated_amount']?.toString() ?? '') ?? 0,
        actualAmount: double.tryParse(j['actual_amount']?.toString() ?? '') ?? 0,
        paid: j['paid'] == true || j['paid'] == 1,
        notes: j['notes']?.toString(),
      );
}

class BudgetSummary {
  BudgetSummary({this.count = 0, this.estimated = 0, this.actual = 0, this.paid = 0, this.remaining = 0});
  final int count;
  final double estimated, actual, paid, remaining;

  factory BudgetSummary.fromJson(Map<String, dynamic> j) => BudgetSummary(
        count: (j['count'] as num?)?.toInt() ?? 0,
        estimated: (j['estimated'] as num?)?.toDouble() ?? 0,
        actual: (j['actual'] as num?)?.toDouble() ?? 0,
        paid: (j['paid'] as num?)?.toDouble() ?? 0,
        remaining: (j['remaining'] as num?)?.toDouble() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Guests
// ---------------------------------------------------------------------------

class GuestModel {
  GuestModel({
    required this.id,
    required this.name,
    this.phone,
    this.plusOnes = 0,
    this.rsvpStatus = 'invited',
    this.group,
    this.tableNumber,
    this.notes,
  });

  final int id;
  final String name;
  final String? phone;
  final int plusOnes;
  final String rsvpStatus;
  final String? group;
  final String? tableNumber;
  final String? notes;

  factory GuestModel.fromJson(Map<String, dynamic> j) => GuestModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        phone: j['phone']?.toString(),
        plusOnes: (j['plus_ones'] as num?)?.toInt() ?? 0,
        rsvpStatus: (j['rsvp_status'] ?? 'invited').toString(),
        group: j['group']?.toString(),
        tableNumber: j['table_number']?.toString(),
        notes: j['notes']?.toString(),
      );
}

class GuestSummary {
  GuestSummary({
    this.total = 0, this.invited = 0, this.confirmed = 0, this.declined = 0,
    this.maybe = 0, this.expectedHeads = 0,
  });
  final int total, invited, confirmed, declined, maybe, expectedHeads;

  factory GuestSummary.fromJson(Map<String, dynamic> j) => GuestSummary(
        total: (j['total'] as num?)?.toInt() ?? 0,
        invited: (j['invited'] as num?)?.toInt() ?? 0,
        confirmed: (j['confirmed'] as num?)?.toInt() ?? 0,
        declined: (j['declined'] as num?)?.toInt() ?? 0,
        maybe: (j['maybe'] as num?)?.toInt() ?? 0,
        expectedHeads: (j['expected_heads'] as num?)?.toInt() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Helpers + services
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _asList(dynamic body) {
  if (body is List) return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  if (body is Map && body['data'] is List) {
    return (body['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const [];
}

Map<String, dynamic> _asMap(dynamic body) {
  if (body is Map) {
    if (body['data'] is Map) return Map<String, dynamic>.from(body['data'] as Map);
    return Map<String, dynamic>.from(body);
  }
  return const {};
}

class BudgetService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<BudgetItemModel>> list() async {
    final res = await _dio.get('/budget-items');
    _ensureOk(res);
    return _asList(res.data).map(BudgetItemModel.fromJson).toList();
  }

  Future<BudgetSummary> summary() async {
    final res = await _dio.get('/budget-items/summary');
    _ensureOk(res);
    return BudgetSummary.fromJson(_asMap(res.data));
  }

  Future<BudgetItemModel> create({
    required String name,
    String? category,
    double estimated = 0,
    double actual = 0,
    bool paid = false,
  }) async {
    final res = await _dio.post('/budget-items', data: {
      'name': name,
      if (category != null && category.isNotEmpty) 'category': category,
      'estimated_amount': estimated,
      'actual_amount': actual,
      'paid': paid,
    });
    _ensureOk(res);
    return BudgetItemModel.fromJson(_asMap(res.data));
  }

  Future<BudgetItemModel> update(int id, Map<String, dynamic> patch) async {
    final res = await _dio.put('/budget-items/$id', data: patch);
    _ensureOk(res);
    return BudgetItemModel.fromJson(_asMap(res.data));
  }

  Future<void> delete(int id) async {
    final res = await _dio.delete('/budget-items/$id');
    _ensureOk(res);
  }
}

class GuestService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<GuestModel>> list({String? rsvpStatus}) async {
    final res = await _dio.get('/guests', queryParameters: {
      'rsvp_status': ?rsvpStatus,
    });
    _ensureOk(res);
    return _asList(res.data).map(GuestModel.fromJson).toList();
  }

  Future<GuestSummary> summary() async {
    final res = await _dio.get('/guests/summary');
    _ensureOk(res);
    return GuestSummary.fromJson(_asMap(res.data));
  }

  Future<GuestModel> create({
    required String name,
    String? phone,
    int plusOnes = 0,
    String rsvpStatus = 'invited',
    String? group,
    String? tableNumber,
  }) async {
    final res = await _dio.post('/guests', data: {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'plus_ones': plusOnes,
      'rsvp_status': rsvpStatus,
      if (group != null && group.isNotEmpty) 'group': group,
      if (tableNumber != null && tableNumber.isNotEmpty) 'table_number': tableNumber,
    });
    _ensureOk(res);
    return GuestModel.fromJson(_asMap(res.data));
  }

  Future<GuestModel> update(int id, Map<String, dynamic> patch) async {
    final res = await _dio.put('/guests/$id', data: patch);
    _ensureOk(res);
    return GuestModel.fromJson(_asMap(res.data));
  }

  Future<void> delete(int id) async {
    final res = await _dio.delete('/guests/$id');
    _ensureOk(res);
  }
}
