
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

class ActivityService {
  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  // =====================================
  // جلب Token الخاص بولي الأمر
  // =====================================

  static Future<String> _getToken() async {
    final String? token =
    await _storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('يرجى تسجيل الدخول أولاً.');
    }

    return token;
  }

  // =====================================
  // إضافة نشاط جديد
  // POST /api/children/{childId}/activities
  // =====================================

  static Future<Map<String, dynamic>> addActivity({
    required int childId,
    required String activityName,
    required String duration,
    required String intensity,
    required String activityDate,
    required String activityTime,
  }) async {
    try {
      final String token = await _getToken();

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/children/$childId/activities',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'activity_name': activityName.trim(),
          'duration': duration,
          'intensity': intensity,
          'activity_date': activityDate,
          'activity_time': activityTime,
        }),
      ).timeout(const Duration(seconds: 20));

      final Map<String, dynamic> data =
      _decodeResponse(response);

      if (response.statusCode == 201 &&
          data['data'] is Map) {
        return Map<String, dynamic>.from(
          data['data'] as Map,
        );
      }

      _throwApiError(
        response.statusCode,
        data,
        'تعذر حفظ النشاط.',
      );
    } on TimeoutException {
      throw Exception(
        'انتهت مهلة الاتصال بالخادم. حاولي مرة أخرى.',
      );
    } on SocketException {
      throw Exception(
        'تعذر الاتصال بالخادم. تأكدي أن Laravel يعمل.',
      );
    } on http.ClientException {
      throw Exception(
        'تعذر الاتصال بالخادم. تأكدي من الاتصال بالشبكة.',
      );
    } on FormatException {
      throw Exception(
        'تعذر قراءة استجابة الخادم.',
      );
    }
  }

  // =====================================
  // جلب أنشطة الطفل
  // GET /api/children/{childId}/activities
  // =====================================

  static Future<List<Map<String, dynamic>>> getActivities({
    required int childId,
  }) async {
    try {
      final String token = await _getToken();

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/children/$childId/activities',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      final Map<String, dynamic> data =
      _decodeResponse(response);

      if (response.statusCode == 200 &&
          data['data'] is List) {
        final List<dynamic> activities =
        data['data'] as List<dynamic>;

        return activities.map((item) {
          if (item is! Map) {
            throw const FormatException(
              'بيانات النشاط غير صحيحة.',
            );
          }

          return Map<String, dynamic>.from(item);
        }).toList();
      }

      _throwApiError(
        response.statusCode,
        data,
        'تعذر جلب سجلات النشاط.',
      );
    } on TimeoutException {
      throw Exception(
        'انتهت مهلة الاتصال بالخادم. حاولي مرة أخرى.',
      );
    } on SocketException {
      throw Exception(
        'تعذر الاتصال بالخادم. تأكدي أن Laravel يعمل.',
      );
    } on http.ClientException {
      throw Exception(
        'تعذر الاتصال بالخادم. تأكدي من الاتصال بالشبكة.',
      );
    } on FormatException {
      throw Exception(
        'تعذر قراءة بيانات النشاط من الخادم.',
      );
    }
  }

  // =====================================
  // قراءة استجابة Laravel
  // =====================================

  static Map<String, dynamic> _decodeResponse(
      http.Response response,
      ) {
    final dynamic decoded =
    jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'استجابة غير صحيحة من الخادم.',
      );
    }

    return decoded;
  }

  // =====================================
  // معالجة أخطاء Laravel
  // =====================================

  static Never _throwApiError(
      int statusCode,
      Map<String, dynamic> data,
      String defaultMessage,
      ) {
    if (statusCode == 401) {
      throw Exception(
        'انتهت صلاحية تسجيل الدخول. يرجى تسجيل الدخول مجددًا.',
      );
    }

    if (statusCode == 404) {
      throw Exception(
        'الطفل غير موجود أو لا تملكين صلاحية الوصول إليه.',
      );
    }

    if (statusCode == 422) {
      final dynamic errors = data['errors'];

      if (errors is Map && errors.isNotEmpty) {
        final dynamic firstError = errors.values.first;

        if (firstError is List &&
            firstError.isNotEmpty) {
          throw Exception(firstError.first.toString());
        }
      }
    }

    throw Exception(
      data['message']?.toString() ?? defaultMessage,
    );
  }
}
