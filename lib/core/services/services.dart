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
  }) async {
    try {
      final res = await _dio.post('/auth/register', data: {
        'name': name,
        'phone': phone,
        'password': password,
        'password_confirmation': password,
        if (email != null && email.isNotEmpty) 'email': email,
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
      final res = await _dio.get('/cities');
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
    int? userId,
    int? delegateId,
    bool? activeOnly,
    int? perPage,
  }) async {
    try {
      final res = await _dio.get('/vendors', queryParameters: {
        if (categoryId != null) 'category_id': categoryId,
        if (parentCategoryId != null) 'parent_category_id': parentCategoryId,
        if (cityId != null) 'city_id': cityId,
        if (query != null && query.isNotEmpty) 'q': query,
        if (featured == true) 'featured': 1,
        if (verified == true) 'verified': 1,
        if (userId != null) 'user_id': userId,
        if (delegateId != null) 'delegate_id': delegateId,
        if (activeOnly != null) 'active_only': activeOnly ? 1 : 0,
        if (perPage != null) 'per_page': perPage,
      });
      return _unwrapList(res.data).map(VendorModel.fromJson).toList();
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
}

// ---------------------------------------------------------------------------
// UPLOAD (multipart file upload — images, etc.)
// ---------------------------------------------------------------------------

class UploadService {
  final _dio = ApiClient.instance.dio;

  /// Uploads a local file to the server and returns its public URL.
  /// [folder] groups files server-side, e.g. "vendors/logos".
  Future<String> uploadFile(String filePath, {String folder = 'general'}) async {
    try {
      final form = FormData.fromMap({
        'folder': folder,
        'file': await MultipartFile.fromFile(filePath),
      });
      final res = await _dio.post('/uploads', data: form);
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

  Future<List<ServiceModel>> list({int? vendorId, int? categoryId}) async {
    try {
      final res = await _dio.get('/services', queryParameters: {
        if (vendorId != null) 'vendor_id': vendorId,
        if (categoryId != null) 'category_id': categoryId,
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
        if (descriptionAr != null) 'description_ar': descriptionAr,
        if (descriptionEn != null) 'description_en': descriptionEn,
        if (discountPrice != null) 'discount_price': discountPrice,
        if (duration != null) 'duration': duration,
        if (image != null) 'image': image,
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
        if (nameAr != null) 'name_ar': nameAr,
        if (nameEn != null) 'name_en': nameEn,
        if (descriptionAr != null) 'description_ar': descriptionAr,
        if (descriptionEn != null) 'description_en': descriptionEn,
        if (price != null) 'price': price,
        if (discountPrice != null) 'discount_price': discountPrice,
        if (duration != null) 'duration': duration,
        if (image != null) 'image': image,
        if (isActive != null) 'is_active': isActive,
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
