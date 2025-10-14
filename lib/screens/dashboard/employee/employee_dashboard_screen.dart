import 'package:flutter/material.dart';
import 'package:hmu_time/screens/leaves/leave_application_screen.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import 'employee_home_screen.dart';
import 'employee_holidays_screen.dart';
import 'office_teammates_screen.dart';
import '../../profile/personal_information_screen.dart';
import '../../profile/security_settings_screen.dart';
import '../../profile/notification_settings_screen.dart';
import '../../profile/help_support_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final AppUser user;

  const EmployeeDashboardScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          EmployeeHomeScreen(user: widget.user),
          const EmployeeHolidaysScreen(),
          const OfficeTeammatesScreen(),
          LeaveApplicationScreen(user: widget.user),
          // _buildLeavesTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF4285F4),
        unselectedItemColor: Colors.grey[600],
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        elevation: 10,
        selectedFontSize: 12,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Holidays',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Office Teammates',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_note),
            label: 'Leaves',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }







  // Profile Tab
  Widget _buildProfileTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Enhanced Profile Details Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4285F4),
                    Color(0xFF6366F1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Picture with Status Indicator
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: Text(
                            widget.user.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (widget.user.isActive)
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Name and Basic Info
                  Text(
                    widget.user.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Role with Icon
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.user.role == UserRole.admin 
                              ? Icons.admin_panel_settings 
                              : Icons.person,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.user.role.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Employee Details in Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.badge,
                          label: 'Employee ID',
                          value: widget.user.displayEmpCode,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.business,
                          label: 'Department',
                          value: widget.user.department ?? 'General',
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Additional Info Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.work,
                          label: 'Designation',
                          value: widget.user.designation ?? 'Employee',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.schedule,
                          label: 'Work Hours',
                          value: '${widget.user.workingHours?.toStringAsFixed(0) ?? "8"} hrs/day',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // const SizedBox(height: 24),
            
            // Quick Status Card
            // Container(
            //   padding: const EdgeInsets.all(20),
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     borderRadius: BorderRadius.circular(16),
            //     boxShadow: [
            //       BoxShadow(
            //         color: Colors.black.withValues(alpha: 0.05),
            //         blurRadius: 10,
            //         offset: const Offset(0, 4),
            //       ),
            //     ],
            //   ),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
                  
            //       // const SizedBox(height: 16),
                  
            //     ],
            //   ),
            // ),
            
            const SizedBox(height: 30),
            
            // Profile Options
            _buildProfileOption(
              icon: Icons.person,
              title: 'Personal Information',
              onTap: () => _navigateToPersonalInformation(context),
            ),
            _buildProfileOption(
              icon: Icons.security,
              title: 'Security Settings',
              onTap: () => _navigateToSecuritySettings(context),
            ),
            _buildProfileOption(
              icon: Icons.notifications,
              title: 'Notifications',
              onTap: () => _navigateToNotificationSettings(context),
            ),
            _buildProfileOption(
              icon: Icons.help,
              title: 'Help & Support',
              onTap: () => _navigateToHelpSupport(context),
            ),
            _buildProfileOption(
              icon: Icons.logout,
              title: 'Logout',
              onTap: () => _logout(context),
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive 
                ? Colors.red.withValues(alpha: 0.1)
                : const Color(0xFF4285F4).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : const Color(0xFF4285F4),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[600],
        ),
        onTap: onTap,
      ),
    );
  }

  void _logout(BuildContext context) async {
    await AuthService().signOut();
    // Navigation is handled by AuthWrapper
  }

  void _navigateToPersonalInformation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalInformationScreen(user: widget.user),
      ),
    );
  }

  void _navigateToSecuritySettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecuritySettingsScreen(user: widget.user),
      ),
    );
  }

  void _navigateToNotificationSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationSettingsScreen(user: widget.user),
      ),
    );
  }

  void _navigateToHelpSupport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HelpSupportScreen(user: widget.user),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.8),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }


}
