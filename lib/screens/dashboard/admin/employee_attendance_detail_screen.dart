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
  State<EmployeeAttendanceDetailScreen> createState() =>
      _EmployeeAttendanceDetailScreenState();
}

class _EmployeeAttendanceDetailScreenState
    extends State<EmployeeAttendanceDetailScreen> {
  final BiometricService _biometricService = BiometricService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  final HolidayService _holidayService = HolidayService();
  final LeaveService _leaveService = LeaveService();

  List<BiometricRecord> _monthPunches = [];
  List<Holiday> _monthHolidays = [];
  List<DateTime> _leaveDates = [];
  List<DateTime> _officialLeaveDates =
      []; // Separate OL dates for priority handling
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
  double _totalWorkingHours = 0.0;
  double _attendancePercentage = 0.0;

  // Additional tracking for extra pay eligible attendance
  int _sundayPresentDays = 0; // Track Sunday attendance separately
  int _governmentHolidayPresentDays =
      0; // Track government holiday attendance separately
  int _uncertainHolidayPresentDays =
      0; // Track uncertain holiday attendance separately
  double _extraPayEligibleDays =
      0.0; // Track extra pay eligible days (Sunday + Gov Holiday)

  // New detailed attendance metrics
  int _fullDays =
      0; // Full Day + Late + Full + Incomplete + Late + Incomplete (company policy)
  int _halfDays = 0; // Half Day + Late + Half
  int _incompleteDays =
      0; // Late + Full + Late + Half + Incomplete + Late + Incomplete (behavioral tracking)
  int _leaveDays =
      0; // Only days where employee applied for leave AND was actually absent
  int _totalHolidays = 0; // Total holidays in the month

  final List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // Add controller for salary input
  final TextEditingController _salaryController = TextEditingController();
  double _enteredSalary = 0.0;

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
      _workingHoursSettings = await _workingHoursService
          .getWorkingHoursSettings();

      // Check if settings were loaded successfully
      if (_workingHoursSettings != null) {
        // Set employee-specific thresholds based on employee type
        if (widget.employee.isPartTimeEmployee) {
          _requiredHours = _workingHoursSettings!.partTimeEmployee.workingHours;
          _incompleteThreshold =
              _workingHoursSettings!.partTimeEmployee.incompleteRange.end;
          _halfDayThreshold = 0.0; // Part-time doesn't use half-day concept
        } else if (widget.employee.isConsultantEmployee) {
          _requiredHours =
              _workingHoursSettings!.consultantEmployee.workingHours;
          _halfDayThreshold = 0.0; // Consultant doesn't use half-day concept
          _incompleteThreshold =
              0.0; // Consultant doesn't use incomplete concept
        } else {
          // Full-time employee
          _requiredHours = _workingHoursSettings!.fullTimeEmployee.workingHours;
          _halfDayThreshold =
              _workingHoursSettings!.fullTimeEmployee.halfDayRange.end;
          _incompleteThreshold =
              _workingHoursSettings!.fullTimeEmployee.incompleteRange.end;
          _lateThresholdTime =
              _workingHoursSettings!.fullTimeEmployee.lateThresholdTime;
        }
        return; // Exit early if settings loaded successfully
      }
    } catch (e) {
      print('⚠️ Failed to load working hours settings: $e');
    }

    // Use default values if settings couldn't be loaded (either exception or null result)
    if (_workingHoursSettings == null) {
      print('⚠️ Using default working hours settings');
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
    if (widget.employee.empCode == null || widget.employee.empCode!.isEmpty) {
      return;
    }

    try {
      final empCode = widget.employee.empCode!; // Store once for reuse
      // Get date range for selected month
      final fromDate = DateTime(
        widget.selectedMonth.year,
        widget.selectedMonth.month,
        1,
      );
      final toDate = DateTime(
        widget.selectedMonth.year,
        widget.selectedMonth.month + 1,
        0,
      );

      // Try to get stored records first
      final result = await _biometricService.getStoredBiometricRecords(
        empCode: empCode,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (result.success && result.records.isNotEmpty) {
        _monthPunches = result.records;
      } else {
        // If no stored data, try to sync
        final syncResult = await _biometricService.syncBiometricData(
          empCode: empCode,
          fromDate: fromDate,
          toDate: toDate,
        );

        if (syncResult.success) {
          // Wait for consistency and get synced data
          await Future.delayed(const Duration(seconds: 2));
          final syncedResult = await _biometricService
              .getStoredBiometricRecords(
                empCode: empCode,
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
      final allHolidays = await _holidayService.getHolidaysForYear(
        widget.selectedMonth.year,
      );

      // Filter for government and uncertain holidays only in the selected month
      final holidaysForMonth = allHolidays.where((holiday) {
        final isTargetMonth = holiday.date.month == widget.selectedMonth.month;
        final isGovernmentOrUncertain =
            holiday.type == HolidayType.government ||
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
    // Check if employee has valid empCode
    if (widget.employee.empCode == null || widget.employee.empCode!.isEmpty) {
      return;
    }

    try {
      // Get leave requests for this specific employee
      final result = await _leaveService.getAllEmployeeLeaveRequests(
        employeeId: widget.employee.empCode,
        limit: 100,
      );

      if (result.success) {
        final List<DateTime> leaveDates = [];
        final List<DateTime> officialLeaveDates = [];

        for (final request in result.requests) {
          // Include approved and completed leaves
          if (request.status == 'approved' || request.status == 'completed') {
            List<DateTime> datesToAdd = [];

            // Use deductionDates from the leave request if available
            if (request.deductionDates != null &&
                request.deductionDates!.isNotEmpty) {
              // Check if the leave deduction dates fall within the selected month
              final monthStart = DateTime(
                widget.selectedMonth.year,
                widget.selectedMonth.month,
                1,
              );
              final monthEnd = DateTime(
                widget.selectedMonth.year,
                widget.selectedMonth.month + 1,
                0,
              );

              for (final deductionDate in request.deductionDates!) {
                // Only add if it's within the selected month
                if (!deductionDate.isBefore(monthStart) &&
                    !deductionDate.isAfter(monthEnd)) {
                  datesToAdd.add(
                    DateTime(
                      deductionDate.year,
                      deductionDate.month,
                      deductionDate.day,
                    ),
                  );
                }
              }
            } else {
              // Fallback: Generate dates from start to end date for approved leaves (excluding Sundays)
              final startDate = DateTime.parse(request.startDate);
              final endDate = DateTime.parse(request.endDate);

              // Check if the leave falls within the selected month
              final monthStart = DateTime(
                widget.selectedMonth.year,
                widget.selectedMonth.month,
                1,
              );
              final monthEnd = DateTime(
                widget.selectedMonth.year,
                widget.selectedMonth.month + 1,
                0,
              );

              // Generate all dates between start and end date
              DateTime currentDate = startDate;
              while (!currentDate.isAfter(endDate)) {
                // Only add if it's within the selected month
                if (!currentDate.isBefore(monthStart) &&
                    !currentDate.isAfter(monthEnd)) {
                  // Skip Sundays (weekday 7)
                  if (currentDate.weekday != 7) {
                    datesToAdd.add(
                      DateTime(
                        currentDate.year,
                        currentDate.month,
                        currentDate.day,
                      ),
                    );
                  }
                }
                currentDate = currentDate.add(const Duration(days: 1));
              }
            }

            // Separate Official Leave (OL) from other leave types
            if (request.leaveType == 'OL' ||
                request.leaveType == 'officialLeave') {
              officialLeaveDates.addAll(datesToAdd);
            } else {
              leaveDates.addAll(datesToAdd);
            }
          }
        }

        setState(() {
          _leaveDates = leaveDates;
          _officialLeaveDates = officialLeaveDates;
        });
      }
    } catch (e) {
      print('❌ Error loading leave data: $e');
      setState(() {
        _leaveDates = [];
        _officialLeaveDates = [];
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
    _totalWorkingHours = 0.0;

    // Reset new detailed metrics
    _fullDays = 0;
    _halfDays = 0;
    _incompleteDays = 0;
    _leaveDays = 0;
    _totalHolidays = 0;
    _sundayPresentDays = 0;
    _governmentHolidayPresentDays = 0;
    _uncertainHolidayPresentDays = 0;
    _extraPayEligibleDays = 0.0;

    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(year, month, day);

      // Check if it's a government holiday (separate from uncertain)
      final isGovernmentHoliday = _monthHolidays.any(
        (holiday) =>
            holiday.type == HolidayType.government &&
            holiday.date.day == day &&
            holiday.date.month == date.month &&
            holiday.date.year == date.year,
      );

      // Check if it's an uncertain holiday
      final isUncertainHoliday = _monthHolidays.any(
        (holiday) =>
            holiday.type == HolidayType.uncertain &&
            holiday.date.day == day &&
            holiday.date.month == date.month &&
            holiday.date.year == date.year,
      );

      // Check if it's a leave day
      final isLeaveDay = _leaveDates.any(
        (leaveDate) =>
            leaveDate.day == day &&
            leaveDate.month == date.month &&
            leaveDate.year == date.year,
      );

      // Check if it's an Official Leave (OL) day
      final isOfficialLeaveDay = _officialLeaveDates.any(
        (olDate) =>
            olDate.day == day &&
            olDate.month == date.month &&
            olDate.year == date.year,
      );

      // Skip future dates
      if (date.isAfter(today)) continue;

      // Get attendance data for this day
      final dayPunches = _monthPunches
          .where(
            (punch) =>
                punch.dateTime.year == year &&
                punch.dateTime.month == month &&
                punch.dateTime.day == day,
          )
          .toList();

      // Handle different day types
      if (date.weekday == 7) {
        // Sunday - count as holiday/present day
        _totalHolidays++; // Count Sunday as holiday for present days calculation
        _presentDays++; // Include Sunday as present day
        if (dayPunches.isNotEmpty) {
          _sundayPresentDays++; // Track Sunday attendance count

          // Calculate Sunday eligible days (full=1.0, half=0.5) - no late/incomplete deduction
          final dayData = _calculateDayWorkingHours(dayPunches);
          final status = dayData['status'] as String;

          if (status == 'Full Day' || status == 'Incomplete') {
            _extraPayEligibleDays +=
                1.0; // Sunday: Incomplete treated as Full Day
          } else if (status == 'Half Day') {
            _extraPayEligibleDays += 0.5; // Sunday: Half Day = 0.5
          }
        }
      } else if (isGovernmentHoliday && dayPunches.isEmpty) {
        // Government holiday with no attendance - count as present day
        _totalHolidays++; // Count all holidays for present days calculation
        _presentDays++; // Include all holidays as present days
      } else if (isUncertainHoliday) {
        // Uncertain holiday - count as present day, regardless of attendance
        _totalHolidays++; // Count all holidays for present days calculation
        _presentDays++; // Include all holidays as present days
        if (dayPunches.isNotEmpty) {
          _uncertainHolidayPresentDays++; // Track uncertain holiday attendance separately
        }
      } else if (isGovernmentHoliday && dayPunches.isNotEmpty) {
        // Government holiday with attendance - treat as extra pay, not regular working day
        _totalHolidays++; // Count all holidays for present days calculation
        _presentDays++; // Include all holidays as present days
        _governmentHolidayPresentDays++; // Track government holiday attendance

        // Calculate extra pay eligible days for government holiday
        final dayData = _calculateDayWorkingHours(dayPunches);
        final status = dayData['status'] as String;

        if (status == 'Full Day' || status == 'Incomplete') {
          _extraPayEligibleDays +=
              1.0; // Government holiday: Incomplete treated as Full Day
        } else if (status == 'Half Day') {
          _extraPayEligibleDays += 0.5; // Government holiday: Half Day = 0.5
        }
      } else {
        // Regular working day (not government holiday)
        _totalWorkingDays++;

        // Check for Official Leave FIRST (takes priority over everything)
        if (isOfficialLeaveDay) {
          _leaveDays++; // OL counts as a paid leave day, regardless of attendance
        } else if (dayPunches.isEmpty) {
          // No attendance data
          if (isLeaveDay) {
            _leaveDays++; // Other leave types - only count as leave, not absent
          } else {
            _absentDays++; // Pure absent day (no leave, no attendance)
          }
        } else {
          // Has attendance data and no OL on regular working day
          _presentDays++; // Count attendance on regular working days only

          // Calculate working hours and status for this day
          final dayData = _calculateDayWorkingHours(dayPunches);
          _totalWorkingHours += dayData['workingHours'] as double;

          final status = dayData['status'] as String;
          final isLate = dayData['isLate'] as bool;

          // Count detailed metrics based on status and late combination
          if (status == 'Full Day') {
            _fullDays++;
            if (isLate) {
              _incompleteDays++; // Late + Full counts as incomplete behavior
            }
          } else if (status == 'Half Day') {
            _halfDays++;
            if (isLate) {
              _incompleteDays++; // Late + Half counts as incomplete behavior
            }
          } else if (status == 'Incomplete') {
            _fullDays++; // Company policy: Incomplete is treated as Full Day
            _incompleteDays++; // Also count as incomplete behavior
            if (isLate) {
              // Late + Incomplete already counted above for both metrics
            }
          }
        }
      }
    }

    _attendancePercentage = _totalWorkingDays > 0
        ? ((_presentDays - _totalHolidays) / _totalWorkingDays) * 100
        : 0.0;
  }

  Map<String, dynamic> _calculateDayWorkingHours(
    List<BiometricRecord> dayPunches,
  ) {
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

      isLate =
          checkInTime.hour > lateHour ||
          (checkInTime.hour == lateHour && checkInTime.minute > lateMinute);
    }

    // Calculate status based on employee type and working hours
    if (workingHours == 0.0) {
      if (checkInTime != null) {
        // Has check-in but no check-out
        if (widget.employee.isPartTimeEmployee ||
            widget.employee.isConsultantEmployee) {
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
      } else if (workingHours > _halfDayThreshold &&
          workingHours <= _incompleteThreshold) {
        return 'Incomplete';
      } else if (workingHours > _incompleteThreshold &&
          workingHours < _requiredHours) {
        return 'Full Day'; // Hours between incomplete end and required hours = Full Day
      } else if (workingHours > 0 && workingHours <= _halfDayThreshold) {
        return 'Half Day';
      } else {
        return 'Total Hours';
      }
    }
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
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
          children: weekDays
              .map(
                (day) => Expanded(
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
                ),
              )
              .toList(),
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

                    if (cellIndex < leadingEmptyCells ||
                        dayNumber > totalDays) {
                      // Empty cell
                      return Expanded(child: Container());
                    }

                    final date = DateTime(year, month, dayNumber);
                    final dayPunches = _monthPunches
                        .where(
                          (p) =>
                              p.dateTime.year == year &&
                              p.dateTime.month == month &&
                              p.dateTime.day == dayNumber,
                        )
                        .toList();

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
            _buildLegendItem('OL - Official Leave', Colors.amber),
            _buildLegendItem('Full - Full Day', Colors.green),
            _buildLegendItem('Half Day, Late + Half', Colors.purple),
            _buildLegendItem(
              'Incomplete, Late + Full, Late + Inc',
              Colors.orange,
            ),
            _buildLegendItem('Absent', Colors.red),
            _buildLegendItem('Holiday (Sunday)', Colors.blue),
            _buildLegendItem('Holiday (Gov)', Colors.indigo),
            _buildLegendItem('Holiday (Uncertain)', Colors.indigo),
            _buildLegendItem('Extra Pay (E-F/E-H)', Colors.deepPurple),
            _buildLegendItem('Leave (SL/PL/CL/OH)', Colors.teal),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarCell(
    int dayNumber,
    List<BiometricRecord> punches,
    DateTime date,
  ) {
    // Check if it's Sunday (weekday == 7)
    final isSunday = date.weekday == 7;

    // Check if it's a government holiday (separate from uncertain)
    final isGovernmentHoliday = _monthHolidays.any(
      (holiday) =>
          holiday.type == HolidayType.government &&
          holiday.date.day == dayNumber &&
          holiday.date.month == date.month &&
          holiday.date.year == date.year,
    );

    // Check if it's an uncertain holiday
    final isUncertainHoliday = _monthHolidays.any(
      (holiday) =>
          holiday.type == HolidayType.uncertain &&
          holiday.date.day == dayNumber &&
          holiday.date.month == date.month &&
          holiday.date.year == date.year,
    );

    // Check if it's a leave day
    final isLeaveDay = _leaveDates.any(
      (leaveDate) =>
          leaveDate.day == dayNumber &&
          leaveDate.month == date.month &&
          leaveDate.year == date.year,
    );

    // Check if it's an Official Leave (OL) day
    final isOfficialLeaveDay = _officialLeaveDates.any(
      (olDate) =>
          olDate.day == dayNumber &&
          olDate.month == date.month &&
          olDate.year == date.year,
    );

    final today = DateTime.now();
    final currentDate = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(today.year, today.month, today.day);

    Color backgroundColor;
    Color textColor = Colors.black87;
    Color borderColor;
    String? statusText;

    // Priority 1: Official Leave (OL) - Takes precedence over EVERYTHING (attendance, holidays, etc.)
    if (isOfficialLeaveDay) {
      backgroundColor = Colors.amber.withOpacity(0.2);
      borderColor = Colors.amber;
      textColor = Colors.amber[800]!;
      statusText = 'OL';
    } else if (isGovernmentHoliday && punches.isEmpty) {
      // Priority 2: Government Holiday (only if no attendance)
      backgroundColor = Colors.indigo.withOpacity(0.2);
      borderColor = Colors.indigo;
      textColor = Colors.indigo[800]!;
      statusText = 'Gov Hol';
    } else if (isUncertainHoliday) {
      // Priority 3: Uncertain Holiday (ALWAYS shows as holiday, even if employee was present)
      backgroundColor = Colors.indigo.withOpacity(0.2);
      borderColor = Colors.indigo;
      textColor = Colors.indigo[800]!;
      statusText = 'Unc Hol';
    } else if (punches.isNotEmpty) {
      // Priority 4: Check for attendance data (takes priority over employee leave/Sunday/Government holidays when present)
      final dayData = _calculateDayWorkingHours(punches);
      final status = dayData['status'] as String;
      final isLate = dayData['isLate'] as bool;

      // Check if this is Extra Pay day (Sunday or Government Holiday with attendance)
      final isExtraPayDay = isSunday || isGovernmentHoliday;

      // Determine background color and status text
      if (status == 'Full Day') {
        if (isExtraPayDay) {
          // Extra Pay Full Day - Special styling and no late marking
          backgroundColor = Colors.deepPurple.withOpacity(0.2);
          borderColor = Colors.deepPurple;
          textColor = Colors.deepPurple[800]!;
          statusText = 'E-F'; // Extra Pay Full Day
        } else if (isLate) {
          backgroundColor = Colors.orange.withOpacity(0.2);
          borderColor = Colors.orange;
          statusText = 'L-F'; // Late + Full Day
        } else {
          backgroundColor = Colors.green.withOpacity(0.2);
          borderColor = Colors.green;
          statusText = 'Full';
        }
      } else if (status == 'Half Day') {
        if (isExtraPayDay) {
          // Extra Pay Half Day - Special styling and no late marking
          backgroundColor = Colors.deepPurple.withOpacity(0.2);
          borderColor = Colors.deepPurple;
          textColor = Colors.deepPurple[800]!;
          statusText = 'E-H'; // Extra Pay Half Day
        } else {
          backgroundColor = Colors.purple.withOpacity(0.2);
          borderColor = Colors.purple;
          // Combine half day and late status
          if (isLate) {
            statusText = 'L-H'; // Late + Half Day
          } else {
            statusText = 'Half';
          }
        }
      } else if (status == 'Incomplete') {
        if (isExtraPayDay) {
          // For Extra Pay days, don't show incomplete - treat as Full Day attendance
          backgroundColor = Colors.deepPurple.withOpacity(0.2);
          borderColor = Colors.deepPurple;
          textColor = Colors.deepPurple[800]!;
          statusText = 'E-F'; // Extra Pay Full Day (even if incomplete hours)
        } else {
          backgroundColor = Colors.orange.withOpacity(0.2);
          borderColor = Colors.orange;
          statusText = isLate ? 'L-Inc' : 'Inc';
        }
      } else {
        // Any other status (like 'Total Hours')
        if (isExtraPayDay) {
          // For Extra Pay days, treat any attendance as Full Day
          backgroundColor = Colors.deepPurple.withOpacity(0.2);
          borderColor = Colors.deepPurple;
          textColor = Colors.deepPurple[800]!;
          statusText = 'E-F'; // Extra Pay Full Day
        } else {
          backgroundColor = Colors.orange.withOpacity(0.2);
          borderColor = Colors.orange;
          statusText = isLate ? 'L-Oth' : 'Other';
        }
      }
    } else if (currentDate.isAfter(todayDate)) {
      // Priority 5: Future date
      backgroundColor = Colors.grey.withOpacity(0.1);
      borderColor = Colors.grey[300]!;
      textColor = Colors.grey[600]!;
      statusText = null; // Future dates don't need status text
    } else if (isSunday) {
      // Priority 6: Sunday Holiday (only if no attendance and no gov/unc holiday)
      backgroundColor = Colors.blue.withOpacity(0.2);
      borderColor = Colors.blue;
      textColor = Colors.blue[800]!;
      statusText = 'Holiday';
    } else if (isLeaveDay) {
      // Priority 7: Employee Leave (only if no attendance and no gov/unc holiday)
      backgroundColor = Colors.teal.withOpacity(0.2);
      borderColor = Colors.teal;
      textColor = Colors.teal[800]!;
      statusText = 'Leave';
    } else {
      // Priority 8: No attendance data and no special status - Absent
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
        border: Border.all(color: borderColor, width: 1),
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
                  statusText,
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
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                          widget.employee.name.isNotEmpty
                              ? widget.employee.initials
                              : '?',
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
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: .8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMetricCard(
                  'Present Days',
                  '${_presentDays - _totalHolidays}/$_totalWorkingDays',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildMetricCard(
                  'Late/Incomplete',
                  _incompleteDays.toString(),
                  Icons.access_time,
                  Colors.orange,
                ),
                _buildMetricCard(
                  'Leave Days',
                  _leaveDays.toString(),
                  Icons.beach_access,
                  Colors.teal,
                ),
                _buildMetricCard(
                  'Full Days',
                  _fullDays.toString(),
                  Icons.check_circle_outline,
                  Colors.green,
                ),
                _buildMetricCard(
                  'Half Days',
                  _halfDays.toString(),
                  Icons.schedule,
                  Colors.purple,
                ),
                _buildMetricCard(
                  'Absent Days',
                  _absentDays.toString(),
                  Icons.cancel,
                  Colors.red,
                ),

                _buildMetricCard(
                  'Attendance %',
                  '${_attendancePercentage.toStringAsFixed(1)}%',
                  Icons.calendar_today,
                  _getAttendanceColor(_attendancePercentage),
                ),
                _buildMetricCard(
                  'Working Hours',
                  '${_totalWorkingHours.toStringAsFixed(1)}h',
                  Icons.timer,
                  Colors.blue,
                ),
                _buildMetricCard(
                  'Extra Pay',
                  '${_sundayPresentDays + _governmentHolidayPresentDays}',
                  Icons.add_circle_outline,
                  Colors.amber,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Salary Eligibility Section
          _buildSalaryEligibilitySection(),

          const SizedBox(height: 24),

          // Salary Calculator Section
          _buildSalaryCalculatorSection(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  Map<String, double> _calculateSalaryEligibility() {
    // Step 1: Calculate basic eligible days
    double fullDaysCredit = _fullDays.toDouble();
    double halfDaysCredit = _halfDays * 0.5; // 1 half day = 0.5 day
    double leaveDaysCredit = _leaveDays.toDouble();
    double holidaysCredit = _totalHolidays
        .toDouble(); // Add holidays to credits
    double extraPayDaysCredit =
        _extraPayEligibleDays; // Sunday + Government holiday eligible days

    // Step 2: Calculate total before deductions (including holidays in regular salary)
    double totalBeforeDeductions =
        fullDaysCredit + halfDaysCredit + leaveDaysCredit + holidaysCredit;

    // Step 3: Calculate Late/Incomplete deductions
    double lateIncompleteDeduction = 0.0;

    if (_incompleteDays > 0) {
      if (_incompleteDays <= 6) {
        // For 1-6 late/incomplete marks: deduct full days (3 marks = 1 day, 6 marks = 2 days)
        lateIncompleteDeduction = (_incompleteDays / 3.0).floorToDouble();
      } else {
        // After 6 marks: first 6 marks deduct 2 full days, then each additional mark deducts 0.5 day
        lateIncompleteDeduction = 2.0; // First 6 marks = 2 days
        int additionalMarks = _incompleteDays - 6;
        lateIncompleteDeduction +=
            additionalMarks * 0.5; // Each additional mark = 0.5 day
      }
    }

    // Step 4: Calculate final eligible days (regular salary days only)
    double finalEligibleDays = totalBeforeDeductions - lateIncompleteDeduction;
    if (finalEligibleDays < 0) finalEligibleDays = 0; // Can't be negative

    return {
      'fullDaysCredit': fullDaysCredit,
      'halfDaysCredit': halfDaysCredit,
      'leaveDaysCredit': leaveDaysCredit,
      'holidaysCredit': holidaysCredit,
      'extraPayDaysCredit': extraPayDaysCredit,
      'totalBeforeDeductions': totalBeforeDeductions,
      'lateIncompleteDeduction': lateIncompleteDeduction,
      'finalEligibleDays': finalEligibleDays,
    };
  }

  Widget _buildSalaryEligibilitySection() {
    final salaryData = _calculateSalaryEligibility();

    return Card(
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Salary Eligibility Calculation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Addition Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credits (+)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCalculationRow(
                    'Full Days',
                    '${_fullDays} × 1.0',
                    '${(salaryData['fullDaysCredit'] ?? 0.0).toStringAsFixed(1)} days',
                    Colors.green[600]!,
                  ),
                  _buildCalculationRow(
                    'Half Days',
                    '${_halfDays} × 0.5',
                    '${(salaryData['halfDaysCredit'] ?? 0.0).toStringAsFixed(1)} days',
                    Colors.purple[600]!,
                  ),
                  _buildCalculationRow(
                    'Leave Days',
                    '${_leaveDays} × 1.0',
                    '${(salaryData['leaveDaysCredit'] ?? 0.0).toStringAsFixed(1)} days',
                    Colors.teal[600]!,
                  ),
                  _buildCalculationRow(
                    'Holidays',
                    '${_totalHolidays} × 1.0',
                    '${(salaryData['holidaysCredit'] ?? 0.0).toStringAsFixed(1)} days',
                    Colors.cyan[600]!,
                  ),
                  const Divider(),
                  _buildCalculationRow(
                    'Total Before Deductions',
                    '',
                    '${(salaryData['totalBeforeDeductions'] ?? 0.0).toStringAsFixed(1)} days',
                    Colors.green[700]!,
                    isTotal: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Deduction Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deductions (-)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCalculationRow(
                    'Late/Incomplete Penalty',
                    _buildDeductionFormula(),
                    '${(salaryData['lateIncompleteDeduction'] ?? 0.0).toStringAsFixed(1)} days',
                    Colors.red[600]!,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Extra Pay Section
            if (_extraPayEligibleDays > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.stars,
                          color: Colors.deepPurple[700],
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Extra Pay Days (Bonus)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_sundayPresentDays > 0)
                      _buildCalculationRow(
                        'Sunday Attendance',
                        '${_sundayPresentDays} days present',
                        'Extra Pay',
                        Colors.deepPurple[600]!,
                      ),
                    if (_governmentHolidayPresentDays > 0)
                      _buildCalculationRow(
                        'Government Holiday Attendance',
                        '${_governmentHolidayPresentDays} days present',
                        'Extra Pay',
                        Colors.deepPurple[600]!,
                      ),
                    const Divider(),
                    _buildCalculationRow(
                      'Total Extra Pay',
                      '',
                      '${(salaryData['extraPayDaysCredit'] ?? 0.0).toStringAsFixed(1)} days',
                      Colors.deepPurple[700]!,
                      isTotal: true,
                    ),
                  ],
                ),
              ),

            if (_extraPayEligibleDays > 0) const SizedBox(height: 12),

            // Final Result
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[300]!, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Text(
                  //   '${(_presentDays + _sundayPresentDays)} present days total (including ${_totalHolidays} holidays)',
                  //   style: TextStyle(
                  //     fontSize: 14,
                  //     color: Colors.blue[600],
                  //     fontStyle: FontStyle.italic,
                  //   ),
                  //   textAlign: TextAlign.center,
                  // ),

                  // const SizedBox(height: 8),
                  Text(
                    'Final Salary Eligible Days',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(salaryData['finalEligibleDays'] ?? 0.0).toStringAsFixed(1)} out of ${DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day} days',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (_extraPayEligibleDays > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurple[300]!),
                      ),
                      child: Text(
                        '& eligible for ${_extraPayEligibleDays.toStringAsFixed(1)} extra pay days',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.deepPurple[700],
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Extra attendance info (if any holiday attendance - Sunday now counted in salary)
            if (_governmentHolidayPresentDays > 0 ||
                _uncertainHolidayPresentDays > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber[700],
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Extra Attendance (Not counted in salary)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_governmentHolidayPresentDays > 0)
                      Text(
                        '• Government holiday attendance: $_governmentHolidayPresentDays days',
                      ),

                    const SizedBox(height: 8),

                    // Formula explanation
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Deduction Rule: First 6 late/incomplete marks → 1 day deducted per 3 marks. After 6 marks → 0.5 day deducted per additional mark.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationRow(
    String label,
    String formula,
    String result,
    Color color, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          if (formula.isNotEmpty)
            Expanded(
              flex: 2,
              child: Text(
                formula,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          Expanded(
            flex: 2,
            child: Text(
              result,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _buildDeductionFormula() {
    if (_incompleteDays == 0) return '0 marks';

    if (_incompleteDays <= 6) {
      return '$_incompleteDays ÷ 3';
    } else {
      int additionalMarks = _incompleteDays - 6;
      return '2 + ($additionalMarks × 0.5)';
    }
  }

  Widget _buildSalaryCalculatorSection() {
    final salaryData = _calculateSalaryEligibility();
    final totalDaysInMonth = DateTime(
      widget.selectedMonth.year,
      widget.selectedMonth.month + 1,
      0,
    ).day;
    final finalEligibleDays = salaryData['finalEligibleDays'] ?? 0.0;
    final extraPayDays = salaryData['extraPayDaysCredit'] ?? 0.0;

    // Calculate per day rate
    final perDayRate = _enteredSalary > 0
        ? _enteredSalary / totalDaysInMonth
        : 0.0;

    // Calculate employee salary based on eligible days
    final employeeSalary = perDayRate * finalEligibleDays;

    // Calculate extra pay
    final extraPay = perDayRate * extraPayDays;

    // Total salary
    final totalSalary = employeeSalary + extraPay;

    return Card(
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.currency_rupee, color: Colors.green[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Salary Calculator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Salary Input Field
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter Monthly Salary (₹)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _salaryController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _enteredSalary = double.tryParse(value) ?? 0.0;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter salary amount',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_enteredSalary > 0) ...[
              const SizedBox(height: 16),

              // Calculation Formula Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calculation Formula',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Per Day Rate Calculation
                    _buildSalaryCalculationRow(
                      'Per Day Rate',
                      '₹${_enteredSalary.toStringAsFixed(0)} ÷ $totalDaysInMonth days',
                      '₹${perDayRate.toStringAsFixed(2)}',
                      Colors.blue[600]!,
                    ),

                    const Divider(height: 20),

                    // Employee Salary Calculation
                    _buildSalaryCalculationRow(
                      'Employee Salary',
                      '₹${perDayRate.toStringAsFixed(2)} × ${finalEligibleDays.toStringAsFixed(1)} days',
                      '₹${employeeSalary.toStringAsFixed(2)}',
                      Colors.green[600]!,
                    ),

                    if (extraPayDays > 0) ...[
                      // Extra Pay Calculation
                      _buildSalaryCalculationRow(
                        'Extra Pay',
                        '₹${perDayRate.toStringAsFixed(2)} × ${extraPayDays.toStringAsFixed(1)} days',
                        '₹${extraPay.toStringAsFixed(2)}',
                        Colors.deepPurple[600]!,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Final Result
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Final Salary Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Employee Salary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Employee Salary:',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          '₹${employeeSalary.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),

                    if (extraPayDays > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Extra Pay:',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.deepPurple[700],
                            ),
                          ),
                          Text(
                            '₹${extraPay.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple[700],
                            ),
                          ),
                        ],
                      ),
                    ],

                    const Divider(height: 20),

                    // Total Salary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Payable:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                        Text(
                          '₹${totalSalary.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      extraPayDays > 0
                          ? 'Employee is eligible for ₹${employeeSalary.toStringAsFixed(2)} + ₹${extraPay.toStringAsFixed(2)} (extra pay)'
                          : 'Employee is eligible for ₹${employeeSalary.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.green[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryCalculationRow(
    String label,
    String formula,
    String result,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              formula,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              result,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
