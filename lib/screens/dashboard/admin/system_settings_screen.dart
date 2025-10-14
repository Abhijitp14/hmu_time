import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';
import '../../../services/notification_service.dart';

class SystemSettingsScreen extends StatefulWidget {
  final AppUser user;

  const SystemSettingsScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Working Hours Settings
  TimeOfDay _workingStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _workingEndTime = const TimeOfDay(hour: 18, minute: 0);
  double _workingHoursPerDay = 8.0;
  
  // Attendance Settings
  TimeOfDay _lateThreshold = const TimeOfDay(hour: 10, minute: 0);
  int _lateGracePeriod = 15; // minutes
  bool _enableOvertimeTracking = true;
  double _overtimeRate = 1.5;
  
  // Leave Settings
  int _casualLeaveBalance = 12;
  int _sickLeaveBalance = 12;
  int _paidLeaveBalance = 21;
  int _optionalHolidayBalance = 3;
  bool _requireManagerApproval = true;
  int _advanceNotificationDays = 1;
  
  // Notification Settings
  bool _sendDailyReminders = true;
  bool _sendWeeklyReports = true;
  bool _sendLeaveNotifications = true;
  bool _sendSystemUpdates = true;
  
  // Security Settings  
  bool _requirePasswordChange = false;
  int _passwordExpiryDays = 90;
  int _maxLoginAttempts = 5;
  int _sessionTimeoutMinutes = 60;
  
