import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/user_model.dart';
import '../../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final AppUser user;

  const NotificationSettingsScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _leaveNotifications = true;
  bool _attendanceReminders = true;
  bool _systemUpdates = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;


  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _pushNotifications 
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _pushNotifications 
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _pushNotifications ? Icons.notifications_active : Icons.notifications_off,
                    color: _pushNotifications ? Colors.green[700] : Colors.orange[700],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pushNotifications ? 'Notifications Enabled' : 'Notifications Disabled',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _pushNotifications ? Colors.green[700] : Colors.orange[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _pushNotifications 
                              ? 'You\'ll receive important updates and reminders'
                              : 'Turn on notifications to stay updated',
                          style: TextStyle(
                            fontSize: 14,
                            color: _pushNotifications ? Colors.green[600] : Colors.orange[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // General Notifications
            const Text(
              'General Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildNotificationTile(
              title: 'Push Notifications',
              subtitle: 'Receive notifications on this device',
              value: _pushNotifications,
              onChanged: (value) => setState(() => _pushNotifications = value),
              icon: Icons.notifications,
            ),
            
            _buildNotificationTile(
              title: 'Leave Notifications',
              subtitle: 'Updates about leave requests and approvals',
              value: _leaveNotifications,
              onChanged: (value) => setState(() => _leaveNotifications = value),
              icon: Icons.event_busy,
              enabled: _pushNotifications,
            ),
            
            _buildNotificationTile(
              title: 'Attendance Reminders',
              subtitle: 'Daily check-in and check-out reminders',
              value: _attendanceReminders,
              onChanged: (value) => setState(() => _attendanceReminders = value),
              icon: Icons.access_time,
              enabled: _pushNotifications,
            ),
            
            _buildNotificationTile(
              title: 'System Updates',
              subtitle: 'App updates and new feature announcements',
              value: _systemUpdates,
              onChanged: (value) => setState(() => _systemUpdates = value),
              icon: Icons.system_update,
              enabled: _pushNotifications,
            ),
            
            const SizedBox(height: 30),
            
            // Notification Behavior
            const Text(
              'Notification Behavior',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildNotificationTile(
              title: 'Sound',
              subtitle: 'Play sound for notifications',
              value: _soundEnabled,
              onChanged: (value) => setState(() => _soundEnabled = value),
              icon: Icons.volume_up,
              enabled: _pushNotifications,
            ),
            
            _buildNotificationTile(
              title: 'Vibration',
              subtitle: 'Vibrate for notifications',
              value: _vibrationEnabled,
              onChanged: (value) => setState(() => _vibrationEnabled = value),
              icon: Icons.vibration,
              enabled: _pushNotifications,
            ),
            

            
            const SizedBox(height: 30),
            
            // Test Notification Buttons
            const Text(
              'Test Different Notification Types',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1a1a1a),
              ),
            ),
            const SizedBox(height: 12),
            
            // First row of test buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testGeneralNotification,
                    icon: const Icon(Icons.notifications),
                    label: const Text('General'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testLeaveNotification,
                    icon: const Icon(Icons.event_busy),
                    label: const Text('Leave'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Second row of test buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testAttendanceNotification,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Attendance'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testSystemNotification,
                    icon: const Icon(Icons.system_update),
                    label: const Text('System'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tileColor: enabled ? Colors.white : Colors.grey.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled 
                ? const Color(0xFF4285F4).withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: enabled ? const Color(0xFF4285F4) : Colors.grey,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: enabled ? Colors.black87 : Colors.grey,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: enabled ? Colors.grey[600] : Colors.grey,
          ),
        ),
        trailing: Switch(
          value: enabled ? value : false,
          onChanged: enabled ? onChanged : null,
          activeColor: const Color(0xFF4285F4),
        ),
      ),
    );
  }



  void _testGeneralNotification() async {
    if (!_pushNotifications) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable push notifications first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await NotificationService.showTestNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('General test notification sent!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _testLeaveNotification() async {
    if (!_pushNotifications) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable push notifications first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await NotificationService.showLeaveNotification(
        title: 'Leave Request Update',
        body: 'Your leave request for tomorrow has been approved.',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave notification sent! (if enabled in settings)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _testAttendanceNotification() async {
    if (!_pushNotifications) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable push notifications first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await NotificationService.showAttendanceReminder(
        title: 'Attendance Reminder',
        body: 'Don\'t forget to punch in! Your shift starts in 15 minutes.',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance notification sent! (if enabled in settings)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _testSystemNotification() async {
    if (!_pushNotifications) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable push notifications first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await NotificationService.showSystemUpdate(
        title: 'System Update Available',
        body: 'A new version of HMU Time is available. Update now for the latest features.',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System notification sent! (if enabled in settings)'),
            backgroundColor: Colors.purple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Check both new and old key formats for backward compatibility
      _pushNotifications = prefs.getBool('general_notifications') ?? prefs.getBool('pushNotifications') ?? true;
      _leaveNotifications = prefs.getBool('leave_notifications') ?? prefs.getBool('leaveNotifications') ?? true;
      _attendanceReminders = prefs.getBool('attendance_reminders') ?? prefs.getBool('attendanceReminders') ?? true;
      _systemUpdates = prefs.getBool('system_updates') ?? prefs.getBool('systemUpdates') ?? false;
      _soundEnabled = prefs.getBool('sound') ?? prefs.getBool('soundEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration') ?? prefs.getBool('vibrationEnabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save with keys that match NotificationService expectations
      await prefs.setBool('general_notifications', _pushNotifications);
      await prefs.setBool('leave_notifications', _leaveNotifications);
      await prefs.setBool('attendance_reminders', _attendanceReminders);
      await prefs.setBool('system_updates', _systemUpdates);
      await prefs.setBool('sound', _soundEnabled);
      await prefs.setBool('vibration', _vibrationEnabled);
      
      // Also save with old keys for backward compatibility
      await prefs.setBool('pushNotifications', _pushNotifications);
      await prefs.setBool('leaveNotifications', _leaveNotifications);
      await prefs.setBool('attendanceReminders', _attendanceReminders);
      await prefs.setBool('systemUpdates', _systemUpdates);
      await prefs.setBool('soundEnabled', _soundEnabled);
      await prefs.setBool('vibrationEnabled', _vibrationEnabled);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}