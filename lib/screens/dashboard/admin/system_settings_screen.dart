import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/user_model.dart';
import '../../../services/working_hours_service.dart';

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
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  
  // Working Hours Settings - Full Time
  double _workingHoursPerDay = 8.0;
  
  // Time ranges for categories
  TimeOfDay _halfDayStart = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _halfDayEnd = const TimeOfDay(hour: 5, minute: 59);
  TimeOfDay _incompleteStart = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _incompleteEnd = const TimeOfDay(hour: 7, minute: 59);
  
  // Working Hours Settings - Part Time
  double _partTimeWorkingHours = 6.0;
  
  // Part-time time ranges
  TimeOfDay _partTimeIncompleteStart = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _partTimeIncompleteEnd = const TimeOfDay(hour: 4, minute: 0);
  
  // Working Hours Settings - Consultant
  double _consultantWorkingHours = 4.0;
  
  // Late Threshold for Full-time employees only
  TimeOfDay _lateThreshold = const TimeOfDay(hour: 10, minute: 0);
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSystemSettings();
  }

  Future<void> _loadSystemSettings() async {
    try {
      // Check if user is authenticated first
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user found');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Verify user has admin privileges
      if (!widget.user.isAdmin) {
        print('❌ User does not have admin privileges');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: Admin privileges required')),
        );
        return;
      }

      // Try to load working hours settings (with automatic fallback to Firestore)
      WorkingHoursSettings? workingHoursSettings;
      try {
        print('🔧 Loading settings for authenticated admin user: ${currentUser.email}');
        workingHoursSettings = await _workingHoursService.getWorkingHoursSettings();
        print('✅ Successfully loaded working hours settings');
      } catch (e) {
        print('❌ Failed to load settings: $e');
        // Show user-friendly error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Settings loaded from local defaults. You can still update them.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      setState(() {
        if (workingHoursSettings != null) {
          // Use loaded settings - Full-time employee
          _workingHoursPerDay = workingHoursSettings.fullTimeEmployee.workingHours;
          _halfDayStart = _decimalToTimeOfDay(workingHoursSettings.fullTimeEmployee.halfDayRange.start);
          _halfDayEnd = _decimalToTimeOfDay(workingHoursSettings.fullTimeEmployee.halfDayRange.end);
          _incompleteStart = _decimalToTimeOfDay(workingHoursSettings.fullTimeEmployee.incompleteRange.start);
          _incompleteEnd = _decimalToTimeOfDay(workingHoursSettings.fullTimeEmployee.incompleteRange.end);
          
          // Parse late threshold time
          final lateTimeParts = workingHoursSettings.fullTimeEmployee.lateThresholdTime.split(':');
          _lateThreshold = TimeOfDay(
            hour: int.parse(lateTimeParts[0]),
            minute: int.parse(lateTimeParts[1]),
          );
          
          // Use loaded settings - Part-time employee
          _partTimeWorkingHours = workingHoursSettings.partTimeEmployee.workingHours;
          _partTimeIncompleteStart = _decimalToTimeOfDay(workingHoursSettings.partTimeEmployee.incompleteRange.start);
          _partTimeIncompleteEnd = _decimalToTimeOfDay(workingHoursSettings.partTimeEmployee.incompleteRange.end);
          
          // Use loaded settings - Consultant employee
          _consultantWorkingHours = workingHoursSettings.consultantEmployee.workingHours;
        } else {
          // Use sensible defaults for admin to configure
          _workingHoursPerDay = 8.0;
          _partTimeWorkingHours = 4.0;
          _consultantWorkingHours = 6.0;
          
          // Default time ranges for full-time
          _halfDayStart = const TimeOfDay(hour: 0, minute: 0);
          _halfDayEnd = const TimeOfDay(hour: 4, minute: 0);
          _incompleteStart = const TimeOfDay(hour: 6, minute: 0);
          _incompleteEnd = const TimeOfDay(hour: 7, minute: 30);
          
          // Default time ranges for part-time
          _partTimeIncompleteStart = const TimeOfDay(hour: 0, minute: 0);
          _partTimeIncompleteEnd = const TimeOfDay(hour: 3, minute: 30);
          
          // Default late threshold
          _lateThreshold = const TimeOfDay(hour: 10, minute: 0);
        }
      });
    } catch (e) {
      _showMessage('Failed to load settings: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }



  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Validate time ranges before saving
      if (!_validateTimeRanges()) {
        return; // Validation failed, don't save
      }

      // Create the new v3.0 structured settings object
      final settings = WorkingHoursSettings(
        fullTimeEmployee: FullTimeEmployeeSettings(
          workingHours: _workingHoursPerDay,
          halfDayRange: TimeRange(start: _timeToDecimal(_halfDayStart), end: _timeToDecimal(_halfDayEnd)),
          incompleteRange: TimeRange(start: _timeToDecimal(_incompleteStart), end: _timeToDecimal(_incompleteEnd)),
          lateThresholdTime: '${_lateThreshold.hour.toString().padLeft(2, '0')}:${_lateThreshold.minute.toString().padLeft(2, '0')}',
        ),
        partTimeEmployee: PartTimeEmployeeSettings(
          workingHours: _partTimeWorkingHours,
          incompleteRange: TimeRange(start: _timeToDecimal(_partTimeIncompleteStart), end: _timeToDecimal(_partTimeIncompleteEnd)),
        ),
        consultantEmployee: ConsultantEmployeeSettings(
          workingHours: _consultantWorkingHours,
        ),
      );

      final result = await _workingHoursService.updateWorkingHoursSettings(settings);

      if (result.success) {
        _showMessage(result.message ?? 'Settings saved successfully', isError: false);
      } else {
        _showMessage('Error saving settings: ${result.error}', isError: true);
      }
    } catch (e) {
      _showMessage('Error saving settings: $e', isError: true);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  double _timeToDecimal(TimeOfDay time) {
    return time.hour + (time.minute / 60.0);
  }

  TimeOfDay _decimalToTimeOfDay(double decimal) {
    int hours = decimal.floor();
    int minutes = ((decimal - hours) * 60).round();
    return TimeOfDay(hour: hours, minute: minutes);
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  bool _validateTimeRanges() {
    // Convert times to decimal for easier validation
    final halfDayStartDecimal = _timeToDecimal(_halfDayStart);
    final halfDayEndDecimal = _timeToDecimal(_halfDayEnd);
    final incompleteStartDecimal = _timeToDecimal(_incompleteStart);
    final incompleteEndDecimal = _timeToDecimal(_incompleteEnd);
    final partTimeIncompleteStartDecimal = _timeToDecimal(_partTimeIncompleteStart);
    final partTimeIncompleteEndDecimal = _timeToDecimal(_partTimeIncompleteEnd);

    // Validate Full-Time Employee ranges
    if (halfDayStartDecimal >= halfDayEndDecimal) {
      _showMessage('Error: Half Day start time must be before end time', isError: true);
      return false;
    }

    if (incompleteStartDecimal >= incompleteEndDecimal) {
      _showMessage('Error: Incomplete start time must be before end time', isError: true);
      return false;
    }

    // Check for gaps: Incomplete should start immediately after Half Day ends
    final expectedIncompleteStart = halfDayEndDecimal + (1/60); // Add 1 minute
    if (incompleteStartDecimal > expectedIncompleteStart + 0.01) { // Allow small rounding tolerance
      _showMessage(
        'Error: Gap detected between Half Day (${_formatTimeOfDay(_halfDayEnd)}) and Incomplete (${_formatTimeOfDay(_incompleteStart)}). '
        'Incomplete should start at ${_formatDecimalTime(halfDayEndDecimal + (1/60))} or immediately after Half Day ends.',
        isError: true
      );
      return false;
    }

    // Check that incomplete doesn't end beyond working hours
    if (incompleteEndDecimal >= _workingHoursPerDay) {
      _showMessage(
        'Error: Incomplete range cannot end at or after the full working day (${_workingHoursPerDay.toStringAsFixed(1)} hours). '
        'Incomplete should end before ${_formatDecimalTime(_workingHoursPerDay)}.',
        isError: true
      );
      return false;
    }

    // Validate Part-Time Employee ranges
    if (partTimeIncompleteStartDecimal >= partTimeIncompleteEndDecimal) {
      _showMessage('Error: Part-Time incomplete start time must be before end time', isError: true);
      return false;
    }

    if (partTimeIncompleteEndDecimal >= _partTimeWorkingHours) {
      _showMessage(
        'Error: Part-Time incomplete range cannot end at or after the full working day (${_partTimeWorkingHours.toStringAsFixed(1)} hours). '
        'Part-Time incomplete should end before ${_formatDecimalTime(_partTimeWorkingHours)}.',
        isError: true
      );
      return false;
    }

    return true; // All validations passed
  }

  String _formatDecimalTime(double decimal) {
    int hours = decimal.floor();
    int minutes = ((decimal - hours) * 60).round();
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _autoAdjustIncompleteStart() {
    // Calculate what the incomplete start time should be (1 minute after half day ends)
    final halfDayEndDecimal = _timeToDecimal(_halfDayEnd);
    final newIncompleteStartDecimal = halfDayEndDecimal + (1/60); // Add 1 minute
    
    // Convert back to TimeOfDay
    final newIncompleteStart = _decimalToTimeOfDay(newIncompleteStartDecimal);
    
    // Only update if the current incomplete start is creating a gap
    final currentIncompleteStartDecimal = _timeToDecimal(_incompleteStart);
    if (currentIncompleteStartDecimal > newIncompleteStartDecimal + 0.01) { // Allow small tolerance
      _incompleteStart = newIncompleteStart;
      
      // Show a helpful message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Auto-adjusted: Incomplete range now starts at ${_formatTimeOfDay(_incompleteStart)} to prevent gaps'
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _validatePartTimeRange() {
    final partTimeIncompleteEndDecimal = _timeToDecimal(_partTimeIncompleteEnd);
    
    // Warn if incomplete range exceeds working hours
    if (partTimeIncompleteEndDecimal >= _partTimeWorkingHours) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Warning: Part-time incomplete range ends at or after full day hours (${_partTimeWorkingHours.toStringAsFixed(1)}h). This may cause classification issues.'
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _validateWorkingHoursChange() {
    final incompleteEndDecimal = _timeToDecimal(_incompleteEnd);
    
    // Auto-adjust incomplete range if it exceeds new working hours
    if (incompleteEndDecimal >= _workingHoursPerDay) {
      final newIncompleteEndDecimal = _workingHoursPerDay - (1/60); // 1 minute before working hours
      _incompleteEnd = _decimalToTimeOfDay(newIncompleteEndDecimal.clamp(0.0, 23.98)); // Max 23:59
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Auto-adjusted: Incomplete range end moved to ${_formatTimeOfDay(_incompleteEnd)} to stay within working hours'
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _validatePartTimeWorkingHoursChange() {
    final partTimeIncompleteEndDecimal = _timeToDecimal(_partTimeIncompleteEnd);
    
    // Auto-adjust part-time incomplete range if it exceeds new working hours
    if (partTimeIncompleteEndDecimal >= _partTimeWorkingHours) {
      final newPartTimeIncompleteEndDecimal = _partTimeWorkingHours - (1/60); // 1 minute before working hours
      _partTimeIncompleteEnd = _decimalToTimeOfDay(newPartTimeIncompleteEndDecimal.clamp(0.0, 23.98)); // Max 23:59
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Auto-adjusted: Part-time incomplete range end moved to ${_formatTimeOfDay(_partTimeIncompleteEnd)} to stay within working hours'
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }



  Future<void> _showCustomTimePicker(BuildContext context, TimeOfDay currentTime, Function(TimeOfDay) onTimeChanged) async {
    final TextEditingController hourController = TextEditingController(text: currentTime.hour.toString().padLeft(2, '0'));
    final TextEditingController minuteController = TextEditingController(text: currentTime.minute.toString().padLeft(2, '0'));

    final result = await showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Time (24-hour format)'),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hour input
              SizedBox(
                width: 60,
                child: TextField(
                  controller: hourController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 2,
                  decoration: const InputDecoration(
                    labelText: 'HH',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(':', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              // Minute input
              SizedBox(
                width: 60,
                child: TextField(
                  controller: minuteController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 2,
                  decoration: const InputDecoration(
                    labelText: 'MM',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final hour = int.tryParse(hourController.text) ?? 0;
                final minute = int.tryParse(minuteController.text) ?? 0;
                
                // Validate hour and minute ranges
                if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
                  Navigator.of(context).pop(TimeOfDay(hour: hour, minute: minute));
                } else {
                  // Show error for invalid time
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid time! Hour: 0-23, Minute: 0-59')),
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      onTimeChanged(result);
    }
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



  Future<void> _showRecalculateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recalculate Attendance'),
        content: const Text(
          'This will recalculate all attendance statuses based on the current working hours settings. '
          'This may take a few minutes for large datasets.\n\n'
          'Do you want to proceed?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
            ),
            child: const Text('Recalculate'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _recalculateAttendance();
    }
  }

  Future<void> _recalculateAttendance() async {
    try {
      _showMessage('Starting recalculation...', isError: false);
      
      final result = await _workingHoursService.recalculateAllAttendanceStatuses();
      
      if (result.success) {
        _showMessage(
          'Successfully recalculated ${result.recordsUpdated} attendance records!', 
          isError: false
        );
      } else {
        _showMessage('Failed to recalculate: ${result.error}', isError: true);
      }
    } catch (e) {
      _showMessage('Error during recalculation: $e', isError: true);
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
              onPressed: _saveSettings,
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
                  const SizedBox(height: 32),
                  // Save All Settings Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
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
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
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
              // Full-Time Employee Settings
              _buildEmployeeTypeHeader('Full-Time Employees', Icons.work),
              const SizedBox(height: 16),
              
              _buildNumberSlider(
                'Full Day Working Hours',
                _workingHoursPerDay,
                6.0,
                12.0,
                (value) => setState(() {
                  _workingHoursPerDay = value;
                  _validateWorkingHoursChange();
                }),
                suffix: 'hours',
              ),
              const SizedBox(height: 16),
              
              _buildTimeRangePicker(
                'Incomplete Hours Range',
                'From',
                _incompleteStart,
                (time) => setState(() => _incompleteStart = time),
                'To',
                _incompleteEnd,
                (time) => setState(() => _incompleteEnd = time),
              ),
              const SizedBox(height: 16),
              
              _buildTimeRangePicker(
                'Half Day Range', 
                'From',
                _halfDayStart,
                (time) => setState(() => _halfDayStart = time),
                'To',
                _halfDayEnd,
                (time) => setState(() {
                  _halfDayEnd = time;
                  // Auto-adjust incomplete start to prevent gaps
                  _autoAdjustIncompleteStart();
                }),
              ),
              const SizedBox(height: 16),
              
              Align(
                alignment: Alignment.centerLeft,
                child: _buildTimeSelector(
                  'Late Threshold Time',
                  _lateThreshold,
                  (time) => setState(() => _lateThreshold = time),
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // Part-Time Employee Settings
              _buildEmployeeTypeHeader('Part-Time Employees', Icons.schedule),
              const SizedBox(height: 16),
              
              _buildNumberSlider(
                'Part-Time Full Day Hours',
                _partTimeWorkingHours,
                4.0,
                8.0,
                (value) => setState(() {
                  _partTimeWorkingHours = value;
                  _validatePartTimeWorkingHoursChange();
                }),
                suffix: 'hours',
              ),
              const SizedBox(height: 16),
              
              _buildTimeRangePicker(
                'Part-Time Incomplete Range',
                'From',
                _partTimeIncompleteStart,
                (time) => setState(() => _partTimeIncompleteStart = time),
                'To',
                _partTimeIncompleteEnd,
                (time) => setState(() {
                  _partTimeIncompleteEnd = time;
                  _validatePartTimeRange();
                }),
              ),
              
              const SizedBox(height: 12),
              
              // Part-Time Range Configuration
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Part-Time Configuration',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '✓ Incomplete: ${_formatTimeOfDay(_partTimeIncompleteStart)} - ${_formatTimeOfDay(_partTimeIncompleteEnd)}',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                    ),
                    Text(
                      '✓ Full Day: ${_formatDecimalTime(_timeToDecimal(_partTimeIncompleteEnd) + (1/60))} - ${_formatDecimalTime(_partTimeWorkingHours)} (${_partTimeWorkingHours.toStringAsFixed(1)}+ hours)',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // Consultant Employee Settings
              _buildEmployeeTypeHeader('Consultant Employees', Icons.business_center),
              const SizedBox(height: 16),
              
              _buildNumberSlider(
                'Consultant Full Day Hours',
                _consultantWorkingHours,
                2.0,
                6.0,
                (value) => setState(() => _consultantWorkingHours = value),
                suffix: 'hours',
              ),
              
              const SizedBox(height: 20),

              // Range Configuration Validation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Time Range Configuration',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '✓ Half Day: ${_formatTimeOfDay(_halfDayStart)} - ${_formatTimeOfDay(_halfDayEnd)}',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                    ),
                    Text(
                      '✓ Incomplete: ${_formatTimeOfDay(_incompleteStart)} - ${_formatTimeOfDay(_incompleteEnd)}',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                    ),
                    Text(
                      '✓ Full Day: ${_formatDecimalTime(_timeToDecimal(_incompleteEnd) + (1/60))} - ${_formatDecimalTime(_workingHoursPerDay)} (${_workingHoursPerDay.toStringAsFixed(1)}+ hours)',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Note: Ranges are automatically adjusted to prevent gaps. Incomplete starts right after Half Day ends.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Working Hours Guide
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Working Hours Guide:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    
                    const Text(
                      'Full-Time Employees:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      '• Half Day: ${_formatTimeOfDay(_halfDayStart)} to ${_formatTimeOfDay(_halfDayEnd)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Incomplete: ${_formatTimeOfDay(_incompleteStart)} to ${_formatTimeOfDay(_incompleteEnd)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Full Day: ${_workingHoursPerDay.toStringAsFixed(1)} hours or more',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Late Threshold: ${_formatTimeOfDay(_lateThreshold)} (attendance marked as late after this time)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    
                    const SizedBox(height: 8),
                    const Text(
                      'Part-Time Employees:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      '• Incomplete: ${_formatTimeOfDay(_partTimeIncompleteStart)} to ${_formatTimeOfDay(_partTimeIncompleteEnd)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Full Day: ${_partTimeWorkingHours.toStringAsFixed(1)} hours or more',
                      style: const TextStyle(fontSize: 12),
                    ),
                    
                    const SizedBox(height: 8),
                    const Text(
                      'Consultant Employees:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      '• Full Day: ${_consultantWorkingHours.toStringAsFixed(1)} hours or more',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• No incomplete hours threshold (all attendance is either full day or absent)',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showRecalculateDialog,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recalculate All Attendance'),
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

  Widget _buildEmployeeTypeHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4285F4), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4285F4),
          ),
        ),
      ],
    );
  }













  Widget _buildTimeSelector(String label, TimeOfDay currentTime, Function(TimeOfDay) onTimeChanged) {
    return Column(
      // mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
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

  Widget _buildTimeInputField(TimeOfDay currentTime, Function(TimeOfDay) onTimeChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: InkWell(
        onTap: () => _showCustomTimePicker(context, currentTime, onTimeChanged),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              _formatTimeOfDay(currentTime),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF34495E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangePicker(
    String title,
    String fromLabel,
    TimeOfDay fromTime,
    Function(TimeOfDay) onFromChanged,
    String toLabel,
    TimeOfDay toTime,
    Function(TimeOfDay) onToChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF34495E),
          ),
        ),
        const SizedBox(height: 8),
        // Labels row
        Row(
          children: [
            Expanded(
              child: Text(
                fromLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF34495E),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                toLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF34495E),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Time input fields row
        Row(
          children: [
            Expanded(
              child: _buildTimeInputField(fromTime, onFromChanged),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimeInputField(toTime, onToChanged),
            ),
          ],
        ),
      ],
    );
  }


}