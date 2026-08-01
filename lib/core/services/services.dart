import 'dart:convert';

import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/auth_storage.dart';
import '../models/models.dart';

/// Helper to unwrap Laravel-style responses that may be either
/// `{ "data": [...] }` or a raw list / object.
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
// AUTH
// ---------------------------------------------------------------------------

class AuthResult {
  AuthResult({required this.user, required this.token});
  final UserModel user;
  final String token;
}

class AuthService {
  final _dio = ApiClient.instance.dio;

  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        'phone': phone,
        'password': password,
      });
      if (res.statusCode != 200) throw _err(res.data);
      return _persist(res.data);
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<AuthResult> register({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? referralCode,
  }) async {
    try {
      final res = await _dio.post('/auth/register', data: {
        'name': name,
        'phone': phone,
        'password': password,
        'password_confirmation': password,
        if (email != null && email.isNotEmpty) 'email': email,
        if (referralCode != null && referralCode.trim().isNotEmpty)
          'referral_code': referralCode.trim().toUpperCase(),
      });
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw _err(res.data);
      }
      return _persist(res.data);
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<UserModel> me() async {
    try {
      final res = await _dio.get('/auth/me');
      if (res.statusCode != 200) throw _err(res.data);
      return UserModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // ignore network errors on logout
    } finally {
      await AuthStorage.instance.clear();
    }
  }

  /// Enables/disables the signed-in user's notifications. Returns the new value.
  Future<bool> updateNotifications(bool enabled) async {
    try {
      final res = await _dio.patch('/auth/notifications',
          data: {'notifications_enabled': enabled});
      final data = res.data;
      if (data is Map && data['notifications_enabled'] != null) {
        final v = data['notifications_enabled'];
        return v == true || v == 1;
      }
      return enabled;
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Changes the signed-in user's own password (any role). Requires the
  /// current password. Throws [ApiException] with the server message on failure.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.post('/auth/change-password', data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPassword,
      });
      if (res.statusCode != 200) throw _err(res.data);
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Permanently deletes the authenticated user's account on the server, then
  /// clears the local session. Throws on failure (session is kept intact).
  Future<void> deleteAccount() async {
    try {
      final res = await _dio.delete('/auth/account');
      if (res.statusCode != 200) throw _err(res.data);
      await AuthStorage.instance.clear();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<AuthResult> _persist(dynamic data) async {
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final token = (map['token'] ?? map['access_token'] ?? '').toString();
    final userMap = map['user'] is Map
        ? Map<String, dynamic>.from(map['user'] as Map)
        : _unwrapObject(map['data']);
    final user = UserModel.fromJson(userMap);
    if (token.isNotEmpty) {
      await AuthStorage.instance.writeToken(token);
      await AuthStorage.instance.writeUserJson(jsonEncode(user.toJson()));
    }
    return AuthResult(user: user, token: token);
  }

  Exception _err(dynamic data) => ApiException(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'فشلت العملية',
      );
}

// ---------------------------------------------------------------------------
// CITY / CATEGORY
// ---------------------------------------------------------------------------

class CityService {
  final _dio = ApiClient.instance.dio;

  Future<List<CityModel>> list() async {
    try {
      final res = await _dio.get('/cities', queryParameters: {'per_page': 100});
      return _unwrapList(res.data).map(CityModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }
}

class CategoryService {
  final _dio = ApiClient.instance.dio;

  /// Returns top-level categories. Pass [tree] = true to also include
  /// nested subcategories on each parent.
  Future<List<CategoryModel>> list({bool tree = false}) async {
    try {
      final res = await _dio.get('/categories', queryParameters: {
        if (tree) 'tree': 1,
      });
      return _unwrapList(res.data).map(CategoryModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Returns the direct children (subcategories) of [parentId].
  Future<List<CategoryModel>> children(int parentId) async {
    try {
      final res = await _dio.get('/categories', queryParameters: {
        'parent_id': parentId,
        'per_page': 200,
      });
      return _unwrapList(res.data).map(CategoryModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// VENDOR
// ---------------------------------------------------------------------------

class VendorService {
  final _dio = ApiClient.instance.dio;

  Future<List<VendorModel>> list({
    int? categoryId,
    int? parentCategoryId,
    int? cityId,
    String? query,
    bool? featured,
    bool? verified,
    bool? vip,
    int? userId,
    int? delegateId,
    bool? activeOnly,
    int? perPage,
  }) async {
    try {
      final res = await _dio.get('/vendors', queryParameters: {
        'category_id': ?categoryId,
        'parent_category_id': ?parentCategoryId,
        'city_id': ?cityId,
        if (query != null && query.isNotEmpty) 'q': query,
        if (featured == true) 'featured': 1,
        if (verified == true) 'verified': 1,
        if (vip == true) 'vip': 1,
        'user_id': ?userId,
        'delegate_id': ?delegateId,
        if (activeOnly != null) 'active_only': activeOnly ? 1 : 0,
        'per_page': ?perPage,
      });
      return _unwrapList(res.data).map(VendorModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Paginated vendor list — returns the page items plus whether more pages
  /// exist, so lists can load-more on scroll instead of showing only page 1.
  Future<({List<VendorModel> items, bool hasMore})> listPaged({
    int? categoryId,
    int? parentCategoryId,
    int? cityId,
    String? query,
    bool? featured,
    bool? verified,
    bool? vip,
    int? userId,
    int? delegateId,
    bool? activeOnly,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final res = await _dio.get('/vendors', queryParameters: {
        'category_id': ?categoryId,
        'parent_category_id': ?parentCategoryId,
        'city_id': ?cityId,
        if (query != null && query.isNotEmpty) 'q': query,
        if (featured == true) 'featured': 1,
        if (verified == true) 'verified': 1,
        if (vip == true) 'vip': 1,
        'user_id': ?userId,
        'delegate_id': ?delegateId,
        if (activeOnly != null) 'active_only': activeOnly ? 1 : 0,
        'page': page,
        'per_page': perPage,
      });
      final body = res.data;
      final items = _unwrapList(body).map(VendorModel.fromJson).toList();
      var hasMore = false;
      if (body is Map) {
        final cp = body['current_page'];
        final lp = body['last_page'];
        if (cp is num && lp is num) hasMore = cp.toInt() < lp.toInt();
      }
      return (items: items, hasMore: hasMore);
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<VendorModel> show(int id) async {
    try {
      final res = await _dio.get('/vendors/$id');
      return VendorModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Returns the vendor profile owned by the currently-authenticated user.
  Future<VendorModel> mine() async {
    try {
      final res = await _dio.get('/vendors/mine');
      return VendorModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<VendorModel> update(int id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('/vendors/$id', data: data);
      return VendorModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Admin (or owner): permanently delete a vendor/shop.
  Future<void> delete(int id) async {
    try {
      await _dio.delete('/vendors/$id');
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Vendor owner (or admin): list users who follow this shop + total count.
  Future<({List<UserModel> users, int total})> followers(
    int vendorId, {
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      final res = await _dio.get('/vendors/$vendorId/followers',
          queryParameters: {'page': page, 'per_page': perPage});
      final body = res.data;
      final total = (body is Map && body['total'] is num)
          ? (body['total'] as num).toInt()
          : 0;
      final users = _unwrapList(body).map(UserModel.fromJson).toList();
      return (users: users, total: total);
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Vendor owner sends a notification to all of their followers.
  /// Returns how many followers were notified.
  Future<int> notifyFollowers(int vendorId,
      {required String title, String? body}) async {
    try {
      final res = await _dio.post('/vendors/$vendorId/notify-followers', data: {
        'title': title,
        if (body != null && body.isNotEmpty) 'body': body,
      });
      final m = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {};
      return (m['sent'] is num) ? (m['sent'] as num).toInt() : 0;
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Admin: paginated + searchable vendor list that INCLUDES inactive shops
  /// (active_only=0), for the in-app admin management screen.
  Future<VendorsResult> adminList({
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final res = await _dio.get('/vendors', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'active_only': 0,
        'page': page,
        'per_page': perPage,
      });
      final body = res.data;
      final items = _unwrapList(body).map(VendorModel.fromJson).toList();
      int current = page, last = page;
      if (body is Map) {
        final cp = body['current_page'];
        final lp = body['last_page'];
        if (cp is num) current = cp.toInt();
        if (lp is num) last = lp.toInt();
      }
      return VendorsResult(items: items, currentPage: current, lastPage: last);
    } catch (e) {
      throw toApiException(e);
    }
  }
}

/// One page of vendors plus paging info for infinite scroll (admin list).
class VendorsResult {
  VendorsResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });
  final List<VendorModel> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}

// ---------------------------------------------------------------------------
// UPLOAD (multipart file upload — images, etc.)
// ---------------------------------------------------------------------------

class UploadService {
  final _dio = ApiClient.instance.dio;

  /// Uploads a local file to the server and returns its public URL.
  /// [folder] groups files server-side, e.g. "vendors/logos".
  /// [onProgress] reports upload progress in the range 0.0–1.0 (useful for
  /// large reel videos); it may be called with values > total unknown, so it is
  /// clamped before being emitted.
  Future<String> uploadFile(
    String filePath, {
    String folder = 'general',
    void Function(double progress)? onProgress,
  }) async {
    try {
      final form = FormData.fromMap({
        'folder': folder,
        'file': await MultipartFile.fromFile(filePath),
      });
      final res = await _dio.post(
        '/uploads',
        data: form,
        onSendProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress((sent / total).clamp(0.0, 1.0));
              },
      );
      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw toApiException(DioException(
          requestOptions: res.requestOptions,
          response: res,
        ));
      }
      final body = res.data;
      final url = body is Map ? (body['url'] ?? '').toString() : '';
      if (url.isEmpty) {
        throw ApiException('تعذّر رفع الملف');
      }
      return url;
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// SERVICE
// ---------------------------------------------------------------------------

class ServiceService {
  final _dio = ApiClient.instance.dio;

  Future<List<ServiceModel>> list({int? vendorId, int? categoryId, bool mine = false}) async {
    try {
      final res = await _dio.get('/services', queryParameters: {
        'vendor_id': ?vendorId,
        'category_id': ?categoryId,
        if (mine) 'mine': 1,
      });
      return _unwrapList(res.data).map(ServiceModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<ServiceModel> show(int id) async {
    try {
      final res = await _dio.get('/services/$id');
      return ServiceModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<ServiceModel> create({
    required int vendorId,
    required String nameAr,
    required String nameEn,
    required double price,
    String? descriptionAr,
    String? descriptionEn,
    double? discountPrice,
    String? duration,
    String? image,
    bool isActive = true,
  }) async {
    try {
      final res = await _dio.post('/services', data: {
        'vendor_id': vendorId,
        'name_ar': nameAr,
        'name_en': nameEn,
        'price': price,
        'description_ar': ?descriptionAr,
        'description_en': ?descriptionEn,
        'discount_price': ?discountPrice,
        'duration': ?duration,
        'image': ?image,
        'is_active': isActive,
      });
      return ServiceModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<ServiceModel> update(int id, {
    String? nameAr,
    String? nameEn,
    String? descriptionAr,
    String? descriptionEn,
    double? price,
    double? discountPrice,
    String? duration,
    String? image,
    bool? isActive,
  }) async {
    try {
      final res = await _dio.put('/services/$id', data: {
        'name_ar': ?nameAr,
        'name_en': ?nameEn,
        'description_ar': ?descriptionAr,
        'description_en': ?descriptionEn,
        'price': ?price,
        'discount_price': ?discountPrice,
        'duration': ?duration,
        'image': ?image,
        'is_active': ?isActive,
      });
      return ServiceModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/services/$id');
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// BOOKING
// ---------------------------------------------------------------------------

class BookingService {
  final _dio = ApiClient.instance.dio;

  Future<List<BookingModel>> list() async {
    try {
      final res = await _dio.get('/bookings');
      return _unwrapList(res.data).map(BookingModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<BookingModel> create({
    required int serviceId,
    required int vendorId,
    required DateTime eventDate,
    String? notes,
  }) async {
    try {
      final res = await _dio.post('/bookings', data: {
        'service_id': serviceId,
        'vendor_id': vendorId,
        'event_date': eventDate.toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw ApiException((res.data is Map &&
                res.data['message'] != null)
            ? res.data['message'].toString()
            : 'تعذّر إنشاء الحجز');
      }
      return BookingModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _dio.delete('/bookings/$id');
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// FAVORITES
// ---------------------------------------------------------------------------

class FavoriteService {
  final _dio = ApiClient.instance.dio;

  Future<List<VendorModel>> list() async {
    try {
      final res = await _dio.get('/favorites');
      return _unwrapList(res.data).map((m) {
        if (m['vendor'] is Map) {
          return VendorModel.fromJson(
              Map<String, dynamic>.from(m['vendor'] as Map));
        }
        return VendorModel.fromJson(m);
      }).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<bool> toggle(int vendorId) async {
    try {
      final res = await _dio.post('/favorites/$vendorId/toggle');
      final body = _unwrapObject(res.data);
      return body['is_favorite'] == true ||
          (body['status']?.toString() == 'added');
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// PROMOTIONS
// ---------------------------------------------------------------------------

class PromotionService {
  final _dio = ApiClient.instance.dio;

  Future<List<PromotionModel>> list() async {
    try {
      final res = await _dio.get('/promotions');
      return _unwrapList(res.data).map(PromotionModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// All promotions for one vendor (incl. inactive/expired) — for the vendor's
  /// own management screen.
  Future<List<PromotionModel>> listForVendor(int vendorId) async {
    try {
      final res = await _dio.get('/promotions', queryParameters: {
        'vendor_id': vendorId,
        'active_only': 0,
        'per_page': 50,
      });
      return _unwrapList(res.data).map(PromotionModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Create a promotion for [vendorId] (vendor owner / admin authorized server-side).
  Future<PromotionModel> create({
    required int vendorId,
    required String titleAr,
    required String titleEn,
    String? descriptionAr,
    String? descriptionEn,
    String? image,
    String discountType = 'percent',
    double? discountValue,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) async {
    try {
      final res = await _dio.post('/promotions', data: {
        'vendor_id': vendorId,
        'title_ar': titleAr,
        'title_en': titleEn.isEmpty ? titleAr : titleEn,
        if (descriptionAr != null && descriptionAr.isNotEmpty)
          'description_ar': descriptionAr,
        if (descriptionEn != null && descriptionEn.isNotEmpty)
          'description_en': descriptionEn,
        if (image != null && image.isNotEmpty) 'image': image,
        'discount_type': discountType,
        'discount_value': ?discountValue,
        if (startDate != null) 'start_date': _ymd(startDate),
        if (endDate != null) 'end_date': _ymd(endDate),
        'is_active': isActive,
      });
      return PromotionModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/promotions/$id');
    } catch (e) {
      throw toApiException(e);
    }
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// HOME STATS
// ---------------------------------------------------------------------------

class HomeStats {
  const HomeStats({
    this.vendors = 0,
    this.users = 0,
    this.likes = 0,
    this.visitors = 0,
    this.offers = 0,
    this.cities = 0,
  });

  final int vendors;
  final int users;
  final int likes;
  final int visitors;
  final int offers;
  final int cities;

  factory HomeStats.fromJson(Map<String, dynamic> json) => HomeStats(
        vendors: (json['vendors'] as num?)?.toInt() ?? 0,
        users: (json['users'] as num?)?.toInt() ?? 0,
        likes: (json['likes'] as num?)?.toInt() ?? 0,
        visitors: (json['visitors'] as num?)?.toInt() ?? 0,
        offers: (json['offers'] as num?)?.toInt() ?? 0,
        cities: (json['cities'] as num?)?.toInt() ?? 0,
      );
}

class StatsService {
  final _dio = ApiClient.instance.dio;

  Future<HomeStats> get() async {
    try {
      final res = await _dio.get('/stats');
      final m = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      return HomeStats.fromJson(m);
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// SETTINGS / SOCIAL LINKS
// ---------------------------------------------------------------------------

/// Social-media links configured from the admin panel, shown in the app footer.
class SocialLinks {
  const SocialLinks({this.instagram, this.facebook, this.tiktok, this.whatsapp});

  final String? instagram;
  final String? facebook;
  final String? tiktok;
  final String? whatsapp;

  static String? _clean(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory SocialLinks.fromJson(Map<String, dynamic> json) => SocialLinks(
        instagram: _clean(json['instagram']),
        facebook: _clean(json['facebook']),
        tiktok: _clean(json['tiktok']),
        whatsapp: _clean(json['whatsapp']),
      );

  bool get isEmpty =>
      instagram == null && facebook == null && tiktok == null && whatsapp == null;
}

class SettingsService {
  final _dio = ApiClient.instance.dio;

  /// Public: social-media links for the footer. Returns empty links on failure
  /// so the footer degrades gracefully.
  Future<SocialLinks> social() async {
    try {
      final res = await _dio.get('/social-links');
      final m = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      return SocialLinks.fromJson(m);
    } catch (_) {
      return const SocialLinks();
    }
  }
}

// ---------------------------------------------------------------------------
// REVIEWS
// ---------------------------------------------------------------------------

class ReviewService {
  final _dio = ApiClient.instance.dio;

  Future<List<ReviewModel>> listForVendor(int vendorId) async {
    try {
      final res = await _dio
          .get('/reviews', queryParameters: {'vendor_id': vendorId});
      return _unwrapList(res.data).map(ReviewModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Paginated reviews for a vendor. Returns the page items plus the real
  /// [total] count (from the server's paginator) and whether more pages exist.
  Future<({List<ReviewModel> items, int total, bool hasMore})>
      listPagedForVendor(int vendorId, {int page = 1, int perPage = 15}) async {
    try {
      final res = await _dio.get('/reviews', queryParameters: {
        'vendor_id': vendorId,
        'page': page,
        'per_page': perPage,
      });
      final body = res.data;
      final items = _unwrapList(body).map(ReviewModel.fromJson).toList();
      var total = items.length;
      var hasMore = false;
      if (body is Map) {
        final t = body['total'];
        if (t is num) total = t.toInt();
        final cp = body['current_page'];
        final lp = body['last_page'];
        if (cp is num && lp is num) hasMore = cp.toInt() < lp.toInt();
      }
      return (items: items, total: total, hasMore: hasMore);
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<ReviewModel> create({
    required int vendorId,
    required double rating,
    String? comment,
  }) async {
    try {
      final res = await _dio.post('/reviews', data: {
        'vendor_id': vendorId,
        'rating': rating.round(),
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
      return ReviewModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// STORY
// ---------------------------------------------------------------------------

class StoryService {
  final _dio = ApiClient.instance.dio;

  Future<List<StoryModel>> listForVendor(int vendorId) async {
    try {
      final res = await _dio.get('/stories', queryParameters: {
        'vendor_id': vendorId,
        'per_page': 30,
      });
      return _unwrapList(res.data).map(StoryModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// All active/approved stories across every vendor (each carries its vendor),
  /// newest first — used by the app-wide stories screen.
  Future<List<StoryModel>> listAll({int perPage = 200}) async {
    try {
      final res = await _dio.get('/stories', queryParameters: {
        'per_page': perPage,
      });
      return _unwrapList(res.data).map(StoryModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Create a story for [vendorId]. The owner of the vendor (or an admin)
  /// is authorized server-side. [image] is a public URL from UploadService.
  Future<StoryModel> create({
    required int vendorId,
    required String image,
    String? captionAr,
    String? captionEn,
    DateTime? expiresAt,
  }) async {
    try {
      final res = await _dio.post('/stories', data: {
        'vendor_id': vendorId,
        'image': image,
        if (captionAr != null && captionAr.isNotEmpty) 'caption_ar': captionAr,
        if (captionEn != null && captionEn.isNotEmpty) 'caption_en': captionEn,
        if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
      });
      return StoryModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/stories/$id');
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<List<VendorStoriesGroup>> feed() async {
    try {
      final res = await _dio.get('/stories/feed');
      final body = res.data;
      final list = (body is Map && body['data'] is List)
          ? List<dynamic>.from(body['data'] as List)
          : (body is List ? List<dynamic>.from(body) : const []);
      return list
          .whereType<Map>()
          .map((m) => VendorStoriesGroup.fromJson(
              Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// HIGHLIGHTS (دائمة)
// ---------------------------------------------------------------------------

class HighlightService {
  final _dio = ApiClient.instance.dio;

  /// Active highlights (with their items) for a vendor profile.
  Future<List<HighlightModel>> listForVendor(int vendorId) async {
    try {
      final res = await _dio.get('/highlights', queryParameters: {
        'vendor_id': vendorId,
        'per_page': 50,
      });
      return _unwrapList(res.data).map(HighlightModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<HighlightModel> create({
    required int vendorId,
    required String title,
    String? coverImage,
    int? sortOrder,
  }) async {
    try {
      final res = await _dio.post('/highlights', data: {
        'vendor_id': vendorId,
        'title': title,
        if (coverImage != null && coverImage.isNotEmpty) 'cover_image': coverImage,
        'sort_order': ?sortOrder,
      });
      return HighlightModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<HighlightModel> update(
    int id, {
    String? title,
    String? coverImage,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final res = await _dio.put('/highlights/$id', data: {
        'title': ?title,
        'cover_image': ?coverImage,
        'sort_order': ?sortOrder,
        'is_active': ?isActive,
      });
      return HighlightModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/highlights/$id');
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Add one media item (image/video URL from UploadService) to a highlight.
  Future<HighlightItemModel> addItem({
    required int highlightId,
    required String mediaUrl,
    String type = 'image',
    String? caption,
    int? sortOrder,
  }) async {
    try {
      final res = await _dio.post('/highlight-items', data: {
        'highlight_id': highlightId,
        'type': type,
        'media_url': mediaUrl,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        'sort_order': ?sortOrder,
      });
      return HighlightItemModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> deleteItem(int itemId) async {
    try {
      await _dio.delete('/highlight-items/$itemId');
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// SLIDER
// ---------------------------------------------------------------------------

class SliderService {
  final _dio = ApiClient.instance.dio;

  Future<List<SliderModel>> list({int limit = 10}) async {
    try {
      final res = await _dio.get('/sliders', queryParameters: {
        'limit': limit,
      });
      return _unwrapList(res.data).map(SliderModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// NOTIFICATIONS
// ---------------------------------------------------------------------------

class NotificationService {
  final _dio = ApiClient.instance.dio;

  Future<List<NotificationModel>> list({int limit = 50, bool unreadOnly = false}) async {
    try {
      final res = await _dio.get('/notifications', queryParameters: {
        'limit': limit,
        if (unreadOnly) 'unread_only': 1,
      });
      return _unwrapList(res.data).map(NotificationModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<int> unreadCount() async {
    try {
      final res = await _dio.get('/notifications/unread-count');
      final data = res.data;
      if (data is Map && data['count'] != null) {
        return int.tryParse(data['count'].toString()) ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markRead(int id) async {
    try {
      await _dio.post('/notifications/$id/read');
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post('/notifications/read-all');
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// STORE PRODUCTS
// ---------------------------------------------------------------------------

class ProductService {
  final _dio = ApiClient.instance.dio;

  Future<List<ProductModel>> list({
    int? vendorId,
    int? sectionId,
    bool mine = false,
    bool availableOnly = false,
  }) async {
    try {
      final res = await _dio.get('/products', queryParameters: {
        'vendor_id': ?vendorId,
        'section_id': ?sectionId,
        if (mine) 'mine': 1,
        if (availableOnly) 'available_only': 1,
        'per_page': 200,
      });
      return _unwrapList(res.data).map(ProductModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<ProductModel> show(int id) async {
    try {
      final res = await _dio.get('/products/$id');
      return ProductModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<ProductModel> create({
    required int vendorId,
    required String nameAr,
    String? nameEn,
    required double price,
    double? discountPrice,
    String? descriptionAr,
    String? image,
    List<String>? images,
    int? sectionId,
    bool isAvailable = true,
  }) async {
    try {
      final res = await _dio.post('/products', data: {
        'vendor_id': vendorId,
        'name_ar': nameAr,
        'name_en': ?nameEn,
        'price': price,
        'discount_price': ?discountPrice,
        'description_ar': ?descriptionAr,
        'image': ?image,
        'images': ?images,
        'section_id': sectionId,
        'is_available': isAvailable,
      });
      return ProductModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<ProductModel> update(int id, {
    String? nameAr,
    String? nameEn,
    double? price,
    double? discountPrice,
    String? descriptionAr,
    String? image,
    List<String>? images,
    int? sectionId,
    bool clearSection = false,
    bool? isAvailable,
  }) async {
    try {
      final res = await _dio.put('/products/$id', data: {
        'name_ar': ?nameAr,
        'name_en': ?nameEn,
        'price': ?price,
        'discount_price': ?discountPrice,
        'description_ar': ?descriptionAr,
        'image': ?image,
        'images': ?images,
        if (clearSection) 'section_id': null else 'section_id': ?sectionId,
        'is_available': ?isAvailable,
      });
      return ProductModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/products/$id');
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// STORE PRODUCT SECTIONS
// ---------------------------------------------------------------------------

class ProductSectionService {
  final _dio = ApiClient.instance.dio;

  Future<List<ProductSectionModel>> list({int? vendorId, bool mine = false}) async {
    try {
      final res = await _dio.get('/product-sections', queryParameters: {
        'vendor_id': ?vendorId,
        if (mine) 'mine': 1,
        'per_page': 200,
      });
      return _unwrapList(res.data).map(ProductSectionModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<ProductSectionModel> create({
    required int vendorId,
    required String nameAr,
    int? sort,
  }) async {
    try {
      final res = await _dio.post('/product-sections', data: {
        'vendor_id': vendorId,
        'name_ar': nameAr,
        'sort': ?sort,
      });
      return ProductSectionModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<ProductSectionModel> update(int id, {String? nameAr, int? sort}) async {
    try {
      final res = await _dio.put('/product-sections/$id', data: {
        'name_ar': ?nameAr,
        'sort': ?sort,
      });
      return ProductSectionModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/product-sections/$id');
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// STORE ORDERS
// ---------------------------------------------------------------------------

class OrderService {
  final _dio = ApiClient.instance.dio;

  Future<List<OrderModel>> list({int? vendorId, String? status}) async {
    try {
      final res = await _dio.get('/orders', queryParameters: {
        'vendor_id': ?vendorId,
        'status': ?status,
        'per_page': 50,
      });
      return _unwrapList(res.data).map(OrderModel.fromJson).toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Places an order (invoice) for [vendorId] with a map of productId → quantity.
  Future<OrderModel> create({
    required int vendorId,
    required Map<int, int> quantities,
    String? customerName,
    String? customerPhone,
    String? note,
  }) async {
    try {
      final items = quantities.entries
          .where((e) => e.value > 0)
          .map((e) => {'product_id': e.key, 'quantity': e.value})
          .toList();
      final res = await _dio.post('/orders', data: {
        'vendor_id': vendorId,
        'items': items,
        'customer_name': ?customerName,
        'customer_phone': ?customerPhone,
        'note': ?note,
      });
      return OrderModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<OrderModel> updateStatus(int id, String status) async {
    try {
      final res = await _dio.put('/orders/$id', data: {'status': status});
      return OrderModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// COMPETITION (توقّع النتيجة)
// ---------------------------------------------------------------------------

class CompetitionService {
  final _dio = ApiClient.instance.dio;

  /// The active competition + the caller's prediction (by account or device).
  Future<({CompetitionModel? competition, PredictionModel? prediction})>
      getActive({String? deviceId}) async {
    try {
      final res = await _dio.get('/competition/active',
          queryParameters: {'device_id': ?deviceId});
      final body = res.data;
      final map =
          body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
      final data = map['data'];
      final pred = map['my_prediction'];
      return (
        competition: data is Map
            ? CompetitionModel.fromJson(Map<String, dynamic>.from(data))
            : null,
        prediction: pred is Map
            ? PredictionModel.fromJson(Map<String, dynamic>.from(pred))
            : null,
      );
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<PredictionModel> predict(int competitionId,
      {required String winner,
      String? score,
      String? deviceId,
      String? platform,
      String? guestName}) async {
    try {
      final res = await _dio.post('/competition/$competitionId/predict', data: {
        'winner': winner,
        'score': ?score,
        'device_id': ?deviceId,
        'platform': ?platform,
        'guest_name': ?guestName,
      });
      return PredictionModel.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }
}

// ---------------------------------------------------------------------------
// POINTS / REWARDS
// ---------------------------------------------------------------------------

/// Result of a successful points redemption at a vendor.
class RedeemResult {
  const RedeemResult({
    required this.balance,
    required this.discount,
    required this.beneficiaries,
    required this.message,
  });
  final int balance;
  final int discount;
  final int beneficiaries;
  final String message;
}

class PointsService {
  final _dio = ApiClient.instance.dio;

  /// The signed-in user's points summary (balance, breakdown, history, code).
  Future<PointsSummary> summary() async {
    try {
      final res = await _dio.get('/points/summary');
      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) throw _err(res.data);
      return PointsSummary.fromJson(_unwrapObject(res.data));
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Redeem points at a vendor for an in-person discount. Because Dio treats
  /// 4xx as a normal response (validateStatus < 500), we inspect the status and
  /// surface the server's Arabic message on insufficient balance / cooldown.
  Future<RedeemResult> redeem(int vendorId) async {
    try {
      final res = await _dio.post('/vendors/$vendorId/redeem-points');
      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) throw _err(res.data);
      final m = _unwrapObject(res.data);
      return RedeemResult(
        balance: (m['balance'] as num?)?.toInt() ?? 0,
        discount: (m['discount'] as num?)?.toInt() ?? 10,
        beneficiaries: (m['beneficiaries_count'] as num?)?.toInt() ?? 0,
        message: (m['message'] ?? 'تم استبدال النقاط').toString(),
      );
    } catch (e) {
      throw toApiException(e);
    }
  }

  Exception _err(dynamic data) => ApiException(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'تعذّرت العملية',
      );
}
