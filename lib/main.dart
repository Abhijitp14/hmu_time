import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  await NotificationService.refreshTokenForCurrentUser();
  
  // Setup FCM token refresh listener
  _setupTokenRefreshListener();
  
  // Handle notification when app is opened from terminated state
  _setupNotificationHandling();
  
  runApp(const HmuTimeApp());
}

// Setup FCM token refresh listener
void _setupTokenRefreshListener() {
  FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
    // Update token in Firestore for current user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      NotificationService.updateTokenInFirestore(user.uid);
    }
  });
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