  // System Settings
  String _companyName = 'HMU Time';
  String _companyEmail = 'support@hmutime.com';
  String _companyPhone = '+918793641948';
  bool _enableBiometricSync = true;
  int _syncIntervalMinutes = 30;
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSystemSettings();
  }

  Future<void> _loadSystemSettings() async {
    try {
      final doc = await _firestore.collection('system_settings').doc('config').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          // Working Hours
          _workingStartTime = _parseTimeFromString(data['workingStartTime'] ?? '09:00');
          _workingEndTime = _parseTimeFromString(data['workingEndTime'] ?? '18:00');
          _workingHoursPerDay = (data['workingHoursPerDay'] ?? 8.0).toDouble();
          
          // Attendance
          _lateThreshold = _parseTimeFromString(data['lateThreshold'] ?? '10:00');
          _lateGracePeriod = data['lateGracePeriod'] ?? 15;
          _enableOvertimeTracking = data['enableOvertimeTracking'] ?? true;
          _overtimeRate = (data['overtimeRate'] ?? 1.5).toDouble();
          
          // Leave Settings
          _casualLeaveBalance = data['casualLeaveBalance'] ?? 12;
          _sickLeaveBalance = data['sickLeaveBalance'] ?? 12;
          _paidLeaveBalance = data['paidLeaveBalance'] ?? 21;
          _optionalHolidayBalance = data['optionalHolidayBalance'] ?? 3;
          _requireManagerApproval = data['requireManagerApproval'] ?? true;
          _advanceNotificationDays = data['advanceNotificationDays'] ?? 1;
          
          // Notifications
          _sendDailyReminders = data['sendDailyReminders'] ?? true;
          _sendWeeklyReports = data['sendWeeklyReports'] ?? true;
          _sendLeaveNotifications = data['sendLeaveNotifications'] ?? true;
          _sendSystemUpdates = data['sendSystemUpdates'] ?? true;
          
          // Security
          _requirePasswordChange = data['requirePasswordChange'] ?? false;
          _passwordExpiryDays = data['passwordExpiryDays'] ?? 90;
          _maxLoginAttempts = data['maxLoginAttempts'] ?? 5;
          _sessionTimeoutMinutes = data['sessionTimeoutMinutes'] ?? 60;
          
          // System
          _companyName = data['companyName'] ?? 'HMU Time';
          _companyEmail = data['companyEmail'] ?? 'support@hmutime.com';
          _companyPhone = data['companyPhone'] ?? '+918793641948';
          _enableBiometricSync = data['enableBiometricSync'] ?? true;
          _syncIntervalMinutes = data['syncIntervalMinutes'] ?? 30;
        });
      }
    } catch (e) {
      _showMessage('Failed to load settings: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  TimeOfDay _parseTimeFromString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]), 
      minute: int.parse(parts[1]),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveSystemSettings() async {
    setState(() => _isSaving = true);
    
    try {
      final data = {
        // Working Hours
        'workingStartTime': _formatTimeOfDay(_workingStartTime),
        'workingEndTime': _formatTimeOfDay(_workingEndTime),
        'workingHoursPerDay': _workingHoursPerDay,
        
        // Attendance
        'lateThreshold': _formatTimeOfDay(_lateThreshold),
        'lateGracePeriod': _lateGracePeriod,
        'enableOvertimeTracking': _enableOvertimeTracking,
        'overtimeRate': _overtimeRate,
        
        // Leave Settings
        'casualLeaveBalance': _casualLeaveBalance,
        'sickLeaveBalance': _sickLeaveBalance,
        'paidLeaveBalance': _paidLeaveBalance,
        'optionalHolidayBalance': _optionalHolidayBalance,
        'requireManagerApproval': _requireManagerApproval,
        'advanceNotificationDays': _advanceNotificationDays,
        
        // Notifications
        'sendDailyReminders': _sendDailyReminders,
        'sendWeeklyReports': _sendWeeklyReports,
        'sendLeaveNotifications': _sendLeaveNotifications,
        'sendSystemUpdates': _sendSystemUpdates,
        
        // Security
        'requirePasswordChange': _requirePasswordChange,
        'passwordExpiryDays': _passwordExpiryDays,
        'maxLoginAttempts': _maxLoginAttempts,
        'sessionTimeoutMinutes': _sessionTimeoutMinutes,
        
        // System
        'companyName': _companyName,
        'companyEmail': _companyEmail,
        'companyPhone': _companyPhone,
        'enableBiometricSync': _enableBiometricSync,
        'syncIntervalMinutes': _syncIntervalMinutes,
        
        'lastUpdatedBy': widget.user.id,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection('system_settings').doc('config').set(data);
      _showMessage('System settings saved successfully!', isError: false);
      
    } catch (e) {
      _showMessage('Failed to save settings: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, TimeOfDay currentTime, Function(TimeOfDay) onTimeSelected) async {
    final time = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    if (time != null) {
      onTimeSelected(time);
    }
  }

  Future<void> _testNotifications() async {
    try {
      await NotificationService.showSystemUpdate(
        title: 'System Settings Test',
        body: 'This is a test notification from System Settings. All notification services are working properly!',
      );
      _showMessage('Test notification sent successfully!', isError: false);
    } catch (e) {
      _showMessage('Failed to send test notification: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _saveSystemSettings,
              icon: const Icon(Icons.save),
              tooltip: 'Save Settings',
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWorkingHoursSection(),
                  const SizedBox(height: 24),
                  _buildAttendanceSection(),
                  const SizedBox(height: 24),
                  _buildLeaveSection(),
                  const SizedBox(height: 24),
                  _buildNotificationSection(),
                  const SizedBox(height: 24),
                  _buildSecuritySection(),
                  const SizedBox(height: 24),
                  _buildCompanySection(),
                  const SizedBox(height: 24),
                  _buildSystemSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4285F4),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildWorkingHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Working Hours', Icons.access_time),
        _buildSettingsCard(
          child: Column(
            children: [
              _buildTimeSelector(
                'Working Start Time',
                _workingStartTime,
                (time) => setState(() => _workingStartTime = time),
              ),
              const SizedBox(height: 16),
              _buildTimeSelector(
                'Working End Time',
                _workingEndTime,
                (time) => setState(() => _workingEndTime = time),
              ),
              const SizedBox(height: 16),
              _buildNumberSlider(
                'Working Hours Per Day',
                _workingHoursPerDay,
                4.0,
                12.0,
                (value) => setState(() => _workingHoursPerDay = value),
                suffix: 'hours',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Attendance Settings', Icons.fingerprint),
        _buildSettingsCard(
          child: Column(
            children: [
              _buildTimeSelector(
                'Late Threshold Time',
                _lateThreshold,
                (time) => setState(() => _lateThreshold = time),
              ),
              const SizedBox(height: 16),
              _buildNumberSlider(
                'Late Grace Period',
                _lateGracePeriod.toDouble(),
                0,
                60,
                (value) => setState(() => _lateGracePeriod = value.round()),
                suffix: 'minutes',
              ),
              const SizedBox(height: 16),
              _buildSwitchTile(
                'Enable Overtime Tracking',
                _enableOvertimeTracking,
                (value) => setState(() => _enableOvertimeTracking = value),
              ),
              if (_enableOvertimeTracking) ...[
                const SizedBox(height: 16),
                _buildNumberSlider(
                  'Overtime Rate Multiplier',
                  _overtimeRate,
                  1.0,
                  3.0,
                  (value) => setState(() => _overtimeRate = value),
                  suffix: 'x',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Leave Management', Icons.event_busy),
        _buildSettingsCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField(
                      'Casual Leave',
                      _casualLeaveBalance.toString(),
                      (value) => _casualLeaveBalance = int.tryParse(value) ?? 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNumberField(
                      'Sick Leave',
                      _sickLeaveBalance.toString(),
                      (value) => _sickLeaveBalance = int.tryParse(value) ?? 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField(
                      'Paid Leave',
                      _paidLeaveBalance.toString(),
                      (value) => _paidLeaveBalance = int.tryParse(value) ?? 21,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNumberField(
                      'Optional Holiday',
                      _optionalHolidayBalance.toString(),
                      (value) => _optionalHolidayBalance = int.tryParse(value) ?? 3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSwitchTile(
                'Require Manager Approval',
                _requireManagerApproval,
                (value) => setState(() => _requireManagerApproval = value),
              ),
              const SizedBox(height: 16),
              _buildNumberSlider(
                'Advance Notice Required',
                _advanceNotificationDays.toDouble(),
                0,
                7,
                (value) => setState(() => _advanceNotificationDays = value.round()),
                suffix: 'days',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Notification Settings', Icons.notifications),
        _buildSettingsCard(
          child: Column(
            children: [
              _buildSwitchTile(
                'Send Daily Attendance Reminders',
                _sendDailyReminders,
                (value) => setState(() => _sendDailyReminders = value),
              ),
              const SizedBox(height: 12),
              _buildSwitchTile(
                'Send Weekly Reports',
                _sendWeeklyReports,
                (value) => setState(() => _sendWeeklyReports = value),
              ),
              const SizedBox(height: 12),
              _buildSwitchTile(
                'Send Leave Notifications',
                _sendLeaveNotifications,
                (value) => setState(() => _sendLeaveNotifications = value),
              ),
              const SizedBox(height: 12),
              _buildSwitchTile(
                'Send System Updates',
                _sendSystemUpdates,
                (value) => setState(() => _sendSystemUpdates = value),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _testNotifications,
                  icon: const Icon(Icons.send),
                  label: const Text('Test Notifications'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4285F4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Security Settings', Icons.security),
        _buildSettingsCard(
          child: Column(
            children: [
              _buildSwitchTile(
                'Require Regular Password Changes',
                _requirePasswordChange,
                (value) => setState(() => _requirePasswordChange = value),
              ),
              if (_requirePasswordChange) ...[
                const SizedBox(height: 16),
                _buildNumberSlider(
                  'Password Expiry',
                  _passwordExpiryDays.toDouble(),
                  30,
                  365,
                  (value) => setState(() => _passwordExpiryDays = value.round()),
                  suffix: 'days',
                ),
              ],
              const SizedBox(height: 16),
              _buildNumberSlider(
                'Max Login Attempts',
                _maxLoginAttempts.toDouble(),
                3,
                10,
                (value) => setState(() => _maxLoginAttempts = value.round()),
                suffix: 'attempts',
              ),
              const SizedBox(height: 16),
              _buildNumberSlider(
                'Session Timeout',
                _sessionTimeoutMinutes.toDouble(),
                15,
                480,
                (value) => setState(() => _sessionTimeoutMinutes = value.round()),
                suffix: 'minutes',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompanySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Company Information', Icons.business),
        _buildSettingsCard(
          child: Column(
            children: [
              _buildTextField(
                'Company Name',
                _companyName,
                (value) => _companyName = value,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Company Email',
                _companyEmail,
                (value) => _companyEmail = value,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Company Phone',
                _companyPhone,
                (value) => _companyPhone = value,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('System Configuration', Icons.settings),
        _buildSettingsCard(
          child: Column(
            children: [
              _buildSwitchTile(
                'Enable Biometric Sync',
                _enableBiometricSync,
                (value) => setState(() => _enableBiometricSync = value),
              ),
              if (_enableBiometricSync) ...[
                const SizedBox(height: 16),
                _buildNumberSlider(
                  'Sync Interval',
                  _syncIntervalMinutes.toDouble(),
                  5,
                  180,
                  (value) => setState(() => _syncIntervalMinutes = value.round()),
                  suffix: 'minutes',
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveSystemSettings,
                      icon: _isSaving 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save All Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay currentTime, Function(TimeOfDay) onTimeChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        InkWell(
          onTap: () => _selectTime(context, currentTime, onTimeChanged),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 8),
                Text(
                  currentTime.format(context),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberSlider(
    String label, 
    double value, 
    double min, 
    double max, 
    Function(double) onChanged,
    {String suffix = ''}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} $suffix',
              style: const TextStyle(fontSize: 16, color: Color(0xFF4285F4)),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * (suffix == 'x' ? 10 : 1)).round(),
          onChanged: onChanged,
          activeColor: const Color(0xFF4285F4),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF4285F4),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4285F4)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField(String label, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4285F4)),
            ),
            suffixText: 'days',
          ),
        ),
      ],
    );
  }
}