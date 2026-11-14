import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

class ReportService {
  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  // =====================================
  // تنسيق التاريخ
  // =====================================

  static String _formatDate(DateTime date) {
    final String year =
    date.year.toString().padLeft(4, '0');

    final String month =
    date.month.toString().padLeft(2, '0');

    final String day =
    date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // =====================================
  // قراءة Token
  // =====================================

  static Future<String> _getToken() async {
    final String? token =
    await _storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    return token;
  }

  // =====================================
  // إنشاء تقرير للطفل من Laravel
  // POST /api/reports/generate
  // =====================================

  static Future<Map<String, dynamic>> generateReport({
    required int childId,
    required String reportType,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final String token = await _getToken();

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/reports/generate',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'child_id': childId,
          'report_type': reportType,
          'start_date': _formatDate(startDate),
          'end_date': _formatDate(endDate),
        }),
      ).timeout(
        const Duration(seconds: 30),
      );

      final dynamic decodedData =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (decodedData is! Map<String, dynamic>) {
        throw Exception('استجابة غير صحيحة من الخادم.');
      }

      if (response.statusCode == 401) {
        throw Exception(
          'انتهت جلسة تسجيل الدخول. سجلي الدخول مجددًا.',
        );
      }

      if (response.statusCode == 403) {
        throw Exception(
          decodedData['message']?.toString() ??
              'ليس لديك صلاحية لإنشاء التقرير.',
        );
      }

      if (response.statusCode == 422) {
        _throwValidationError(decodedData);
      }

      if (response.statusCode == 200 &&
          decodedData['success'] == true &&
          decodedData['report'] is Map) {
        return Map<String, dynamic>.from(
          decodedData['report'] as Map,
        );
      }

      throw Exception(
        decodedData['message']?.toString() ??
            'تعذر إنشاء التقرير.',
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
  // جلب التحليل الصحي الشامل
  // GET /api/health-analysis
  // =====================================

  static Future<Map<String, dynamic>> getHealthAnalysis({
    required int childId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final String token = await _getToken();

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/health-analysis',
      ).replace(
        queryParameters: {
          'child_id': childId.toString(),
          'start_date': _formatDate(startDate),
          'end_date': _formatDate(endDate),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
      );

      final dynamic decodedData =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (decodedData is! Map<String, dynamic>) {
        throw Exception('استجابة التحليل غير صحيحة.');
      }

      if (response.statusCode == 401) {
        throw Exception(
          'انتهت جلسة تسجيل الدخول. سجلي الدخول مجددًا.',
        );
      }

      if (response.statusCode == 403) {
        throw Exception(
          decodedData['message']?.toString() ??
              'ليس لديك صلاحية لعرض التحليل.',
        );
      }

      if (response.statusCode == 422) {
        _throwValidationError(decodedData);
      }

      if (response.statusCode == 404) {
        throw Exception(
          decodedData['message']?.toString() ??
              'الطفل غير موجود.',
        );
      }

      if (response.statusCode == 200 &&
          decodedData['success'] == true &&
          decodedData['analysis'] is Map) {
        return Map<String, dynamic>.from(
          decodedData['analysis'] as Map,
        );
      }

      throw Exception(
        decodedData['message']?.toString() ??
            'تعذر جلب التحليل الصحي.',
      );

    } on TimeoutException {
      throw Exception(
        'انتهت مهلة الاتصال أثناء جلب التحليل.',
      );

    } on http.ClientException {
      throw Exception(
        'تعذر الاتصال بالخادم. تأكدي أن Laravel يعمل.',
      );

    } on FormatException {
      throw Exception(
        'تعذر قراءة استجابة التحليل.',
      );
    }
  }

  // =====================================
  // حفظ التقرير الصحي
  // POST /api/reports
  // =====================================

  static Future<Map<String, dynamic>> saveReport({
    required int childId,
    required String reportType,
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> reportData,
    String? title,
    String? summary,
  }) async {
    try {
      final String token = await _getToken();

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/reports',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'child_id': childId,
          'report_type': reportType,
          'title': title,
          'start_date': _formatDate(startDate),
          'end_date': _formatDate(endDate),
          'summary': summary,
          'report_data': reportData,
        }),
      ).timeout(
        const Duration(seconds: 30),
      );

