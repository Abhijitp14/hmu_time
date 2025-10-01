import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../screens/auth/employee_login_screen.dart';
import '../screens/dashboard/admin/admin_dashboard_screen.dart';
import '../screens/dashboard/employee/employee_dashboard_screen.dart';
import 'splash_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _hasSignedOut = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Show splash screen while waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        
        // Handle connection errors
        if (snapshot.hasError) {
          print('Auth stream error: ${snapshot.error}');
          return const EmployeeLoginScreen();
        }
        
        // User is authenticated
        if (snapshot.hasData && snapshot.data != null && !_hasSignedOut) {
          return FutureBuilder<AppUser?>(
            future: _authService.getUserData(snapshot.data!.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }
              
              // Handle errors in user data loading
              if (userSnapshot.hasError) {
                print('Error loading user data: ${userSnapshot.error}');
                _signOutSafely();
                return const EmployeeLoginScreen();
              }
              
              if (userSnapshot.hasData && userSnapshot.data != null) {
                final user = userSnapshot.data!;
                
                // Route based on user role
                if (user.role == UserRole.admin || 
                    user.role == UserRole.hr || 
                    user.role == UserRole.manager) {
                  return AdminDashboardScreen(user: user);
                } else if (user.role == UserRole.employee) {
                  return EmployeeDashboardScreen(user: user);
                } else {
                  print('Invalid user role: ${user.role}');
                  _signOutSafely();
                  return const EmployeeLoginScreen();
                }
              }
              
              // If no valid user data, show login
              print('No valid user data found, signing out');
              _signOutSafely();
              return const EmployeeLoginScreen();
            },
          );
        }
        
        // No authenticated user or user signed out
        _hasSignedOut = false; // Reset flag for next login
        return const EmployeeLoginScreen();
      },
    );
  }

  void _signOutSafely() {
    if (!_hasSignedOut) {
      _hasSignedOut = true;
      _authService.signOut().catchError((error) {
        print('Error during sign out: $error');
      });
    }
  }
}
