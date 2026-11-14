import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ValueNotifier<ThemeMode> themeNotifier =
  ValueNotifier(ThemeMode.light);
  static const String _activeUserKey =
      'tinyguide_active_user_phone';

  static const String _themeKeyPrefix =
      'tinyguide_theme_';

  // توحيد رقم الهاتف ليكون مفتاح الحساب
  static String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  // استعادة الوضع الخاص بالحساب النشط
  static Future<ThemeMode> loadActiveUserTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final phone = prefs.getString(_activeUserKey);

    if (phone == null || phone.isEmpty) {
      return ThemeMode.light;
    }

    final isDark =
        prefs.getBool('$_themeKeyPrefix$phone') ?? false;

    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // تفعيل حساب واستعادة الوضع الذي اختاره سابقاً
  static Future<ThemeMode> activateUser(String phone) async {
    final normalizedPhone = _normalizePhone(phone);

    if (normalizedPhone.isEmpty) {
      return ThemeMode.light;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _activeUserKey,
      normalizedPhone,
    );

    final isDark =
        prefs.getBool('$_themeKeyPrefix$normalizedPhone') ?? false;

    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // حفظ الوضع الخاص بالحساب الحالي
  static Future<void> saveThemeForActiveUser(
      ThemeMode mode,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    final phone = prefs.getString(_activeUserKey);

    if (phone == null || phone.isEmpty) return;

    await prefs.setBool(
      '$_themeKeyPrefix$phone',
      mode == ThemeMode.dark,
    );
  }

  // إزالة الحساب النشط عند تسجيل الخروج
  static Future<void> clearActiveUser() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_activeUserKey);
  }
}