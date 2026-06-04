import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  /// 🔥 REQUIRED: Background / terminated handler
  static Future<void> backgroundHandler(RemoteMessage message) async {
    print("🔔 Background message received: ${message.messageId}");
  }

  /// 🔔 Init notifications
  Future<void> initNotifications() async {
    // =========================
    // 1️⃣ REQUEST PERMISSION
    // =========================
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print("❌ Notification permission denied");
      return;
    }

    // =========================
    // 2️⃣ ANDROID NOTIFICATION CHANNEL
    // =========================
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'default_channel',
      'Chat Notifications',
      description: 'Message notifications',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // =========================
    // 3️⃣ LOCAL NOTIFICATION INIT
    // =========================
    const InitializationSettings settingsInit = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _local.initialize(settingsInit);

    // =========================
    // 4️⃣ WAIT FOR APNS TOKEN (FIX FOR IOS)
    // =========================
    if (Platform.isIOS) {
      String? apnsToken;

      while (apnsToken == null) {
        apnsToken = await _messaging.getAPNSToken();
        await Future.delayed(const Duration(seconds: 1));
      }

      print("🍏 APNS TOKEN: $apnsToken");
    }

    // =========================
    // 5️⃣ SAVE FCM TOKEN
    // =========================
    await _saveFcmToken();

    // =========================
    // 6️⃣ FOREGROUND NOTIFICATIONS
    // =========================
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? "New Message";
      final body = message.notification?.body ?? "You received a message";

      _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel',
            'Chat Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });

    // =========================
    // 7️⃣ NOTIFICATION TAP
    // =========================
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print("🚀 Notification tapped: ${message.data}");
    });

    print("✅ Notification service initialized");
  }

  /// 🔐 Save FCM token to Firestore
  Future<void> _saveFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();

    if (token == null) {
      print("❌ FCM token is null");
      return;
    }

    print("🔥 FCM TOKEN: $token");

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      "deviceToken": token,
    }, SetOptions(merge: true));

    // 🔄 Token refresh listener
    _messaging.onTokenRefresh.listen((newToken) async {
      print("🔄 FCM TOKEN REFRESHED: $newToken");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        "deviceToken": newToken,
      }, SetOptions(merge: true));
    });
  }
}