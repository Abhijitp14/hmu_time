import 'package:flutter/material.dart';
import '../theme/app_theme_simple.dart';
import '../screens/auth/admin_login_screen.dart';
import '../screens/auth/employee_login_screen.dart';
import '../screens/dashboard/admin/add_employee_screen.dart';
import '../screens/dashboard/admin/add_admin_user_screen.dart';
import '../widgets/auth_wrapper.dart';

class HmuTimeApp extends StatelessWidget {
  const HmuTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HMU Time - Employee Management System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      routes: _buildRoutes(),
    );
  }

  /// Defines all the app routes
  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      '/admin-login': (context) => const AdminLoginScreen(),
      '/employee-login': (context) => const EmployeeLoginScreen(),
      '/add-employee': (context) => const AddEmployeeScreen(),
      '/add-admin-user': (context) => const AddAdminUserScreen(),
    };
  }
}
