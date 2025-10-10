import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Request permissions
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        _handleNotificationTap(response);
      },
    );
    
    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'leave_notifications',
      'Leave Notifications',
      description: 'Notifications for leave applications and decisions',
      importance: Importance.high,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  static Future<void> updateTokenInFirestore(String userId) async {
    try {
      final token = await getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': token});
        print('FCM token updated successfully for user: $userId');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Method to update token for already logged-in user (call this on app startup)
  static Future<void> refreshTokenForCurrentUser() async {
    try {
      // Import FirebaseAuth here to avoid circular dependency
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await updateTokenInFirestore(user.uid);
      }
    } catch (e) {
      print('Error refreshing FCM token for current user: $e');
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'leave_notifications',
      'Leave Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    
    await _localNotifications.show(
      0,
      message.notification?.title,
      message.notification?.body,
      details,
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  }

  // Handle notification tap
  static void _handleNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // You can add navigation logic here based on the payload
    // For example, navigate to leave requests screen if it's a leave notification
  }
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}