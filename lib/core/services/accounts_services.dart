import '../api/api_client.dart';
import '../models/models.dart';

// ---------------------------------------------------------------------------
// Unwrap helpers (kept local to avoid coupling to services.dart privates).
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _unwrapList(dynamic body) {
  if (body is List) {
    return body
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (body is Map) {
    final data = body['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }
  return const [];
}

Map<String, dynamic> _unwrapObject(dynamic body) {
  if (body is Map) {
    if (body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return Map<String, dynamic>.from(body);
  }
  return const {};
}

// ---------------------------------------------------------------------------
// SUBSCRIPTION
// ---------------------------------------------------------------------------

class SubscriptionService {
  final _dio = ApiClient.instance.dio;

  Future<List<SubscriptionModel>> list({
    String? status,
    int? delegateId,
    int? userId,
    int perPage = 30,
  }) async {
    try {
      final res = await _dio.get('/subscriptions', queryParameters: {
        if (status != null) 'status': status,
        if (delegateId != null) 'delegate_id': delegateId,
        if (userId != null) 'user_id': userId,
        'per_page': perPage,
      });
      return _unwrapList(res.data).map(SubscriptionModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<SubscriptionModel> show(int id) async {
    try {
      final res = await _dio.get('/subscriptions/$id');
      return SubscriptionModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// DELEGATE
// ---------------------------------------------------------------------------

class DelegateRegisterClientResult {
  DelegateRegisterClientResult({
    required this.client,
    required this.subscription,
    required this.temporaryPassword,
  });
  final UserModel client;
  final SubscriptionModel subscription;
  final String temporaryPassword;
}

class CommissionsResponse {
  CommissionsResponse({required this.subscriptions, required this.totals});
  final List<SubscriptionModel> subscriptions;
  final CommissionsTotals totals;
}

class DelegateService {
  final _dio = ApiClient.instance.dio;

  Future<List<UserModel>> myClients({String? search, int perPage = 30}) async {
    try {
      final res = await _dio.get('/delegate/clients', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'per_page': perPage,
      });
      return _unwrapList(res.data).map(UserModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<CommissionsResponse> myCommissions({
    String? status,
    bool? commissionPaid,
    int perPage = 30,
  }) async {
    try {
      final res = await _dio.get('/delegate/commissions', queryParameters: {
        if (status != null) 'status': status,
        if (commissionPaid != null) 'commission_paid': commissionPaid ? 1 : 0,
        'per_page': perPage,
      });
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final subs = (data['data'] is List)
          ? (data['data'] as List)
              .whereType<Map>()
              .map((e) => SubscriptionModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <SubscriptionModel>[];
      final totalsMap = data['totals'] is Map
          ? Map<String, dynamic>.from(data['totals'] as Map)
          : <String, dynamic>{};
      return CommissionsResponse(
        subscriptions: subs,
        totals: CommissionsTotals.fromJson(totalsMap),
      );
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<DelegateRegisterClientResult> registerClient({
    required String name,
    required String phone,
    String? email,
    String? password,
    int? cityId,
    String? workField,
    required String planName,
    required double amountPaid,
    double? commissionAmount,
    String? paymentMethod,
    required DateTime startDate,
    required DateTime endDate,
    String? notes,
  }) async {
    try {
      final res = await _dio.post('/delegate/clients', data: {
        'name': name,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (password != null && password.isNotEmpty) 'password': password,
        if (cityId != null) 'city_id': cityId,
        if (workField != null && workField.isNotEmpty) 'work_field': workField,
        'plan_name': planName,
        'amount_paid': amountPaid,
        if (commissionAmount != null) 'commission_amount': commissionAmount,
        if (paymentMethod != null && paymentMethod.isNotEmpty) 'payment_method': paymentMethod,
        'start_date': _date(startDate),
        'end_date': _date(endDate),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      final map = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      return DelegateRegisterClientResult(
        client: UserModel.fromJson(Map<String, dynamic>.from(map['client'] as Map)),
        subscription: SubscriptionModel.fromJson(Map<String, dynamic>.from(map['subscription'] as Map)),
        temporaryPassword: (map['temporary_password'] ?? '').toString(),
      );
    } catch (e) {
      throw toApiException(e);
    }
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// POSTS (post / reel / course)
// ---------------------------------------------------------------------------

class PostService {
  final _dio = ApiClient.instance.dio;

  Future<List<PostModel>> list({
    int? vendorId,
    PostType? type,
    bool mine = false,
    int perPage = 20,
  }) async {
    try {
      final res = await _dio.get('/posts', queryParameters: {
        if (vendorId != null) 'vendor_id': vendorId,
        if (type != null) 'type': postTypeTo(type),
        if (mine) 'mine': 1,
        'per_page': perPage,
      });
      return _unwrapList(res.data).map(PostModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Posts from vendors the current user follows.
  Future<List<PostModel>> feed({int perPage = 20}) async {
    try {
      final res = await _dio.get('/posts/feed/me', queryParameters: {
        'per_page': perPage,
      });
      return _unwrapList(res.data).map(PostModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<PostModel> create({
    required int vendorId,
    required PostType type,
    String? title,
    String? body,
    String? mediaUrl,
    String? thumbnail,
    double? price,
    String? duration,
    bool isPublished = true,
  }) async {
    try {
      final res = await _dio.post('/posts', data: {
        'vendor_id': vendorId,
        'type': postTypeTo(type),
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (thumbnail != null) 'thumbnail': thumbnail,
        if (price != null) 'price': price,
        if (duration != null) 'duration': duration,
        'is_published': isPublished,
      });
      return PostModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/posts/$id');
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Fire-and-forget view increment used by the Reels feed.
  Future<void> markViewed(int id) async {
    try {
      await _dio.post('/posts/$id/view');
    } catch (_) {
      // Silent — never block the UI on view tracking.
    }
  }
}

// ---------------------------------------------------------------------------
// POST COMMENTS (with admin moderation)
// ---------------------------------------------------------------------------

class PostCommentService {
  final _dio = ApiClient.instance.dio;

  /// Public: list approved comments for a post.
  Future<List<PostCommentModel>> list(int postId, {int perPage = 30}) async {
    try {
      final res = await _dio.get('/posts/$postId/comments',
          queryParameters: {'per_page': perPage});
      return _unwrapList(res.data).map(PostCommentModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Auth: create a pending comment. Requires bearer token.
  /// Returns the created comment (not yet approved).
  Future<PostCommentModel> create(int postId, String body) async {
    try {
      final res = await _dio.post('/posts/$postId/comments', data: {'body': body});
      final raw = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final c = raw['comment'] is Map
          ? Map<String, dynamic>.from(raw['comment'] as Map)
          : raw;
      return PostCommentModel.fromJson(c);
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// FOLLOW
// ---------------------------------------------------------------------------

class FollowResult {
  FollowResult({required this.following, required this.followers});
  final bool following;
  final int followers;
}

class FollowService {
  final _dio = ApiClient.instance.dio;

  Future<List<VendorModel>> myFollows({int perPage = 30}) async {
    try {
      final res = await _dio.get('/follows', queryParameters: {'per_page': perPage});
      return _unwrapList(res.data).map(VendorModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<FollowResult> toggle(int vendorId) async {
    try {
      final res = await _dio.post('/follows/$vendorId/toggle');
      final m = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      return FollowResult(
        following: m['following'] == true,
        followers: (m['followers'] is num) ? (m['followers'] as num).toInt() : 0,
      );
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> unfollow(int vendorId) async {
    try {
      await _dio.delete('/follows/$vendorId');
    } catch (e) {
      throw toApiException(e);
    }
  }
}
