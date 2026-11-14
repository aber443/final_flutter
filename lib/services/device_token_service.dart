import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class DeviceTokenService {
  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const Duration _timeout =
  Duration(seconds: 20);

  static StreamSubscription<String>? _tokenSubscription;

  // ==========================================
  // Register Current Device
  // ==========================================

  static Future<void> registerDevice() async {
    final String? authToken =
    await _storage.read(key: 'auth_token');

    if (authToken == null || authToken.trim().isEmpty) {
      throw Exception('المستخدم غير مسجل الدخول.');
    }

    final String? fcmToken =
    await FirebaseMessaging.instance.getToken();

    if (fcmToken == null || fcmToken.isEmpty) {
      throw Exception('تعذر الحصول على FCM Token.');
    }

    await _sendToken(fcmToken);

    // متابعة تغيّر رمز Firebase
    await _tokenSubscription?.cancel();

    _tokenSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen(
              (newToken) async {
            try {
              await _sendToken(newToken);
            } catch (error) {
              print('FCM TOKEN UPDATE ERROR: $error');
            }
          },
        );
  }

  // ==========================================
  // Send Token To Laravel
  // ==========================================

  static Future<void> _sendToken(String fcmToken) async {
    final String? authToken =
    await _storage.read(key: 'auth_token');

    if (authToken == null || authToken.trim().isEmpty) {
      throw Exception('انتهت جلسة تسجيل الدخول.');
    }

    final String platform =
    Platform.isAndroid ? 'android' : 'ios';

    final response = await http
        .post(
      Uri.parse(
        '${ApiConfig.baseUrl}/device-tokens',
      ),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${authToken.trim()}',
      },
      body: jsonEncode({
        'fcm_token': fcmToken,
        'platform': platform,
      }),
    )
        .timeout(_timeout);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'فشل تسجيل الجهاز: ${response.body}',
      );
    }

    print('FCM DEVICE REGISTERED SUCCESSFULLY');
  }

  // ==========================================
  // Stop Token Listener
  // ==========================================

  static Future<void> stopListening() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }
}