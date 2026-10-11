import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'auth_storage.dart';

/// Singleton API client wrapping Dio.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _resolveBaseUrl(),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          // The language the app is showing, so the server's validation
          // lines come back in it. Our own header, not Accept-Language,
          // which browsers set by themselves. Arabic is the only one for now.
          'X-App-Locale': 'ar',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthStorage.instance.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        // A 401 on an authenticated request means the token was revoked
        // (e.g. the admin stopped this account) — force a global logout.
        // Note: 401 arrives here (not onError) because validateStatus allows
        // any status < 500 through as a normal response.
        onResponse: (response, handler) {
          if (response.statusCode == 401 &&
              response.requestOptions.headers.containsKey('Authorization')) {
            onUnauthorized?.call();
          }
          handler.next(response);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;
  Dio get dio => _dio;

  /// Invoked when an authenticated request is rejected with 401 (token revoked
  /// / account stopped). The session controller registers a forced-logout here.
  void Function()? onUnauthorized;

  /// Picks the correct backend URL for the runtime platform.
  /// - Android emulator: host machine is 10.0.2.2
  /// - iOS simulator / desktop / web: localhost
  String _resolveBaseUrl() {
    if (kIsWeb) return '  ';
    try {
      if (Platform.isAndroid) return 'https://afrahna.co/admin/api/v1';
    } catch (_) {}
    return 'https://afrahna.co/admin/api/v1';
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  /// From a JSON error body (`message`, optional `errors` map), with every
  /// line in Arabic. A server from before the Arabic language file answers
  /// in English; [arabicize] turns the handful of Laravel sentences the app
  /// can meet into the lines the Arabic file would have sent.
  factory ApiException.fromBody(
    dynamic data, {
    int? statusCode,
    String fallback = 'حدث خطأ ما',
  }) {
    var message = fallback;
    Map<String, dynamic>? errors;
    if (data is Map) {
      if (data['message'] != null) message = arabicize(data['message'].toString());
      if (data['errors'] is Map) {
        errors = {
          for (final e in (data['errors'] as Map).entries)
            e.key.toString(): e.value is List
                ? [for (final v in e.value as List) arabicize(v.toString())]
                : arabicize(e.value.toString()),
        };
      }
    }
    return ApiException(message, statusCode: statusCode, errors: errors);
  }

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  @override
  String toString() => message;
}

/// Field names as the screens call them, for [arabicize].
const Map<String, String> _arabicAttributes = {
  'phone': 'رقم الجوال',
  'name': 'الاسم',
  'email': 'البريد الإلكتروني',
  'password': 'كلمة المرور',
  'referral code': 'كود الدعوة',
};

/// The English sentences Laravel's default language file produces for the
/// mistakes a sign-up or a form can make, said in Arabic. Anything else is
/// returned untouched. The server speaks Arabic itself now; this covers the
/// window before it was updated and any line it has no translation for.
String arabicize(String message) {
  String attr(String raw) => _arabicAttributes[raw.toLowerCase()] ?? raw;
  final rules = <RegExp, String Function(Match)>{
    RegExp(r'^The (.+) has already been taken\.$'): (m) =>
        m[1]!.toLowerCase() == 'phone'
            ? 'رقم الجوال هذا مسجّل مسبقًا. سجّل الدخول به أو استخدم رقمًا آخر.'
            : '${attr(m[1]!)} مستخدم مسبقًا.',
    RegExp(r'^The (.+) field is required\.$'): (m) => '${attr(m[1]!)} مطلوب.',
    RegExp(r'^The (.+) must be a valid email address\.$'): (m) =>
        '${attr(m[1]!)} غير صحيح.',
    RegExp(r'^The (.+) confirmation does not match\.$'): (_) =>
        'كلمتا المرور غير متطابقتين.',
    RegExp(r'^The (.+) must be at least (\d+) characters\.$'): (m) =>
        'يجب ألا يقل طول ${attr(m[1]!)} عن ${m[2]} أحرف.',
    RegExp(r'^The (.+) must not be greater than (\d+) characters\.$'): (m) =>
        'يجب ألا يتجاوز طول ${attr(m[1]!)} ${m[2]} حرفًا.',
    RegExp(r'^The selected (.+) is invalid\.$'): (m) =>
        '${attr(m[1]!)} غير موجود.',
    RegExp(r'^The given data was invalid\.$'): (_) => 'بعض البيانات غير صحيحة.',
    RegExp(r'^Unauthenticated\.$'): (_) => 'يلزم تسجيل الدخول.',
  };
  for (final e in rules.entries) {
    final m = e.key.firstMatch(message.trim());
    if (m != null) return e.value(m);
  }
  return message;
}

/// Convert a Dio error / non-2xx response into a friendly Arabic message.
ApiException toApiException(Object error) {
  // Already ours: hand it back whole. Re-wrapping kept the message and lost
  // the field errors and the status that came with it.
  if (error is ApiException) return error;
  if (error is DioException) {
    final res = error.response;
    if (res != null) {
      return ApiException.fromBody(res.data, statusCode: res.statusCode);
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiException('انتهت مهلة الاتصال بالخادم');
    }
    if (error.type == DioExceptionType.connectionError) {
      return ApiException('تعذّر الاتصال بالخادم. تأكد من تشغيل الـ API.');
    }
    return ApiException(error.message ?? 'خطأ غير متوقع');
  }
  return ApiException(error.toString());
}
