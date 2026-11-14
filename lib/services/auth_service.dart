import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

class AuthService {

  // =====================================
  // تسجيل دخول ولي الأمر
  // =====================================

  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phone.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 20));

      final dynamic data =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map<String, dynamic>) {
        throw Exception(
          'استجابة غير صحيحة من الخادم.',
        );
      }

      if (response.statusCode == 200 &&
          data['success'] == true &&
          data['token'] is String &&
          (data['token'] as String).isNotEmpty) {
        return data;
      }

      throw Exception(
        data['message']?.toString() ??
            'فشل تسجيل الدخول.',
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
  // إنشاء حساب ولي أمر جديد
  // =====================================

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String middleName,
    required String lastName,
    required String phone,

    // مدينة إقامة ولي الأمر (إجبارية)
    required String city,

    required String password,
  }) async {
    try {

      // رقم الهاتف المحلي المكون من 9 أرقام
      final String localPhone = phone.trim();

      // إضافة مفتاح اليمن عند الحاجة
      final String fullPhone =
      localPhone.startsWith('967')
          ? localPhone
          : '967$localPhone';

      // إرسال بيانات التسجيل إلى Laravel
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/register'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'first_name': firstName.trim(),
          'middle_name': middleName.trim(),
          'last_name': lastName.trim(),
          'phone': fullPhone,

          // إرسال المدينة المختارة إلى Laravel
          'city': city.trim(),

          'password': password,
        }),
      ).timeout(const Duration(seconds: 20));

      // قراءة استجابة Laravel
      final dynamic data =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map<String, dynamic>) {
        throw Exception(
          'استجابة غير صحيحة من الخادم.',
        );
      }

      // نجاح إنشاء الحساب
      if (response.statusCode == 201 &&
          data['success'] == true &&
          data['token'] is String &&
          (data['token'] as String).isNotEmpty) {
        return data;
      }

      // معالجة أخطاء التحقق من Laravel
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
            'تعذر إنشاء الحساب.',
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
  // جلب بيانات ولي الأمر من Laravel
  // GET /api/user
  // =====================================

  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      const storage = FlutterSecureStorage();

      // قراءة التوكن المحفوظ بعد تسجيل الدخول
      final String? token =
      await storage.read(key: 'auth_token');

      if (token == null || token.isEmpty) {
        throw Exception(
          'يجب تسجيل الدخول أولاً.',
        );
      }

      // إرسال طلب جلب بيانات الحساب
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 401) {
        throw Exception(
          'انتهت جلسة تسجيل الدخول. سجلي الدخول مجددًا.',
        );
      }

      final dynamic data =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 &&
          data is Map<String, dynamic>) {

        // يدعم الاستجابة المباشرة أو المغلفة بـ user
        if (data['user'] is Map) {
          return Map<String, dynamic>.from(
            data['user'] as Map,
          );
        }

        return data;
      }

      throw Exception(
        data is Map
            ? (data['message']?.toString() ??
            'تعذر جلب بيانات ولي الأمر.')
            : 'تعذر جلب بيانات ولي الأمر.',
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
        'تعذر قراءة بيانات ولي الأمر من الخادم.',
      );
    }
  }

  // =====================================
  // تعديل بيانات ولي الأمر
  // PUT /api/user
  // =====================================

  static Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String middleName,
    required String lastName,
    required String phone,
  }) async {
    try {
      const storage = FlutterSecureStorage();

      // قراءة التوكن المحفوظ
      final String? token =
      await storage.read(key: 'auth_token');

      if (token == null || token.isEmpty) {
        throw Exception(
          'يجب تسجيل الدخول أولاً.',
        );
      }

      // إرسال البيانات الجديدة إلى Laravel
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/user'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'first_name': firstName.trim(),
          'middle_name': middleName.trim(),
          'last_name': lastName.trim(),
          'phone': phone.trim(),
        }),
      ).timeout(const Duration(seconds: 20));

      final dynamic data =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map<String, dynamic>) {
        throw Exception(
          'استجابة غير صحيحة من الخادم.',
        );
      }

      // نجاح تعديل بيانات ولي الأمر
      if (response.statusCode == 200 &&
          data['success'] == true &&
          data['user'] is Map) {
        return Map<String, dynamic>.from(
          data['user'] as Map,
        );
      }

      // انتهاء صلاحية التوكن أو عدم تسجيل الدخول
      if (response.statusCode == 401) {
        throw Exception(
          'انتهت جلسة تسجيل الدخول. سجلي الدخول مجددًا.',
        );
      }

      // أخطاء التحقق من البيانات
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
            'تعذر تحديث بيانات ولي الأمر.',
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
  // تغيير كلمة مرور ولي الأمر
  // PUT /api/user/change-password
  // =====================================

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      const storage = FlutterSecureStorage();

      // قراءة توكن ولي الأمر المسجل دخوله
      final String? token =
      await storage.read(key: 'auth_token');

      if (token == null || token.isEmpty) {
        throw Exception(
          'يجب تسجيل الدخول أولاً.',
        );
      }

      // إرسال كلمات المرور إلى Laravel
      final response = await http.put(
        Uri.parse(
          '${ApiConfig.baseUrl}/user/change-password',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': confirmPassword,
        }),
      ).timeout(const Duration(seconds: 20));

      // قراءة استجابة Laravel
      final dynamic data =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map<String, dynamic>) {
        throw Exception(
          'استجابة غير صحيحة من الخادم.',
        );
      }

      // انتهاء جلسة تسجيل الدخول
      if (response.statusCode == 401) {
        throw Exception(
          'انتهت جلسة تسجيل الدخول. سجلي الدخول مجددًا.',
        );
      }

      // معالجة أخطاء التحقق من البيانات
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

        throw Exception(
          data['message']?.toString() ??
              'تعذر التحقق من كلمات المرور.',
        );
      }

      // نجاح تغيير كلمة المرور فعليًا
      if (response.statusCode == 200 &&
          data['success'] == true) {
        return data;
      }

      // أي خطأ آخر من Laravel
      throw Exception(
        data['message']?.toString() ??
            'تعذر تغيير كلمة المرور.',
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