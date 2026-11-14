import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class NotificationService {
  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const Duration _timeout = Duration(seconds: 20);

  // ==========================================
  // Get authentication token
  // ==========================================

  static Future<String> _getToken() async {
    final String? token =
    await _storage.read(key: 'auth_token');

    if (token == null || token.trim().isEmpty) {
      throw Exception(
        'انتهت جلسة تسجيل الدخول، يرجى تسجيل الدخول مجددًا.',
      );
    }

    return token.trim();
  }

  // ==========================================
  // Build headers
  // ==========================================

  static Future<Map<String, String>> _headers() async {
    final String token = await _getToken();

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ==========================================
  // Decode response
  // ==========================================

  static Map<String, dynamic> _decodeResponse(
      http.Response response,
      ) {
    if (response.body.trim().isEmpty) {
      return {};
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw const FormatException(
      'Invalid response format',
    );
  }

  // ==========================================
  // Handle API errors
  // ==========================================

  static void _checkResponse(
      http.Response response,
      Map<String, dynamic> data,
      ) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'انتهت جلسة تسجيل الدخول، يرجى تسجيل الدخول مجددًا.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'ليس لديك صلاحية لتنفيذ هذا الإجراء.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'الإشعار غير موجود أو تعذر الوصول إلى المسار.',
      );
    }

    final String message =
        data['message']?.toString() ??
            'حدث خطأ أثناء الاتصال بالخادم.';

    throw Exception(message);
  }

  // ==========================================
  // Handle connection errors
  // ==========================================

  static Future<T> _execute<T>(
      Future<T> Function() operation,
      ) async {
    try {
      return await operation();
    } on TimeoutException {
      throw Exception(
        'انتهت مهلة الاتصال بالخادم، يرجى المحاولة مجددًا.',
      );
    } on SocketException {
      throw Exception(
        'تعذر الاتصال بالخادم، تأكدي من تشغيل Laravel والاتصال بالشبكة.',
      );
    } on http.ClientException {
      throw Exception(
        'حدث خطأ في الاتصال بالخادم.',
      );
    } on FormatException {
      throw Exception(
        'استجابة الخادم غير صحيحة.',
      );
    }
  }

  // ==========================================
  // Get notifications
  // GET /api/notifications
  // ==========================================

  static Future<List<dynamic>> getNotifications() async {
    return _execute(() async {
      final http.Response response = await http
          .get(
        Uri.parse(
          '${ApiConfig.baseUrl}/notifications',
        ),
        headers: await _headers(),
      )
          .timeout(_timeout);

      final Map<String, dynamic> data =
      _decodeResponse(response);

      _checkResponse(response, data);

      final dynamic notifications =
      data['notifications'];

      if (notifications is List) {
        return notifications;
      }

      throw const FormatException(
        'Notifications list is missing',
      );
    });
  }

  // ==========================================
  // Mark one notification as read
  // PATCH /api/notifications/{id}/read
  // ==========================================

  static Future<void> markAsRead({
    required int notificationId,
  }) async {
    return _execute(() async {
      final http.Response response = await http
          .patch(
        Uri.parse(
          '${ApiConfig.baseUrl}/notifications/$notificationId/read',
        ),
        headers: await _headers(),
      )
          .timeout(_timeout);

      final Map<String, dynamic> data =
      _decodeResponse(response);

      _checkResponse(response, data);
    });
  }

  // ==========================================
  // Mark all notifications as read
  // PATCH /api/notifications/read-all
  // ==========================================

  static Future<void> markAllAsRead() async {
    return _execute(() async {
      final http.Response response = await http
          .patch(
        Uri.parse(
          '${ApiConfig.baseUrl}/notifications/read-all',
        ),
        headers: await _headers(),
      )
          .timeout(_timeout);

      final Map<String, dynamic> data =
      _decodeResponse(response);

      _checkResponse(response, data);
    });
  }

  // ==========================================
  // Delete notification
  // DELETE /api/notifications/{id}
  // ==========================================

  static Future<void> deleteNotification({
    required int notificationId,
  }) async {
    return _execute(() async {
      final http.Response response = await http
          .delete(
        Uri.parse(
          '${ApiConfig.baseUrl}/notifications/$notificationId',
        ),
        headers: await _headers(),
      )
          .timeout(_timeout);

      final Map<String, dynamic> data =
      _decodeResponse(response);

      _checkResponse(response, data);
    });
  }

  // ==========================================
  // Get notification settings
  // GET /api/notification-settings
  // ==========================================

  static Future<bool> getNotificationSettings() async {
    return _execute(() async {
      final http.Response response = await http
          .get(
        Uri.parse(
          '${ApiConfig.baseUrl}/notification-settings',
        ),
        headers: await _headers(),
      )
          .timeout(_timeout);

      final Map<String, dynamic> data =
      _decodeResponse(response);

      _checkResponse(response, data);

      final dynamic enabled =
      data['notifications_enabled'];

      if (enabled is bool) {
        return enabled;
      }

      throw const FormatException(
        'Notification settings value is missing',
      );
    });
  }

  // ==========================================
  // Update notification settings
  // PUT /api/notification-settings
  // ==========================================

  static Future<bool> updateNotificationSettings({
    required bool enabled,
  }) async {
    return _execute(() async {
      final http.Response response = await http
          .put(
        Uri.parse(
          '${ApiConfig.baseUrl}/notification-settings',
        ),
        headers: await _headers(),
        body: jsonEncode({
          'notifications_enabled': enabled,
        }),
      )
          .timeout(_timeout);

      final Map<String, dynamic> data =
      _decodeResponse(response);

      _checkResponse(response, data);

      final dynamic updatedValue =
      data['notifications_enabled'];

      if (updatedValue is bool) {
        return updatedValue;
      }

      throw const FormatException(
        'Updated notification settings value is missing',
      );
    });
  }
}