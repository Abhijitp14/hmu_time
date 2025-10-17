import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/biometric_service.dart';
import '../../../services/working_hours_service.dart';

class EmployeeAttendanceDetailScreen extends StatefulWidget {
  final AppUser employee;
  final DateTime selectedMonth;

  const EmployeeAttendanceDetailScreen({
    Key? key,
    required this.employee,
    required this.selectedMonth,
  }) : super(key: key);

  @override
  State<EmployeeAttendanceDetailScreen> createState() => _EmployeeAttendanceDetailScreenState();
}

class _EmployeeAttendanceDetailScreenState extends State<EmployeeAttendanceDetailScreen> {
  final BiometricService _biometricService = BiometricService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  
  List<BiometricRecord> _monthPunches = [];
  bool _isLoading = true;
  WorkingHoursSettings? _workingHoursSettings;
  
  // Employee specific thresholds
  double _requiredHours = 8.0;
  double _halfDayThreshold = 4.0;
  double _incompleteThreshold = 7.5;
  String _lateThresholdTime = '10:00';
  
  // Summary data
  int _totalWorkingDays = 0;
  int _presentDays = 0;
  int _absentDays = 0;
  int _lateDays = 0;
  double _totalWorkingHours = 0.0;
  double _averageWorkingHours = 0.0;
  double _attendancePercentage = 0.0;

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadWorkingHoursSettings();
    await _loadEmployeeAttendanceData();
    _calculateSummaryData();
  }

  Future<void> _loadWorkingHoursSettings() async {
    try {
      _workingHoursSettings = await _workingHoursService.getWorkingHoursSettings();
      
      // Set employee-specific thresholds based on employee type
      if (widget.employee.isPartTimeEmployee) {
        _requiredHours = _workingHoursSettings!.partTimeEmployee.workingHours;
        _incompleteThreshold = _workingHoursSettings!.partTimeEmployee.incompleteRange.end;
        _halfDayThreshold = 0.0; // Part-time doesn't use half-day concept
      } else if (widget.employee.isConsultantEmployee) {
        _requiredHours = _workingHoursSettings!.consultantEmployee.workingHours;
        _halfDayThreshold = 0.0; // Consultant doesn't use half-day concept
        _incompleteThreshold = 0.0; // Consultant doesn't use incomplete concept
      } else {
        // Full-time employee
        _requiredHours = _workingHoursSettings!.fullTimeEmployee.workingHours;
        _halfDayThreshold = _workingHoursSettings!.fullTimeEmployee.halfDayRange.end;
        _incompleteThreshold = _workingHoursSettings!.fullTimeEmployee.incompleteRange.end;
        _lateThresholdTime = _workingHoursSettings!.fullTimeEmployee.lateThresholdTime;
      }
    } catch (e) {
      print('⚠️ Failed to load working hours settings: $e');
      // Use default values based on employee type
      if (widget.employee.isPartTimeEmployee) {
        _requiredHours = 4.0;
        _incompleteThreshold = 3.5;
        _halfDayThreshold = 0.0;
      } else if (widget.employee.isConsultantEmployee) {
        _requiredHours = 6.0;
        _incompleteThreshold = 0.0;
        _halfDayThreshold = 0.0;
      } else {
        _requiredHours = 8.0;
        _halfDayThreshold = 4.0;
        _incompleteThreshold = 7.5;
        _lateThresholdTime = '10:00';
      }
    }
  }

  Future<void> _loadEmployeeAttendanceData() async {
    if (widget.employee.empCode == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Get date range for selected month
      final fromDate = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
      final toDate = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0);
      
      // Try to get stored records first
      final result = await _biometricService.getStoredBiometricRecords(
        empCode: widget.employee.empCode!,
        fromDate: fromDate,
        toDate: toDate,
      );
      
      if (result.success && result.records.isNotEmpty) {
        _monthPunches = result.records;
      } else {
        // If no stored data, try to sync
        final syncResult = await _biometricService.syncBiometricData(
          empCode: widget.employee.empCode!,
          fromDate: fromDate,
          toDate: toDate,
        );
        
        if (syncResult.success) {
          // Wait for consistency and get synced data
          await Future.delayed(const Duration(seconds: 2));
          final syncedResult = await _biometricService.getStoredBiometricRecords(
            empCode: widget.employee.empCode!,
            fromDate: fromDate,
            toDate: toDate,
          );
          
          if (syncedResult.success) {
            _monthPunches = syncedResult.records;
          }
        }
      }
    } catch (e) {
      print('❌ Error loading employee attendance data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateSummaryData() {
    final year = widget.selectedMonth.year;
    final month = widget.selectedMonth.month;
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final today = DateTime.now();
    
    // Calculate total working days (exclude Sundays and future dates)
    _totalWorkingDays = 0;
    _presentDays = 0;
    _absentDays = 0;
    _lateDays = 0;
    _totalWorkingHours = 0.0;
    
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(year, month, day);
      
      // Skip future dates and Sundays
      if (date.isAfter(today) || date.weekday == 7) continue;
      
      _totalWorkingDays++;
      
      final dayPunches = _monthPunches.where((punch) =>
        punch.dateTime.year == year &&
        punch.dateTime.month == month &&
        punch.dateTime.day == day
      ).toList();
      
      if (dayPunches.isEmpty) {
        _absentDays++;
      } else {
        _presentDays++;
        
        // Calculate working hours and status for this day
        final dayData = _calculateDayWorkingHours(dayPunches);
        _totalWorkingHours += dayData['workingHours'] as double;
        
        // Count late days
        if (dayData['isLate'] as bool) _lateDays++;
      }
    }
    
    _averageWorkingHours = _presentDays > 0 ? _totalWorkingHours / _presentDays : 0.0;
    _attendancePercentage = _totalWorkingDays > 0 ? (_presentDays / _totalWorkingDays) * 100 : 0.0;
  }

  Map<String, dynamic> _calculateDayWorkingHours(List<BiometricRecord> dayPunches) {
    if (dayPunches.isEmpty) {
      return {
        'workingHours': 0.0,
        'status': 'Absent',
        'isLate': false,
        'checkIn': null,
        'checkOut': null,
      };
    }

    // Sort punches by time
    final sortedPunches = List<BiometricRecord>.from(dayPunches);
    sortedPunches.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // Get IN and OUT punches
    final inPunches = sortedPunches.where((r) => r.type == 'IN').toList();
    final outPunches = sortedPunches.where((r) => r.type == 'OUT').toList();

    DateTime? checkInTime;
    DateTime? checkOutTime;
    double workingHours = 0.0;
    bool isLate = false;
    String status = 'Total Hours';

    // Set check-in time
    if (inPunches.isNotEmpty) {
      checkInTime = inPunches.first.dateTime;
    } else if (sortedPunches.isNotEmpty) {
      checkInTime = sortedPunches.first.dateTime;
    }

    // Set check-out time
    if (outPunches.isNotEmpty) {
      checkOutTime = outPunches.last.dateTime;
    }

    // Calculate working hours
    if (checkInTime != null && checkOutTime != null) {
      final workingDuration = checkOutTime.difference(checkInTime);
      workingHours = workingDuration.inMinutes / 60.0;
    }

    // Check if late (only for full-time employees)
    if (checkInTime != null && widget.employee.isFullTimeEmployee) {
      final lateTimeParts = _lateThresholdTime.split(':');
      final lateHour = int.parse(lateTimeParts[0]);
      final lateMinute = int.parse(lateTimeParts[1]);
      
      isLate = checkInTime.hour > lateHour || 
               (checkInTime.hour == lateHour && checkInTime.minute > lateMinute);
    }

    // Calculate status based on employee type and working hours
    if (workingHours == 0.0) {
      if (checkInTime != null) {
        // Has check-in but no check-out
        if (widget.employee.isPartTimeEmployee || widget.employee.isConsultantEmployee) {
          status = 'Incomplete';
        } else {
          status = 'Half Day';
        }
      } else {
        status = 'Absent';
      }
    } else {
      // Has working hours - calculate status
      status = _calculateWorkStatus(workingHours);
    }

    return {
      'workingHours': workingHours,
      'status': status,
      'isLate': isLate,
      'checkIn': checkInTime,
      'checkOut': checkOutTime,
    };
  }

  String _calculateWorkStatus(double workingHours) {
    if (widget.employee.isPartTimeEmployee) {
      // Part-time: Only Full Day or Incomplete
      if (workingHours >= _requiredHours) {
        return 'Full Day';
      } else if (workingHours > 0) {
        return 'Incomplete';
      } else {
        return 'Total Hours';
      }
    } else if (widget.employee.isConsultantEmployee) {
      // Consultant: Only Full Day or Incomplete
      if (workingHours >= _requiredHours) {
        return 'Full Day';
      } else if (workingHours > 0) {
        return 'Incomplete';
      } else {
        return 'Total Hours';
      }
    } else {
      // Full-time: Full Day, Incomplete, or Half Day
      if (workingHours >= _requiredHours) {
        return 'Full Day';
      } else if (workingHours > _halfDayThreshold && workingHours <= _incompleteThreshold) {
        return 'Incomplete';
      } else if (workingHours > _incompleteThreshold && workingHours < _requiredHours) {
        return 'Full Day'; // Hours between incomplete end and required hours = Full Day
      } else if (workingHours > 0 && workingHours <= _halfDayThreshold) {
        return 'Half Day';
      } else {
        return 'Total Hours';
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Full Day':
        return Colors.green;
      case 'Half Day':
        return Colors.orange;
      case 'Incomplete':
        return Colors.red;
      case 'Absent':
        return Colors.red.withOpacity(0.7);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.employee.name} - Attendance Detail'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Calendar Section - Fixed height
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: _buildCalendarSection(),
                  ),
                  
                  // Summary Section - Flexible height
                  _buildSummarySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_monthNames[widget.selectedMonth.month - 1]} ${widget.selectedMonth.year} Calendar',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildCalendarGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final year = widget.selectedMonth.year;
    final month = widget.selectedMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday
    
    // Days of week headers
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Calculate total cells needed
    final totalDays = lastDayOfMonth.day;
    final leadingEmptyCells = firstDayWeekday - 1;
    final totalCells = leadingEmptyCells + totalDays;
    final rows = (totalCells / 7).ceil();
    
    return Column(
      children: [
        // Week day headers
        Row(
          children: weekDays.map((day) => Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
          )).toList(),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        
        // Calendar grid
        Expanded(
          child: Column(
            children: List.generate(rows, (rowIndex) {
              return Expanded(
                child: Row(
                  children: List.generate(7, (colIndex) {
                    final cellIndex = rowIndex * 7 + colIndex;
                    final dayNumber = cellIndex - leadingEmptyCells + 1;
                    
                    if (cellIndex < leadingEmptyCells || dayNumber > totalDays) {
                      // Empty cell
                      return Expanded(child: Container());
                    }
                    
                    final date = DateTime(year, month, dayNumber);
                    final dayPunches = _monthPunches.where((p) => 
                      p.dateTime.year == year &&
                      p.dateTime.month == month &&
                      p.dateTime.day == dayNumber
                    ).toList();
                    
                    return Expanded(
                      child: _buildCalendarCell(dayNumber, dayPunches, date),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
        
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildLegendItem('Full Day', Colors.green),
            _buildLegendItem('Half Day', Colors.orange),
            _buildLegendItem('Incomplete', Colors.orange),
            _buildLegendItem('Late', Colors.orange),
            _buildLegendItem('L-H (Late + Half)', Colors.orange),
            _buildLegendItem('L-Inc (Late + Inc)', Colors.orange),
            _buildLegendItem('Absent', Colors.red),
            _buildLegendItem('Holiday', Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarCell(int dayNumber, List<BiometricRecord> punches, DateTime date) {
    // Check if it's Sunday (weekday == 7)
    final isSunday = date.weekday == 7;
    final today = DateTime.now();
    final currentDate = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    
    Color backgroundColor;
    Color textColor = Colors.black87;
    Color? borderColor;
    String? statusText;
    
    if (isSunday) {
      // Sunday - Holiday
      backgroundColor = Colors.blue.withOpacity(0.2);
      borderColor = Colors.blue;
      textColor = Colors.blue[800]!;
      statusText = 'Holiday';
    } else if (currentDate.isAfter(todayDate)) {
      // Future date
      backgroundColor = Colors.grey.withOpacity(0.1);
      borderColor = Colors.grey[300];
      textColor = Colors.grey[600]!;
    } else if (punches.isNotEmpty) {
      // Has attendance data
      final dayData = _calculateDayWorkingHours(punches);
      final status = dayData['status'] as String;
      final isLate = dayData['isLate'] as bool;
      
      // Determine background color and status text
      if (status == 'Full Day') {
        backgroundColor = Colors.green.withOpacity(0.2);
        borderColor = Colors.green;
        statusText = isLate ? 'Late' : 'Full Day';
      } else if (status == 'Half Day') {
        backgroundColor = Colors.orange.withOpacity(0.2);
        borderColor = Colors.orange;
        // Combine half day and late status
        if (isLate) {
          statusText = 'L-H'; // Late + Half Day
        } else {
          statusText = 'Half Day';
        }
      } else if (status == 'Incomplete') {
        backgroundColor = Colors.orange.withOpacity(0.2);
        borderColor = Colors.orange;
        statusText = isLate ? 'L-Inc' : 'Incomplete';
      } else {
        // Any other status (like 'Total Hours')
        backgroundColor = Colors.orange.withOpacity(0.2);
        borderColor = Colors.orange;
        statusText = isLate ? 'Late' : status;
      }
    } else {
      // No attendance data - absent
      backgroundColor = Colors.red.withOpacity(0.2);
      borderColor = Colors.red;
      statusText = 'Absent';
    }
    
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor ?? Colors.transparent,
          width: 1,
        ),
      ),
      child: statusText != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayNumber.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                dayNumber.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: textColor,
                ),
              ),
            ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Summary',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Employee Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFF4285F4),
                        child: Text(
                          widget.employee.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.employee.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Employee Code: ${widget.employee.empCode ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Department: ${widget.employee.department ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
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
          ),
          
          const SizedBox(height: 16),
          
          // Attendance Metrics
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildMetricCard(
                  'Attendance %',
                  '${_attendancePercentage.toStringAsFixed(1)}%',
                  Icons.calendar_today,
                  _getAttendanceColor(_attendancePercentage),
                ),
                _buildMetricCard(
                  'Present Days',
                  '$_presentDays/$_totalWorkingDays',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildMetricCard(
                  'Absent Days',
                  _absentDays.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
                _buildMetricCard(
                  'Late Days',
                  _lateDays.toString(),
                  Icons.access_time,
                  Colors.orange,
                ),
                _buildMetricCard(
                  'Working Hours',
                  '${_totalWorkingHours.toStringAsFixed(1)}h',
                  Icons.timer,
                  Colors.blue,
                ),
                _buildMetricCard(
                  'Avg Hours/Day',
                  '${_averageWorkingHours.toStringAsFixed(1)}h',
                  Icons.bar_chart,
                  Colors.purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 75) return Colors.orange;
    return Colors.red;
  }
}