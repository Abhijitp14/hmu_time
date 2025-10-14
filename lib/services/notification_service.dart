import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  // Web-safe platform detection
  static bool get _isIOS {
    if (kIsWeb) return false; // Web platform is never iOS
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  // Check if running on iOS Simulator (push notifications not supported)
  static bool get _isIOSSimulator {
    return _isIOS && !kReleaseMode && defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<void> initialize() async {
    // Request permissions
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // For iOS, try to ensure APNS token is set (but don't fail if it's not available)
    if (_isIOS) {
      await _ensureAPNSToken();
    }

    // Initialize local notifications (not available on web)
    if (!kIsWeb) {
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
    }
    
    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'leave_notifications',
      'Leave Notifications',
      description: 'Notifications for leave applications and decisions',
      importance: Importance.high,
    );
    
    if (!kIsWeb) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Set up token refresh listener (this handles both FCM and APNS token changes)
    _messaging.onTokenRefresh.listen((fcmToken) async {
      print('FCM Token refreshed: ${fcmToken.substring(0, 20)}...');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': fcmToken});
          print('Updated FCM token in Firestore after refresh');
        } catch (e) {
          print('Error updating refreshed FCM token: $e');
        }
      }
    });
  }

  static Future<String?> getToken() async {
    try {
      // iOS Simulator doesn't support push notifications
      if (_isIOSSimulator) {
        print('📱 Running on iOS Simulator - Push notifications not supported');
        return null;
      }
      
      if (_isIOS) {
        // For iOS, check APNS token availability
        String? apnsToken = await _messaging.getAPNSToken();
        
        if (apnsToken == null) {
          print('APNS token not available immediately, waiting...');
          // Wait up to 5 seconds for APNS token (reduced from 10)
          for (int i = 0; i < 5; i++) {
            await Future.delayed(const Duration(seconds: 1));
            apnsToken = await _messaging.getAPNSToken();
            if (apnsToken != null) {
              print('✅ APNS token became available after ${i + 1} seconds');
              break;
            }
          }
          
          if (apnsToken == null) {
            print('⚠️  APNS token still not available. Common causes:');
            print('   • iOS Simulator (not supported)');
            print('   • Development build without proper certificates');
            print('   • Device with push notifications disabled');
            print('   • Network connectivity issues');
            return null;
          }
        } else {
          print('✅ APNS token available: ${apnsToken.substring(0, 20)}...');
        }
      }
      
      // Get FCM token (should work now that APNS token is available)
      final fcmToken = await _messaging.getToken();
      if (fcmToken != null) {
        print('✅ FCM token obtained: ${fcmToken.substring(0, 20)}...');
      }
      return fcmToken;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      if (_isIOS && e.toString().contains('apns-token-not-set')) {
        print('ℹ️  This is expected in iOS Simulator or development builds');
      }
      return null;
    }
  }

  static Future<void> updateTokenInFirestore(String userId) async {
    try {
      final token = await getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': token});
        print('✅ FCM token updated successfully for user: $userId');
      } else {
        if (_isIOS) {
          print('⚠️  Could not get FCM token - APNS token not available');
          print('   This is normal for iOS Simulator or development builds');
          print('   Push notifications will work once deployed with proper certificates');
        } else {
          print('⚠️  Could not get FCM token - check network and permissions');
        }
      }
    } catch (e) {
      print('❌ Error updating FCM token: $e');
    }
  }

  // Method to update token for already logged-in user (call this on app startup)
  static Future<void> refreshTokenForCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('👤 Found logged-in user: ${user.uid}');
        
        // For iOS, add a small delay and check availability first
        if (_isIOS) {
          await Future.delayed(const Duration(seconds: 1));
          final isAvailable = await isPushNotificationAvailable();
          if (!isAvailable) {
            print('⚠️  Skipping FCM token update - push notifications not available on this iOS device/simulator');
            return;
          }
        }
        
        await updateTokenInFirestore(user.uid);
      } else {
        print('👤 No user currently logged in - skipping FCM token update');
      }
    } catch (e) {
      print('❌ Error refreshing FCM token for current user: $e');
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    // Determine notification category from the message data or type
    String category = 'general';
    if (message.data.containsKey('type')) {
      switch (message.data['type']) {
        case 'leave':
        case 'leave_request':
        case 'leave_approved':
        case 'leave_rejected':
          category = 'leave';
          break;
        case 'attendance':
        case 'punch_reminder':
        case 'attendance_alert':
          category = 'attendance';
          break;
        case 'system':
        case 'system_update':
        case 'maintenance':
          category = 'system';
          break;
      }
    }

    // Use the enhanced notification method that respects user preferences
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      title: message.notification?.title ?? 'HMU Time',
      body: message.notification?.body ?? 'New notification',
      category: category,
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  }

  // Handle notification tap
  static void _handleNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // You can add navigation logic here based on the payload
    // For example, navigate to leave requests screen if it's a leave notification
  }

  // Ensure APNS token is available for iOS
  static Future<bool> _ensureAPNSToken() async {
    try {
      String? apnsToken = await _messaging.getAPNSToken();
      
      if (apnsToken == null) {
        print('APNS token not available, waiting...');
        // Wait up to 5 seconds for APNS token to become available
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(seconds: 1));
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) {
            print('APNS token obtained: ${apnsToken.substring(0, 20)}...');
            return true;
          }
        }
        
        if (apnsToken == null) {
          print('ℹ️  APNS token not available. This is normal in:');
          print('   • iOS Simulator (push notifications not supported)');
          print('   • Development builds without proper certificates');
          print('   • Physical devices in development mode');
          print('   • Apps without push notification entitlements');
          print('📱 Push notifications will not work until APNS token is available.');
          return false;
        }
      } else {
        print('✅ APNS token already available: ${apnsToken.substring(0, 20)}...');
        return true;
      }
    } catch (e) {
      print('Error ensuring APNS token: $e');
      return false;
    }
    return false;
  }

  // Check if push notifications are available
  static Future<bool> isPushNotificationAvailable() async {
    try {
      if (_isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        return apnsToken != null;
      } else {
        // For Android, check if we can get FCM token
        final fcmToken = await _messaging.getToken();
        return fcmToken != null;
      }
    } catch (e) {
      print('Error checking push notification availability: $e');
      return false;
    }
  }

  // Get notification status message for users
  static Future<String> getNotificationStatusMessage() async {
    try {
      if (_isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          return 'Push notifications are enabled and working';
        } else {
          return 'Push notifications unavailable in iOS Simulator/Development mode';
        }
      } else {
        final fcmToken = await _messaging.getToken();
        if (fcmToken != null) {
          return 'Push notifications are enabled and working';
        } else {
          return 'Push notifications are not available - check permissions';
        }
      }
    } catch (e) {
      return 'Push notification status unknown: $e';
    }
  }

  // Retry updating FCM token with delay - useful for iOS after login
  static Future<void> retryUpdateTokenWithDelay(String userId, {int delaySeconds = 5}) async {
    print('📅 Scheduling FCM token update retry in $delaySeconds seconds...');
    Future.delayed(Duration(seconds: delaySeconds), () async {
      try {
        // Check if push notifications are available before retrying
        final isAvailable = await isPushNotificationAvailable();
        if (!isAvailable) {
          print('⏭️  Skipping FCM token retry - push notifications not available');
          return;
        }
        
        await updateTokenInFirestore(userId);
        print('✅ FCM token retry update completed for user: $userId');
      } catch (e) {
        print('❌ FCM token retry update failed for user $userId: $e');
      }
    });
  }

  // Check if notifications are globally enabled
  static Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('general_notifications') ?? true;
  }

  // Check specific notification categories
  static Future<bool> isLeaveNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('leave_notifications') ?? true;
  }

  static Future<bool> isAttendanceReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('attendance_reminders') ?? true;
  }

  static Future<bool> isSystemUpdateEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('system_updates') ?? true;
  }

  // Check notification behavior settings
  static Future<bool> isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sound') ?? true;
  }

  static Future<bool> isVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('vibration') ?? true;
  }



  // Enhanced notification method that respects user preferences
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String category, // 'leave', 'attendance', 'system', 'general'
    String? payload,
  }) async {
    // Check if notifications are globally enabled
    if (!await areNotificationsEnabled()) return;

    // Check specific category permissions
    bool categoryEnabled = true;
    switch (category) {
      case 'leave':
        categoryEnabled = await isLeaveNotificationEnabled();
        break;
      case 'attendance':
        categoryEnabled = await isAttendanceReminderEnabled();
        break;
      case 'system':
        categoryEnabled = await isSystemUpdateEnabled();
        break;
    }

    if (!categoryEnabled) return;

    // Get behavior settings
    final soundEnabled = await isSoundEnabled();
    final vibrationEnabled = await isVibrationEnabled();

    // Create notification details based on user preferences
    final androidDetails = AndroidNotificationDetails(
      category,
      category == 'leave' ? 'Leave Notifications' :
      category == 'attendance' ? 'Attendance Reminders' :
      category == 'system' ? 'System Updates' : 'General Notifications',
      channelDescription: 'Notifications for $category',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: soundEnabled,
      enableVibration: vibrationEnabled,
    );
    
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundEnabled,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Local notifications are not available on web
    if (!kIsWeb) {
      await _localNotifications.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );
    } else {
      // On web, we rely on Firebase Cloud Messaging for notifications
      print('📱 Web notification: $title - $body');
    }
  }

  // Show a test notification
  static Future<void> showTestNotification() async {
    await showNotification(
      id: 999,
      title: 'HMU Time Test',
      body: 'This is a test notification. Your notifications are working correctly!',
      category: 'general',
      payload: 'test_notification',
    );
  }

  // Convenience methods for specific notification types
  static Future<void> showLeaveNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      category: 'leave',
      payload: payload,
    );
  }

  static Future<void> showAttendanceReminder({
    required String title,
    required String body,
    String? payload,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      category: 'attendance',
      payload: payload,
    );
  }

  static Future<void> showSystemUpdate({
    required String title,
    required String body,
    String? payload,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      category: 'system',
      payload: payload,
    );
  }
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}