import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class ReminderService {
  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  // =====================================
  // الحصول على توكن تسجيل الدخول
  // =====================================

  static Future<String> _getToken() async {
    final String? token =
    await _storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('يجب تسجيل الدخول أولًا.');
    }

    return token;
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
        'Invalid server response',
      );
    }

    return decoded;
  }

  // =====================================
  // التعامل مع أخطاء Laravel
  // =====================================

  static  Never _checkError(
      http.Response response,
      Map<String, dynamic> data,
      String defaultMessage,
      ) {
    if (response.statusCode == 401) {
      throw Exception(
        'انتهت جلسة تسجيل الدخول. سجلي الدخول مجددًا.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        data['message']?.toString() ??
            'غير مسموح بتنفيذ العملية.',
      );
    }

    if (response.statusCode == 422) {
      final dynamic errors = data['errors'];

      if (errors is Map && errors.isNotEmpty) {
        final dynamic firstError = errors.values.first;

        if (firstError is List && firstError.isNotEmpty) {
          throw Exception(firstError.first.toString());
        }
      }
    }

    throw Exception(
      data['message']?.toString() ?? defaultMessage,
    );
  }

  // =====================================
  // جلب التذكيرات من Laravel
  // GET /api/reminders
  // =====================================

  static Future<List<Map<String, dynamic>>>
  getReminders() async {
    try {
      final String token = await _getToken();

      final http.Response response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reminders'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      final Map<String, dynamic> data =
      _decodeResponse(response);

      if (response.statusCode == 200 &&
          data['success'] == true) {
        final dynamic items = data['reminders'];

        if (items is! List) {
          throw const FormatException(
            'Invalid reminders list',
          );
        }

        return items.map<Map<String, dynamic>>((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
      }

      _checkError(
        response,
        data,
        'تعذر تحميل التذكيرات.',
      );
    } on TimeoutException {
      throw Exception(
        'انتهت مهلة الاتصال بالخادم. حاولي مرة أخرى.',
      );
    } on http.ClientException {
      throw Exception(
        'تعذر الاتصال بالخادم. تأكدي أن Laravel يعمل.',
      );
    } on FormatException {
      throw Exception(
        'تعذر قراءة بيانات التذكيرات من الخادم.',
      );
    } on TypeError {
      throw Exception(
        'تنسيق بيانات التذكيرات غير صحيح.',
      );
    }
  }

  // =====================================
  // حفظ تذكير جديد في Laravel
  // POST /api/reminders
  // =====================================

  static Future<Map<String, dynamic>> saveReminder({
    required String title,
    required DateTime remindAt,
    required bool isActive,
  }) async {
    try {
      final String token = await _getToken();

      final http.Response response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/reminders'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title.trim(),
          // إرسال الوقت UTC مع Z
          // حتى يُفهم بشكل صحيح في Laravel.
          'remind_at': remindAt.toUtc().toIso8601String(),
          'is_active': isActive,
        }),
      ).timeout(const Duration(seconds: 20));

      final Map<String, dynamic> data =
      _decodeResponse(response);

      if (response.statusCode == 201 &&
          data['success'] == true) {
        final dynamic reminder = data['reminder'];

        if (reminder is! Map) {
          throw const FormatException(
            'Invalid saved reminder',
          );
        }

        return Map<String, dynamic>.from(reminder);
      }

      _checkError(
        response,
        data,
        'تعذر حفظ التذكير.',
      );
    } on TimeoutException {
      throw Exception(
        'انتهت مهلة الاتصال بالخادم. حاولي مرة أخرى.',
      );
    } on http.ClientException {
      throw Exception(
        'تعذر الاتصال بالخادم. تأكدي أن Laravel يعمل.',
      );
    } on FormatException {
      throw Exception(
        'تعذر قراءة استجابة حفظ التذكير.',
      );
    }
  }

  // =====================================
  // حذف تذكير من Laravel
  // DELETE /api/reminders/{reminderId}
  // =====================================

  static Future<bool> deleteReminder({
    required int reminderId,
  }) async {
    try {
      final String token = await _getToken();

      final http.Response response = await http.delete(
        Uri.parse(
          '${ApiConfig.baseUrl}/reminders/$reminderId',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      final Map<String, dynamic> data =
      _decodeResponse(response);

      if (response.statusCode == 200 &&
          data['success'] == true) {
        return true;
      }

      _checkError(
        response,
        data,
        'تعذر حذف التذكير.',
      );
    } on TimeoutException {
      throw Exception(
        'انتهت مهلة الاتصال بالخادم. حاولي مرة أخرى.',
      );
    } on http.ClientException {
      throw Exception(
        'تعذر الاتصال بالخادم. تأكدي أن Laravel يعمل.',
      );
    } on FormatException {
      throw Exception(
        'تعذر قراءة استجابة حذف التذكير.',
      );
    }
  }
}