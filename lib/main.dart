import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize notifications
  await NotificationService.initialize();
  
  // Refresh FCM token for already logged-in user
  print('🔄 Checking FCM token for current user...');
  await NotificationService.refreshTokenForCurrentUser();
  
  // Check notification availability status
  final isAvailable = await NotificationService.isPushNotificationAvailable();
  if (isAvailable) {
    print('✅ Push notifications are available and ready');
  } else {
    print('⚠️  Push notifications are not currently available');
  }
  

  
  // Handle notification when app is opened from terminated state
  _setupNotificationHandling();
  
  runApp(const HmuTimeApp());
}



// Setup notification handling for when app is opened from notification
void _setupNotificationHandling() {
  // Handle notification when app is in background and user taps on it
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('App opened from notification: ${message.data}');
    // You can add navigation logic here
  });

  // Handle notification when app is in terminated state and user opens it
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print('App opened from terminated state with notification: ${message.data}');
      // You can add navigation logic here
    }
  });
}