      final dynamic decodedData =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (decodedData is! Map<String, dynamic>) {
        throw Exception('استجابة حفظ التقرير غير صحيحة.');
      }

      if (response.statusCode == 401) {
        throw Exception(
          'انتهت جلسة تسجيل الدخول. سجلي الدخول مجددًا.',
        );
      }

      if (response.statusCode == 403) {
        throw Exception(
          decodedData['message']?.toString() ??
              'ليس لديك صلاحية لحفظ التقرير.',
        );
      }

      if (response.statusCode == 404) {
        throw Exception(
          decodedData['message']?.toString() ??
              'الطفل غير موجود.',
        );
      }

      if (response.statusCode == 422) {
        _throwValidationError(decodedData);
      }

      if (response.statusCode == 201 &&
          decodedData['success'] == true &&
          decodedData['report'] is Map) {
        return Map<String, dynamic>.from(
          decodedData['report'] as Map,
        );
      }

      throw Exception(
        decodedData['message']?.toString() ??
            'تعذر حفظ التقرير.',
      );

    } on TimeoutException {
      throw Exception(
        'انتهت مهلة الاتصال أثناء حفظ التقرير.',
      );

    } on http.ClientException {
      throw Exception(
        'تعذر الاتصال بالخادم. تأكدي أن Laravel يعمل.',
      );

    } on FormatException {
      throw Exception(
        'تعذر قراءة استجابة حفظ التقرير.',
      );
    }
  }

  // =====================================
  // جلب التقارير المحفوظة
  // GET /api/reports
  // =====================================

  static Future<List<Map<String, dynamic>>> getSavedReports({
    int? childId,
    String? reportType,
  }) async {
    try {
      final String token = await _getToken();

      final Map<String, String> queryParameters = {};

      if (childId != null) {
        queryParameters['child_id'] = childId.toString();
      }

      if (reportType != null && reportType.isNotEmpty) {
        queryParameters['report_type'] = reportType;
      }

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/reports',
      ).replace(
        queryParameters: queryParameters.isEmpty
            ? null
            : queryParameters,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
      );

      final dynamic decodedData =
      jsonDecode(utf8.decode(response.bodyBytes));

      if (decodedData is! Map<String, dynamic>) {
        throw Exception('استجابة التقارير المحفوظة غير صحيحة.');
      }

      if (response.statusCode == 401) {
        throw Exception(
          'انتهت جلسة تسجيل الدخول. سجلي الدخول مجددًا.',
        );
      }

      if (response.statusCode == 403) {
        throw Exception(
          decodedData['message']?.toString() ??
              'ليس لديك صلاحية لعرض التقارير.',
        );
      }

      if (response.statusCode == 422) {
        _throwValidationError(decodedData);
      }

      if (response.statusCode == 200 &&
          decodedData['success'] == true &&
          decodedData['reports'] is List) {
        return (decodedData['reports'] as List)
            .whereType<Map>()
            .map(
              (report) => Map<String, dynamic>.from(report),
        )
            .toList();
      }

      throw Exception(
        decodedData['message']?.toString() ??
            'تعذر جلب التقارير المحفوظة.',
      );

    } on TimeoutException {
      throw Exception(
        'انتهت مهلة الاتصال أثناء جلب التقارير.',
      );

    } on http.ClientException {
      throw Exception(
        'تعذر الاتصال بالخادم. تأكدي أن Laravel يعمل.',
      );

    } on FormatException {
      throw Exception(
        'تعذر قراءة استجابة التقارير.',
      );
    }
  }

  // =====================================
  // معالجة أخطاء التحقق
  // =====================================

  static Never _throwValidationError(
      Map<String, dynamic> decodedData,
      ) {
    final dynamic errors = decodedData['errors'];

    if (errors is Map && errors.isNotEmpty) {
      final dynamic firstError = errors.values.first;

      if (firstError is List && firstError.isNotEmpty) {
        throw Exception(firstError.first.toString());
      }
    }

    throw Exception(
      decodedData['message']?.toString() ??
          'بيانات الطلب غير صحيحة.',
    );
  }
}