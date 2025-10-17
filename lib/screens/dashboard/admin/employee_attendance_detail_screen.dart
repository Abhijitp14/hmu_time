import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/holiday_model.dart';
import '../../../services/biometric_service.dart';
import '../../../services/working_hours_service.dart';
import '../../../services/holiday_service.dart';
import '../../../services/leave_service.dart';

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
  final HolidayService _holidayService = HolidayService();
  final LeaveService _leaveService = LeaveService();
  
  List<BiometricRecord> _monthPunches = [];
  List<Holiday> _monthHolidays = [];
  List<DateTime> _leaveDates = [];
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
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _loadWorkingHoursSettings();
      await _loadEmployeeAttendanceData();
      await _loadHolidays();
      await _loadLeaveData();
      _calculateSummaryData();
    } catch (e) {
      print('❌ Error during initialization: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
    }
  }

  Future<void> _loadHolidays() async {
    try {
      // Get government and uncertain holidays for the selected month/year
      final allHolidays = await _holidayService.getHolidaysForYear(widget.selectedMonth.year);
      
      // Filter for government and uncertain holidays only in the selected month
      final holidaysForMonth = allHolidays.where((holiday) {
        final isTargetMonth = holiday.date.month == widget.selectedMonth.month;
        final isGovernmentOrUncertain = holiday.type == HolidayType.government || 
                                       holiday.type == HolidayType.uncertain;
        return isTargetMonth && isGovernmentOrUncertain;
      }).toList();
      
      setState(() {
        _monthHolidays = holidaysForMonth;
      });
    } catch (e) {
      print('❌ Error loading holidays: $e');
      setState(() {
        _monthHolidays = [];
      });
    }
  }

  Future<void> _loadLeaveData() async {
    try {
      // Get leave requests for this specific employee
      final result = await _leaveService.getAllEmployeeLeaveRequests(
        employeeId: widget.employee.empCode,
        limit: 100,
      );
      
      if (result.success) {
        final List<DateTime> leaveDates = [];
        
        for (final request in result.requests) {
          // Include approved and completed leaves
          if (request.status == 'approved' || request.status == 'completed') {
            // Use deductionDates from the leave request if available
            if (request.deductionDates != null && request.deductionDates!.isNotEmpty) {
              // Check if the leave deduction dates fall within the selected month
              final monthStart = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
              final monthEnd = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0);
              
              for (final deductionDate in request.deductionDates!) {
                // Only add if it's within the selected month
                if (!deductionDate.isBefore(monthStart) && !deductionDate.isAfter(monthEnd)) {
                  leaveDates.add(DateTime(deductionDate.year, deductionDate.month, deductionDate.day));
                }
              }
            } else {
              // Fallback: Generate dates from start to end date for approved leaves (excluding Sundays)
              final startDate = DateTime.parse(request.startDate);
              final endDate = DateTime.parse(request.endDate);
              
              // Check if the leave falls within the selected month
              final monthStart = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
              final monthEnd = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0);
              
              // Generate all dates between start and end date
              DateTime currentDate = startDate;
              while (!currentDate.isAfter(endDate)) {
                // Only add if it's within the selected month
                if (!currentDate.isBefore(monthStart) && !currentDate.isAfter(monthEnd)) {
                  // Skip Sundays (weekday 7)
                  if (currentDate.weekday != 7) {
                    leaveDates.add(DateTime(currentDate.year, currentDate.month, currentDate.day));
                  }
                }
                currentDate = currentDate.add(const Duration(days: 1));
              }
            }
          }
        }
        
        setState(() {
          _leaveDates = leaveDates;
        });
      }
    } catch (e) {
      print('❌ Error loading leave data: $e');
      setState(() {
        _leaveDates = [];
      });
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
      
      // Check if it's a Government/Uncertain holiday
      final isGovernmentOrUncertainHoliday = _monthHolidays.any((holiday) =>
          (holiday.type == HolidayType.government || holiday.type == HolidayType.uncertain) &&
          holiday.date.day == day &&
          holiday.date.month == date.month &&
          holiday.date.year == date.year
      );
      
      // Skip future dates, Sundays, and Government/Uncertain holidays
      if (date.isAfter(today) || date.weekday == 7 || isGovernmentOrUncertainHoliday) continue;
      
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
                _buildCalendarSection(),
                
                // Summary Section - Flexible height
                _buildSummarySection(),
              ],
            ),
          ),
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(rows, (rowIndex) {
              return Flexible(
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
            _buildLegendItem('Full - Full Day', Colors.green),
            _buildLegendItem('Half - Half Day', Colors.purple),
            _buildLegendItem('Inc - Incomplete', Colors.orange),
            _buildLegendItem('L-F - Late + Full', Colors.orange),
            _buildLegendItem('L-H - Late + Half', Colors.purple),
            _buildLegendItem('L-Inc - Late + Incomplete', Colors.orange),
            _buildLegendItem('Absent', Colors.red),
            _buildLegendItem('Holiday (Sunday)', Colors.blue),
            _buildLegendItem('Holiday (Gov/Unc)', Colors.indigo),
            _buildLegendItem('Leave (SL/PL/CL/OL/OH)', Colors.teal),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarCell(int dayNumber, List<BiometricRecord> punches, DateTime date) {
    // Check if it's Sunday (weekday == 7)
    final isSunday = date.weekday == 7;
    
    // Check if it's a government or uncertain holiday
    final isGovernmentOrUncertainHoliday = _monthHolidays.any((holiday) =>
        holiday.date.day == dayNumber &&
        holiday.date.month == date.month &&
        holiday.date.year == date.year
    );
    
    // Check if it's a leave day
    final isLeaveDay = _leaveDates.any((leaveDate) =>
        leaveDate.day == dayNumber &&
        leaveDate.month == date.month &&
        leaveDate.year == date.year
    );
    
    final today = DateTime.now();
    final currentDate = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    
    Color backgroundColor;
    Color textColor = Colors.black87;
    Color borderColor;
    String? statusText;
    
    // Priority 1: Government/Uncertain Holiday (ALWAYS shows as holiday, even if employee was present)
    if (isGovernmentOrUncertainHoliday) {
      backgroundColor = Colors.indigo.withOpacity(0.2);
      borderColor = Colors.indigo;
      textColor = Colors.indigo[800]!;
      statusText = 'Gov/Unc';
    } else if (punches.isNotEmpty) {
      // Priority 2: Check for attendance data (takes priority over employee leave/Sunday only)
      final dayData = _calculateDayWorkingHours(punches);
      final status = dayData['status'] as String;
      final isLate = dayData['isLate'] as bool;
      
      // Determine background color and status text
      if (status == 'Full Day') {
        if (isLate) {
          backgroundColor = Colors.orange.withOpacity(0.2);
          borderColor = Colors.orange;
          statusText = 'L-F'; // Late + Full Day
        } else {
          backgroundColor = Colors.green.withOpacity(0.2);
          borderColor = Colors.green;
          statusText = 'Full';
        }
      } else if (status == 'Half Day') {
        backgroundColor = Colors.purple.withOpacity(0.2);
        borderColor = Colors.purple;
        // Combine half day and late status
        if (isLate) {
          statusText = 'L-H'; // Late + Half Day
        } else {
          statusText = 'Half';
        }
      } else if (status == 'Incomplete') {
        backgroundColor = Colors.orange.withOpacity(0.2);
        borderColor = Colors.orange;
        statusText = isLate ? 'L-Inc' : 'Inc';
      } else {
        // Any other status (like 'Total Hours')
        backgroundColor = Colors.orange.withOpacity(0.2);
        borderColor = Colors.orange;
        statusText = isLate ? 'L-Oth' : 'Other';
      }
    } else if (currentDate.isAfter(todayDate)) {
      // Priority 3: Future date
      backgroundColor = Colors.grey.withOpacity(0.1);
      borderColor = Colors.grey[300]!;
      textColor = Colors.grey[600]!;
      statusText = null; // Future dates don't need status text
    } else if (isSunday) {
      // Priority 4: Sunday Holiday (only if no attendance and no gov/unc holiday)
      backgroundColor = Colors.blue.withOpacity(0.2);
      borderColor = Colors.blue;
      textColor = Colors.blue[800]!;
      statusText = 'Holiday';
    } else if (isLeaveDay) {
      // Priority 5: Employee Leave (only if no attendance and no gov/unc holiday)
      backgroundColor = Colors.teal.withOpacity(0.2);
      borderColor = Colors.teal;
      textColor = Colors.teal[800]!;
      statusText = 'Leave';
    } else {
      // Priority 6: No attendance data and no special status - Absent
      backgroundColor = Colors.red.withOpacity(0.2);
      borderColor = Colors.red;
      textColor = Colors.red[800]!;
      statusText = 'Absent';
    }
    
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: statusText != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              // mainAxisSize: MainAxisSize.min, 
              children: [
                Text(
                  dayNumber.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  statusText ?? '',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
          SizedBox(
            // height: MediaQuery.of(context).size.height * 0.6, // Fixed height for the grid
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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