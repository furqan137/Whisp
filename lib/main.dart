import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import 'Screens/splash/splash.dart';
import 'Service/notification.dart';
import 'firebase_options.dart';
import 'theme/theme_provider.dart';
import 'Screens/vpn/global_vpn.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // =========================
  // 🔥 Initialize Firebase
  // =========================
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // =========================
  // 🔔 Background Notifications
  // =========================
  FirebaseMessaging.onBackgroundMessage(
    NotificationService.backgroundHandler,
  );

  // =========================
  // 🍏 iOS Foreground Notification Settings
  // =========================
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // =========================
  // 🔔 Initialize Notification Service
  // =========================
  final notificationService = NotificationService();
  await notificationService.initNotifications();

  // =========================
  // 🌐 Init Global Fake VPN
  // =========================
  GlobalVPN.init();

  // =========================
  // 🍏 Request Tracking Permission (ATT)
  // =========================
  await requestTrackingPermission();

  // =========================
  // 🚀 Run App
  // =========================
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

Future<void> requestTrackingPermission() async {
  final status = await AppTrackingTransparency.trackingAuthorizationStatus;

  if (status == TrackingStatus.notDetermined) {
    await AppTrackingTransparency.requestTrackingAuthorization();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Whisp Chat',

          // 🔥 Use saved theme mode
          themeMode: themeProvider.themeMode,

          // 🌞 Light Theme
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              surfaceTintColor: Colors.white,
            ),
          ),

          // 🌙 Dark Theme
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xff090F21),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xff090F21),
              foregroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Color(0xff090F21),
            ),
          ),

          home: const SplashScreen(),
        );
      },
    );
  }
}