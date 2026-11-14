import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class MedicationService {
  // ===== START: ABEER - Medication API Service =====

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  // =====================================
  // جلب Token تسجيل الدخول
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
  // جلب أدوية طفل معين
  // GET /api/children/{childId}/medications
  // =====================================

  static Future<List<Map<String, dynamic>>> getMedications({
    required int childId,
  }) async {
    final response = await _sendRequest(
      method: 'GET',
      path: '/children/$childId/medications',
    );

    final data = _handleResponse(
      response,
      expectedStatusCode: 200,
      defaultError: 'تعذر جلب الأدوية.',
    );

    if (data['medications'] is! List) {
      throw Exception('بيانات الأدوية غير صحيحة.');
    }

    return (data['medications'] as List).map((item) {
      if (item is! Map<String, dynamic>) {
        throw Exception('بيانات أحد الأدوية غير صحيحة.');
      }

      return item;
    }).toList();
  }

  // =====================================
  // إضافة دواء جديد
  // POST /api/children/{childId}/medications
  // =====================================

  static Future<Map<String, dynamic>> addMedication({
    required int childId,
    required Map<String, dynamic> medicationData,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      path: '/children/$childId/medications',
      body: medicationData,
    );

    final data = _handleResponse(
      response,
      expectedStatusCode: 201,
      defaultError: 'تعذر حفظ الدواء.',
    );

    if (data['medication'] is! Map) {
      throw Exception('بيانات الدواء المحفوظ غير صحيحة.');
    }

    return Map<String, dynamic>.from(
      data['medication'] as Map,
    );
  }

  // =====================================
  // تعديل دواء موجود
  // PUT /api/children/{childId}/medications/{medicationId}
  // =====================================

  static Future<Map<String, dynamic>> updateMedication({
    required int childId,
    required int medicationId,
    required Map<String, dynamic> medicationData,
  }) async {
    final response = await _sendRequest(
      method: 'PUT',
      path: '/children/$childId/medications/$medicationId',
      body: medicationData,
    );

    final data = _handleResponse(
      response,
      expectedStatusCode: 200,
      defaultError: 'تعذر تعديل الدواء.',
    );

    if (data['medication'] is! Map) {
      throw Exception('بيانات الدواء المعدل غير صحيحة.');
    }

    return Map<String, dynamic>.from(
      data['medication'] as Map,
    );
  }

  // =====================================
  // حذف دواء
  // DELETE /api/children/{childId}/medications/{medicationId}
  // =====================================

  static Future<void> deleteMedication({
    required int childId,
    required int medicationId,
  }) async {
    final response = await _sendRequest(
      method: 'DELETE',
      path: '/children/$childId/medications/$medicationId',
    );

    _handleResponse(
      response,
      expectedStatusCode: 200,
      defaultError: 'تعذر حذف الدواء.',
    );
  }

  // =====================================
  // إرسال الطلب إلى Laravel
  // =====================================

  static Future<http.Response> _sendRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    try {
      final token = await _getToken();

      final uri = Uri.parse('${ApiConfig.baseUrl}$path');

      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      late final http.Response response;

      switch (method) {
        case 'GET':
          response = await http.get(
            uri,
            headers: headers,
          ).timeout(const Duration(seconds: 20));
          break;

        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 30));
          break;

        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 30));
          break;

        case 'DELETE':
          response = await http.delete(
            uri,
            headers: headers,
          ).timeout(const Duration(seconds: 20));
          break;

        default:
          throw Exception('نوع الطلب غير مدعوم.');
      }

      return response;
    } on TimeoutException {
      throw Exception(
        'انتهت مهلة الاتصال بالخادم. حاولي مرة أخرى.',
      );
    } on http.ClientException {
      throw Exception(
        'تعذر الاتصال بالخادم. تأكدي أن Laravel يعمل.',
      );
    }
  }

  // =====================================
  // قراءة استجابة Laravel ومعالجة الأخطاء
  // =====================================

  static Map<String, dynamic> _handleResponse(
      http.Response response, {
        required int expectedStatusCode,
        required String defaultError,
      }) {
    dynamic data;

    try {
      data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    } on FormatException {
      throw Exception('تعذر قراءة استجابة الخادم.');
    }

    if (data is! Map<String, dynamic>) {
      throw Exception('استجابة غير صحيحة من الخادم.');
    }

    if (response.statusCode == expectedStatusCode) {
      return data;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'انتهت صلاحية تسجيل الدخول. يرجى تسجيل الدخول مجددًا.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'الطفل أو الدواء غير موجود، أو لا تملكين صلاحية الوصول إليه.',
      );
    }

    if (response.statusCode == 422) {
      final errors = data['errors'];

      if (errors is Map && errors.isNotEmpty) {
        final firstError = errors.values.first;

        if (firstError is List && firstError.isNotEmpty) {
          throw Exception(firstError.first.toString());
        }
      }
    }

    throw Exception(
      data['message']?.toString() ?? defaultError,
    );
  }

// ===== END: ABEER - Medication API Service =====
}