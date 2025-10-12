import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Request permissions for iOS
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _initialized = true;
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showNotification(
      title: message.notification?.title ?? 'New notification',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for task deadlines',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for task deadlines',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      taskId.hashCode,
      'Task Reminder',
      title,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: taskId,
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await _localNotifications.cancel(taskId.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}

// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
}