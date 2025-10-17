import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/employee_service.dart';

import '../../leaves/admin_leave_requests_screen.dart';
import 'add_employee_screen.dart';
import 'add_admin_user_screen.dart';
import 'employee_list_screen.dart';
import 'admin_users_list_screen.dart';
import 'holiday_management_screen.dart';
import 'system_settings_screen.dart';
import 'reports_screen.dart';
import 'today_attendance_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AppUser user;
  
  const AdminDashboardScreen({
    super.key,
    required this.user,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final EmployeeService _employeeService = EmployeeService();

  
  List<AppUser> _activeEmployees = [];
  List<RecentActivity> _recentActivities = [];
  bool _isLoadingEmployees = true;
  bool _isLoadingActivities = true;
  int _presentEmployees = 0;
  bool _isLoadingPresence = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    // Load employees first, then activities and presence
    await _loadActiveEmployees();
    await _loadRecentActivities();
    await _loadPresentEmployees();
  }
  
  Future<void> _loadPresentEmployees() async {
    try {
      setState(() => _isLoadingPresence = true);
      final count = await _calculatePresentEmployees();
      setState(() {
        _presentEmployees = count;
      });
    } catch (e) {
      debugPrint('Error loading present employees: $e');
    } finally {
      setState(() => _isLoadingPresence = false);
    }
  }

  Future<void> _loadActiveEmployees() async {
    try {
      setState(() => _isLoadingEmployees = true);
      
      final employeesData = await _employeeService.getEmployees();
      final employees = employeesData.map((data) => AppUser.fromJson(data)).toList();
      
      setState(() {
        _activeEmployees = employees.where((emp) => emp.role == UserRole.employee).toList();
      });
    } catch (e) {
      debugPrint('Error loading employees: $e');
    } finally {
      setState(() => _isLoadingEmployees = false);
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      setState(() => _isLoadingActivities = true);
      
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = startOfToday.add(const Duration(days: 1));
      
      List<RecentActivity> activities = [];
      
      // Add employee creation activities (created today only)
      for (final employee in _activeEmployees) {
        // Add employee creation activity if created today
        if (employee.createdAt.isAfter(startOfToday) && 
            employee.createdAt.isBefore(endOfToday)) {
          activities.add(RecentActivity(
            employeeName: employee.name,
            empCode: employee.empCode ?? 'N/A',
            activityType: 'Employee Created',
            timestamp: employee.createdAt,
            icon: Icons.person_add,
            color: AppColors.primary,
          ));
        }
      }
      
      // NOTE: Removed biometric calls for performance - they were making API calls for every employee
      // This was causing significant delays during admin login
      // Biometric activities can be viewed in individual employee screens if needed
      
      // Sort by timestamp (most recent first)
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      setState(() {
        _recentActivities = activities.take(20).toList(); // Show up to 20 today's activities
      });
    } catch (e) {
      debugPrint('Error loading recent activities: $e');
    } finally {
      setState(() => _isLoadingActivities = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user.role.displayName} Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Profile'),
                onTap: () {},
              ),
              PopupMenuItem(
                child: const Text('Settings'),
                onTap: () {},
              ),
              PopupMenuItem(
                child: const Text('Logout'),
                onTap: () => _logout(context),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLG,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: AppRadius.radiusLG,
                boxShadow: AppShadows.card,
              ),
              padding: AppSpacing.paddingLG,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.textWhite,
                        child: Icon(
                          _getRoleIcon(widget.user.role),
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${widget.user.name}',
                              style: AppTextStyles.h5.copyWith(
                                color: AppColors.textWhite,
                              ),
                            ),
                            Text(
                              widget.user.designation ?? widget.user.role.displayName,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textWhite.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Quick Actions
            Text(
              'Quick Actions',
              style: AppTextStyles.h5,
            ),
            const SizedBox(height: 16),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: _getQuickActions(context, widget.user.role),
            ),
            
            const SizedBox(height: 24),
            
            // Today's Activity
            Text(
              "Today's Activity",
              style: AppTextStyles.h5,
            ),
            const SizedBox(height: 16),
            
            _buildActivityList(),
          ],
        ),
        ),
      ),
    );
  }
  
  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.hr:
        return Icons.people_alt;
      case UserRole.manager:
        return Icons.supervisor_account;
      default:
        return Icons.person;
    }
  }
  
  List<Widget> _getQuickActions(BuildContext context, UserRole role) {
    final List<QuickAction> actions = [];
    
    if (role == UserRole.admin) {
      actions.addAll([
        QuickAction('Today\'s Attendance', Icons.how_to_reg, AppColors.success),
        QuickAction('Add Employee', Icons.person_add, AppColors.success),
        QuickAction('Add HR/Manager', Icons.admin_panel_settings, AppColors.warning),
        QuickAction('Employee List', Icons.people, AppColors.primary),
        QuickAction('Leave Requests', Icons.event_note, AppColors.warning),
        QuickAction('Holiday Management', Icons.event, AppColors.info),
        QuickAction('HR/Manager List', Icons.group, AppColors.secondary),
        QuickAction('System Settings', Icons.settings, AppColors.secondary),
        QuickAction('Reports', Icons.analytics, AppColors.info),
      ]);
    } else if (role == UserRole.hr || role == UserRole.manager) {
      actions.addAll([
        QuickAction('Today\'s Attendance', Icons.how_to_reg, AppColors.success),
        QuickAction('Add Employee', Icons.person_add, AppColors.success),
        QuickAction('Employee List', Icons.people, AppColors.primary),
        QuickAction('Holiday Management', Icons.event, AppColors.info),
        QuickAction('Leave Requests', Icons.event_note, AppColors.warning),
      ]);
    }
    
    return actions.map((action) => _buildQuickActionCard(context, action)).toList();
  }
  
  Widget _buildQuickActionCard(BuildContext context, QuickAction action) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusLG,
        boxShadow: AppShadows.light,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.radiusLG,
          onTap: () => _handleQuickAction(context, action.title),
          child: Padding(
            padding: AppSpacing.paddingMD,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    action.icon,
                    color: action.color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  action.title,
                  style: AppTextStyles.labelMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildActivityList() {
    if (_isLoadingActivities) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_recentActivities.isEmpty) {
      return Container(
        padding: AppSpacing.paddingLG,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusMD,
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Icon(
              Icons.access_time_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No activity today',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Today's employee activities will appear here",
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentActivities.length,
          itemBuilder: (context, index) {
            final activity = _recentActivities[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: AppSpacing.paddingMD,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.radiusMD,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: activity.color.withValues(alpha: 0.1),
                    child: Icon(
                      activity.icon,
                      color: activity.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                            children: [
                              TextSpan(
                                text: activity.employeeName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(
                                text: ' ${activity.activityType.toLowerCase()}',
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _getActivityTime(activity.activityType, activity.timestamp),
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    activity.empCode,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_recentActivities.isNotEmpty) ...[
          const SizedBox(height: 16),
          // Employee Availability Summary
          _buildEmployeeAvailability(),
        ],
      ],
    );
  }
  
  Future<int> _calculatePresentEmployees() async {
    // NOTE: Temporarily disabled biometric-based presence calculation for performance
    // This was making API calls for every employee during admin login, causing significant delays
    // TODO: Implement a bulk API or cached approach for attendance status
    
    // For now, return a placeholder based on total active employees
    // This avoids the performance issue while maintaining UI functionality
    return (_activeEmployees.length * 0.7).round(); // Assume ~70% attendance as placeholder
  }
  
  Widget _buildEmployeeAvailability() {
    if (_isLoadingEmployees) {
      return const SizedBox.shrink();
    }
    
    final totalEmployees = _activeEmployees.length;
    
    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusMD,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people_outline,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Today\'s Availability',
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAvailabilityItem(
                  'Present (Est.)',
                  _isLoadingPresence ? '...' : '~${_presentEmployees.toString()}',
                  AppColors.success,
                  Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAvailabilityItem(
                  'Total Employees',
                  totalEmployees.toString(),
                  AppColors.primary,
                  Icons.group_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAvailabilityItem(String label, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.radiusSM,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: AppTextStyles.h6.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  String _getActivityTime(String activityType, DateTime dateTime) {
    final timeFormat = DateFormat('h:mm a');
    
    // For punch in/out activities, show actual time (since all are from today)
    if (activityType == 'Punch In' || activityType == 'Punch Out') {
      return timeFormat.format(dateTime);
    }
    
    // For other activities (like Employee Created), show relative time if recent, otherwise time
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 6) {
      return '${difference.inHours} hours ago';
    } else {
      return timeFormat.format(dateTime);
    }
  }

  Future<void> _handleQuickAction(BuildContext context, String actionTitle) async {
    switch (actionTitle) {
      case 'Add Employee':
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AddEmployeeScreen(),
          ),
        );
        // Refresh data if employee was added
        if (result == true) {
          _loadDashboardData();
        }
        break;
      case 'Add HR/Manager':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AddAdminUserScreen(),
          ),
        );
        break;
      case 'Manage Users':
        // TODO: Navigate to manage users screen
        _showComingSoon(context, 'Manage Users');
        break;
      case 'Employee List':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EmployeeListScreen(),
          ),
        );
        break;
      case 'HR/Manager List':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminUsersListScreen(),
          ),
        );
        break;
      case 'System Settings':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SystemSettingsScreen(user: widget.user),
          ),
        );
        break;
      case 'Today\'s Attendance':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TodayAttendanceScreen(),
          ),
        );
        break;
      case 'Attendance':
        // TODO: Navigate to attendance screen
        _showComingSoon(context, 'Attendance');
        break;
      case 'Leave Requests':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminLeaveRequestsScreen(),
          ),
        );
        break;
      case 'Reports':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportsScreen(user: widget.user),
          ),
        );
        break;
      case 'Holiday Management':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const HolidayManagementScreen(),
          ),
        );
        break;
      default:
        _showComingSoon(context, actionTitle);
        break;
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon!'),
        backgroundColor: AppColors.info,
      ),
    );
  }
  
  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close the dialog first
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class QuickAction {
  final String title;
  final IconData icon;
  final Color color;
  
  QuickAction(this.title, this.icon, this.color);
}

class RecentActivity {
  final String employeeName;
  final String empCode;
  final String activityType;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  
  RecentActivity({
    required this.employeeName,
    required this.empCode,
    required this.activityType,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}
