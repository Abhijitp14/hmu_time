import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../theme/theme.dart';
import '../../services/auth_service.dart';
import 'admin_login_screen.dart';

class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await _authService.signInAsEmployee(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess && result.user != null) {
      if (mounted) {
        _navigateToEmployeeDashboard();
      }
    } else {
      if (mounted) {
        _showErrorSnackBar(result.message ?? 'Login failed');
      }
    }
  }

  void _navigateToEmployeeDashboard() {
    // Clear the navigation stack and navigate to home (AuthWrapper will handle routing)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Login successful! Welcome Employee'),
        backgroundColor: AppColors.success,
      ),
    );
    
    // Clear all routes and go to home - AuthWrapper will redirect to employee dashboard
    Navigator.pushNamedAndRemoveUntil(
      context, 
      '/', 
      (route) => false,
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your email address first');
      return;
    }

    final result = await _authService.resetPassword(_emailController.text.trim());
    
    if (result.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Password reset email sent'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        _showErrorSnackBar(result.message ?? 'Failed to send reset email');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLG,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Employee Icon
              _buildEmployeeIcon(),
              
              const SizedBox(height: 40),
              
              // Welcome Text
              _buildWelcomeText(),
              
              const SizedBox(height: 32),
              
              // Login Form
              _buildLoginForm(),
              
              const SizedBox(height: 24),
              
              // Forgot Password
              _buildForgotPassword(),
              
              const SizedBox(height: 32),
              
              // Login Button
              _buildLoginButton(),
              
              const SizedBox(height: 32),
              
              // Back to Admin Login
              _buildBackToAdminLogin(),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success,
            AppColors.success.withOpacity(0.8),
            AppColors.success.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.person_rounded,
        color: AppColors.textWhite,
        size: 40,
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          textAlign: TextAlign.start,
          text: TextSpan(
            style: AppTextStyles.h2,
            children: [
              const TextSpan(
                text: 'Hello ',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              TextSpan(
                text: '👋',
                style: AppTextStyles.h2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTextStyles.h2,
            children: [
              TextSpan(
                text: 'Employee',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text: ' Portal',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your credentials to access your dashboard',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.start,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'employee@company.com',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: AppColors.success,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: '••••••••',
              prefixIcon: Icon(
                Icons.lock_outline,
                color: AppColors.success,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.success,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _forgotPassword,
        child: Text(
          'Forgot Password ?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.textWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: AppColors.success.withOpacity(0.3),
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: Lottie.asset(
                  'assets/animations/loading.json',
                ),
              )
            : Text(
                'Login',
                style: AppTextStyles.buttonText.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildBackToAdminLogin() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Need admin access?',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminLoginScreen(),
                ),
              );
            },
            child: Text(
              'Admin Login',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
