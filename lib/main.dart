import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'SplashScreen.dart';

// ==========================================
// Theme
// ==========================================

final ValueNotifier<ThemeMode> themeNotifier =
ValueNotifier(ThemeMode.light);

// ==========================================
// Notification Update Notifier
// ==========================================

// إبلاغ الصفحة الرئيسية عند وصول إشعار جديد
final ValueNotifier<int> notificationUpdateNotifier =
ValueNotifier<int>(0);

// ==========================================
// Local Notifications
// ==========================================

final FlutterLocalNotificationsPlugin localNotifications =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel notificationChannel =
AndroidNotificationChannel(
  'tinyguide_notifications',
  'إشعارات TinyGuide',
  description: 'إشعارات الإدارة والتذكيرات',
  importance: Importance.high,
  playSound: true,
);

// ==========================================
// Firebase Background Handler
// ==========================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  await Firebase.initializeApp();

  debugPrint(
    'FCM BACKGROUND MESSAGE: ${message.messageId}',
  );
}

// ==========================================
// Initialize Local Notifications
// ==========================================

Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings =
  InitializationSettings(
    android: androidSettings,
  );

  await localNotifications.initialize(
    settings: settings,
  );

  final androidPlugin =
  localNotifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(
    notificationChannel,
  );
}

// ==========================================
// Show Foreground Notification
// ==========================================

Future<void> showForegroundNotification(
    RemoteMessage message,
    ) async {
  final notification = message.notification;

  final String title =
      notification?.title ??
          message.data['title']?.toString() ??
          'TinyGuide';

  final String body =
      notification?.body ??
          message.data['body']?.toString() ??
          '';

  if (body.isEmpty && notification == null) {
    return;
  }

  await localNotifications.show(
    id: DateTime.now()
        .millisecondsSinceEpoch
        .remainder(2147483647),
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'tinyguide_notifications',
        'إشعارات TinyGuide',
        channelDescription: 'إشعارات الإدارة والتذكيرات',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: message.data.toString(),
  );
}

// ==========================================
// Main
// ==========================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // استرجاع آخر وضع اختاره المستخدم
  final prefs = await SharedPreferences.getInstance();

  final savedTheme = prefs.getString('themeMode');

  themeNotifier.value = savedTheme == 'dark'
      ? ThemeMode.dark
      : ThemeMode.light;

  // Firebase
  await Firebase.initializeApp();

  // Background messages
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  // Notification permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Local notifications
  await initializeLocalNotifications();

  // Foreground messages
  FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
      debugPrint(
        'FCM FOREGROUND MESSAGE: ${message.messageId}',
      );

      // إبلاغ الصفحة الرئيسية بوصول إشعار جديد
      notificationUpdateNotifier.value++;

      try {
        await showForegroundNotification(message);
      } catch (error) {
        debugPrint(
          'FOREGROUND NOTIFICATION ERROR: $error',
        );
      }
    },
  );

  // Get FCM token
  try {
    final String? fcmToken =
    await FirebaseMessaging.instance.getToken();

    debugPrint('FCM TOKEN: $fcmToken');
  } catch (e) {
    debugPrint('FCM TOKEN ERROR: $e');
  }

  runApp(const TinyGuideApp());
}

// ==========================================
// TinyGuide App
// ==========================================

class TinyGuideApp extends StatelessWidget {
  const TinyGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'TinyGuide',

          themeMode: currentThemeMode,

          // =========================
          // Light Theme
          // =========================

          theme: ThemeData(
            brightness: Brightness.light,

            primaryColor: const Color(0xff64C7C4),

            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff64C7C4),
              brightness: Brightness.light,
            ).copyWith(
              surface: Colors.white,
              onSurface: const Color(0xff2C4A5A),
            ),

            scaffoldBackgroundColor:
            const Color(0xffF1F8F8),

            cardColor: Colors.white,

            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xff64C7C4),
              foregroundColor: Colors.white,
            ),

            inputDecorationTheme:
            const InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,

              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Color(0xff64C7C4),
                  width: 2,
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(14),
                ),
              ),
            ),

            elevatedButtonTheme:
            ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xff64C7C4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            dividerColor:
            const Color(0xffE2EEEE),

            iconTheme: const IconThemeData(
              color: Color(0xff2C4A5A),
            ),
          ),

          // =========================
          // Dark Theme
          // =========================

          darkTheme: ThemeData(
            brightness: Brightness.dark,

            primaryColor: const Color(0xff64C7C4),

            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff64C7C4),
              brightness: Brightness.dark,
            ).copyWith(
              surface: const Color(0xff1D292D),
              onSurface: Colors.white,
            ),

            scaffoldBackgroundColor:
            const Color(0xff121A1D),

            cardColor:
            const Color(0xff1D292D),

            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xff1D292D),
              foregroundColor: Colors.white,
            ),

            inputDecorationTheme:
            const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xff1D292D),

              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Color(0xff64C7C4),
                  width: 2,
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(14),
                ),
              ),
            ),

            elevatedButtonTheme:
            ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xff64C7C4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            dividerColor:
            Colors.white.withOpacity(0.12),

            iconTheme: const IconThemeData(
              color: Colors.white,
            ),
          ),

          home: const SplashScreen(),
        );
      },
    );
  }
}