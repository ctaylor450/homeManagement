import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles push notifications, token management, and local display.
class NotificationService {
  // Singleton instance
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _fcm = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;
  final _local = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _boundUid;

  // === INITIALIZATION ===
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Request permissions (iOS)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Foreground local notifications setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(initSettings);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification != null) {
        await _local.show(
          notification.hashCode,
          notification.title ?? 'New Notification',
          notification.body ?? '',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'public_tasks',
              'Public tasks',
              channelDescription: 'Notifications about new household tasks',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // === BIND / UNBIND USER ===
  /// Call when a user logs in to associate tokens with their account.
  Future<void> bindUser(String uid) async {
    _boundUid = uid;

    // Save the current token immediately
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveToken(uid, token);
    }

    // Listen for token refreshes
    _fcm.onTokenRefresh.listen((token) async {
      if (_boundUid != null) {
        await _saveToken(_boundUid!, token);
      }
    });
  }

  /// Call when the user logs out to clear internal state.
  Future<void> unbindUser() async {
    _boundUid = null;
    // Optional: Unsubscribe from topics or remove tokens if desired
  }

  // === TOKEN PERSISTENCE ===
  Future<void> _saveToken(String uid, String token) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'platform': Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
                ? 'android'
                : kIsWeb
                    ? 'web'
                    : 'other',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  // === OPTIONAL LOCAL DISPLAY HELPERS ===
  Future<void> showLocalNotification(String title, String body) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'Default',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> cancelAllLocalNotifications() async {
    await _local.cancelAll();
  }
}

// === BACKGROUND HANDLER ===
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized if needed in background isolate
  // await Firebase.initializeApp(); // optional if required
  debugPrint('📩 Background message: ${message.messageId}');
}
