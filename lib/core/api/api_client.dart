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

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  @override
  String toString() => message;
}

/// Convert a Dio error / non-2xx response into a friendly Arabic message.
ApiException toApiException(Object error) {
  if (error is DioException) {
    final res = error.response;
    if (res != null) {
      final data = res.data;
      String message = 'حدث خطأ ما';
      Map<String, dynamic>? errors;
      if (data is Map) {
        message = (data['message'] ?? message).toString();
        if (data['errors'] is Map) {
          errors = Map<String, dynamic>.from(data['errors'] as Map);
        }
      }
      return ApiException(message, statusCode: res.statusCode, errors: errors);
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
