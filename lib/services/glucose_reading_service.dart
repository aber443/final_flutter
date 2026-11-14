import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

class GlucoseReadingService {
  // =====================================
  // قراءة Token تسجيل الدخول
  // =====================================

  static Future<String> _getToken() async {
    const storage = FlutterSecureStorage();

    final String? token =
    await storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('يجب تسجيل الدخول أولًا.');
    }

    return token;
  }

  // =====================================
  // حفظ قراءة السكر في Laravel
  // POST /api/glucose-readings
  // =====================================

  static Future<Map<String, dynamic>> saveReading({
    required int childId,
    required String readingType,
    required double glucoseLevel,
    required String readingDate,
    required String readingTime,
    String? mealStatus,
    int? mealId,
  }) async {
    try {
      final String token = await _getToken();

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/glucose-readings',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'child_id': childId,
          'reading_type': readingType,
          'glucose_level': glucoseLevel,
          'unit': 'mg/dL',
          'reading_date': readingDate,
          'reading_time': readingTime,
          'meal_status': mealStatus,
          'meal_id': mealId,
        }),
      ).timeout(
        const Duration(seconds: 20),
      );

      final dynamic data =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map<String, dynamic>) {
        throw Exception(
          'استجابة غير صحيحة من الخادم.',
        );
      }

      if (response.statusCode == 201 &&
          data['success'] == true) {
        return data;
      }

      if (response.statusCode == 401) {
        throw Exception(
          'انتهت جلسة تسجيل الدخول. سجلي الدخول مجددًا.',
        );
      }

      if (response.statusCode == 422) {
        final errors = data['errors'];

        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;

          if (firstError is List &&
              firstError.isNotEmpty) {
            throw Exception(
              firstError.first.toString(),
            );
          }
        }
      }

      throw Exception(
        data['message']?.toString() ??
            'تعذر حفظ قراءة السكر.',
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
        'تعذر قراءة استجابة الخادم.',
      );
    }
  }

  // =====================================
  // جلب قراءات السكر للطفل من Laravel
  // GET /api/glucose-readings?child_id=...
  // =====================================

  static Future<List<Map<String, dynamic>>> getReadings({
    required int childId,
  }) async {
    try {
      final String token = await _getToken();

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/glucose-readings',
      ).replace(
        queryParameters: {
          'child_id': childId.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 20),
      );

      final dynamic data =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map<String, dynamic>) {
        throw Exception(
          'استجابة غير صحيحة من الخادم.',
        );
      }

      if (response.statusCode == 200 &&
          data['success'] == true) {
        final dynamic readings =
        data['glucose_readings'];

        if (readings is! List) {
          throw const FormatException(
            'Invalid glucose readings list',
          );
        }

        return readings.map<Map<String, dynamic>>((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
      }

      if (response.statusCode == 401) {
        throw Exception(
          'انتهت جلسة تسجيل الدخول. سجلي الدخول مجددًا.',
        );
      }

      throw Exception(
        data['message']?.toString() ??
            'تعذر تحميل قراءات السكر.',
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
        'تعذر قراءة بيانات قراءات السكر.',
      );
    } on TypeError {
      throw Exception(
        'تنسيق بيانات قراءات السكر غير صحيح.',
      );
    }
  }

  // =====================================
  // حذف قراءة السكر من Laravel
  // DELETE /api/glucose-readings/{readingId}
  // =====================================

  static Future<bool> deleteReading({
    required int readingId,
  }) async {
    try {
      final String token = await _getToken();

      final response = await http.delete(
        Uri.parse(
          '${ApiConfig.baseUrl}/glucose-readings/$readingId',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 20),
      );

      final dynamic data =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map<String, dynamic>) {
        throw Exception(
          'استجابة غير صحيحة من الخادم.',
        );
      }

      if (response.statusCode == 200 &&
          data['success'] == true) {
        return true;
      }

      if (response.statusCode == 401) {
        throw Exception(
          'انتهت جلسة تسجيل الدخول. سجلي الدخول مجددًا.',
        );
      }

      throw Exception(
        data['message']?.toString() ??
            'تعذر حذف قراءة السكر.',
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
        'تعذر قراءة استجابة الخادم.',
      );
    }
  }
}