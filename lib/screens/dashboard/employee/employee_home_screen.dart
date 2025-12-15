import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../../models/user_model.dart';
import '../../../models/holiday_model.dart';
import '../../../services/biometric_service.dart';
import '../../../services/working_hours_service.dart';
import '../../../services/holiday_service.dart';
import '../../../services/leave_service.dart';

class EmployeeHomeScreen extends StatefulWidget {
  final AppUser user;

  const EmployeeHomeScreen({super.key, required this.user});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  final BiometricService _biometricService = BiometricService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  final HolidayService _holidayService = HolidayService();
  final LeaveService _leaveService = LeaveService();
  List<BiometricRecord> _todayPunches = [];
  List<Holiday> _monthHolidays = [];
  List<DateTime> _leaveDates = [];
  List<DateTime> _officialLeaveDates = [];
  bool _isLoadingToday = true; // Start with loading state
  bool _isSyncing = false;
  String? _todayCheckIn;
  String? _todayCheckOut;

  DateTime? _lastSyncTime;
  DateTime?
  _checkInDateTime; // Store actual check-in DateTime for late calculation
  Set<String> _syncedMonths = {}; // Track which months have been synced
  double _workingHours = 0.0; // Store working hours as decimal for calculation
  String _workStatus = 'Total Hours'; // Store work status text

  // Dynamic working hours settings from admin
  WorkingHoursSettings? _workingHoursSettings;
  double _requiredHours = 8.0;
  double _halfDayThreshold = 4.9; // Half Day: 0 to 4:59 hours
  double _incompleteThreshold = 7.9; // Incomplete: 5 to 7:59 hours
  String _lateThresholdTime = '10:00'; // Late threshold time

  // Month selection variables
  DateTime _selectedMonth = DateTime.now();
  List<DateTime> _availableMonths = [];
  DateTime _selectedDate = DateTime.now();
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

  // Summary data variables
  int _totalWorkingDays = 0;
  int _presentDays = 0;
  int _absentDays = 0;
  double _totalWorkingHours = 0.0;
  double _attendancePercentage = 0.0;

  // Additional tracking for extra pay eligible attendance
  int _sundayPresentDays = 0;
  int _governmentHolidayPresentDays = 0;
  int _uncertainHolidayPresentDays = 0;
  double _extraPayEligibleDays = 0.0;

  // New detailed attendance metrics
  int _fullDays = 0;
  int _halfDays = 0;
  int _incompleteDays = 0;
  int _leaveDays = 0;
  int _totalHolidays = 0; // Total holidays in the month

  // Calendar expansion state
  bool _isCalendarExpanded = false;

  @override
  void initState() {
    super.initState();
    _calculateAvailableMonths();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Set loading state from the beginning
    if (mounted) {
      setState(() => _isLoadingToday = true);
    }

    try {
      // Load working hours settings first
      await _loadWorkingHoursSettings();
      // Load holidays and leave data for summary
      await _loadHolidays();
      await _loadLeaveData();
      // Load existing data
      await _loadTodayPunches();
      // Calculate summary data
      _calculateSummaryData();

      // The loadTodayPunches already handles syncing if no data is found
      // No need for additional sync logic here
    } catch (e) {
      debugPrint('❌ Error during initialization: $e');
      _showSnackBar('Failed to load initial data: $e', isError: true);
    } finally {
      // Loading state is handled in _loadTodayPunches, so don't set it here
    }
  }

  bool _shouldAutoSync({bool isRefresh = false}) {
    // No last sync time - allow only on app start, not frequent auto-syncs
    if (_lastSyncTime == null) return true;

    final now = DateTime.now();
    final timeSinceLastSync = now.difference(_lastSyncTime!);

    // For pull-to-refresh on current day, require at least 2 minutes between syncs
    if (isRefresh && _isSelectedDateToday()) {
      return timeSinceLastSync.inMinutes >= 2;
    }

    // For regular auto-sync, wait 10 minutes (much less aggressive)
    return timeSinceLastSync.inMinutes >= 10;
  }

  void _calculateAvailableMonths() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final joiningDate = widget.user.joiningDate;

    _availableMonths = [currentMonth];

    // Calculate previous months (up to 2 months back)
    final joiningMonth = joiningDate != null
        ? DateTime(joiningDate.year, joiningDate.month)
        : null;

    DateTime workingMonth = currentMonth;
    for (int i = 1; i <= 2; i++) {
      workingMonth = DateTime(workingMonth.year, workingMonth.month - 1, 1);

      // Add month if employee was working during this period
      if (joiningMonth == null ||
          workingMonth.isAfter(joiningMonth) ||
          workingMonth.isAtSameMomentAs(joiningMonth)) {
        _availableMonths.insert(0, workingMonth);
      }
    }

    // Set selected month to current month by default
    _selectedMonth = currentMonth;
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Future<void> _loadWorkingHoursSettings() async {
    try {
      _workingHoursSettings = await _workingHoursService
          .getWorkingHoursSettings();
      setState(() {
        // Use employee-type-specific working hours from v3.0 structure
        if (widget.user.isPartTimeEmployee) {
          _requiredHours = _workingHoursSettings!.partTimeEmployee.workingHours;
          _incompleteThreshold =
              _workingHoursSettings!.partTimeEmployee.incompleteRange.end;
          // Part-time doesn't use half-day concept, only complete/incomplete
          _halfDayThreshold = 0.0;
        } else if (widget.user.isConsultantEmployee) {
          _requiredHours =
              _workingHoursSettings!.consultantEmployee.workingHours;
          // Consultant doesn't use half-day or incomplete concept, only full day or absent
          _halfDayThreshold = 0.0;
          _incompleteThreshold = 0.0;
        } else {
          // Full-time employee - use v3.0 structure
          _requiredHours = _workingHoursSettings!.fullTimeEmployee.workingHours;
          _halfDayThreshold =
              _workingHoursSettings!.fullTimeEmployee.halfDayRange.end;
          _incompleteThreshold =
              _workingHoursSettings!.fullTimeEmployee.incompleteRange.end;
          _lateThresholdTime =
              _workingHoursSettings!.fullTimeEmployee.lateThresholdTime;
        }
      });

      final employeeTypeText = widget.user.isPartTimeEmployee
          ? 'Part-Time'
          : widget.user.isConsultantEmployee
          ? 'Consultant'
          : 'Full-Time';
      print(
        '📋 Loaded Working Hours Settings for $employeeTypeText: Required=${_requiredHours}h, Half=${_halfDayThreshold}h, Incomplete=${_incompleteThreshold}h',
      );
    } catch (e) {
      print('⚠️ Failed to load working hours settings, using defaults: $e');
      // Keep default values based on employee type
      if (widget.user.isPartTimeEmployee) {
        _requiredHours = 4.0;
        _incompleteThreshold = 3.5;
        _halfDayThreshold = 0.0;
      } else if (widget.user.isConsultantEmployee) {
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

  void _onMonthChanged(DateTime? newMonth) {
    if (newMonth != null && newMonth != _selectedMonth) {
      setState(() {
        _selectedMonth = newMonth;
        // Reset selected date to first day of new month or today if current month
        final today = DateTime.now();
        if (newMonth.year == today.year && newMonth.month == today.month) {
          _selectedDate = today;
        } else {
          _selectedDate = DateTime(newMonth.year, newMonth.month, 1);
        }
      });
      // Reload all data for the selected month (holidays, leave data, and attendance)
      _reloadDataForMonth();
    }
  }

  Future<void> _reloadDataForMonth() async {
    try {
      // Load holidays and leave data for the new month
      await _loadHolidays();
      await _loadLeaveData();
      // Load attendance data
      await _loadTodayPunches();
      // The summary data will be calculated in _loadTodayPunches
    } catch (e) {
      debugPrint('❌ Error reloading data for month: $e');
      _showSnackBar('Failed to reload data: $e', isError: true);
    }
  }

  void _onDateSelected(DateTime selectedDate) {
    setState(() {
      _selectedDate = selectedDate;
      // Recalculate times for the selected date (no loading needed, just filtering existing data)
      _calculateTodayTimes();
    });
  }

  Future<void> _loadTodayPunches() async {
    debugPrint(
      '🔄 _loadTodayPunches started for empCode: ${widget.user.empCode}',
    );

    if (widget.user.empCode == null) {
      debugPrint('❌ No empCode found, setting loading to false');
      if (mounted) {
        setState(() => _isLoadingToday = false);
      }
      return;
    }

    try {
      // Ensure loading state is set (only set if not already loading)
      if (mounted && !_isLoadingToday) {
        setState(() => _isLoadingToday = true);
      }

      // Use selected month for data loading
      final today = DateTime.now();
      final isCurrentMonth =
          _selectedMonth.year == today.year &&
          _selectedMonth.month == today.month;

      // Get date range for selected month
      final fromDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final toDate = isCurrentMonth
          ? today
          : DateTime(
              _selectedMonth.year,
              _selectedMonth.month + 1,
              0,
            ); // Last day of month

      debugPrint(
        '📅 Date range: ${fromDate.toString()} to ${toDate.toString()}',
      );

      // First try to get stored records (faster)
      debugPrint('🔍 Attempting to get stored records...');
      BiometricSyncResult result = await _biometricService
          .getStoredBiometricRecords(
            empCode: widget.user.empCode!,
            fromDate: fromDate,
            toDate: toDate,
          );

      debugPrint(
        '📊 Stored records result: success=${result.success}, recordCount=${result.records.length}',
      );

      // Create month key for tracking
      final monthKey =
          '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

      // Check if we need to sync based on different scenarios
      bool shouldSync = false;
      String syncReason = '';

      if (!result.success || result.records.isEmpty) {
        // No stored data at all for this month
        shouldSync = true;
        syncReason = 'No stored data found for $monthKey';
      } else if (isCurrentMonth) {
        // For current month, always sync if it's today to get latest punch data
        final today = DateTime.now();
        final todayRecords = result.records
            .where(
              (record) =>
                  record.dateTime.year == today.year &&
                  record.dateTime.month == today.month &&
                  record.dateTime.day == today.day,
            )
            .toList();

        if (todayRecords.isEmpty) {
          // No data for today - always sync
          shouldSync = true;
          syncReason = 'No data for today (${today.day}/${today.month})';
        } else {
          // Check if we should sync for latest punch data
          final now = DateTime.now();
          final lastSyncHours = _lastSyncTime != null
              ? now.difference(_lastSyncTime!).inHours
              : 999;

          // Sync if it's during work hours (6 AM to 8 PM) and haven't synced in last hour
          final isWorkHours = now.hour >= 6 && now.hour <= 20;

          if (isWorkHours && lastSyncHours >= 1) {
            shouldSync = true;
            syncReason =
                'Syncing for latest punch data (last sync: ${lastSyncHours}h ago)';
          } else if (lastSyncHours >= 6) {
            // Always sync if haven't synced in 6+ hours
            shouldSync = true;
            syncReason = 'Long time since last sync (${lastSyncHours}h ago)';
          }
        }
      } else {
        // For previous months, check if month was ever synced
        if (!_syncedMonths.contains(monthKey)) {
          shouldSync = true;
          syncReason = 'Month $monthKey never synced before';
        }
      }

      if (shouldSync) {
        debugPrint('🔄 Syncing data: $syncReason');

        final syncResult = await _biometricService.syncBiometricData(
          empCode: widget.user.empCode!,
          fromDate: fromDate,
          toDate: toDate,
        );

        debugPrint(
          '🔄 Sync result: success=${syncResult.success}, recordsProcessed=${syncResult.recordsProcessed}',
        );

        if (syncResult.success) {
          // Mark this month as synced
          _syncedMonths.add(monthKey);

          // Update last sync time for current month
          if (isCurrentMonth) {
            _lastSyncTime = DateTime.now();
          }

          // Wait for Firestore consistency
          await Future.delayed(const Duration(seconds: 2));

          // Get the synced data
          result = await _biometricService.getStoredBiometricRecords(
            empCode: widget.user.empCode!,
            fromDate: fromDate,
            toDate: toDate,
          );

          debugPrint(
            '📊 After sync for $monthKey: success=${result.success}, recordCount=${result.records.length}',
          );
        } else {
          result = syncResult;
        }
      } else {
        debugPrint(
          '✅ Using stored data - no sync needed for $monthKey (${result.records.length} records)',
        );
      }

      // Process the data
      if (mounted) {
        setState(() {
          _todayPunches.clear();
          if (result.success && result.records.isNotEmpty) {
            _todayPunches = _removeDuplicateRecords(result.records);
          }
          _calculateTodayTimes();
        });
      }

      debugPrint('📋 Final processed punches: ${_todayPunches.length}');

      // Calculate summary data after loading punch data
      _calculateSummaryData();
    } catch (e) {
      debugPrint('❌ Exception in _loadTodayPunches: $e');
      _showSnackBar('Failed to load data: ${e.toString()}', isError: true);
    } finally {
      debugPrint('🏁 _loadTodayPunches finished, setting loading to false');
      if (mounted) {
        setState(() => _isLoadingToday = false);
      }
    }
  }

  List<BiometricRecord> _removeDuplicateRecords(List<BiometricRecord> records) {
    final seen = <String>{};
    return records.where((record) {
      final key = '${record.dateTime.millisecondsSinceEpoch}_${record.type}';
      return seen.add(key);
    }).toList();
  }

  void _calculateTodayTimes() {
    // Filter for selected date's punches
    final selectedDateOnly = _todayPunches
        .where(
          (punch) =>
              punch.dateTime.year == _selectedDate.year &&
              punch.dateTime.month == _selectedDate.month &&
              punch.dateTime.day == _selectedDate.day,
        )
        .toList();

    // Always initialize default values first
    _todayCheckIn = null;
    _todayCheckOut = null;
    _checkInDateTime = null;
    _workingHours = 0.0;
    _workStatus = 'Total Hours';

    if (selectedDateOnly.isEmpty) {
      return;
    }

    // Sort punches by time
    final sortedPunches = List<BiometricRecord>.from(selectedDateOnly);
    sortedPunches.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // Look for explicit IN and OUT punches first, fallback to first/last logic
    final inPunches = sortedPunches.where((r) => r.type == 'IN').toList();
    final outPunches = sortedPunches.where((r) => r.type == 'OUT').toList();

    // Set check-in time
    if (inPunches.isNotEmpty) {
      _checkInDateTime = inPunches.first.dateTime;
      _todayCheckIn = DateFormat('hh:mm a').format(inPunches.first.dateTime);
    } else if (sortedPunches.isNotEmpty) {
      _checkInDateTime = sortedPunches.first.dateTime;
      _todayCheckIn = DateFormat(
        'hh:mm a',
      ).format(sortedPunches.first.dateTime);
    } else {
      _checkInDateTime = null;
    }

    // Set check-out time and calculate working hours
    if (outPunches.isNotEmpty) {
      _todayCheckOut = DateFormat('hh:mm a').format(outPunches.last.dateTime);

      if (inPunches.isNotEmpty) {
        final workingDuration = outPunches.last.dateTime.difference(
          inPunches.first.dateTime,
        );
        final hours = workingDuration.inHours;
        final minutes = workingDuration.inMinutes % 60;

        // Calculate working hours as decimal (e.g., 8.5 hours)
        _workingHours = hours + (minutes / 60.0);
        _calculateWorkStatus();
        print(
          '⏱️ Working Hours Debug: Duration=${workingDuration.inMinutes}min, Hours=$hours, Minutes=$minutes, TotalHours=$_workingHours, Status=$_workStatus',
        );
      }
    } else {
      // No OUT punch found - check if there's a check-in
      _todayCheckOut = null;

      _workingHours = 0.0;

      if (inPunches.isNotEmpty) {
        // Has check-in but no check-out - apply employee type-specific logic
        if (widget.user.isPartTimeEmployee ||
            widget.user.isConsultantEmployee) {
          _workStatus = 'Incomplete';
          print(
            '⏱️ Working Hours Debug: ${widget.user.isPartTimeEmployee ? 'Part-time' : 'Consultant'} employee with check-in but no check-out - Status set to Incomplete',
          );
        } else {
          _workStatus = 'Half Day';
          print(
            '⏱️ Working Hours Debug: Full-time employee with check-in but no check-out - Status set to Half Day',
          );
        }
      } else {
        // No check-in and no check-out
        _workStatus = 'Total Hours';
      }
    }
  }

  bool _isCheckInLate() {
    if (_checkInDateTime == null) return false;

    // Only check for late arrival for full-time employees
    if (!widget.user.isFullTimeEmployee) {
      return false; // Part-time and consultants don't have late marks
    }

    // Get late threshold from settings, default to 10:00 if not available
    String lateThresholdTime = '10:00';
    if (_workingHoursSettings != null) {
      lateThresholdTime = _workingHoursSettings!.lateThresholdTime;
    }

    // Parse the late threshold time
    final lateTimeParts = lateThresholdTime.split(':');
    final lateHour = int.parse(lateTimeParts[0]);
    final lateMinute = int.parse(lateTimeParts[1]);

    // Extract the hour/minute from the UTC DateTime but treat them as local values
    final utcHour = _checkInDateTime!.hour;
    final utcMinute = _checkInDateTime!.minute;

    // Check if check-in time is after the late threshold
    final isLate =
        utcHour > lateHour || (utcHour == lateHour && utcMinute > lateMinute);

    print(
      '🕐 Late Check Debug: CheckIn=${_checkInDateTime}, UTCHour=$utcHour, UTCMinute=$utcMinute, LateThreshold=${lateThresholdTime}, IsLate=$isLate',
    );

    return isLate;
  }

  void _calculateWorkStatus() {
    if (widget.user.isPartTimeEmployee) {
      // Part-time employee logic: Only Full Day or Incomplete (no half day concepts)
      if (_workingHours >= _requiredHours) {
        _workStatus = 'Full Day';
      } else if (_workingHours > 0) {
        _workStatus = 'Incomplete';
      } else {
        _workStatus = 'Total Hours';
      }
    } else if (widget.user.isConsultantEmployee) {
      // Consultant employee logic: Only Full Day or Incomplete (no half day concepts)
      if (_workingHours >= _requiredHours) {
        _workStatus = 'Full Day';
      } else if (_workingHours > 0) {
        _workStatus = 'Incomplete';
      } else {
        _workStatus = 'Total Hours';
      }
    } else {
      // Full-time employee logic: Use dynamic thresholds from admin settings
      if (_workingHours >= _requiredHours) {
        _workStatus = 'Full Day';
      } else if (_workingHours > _halfDayThreshold &&
          _workingHours <= _incompleteThreshold) {
        _workStatus = 'Incomplete';
      } else if (_workingHours > _incompleteThreshold &&
          _workingHours < _requiredHours) {
        _workStatus =
            'Full Day'; // Hours between incomplete end and required hours = Full Day
      } else if (_workingHours > 0 && _workingHours <= _halfDayThreshold) {
        _workStatus = 'Half Day';
      } else {
        _workStatus = 'Total Hours';
      }
    }

    final employeeType = widget.user.isPartTimeEmployee
        ? 'Part-Time'
        : widget.user.isConsultantEmployee
        ? 'Consultant'
        : 'Full-Time';
    print(
      '📊 Work Status Calculation [$employeeType]: ${_workingHours}h (Required: ${_requiredHours}h, Half: ≤${_halfDayThreshold}h, Incomplete: ≤${_incompleteThreshold}h) -> $_workStatus',
    );

    if (widget.user.isFullTimeEmployee || widget.user.isPartTimeEmployee) {
      print(
        '📊 Range Logic: Half(0-${_halfDayThreshold}h), Incomplete(${_halfDayThreshold}-${_incompleteThreshold}h), Full(${_incompleteThreshold}h+)',
      );
    }
  }

  Color _getWorkStatusColor() {
    switch (_workStatus) {
      case 'Full Day':
        return Colors.green;
      case 'Half Day':
        return Colors.orange;
      case 'Incomplete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  int _getTodayPunchCount() {
    return _todayPunches
        .where(
          (punch) =>
              punch.dateTime.year == _selectedDate.year &&
              punch.dateTime.month == _selectedDate.month &&
              punch.dateTime.day == _selectedDate.day,
        )
        .length;
  }

  bool _isSelectedDateToday() {
    final today = DateTime.now();
    return _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
  }

  Future<void> _syncAttendance({bool isAutoSync = false}) async {
    if (widget.user.empCode == null) {
      _showSnackBar(
        'Employee code not found. Please contact HR.',
        isError: true,
      );
      return;
    }

    // Prevent concurrent sync operations
    if (_isSyncing) {
      if (!isAutoSync) {
        _showSnackBar('Sync already in progress...', isError: false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isSyncing = true);
    }

    try {
      // Record sync start time
      _lastSyncTime = DateTime.now();

      debugPrint(
        '🔄 Starting sync - isAutoSync: $isAutoSync, empCode: ${widget.user.empCode}',
      );
      // Sync current month and previous 2 months
      final today = DateTime.now();
      final currentMonth = DateTime(today.year, today.month, 1);
      final monthsToSync = <DateTime>[];

      // Add current month
      monthsToSync.add(currentMonth);

      // Add previous months based on joining date and availability
      final joiningDate = widget.user.joiningDate;

      // Calculate previous months more reliably
      DateTime workingMonth = currentMonth;
      for (int i = 1; i <= 2; i++) {
        // Subtract one month at a time to handle year boundaries properly
        workingMonth = DateTime(workingMonth.year, workingMonth.month - 1, 1);

        // Check if employee was working in this month
        if (joiningDate == null) {
          monthsToSync.add(workingMonth);
        } else {
          final joiningFirstDay = DateTime(
            joiningDate.year,
            joiningDate.month,
            1,
          );

          // Employee must have joined on or before this month
          if (workingMonth.isAfter(joiningFirstDay) ||
              workingMonth.isAtSameMomentAs(joiningFirstDay)) {
            monthsToSync.add(workingMonth);
          }
        }
      }

      if (!isAutoSync) {
        _showSnackBar(
          'Syncing ${monthsToSync.length} months of data...',
          isError: false,
        );
      }

      // Sync each month
      int successfulSyncs = 0;
      for (final month in monthsToSync) {
        try {
          final fromDate = DateTime(month.year, month.month, 1);
          final isCurrentMonth =
              month.year == today.year && month.month == today.month;
          final toDate = isCurrentMonth
              ? today
              : DateTime(month.year, month.month + 1, 0); // Last day of month

          final result = await _biometricService.syncBiometricData(
            empCode: widget.user.empCode!,
            fromDate: fromDate,
            toDate: toDate,
          );

          if (result.success) {
            successfulSyncs++;

            // Mark this month as synced
            final monthKey =
                '${month.year}-${month.month.toString().padLeft(2, '0')}';
            _syncedMonths.add(monthKey);
          }

          // Small delay between syncs to avoid overwhelming the API
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          // Log error but continue with other months
          debugPrint('Failed to sync month ${month.month}/${month.year}: $e');
        }
      }

      if (successfulSyncs > 0) {
        if (!isAutoSync) {
          _showSnackBar(
            'Successfully synced $successfulSyncs/${monthsToSync.length} months!',
            isError: false,
          );
        }

        // Wait for Firestore to propagate changes before reloading
        await Future.delayed(const Duration(seconds: 3));

        // Reload fresh data after successful sync
        debugPrint('🔄 Reloading data after successful sync...');
        await _loadTodayPunches();

        debugPrint(
          '📊 Data reload completed. Today\'s punches: ${_getTodayPunchCount()}',
        );

        if (!isAutoSync) {
          _showSnackBar('Data refreshed successfully!', isError: false);
        } else {
          debugPrint(
            '✅ Auto-sync completed successfully - ${_getTodayPunchCount()} punches found',
          );
        }
      } else {
        if (!isAutoSync) {
          _showSnackBar('Failed to sync attendance data', isError: true);
        } else {
          debugPrint('❌ Auto-sync failed');
        }
      }
    } catch (e) {
      if (!isAutoSync) {
        _showSnackBar('Sync failed: $e', isError: true);
      } else {
        debugPrint('❌ Auto-sync failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  String _getLastSyncText() {
    if (_lastSyncTime == null) return '';

    final now = DateTime.now();
    final diff = now.difference(_lastSyncTime!);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadHolidays() async {
    try {
      // Get government and uncertain holidays for the selected month/year
      final allHolidays = await _holidayService.getHolidaysForYear(
        _selectedMonth.year,
      );

      print(
        '🗓️ Loading holidays for ${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}',
      );
      print(
        '🗓️ Found ${allHolidays.length} total holidays for year ${_selectedMonth.year}',
      );

      // Filter for government and uncertain holidays only in the selected month
      final holidaysForMonth = allHolidays.where((holiday) {
        final isTargetMonth = holiday.date.month == _selectedMonth.month;
        final isGovernmentOrUncertain =
            holiday.type == HolidayType.government ||
            holiday.type == HolidayType.uncertain;
        final matches = isTargetMonth && isGovernmentOrUncertain;

        if (matches) {
          print(
            '🗓️ Including holiday: ${holiday.name} on ${holiday.date} (${holiday.type})',
          );
        }

        return matches;
      }).toList();

      print(
        '🗓️ Final filtered holidays for month: ${holidaysForMonth.length}',
      );

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
    if (widget.user.empCode == null || widget.user.empCode!.isEmpty) {
      return;
    }

    try {
      // Get leave requests for this specific employee
      final result = await _leaveService.getAllEmployeeLeaveRequests(
        employeeId: widget.user.empCode,
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
              datesToAdd = request.deductionDates!
                  .where(
                    (date) =>
                        date.month == _selectedMonth.month &&
                        date.year == _selectedMonth.year,
                  )
                  .toList();
            } else {
              // Fallback to date range if deductionDates not available
              final startDate = DateTime.parse(request.startDate);
              final endDate = DateTime.parse(request.endDate);
              DateTime currentDate = startDate;
              while (currentDate.isBefore(
                endDate.add(const Duration(days: 1)),
              )) {
                // Only include if in selected month
                if (currentDate.month == _selectedMonth.month &&
                    currentDate.year == _selectedMonth.year) {
                  datesToAdd.add(currentDate);
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
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
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
      final dayPunches = _todayPunches
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

          // Count detailed metrics based on status and late combination (following admin logic)
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
              // Late + Incomplete already counted above for incomplete behavior - don't double count
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
    if (checkInTime != null && widget.user.isFullTimeEmployee) {
      String lateThresholdTime = '10:00';
      if (_workingHoursSettings != null) {
        lateThresholdTime = _workingHoursSettings!.lateThresholdTime;
      }

      final lateTimeParts = lateThresholdTime.split(':');
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
        if (widget.user.isPartTimeEmployee ||
            widget.user.isConsultantEmployee) {
          status = 'Incomplete';
        } else {
          status = 'Half Day';
        }
      } else {
        status = 'Absent';
      }
    } else {
      // Has working hours - calculate status using helper method
      status = _getWorkStatusForHours(workingHours);
    }

    return {
      'workingHours': workingHours,
      'status': status,
      'isLate': isLate,
      'checkIn': checkInTime,
      'checkOut': checkOutTime,
    };
  }

  String _getWorkStatusForHours(double workingHours) {
    if (widget.user.isPartTimeEmployee) {
      // Part-time: Only Full Day or Incomplete
      if (workingHours >= _requiredHours) {
        return 'Full Day';
      } else if (workingHours > 0) {
        return 'Incomplete';
      } else {
        return 'Total Hours';
      }
    } else if (widget.user.isConsultantEmployee) {
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

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 75) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSummarySection() {
    final screenSize = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0).copyWith(bottom: 0),
          child: Text(
            'Monthly Summary',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        _isLoadingToday
            ? SizedBox(
                height: screenSize.height * 0.25,
                child: Center(
                  child: Lottie.asset('assets/animations/sandyLoading.json'),
                ),
              )
            : Container(
                padding: const EdgeInsets.all(16),
                // color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCalendarSection(),
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
                                    widget.user.name.isNotEmpty
                                        ? widget.user.initials
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.user.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Employee Code: ${widget.user.empCode ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        'Department: ${widget.user.department ?? 'N/A'}',
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
                    GridView.count(
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

                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // For current day, only sync if enough time has passed since last sync
            if (_isSelectedDateToday() &&
                !_isSyncing &&
                _shouldAutoSync(isRefresh: true)) {
              debugPrint(
                '📱 Pull-to-refresh on current day: Syncing to get latest punch data...',
              );
              await _syncAttendance(isAutoSync: true);
            } else {
              // For other dates or recent sync, just reload existing data without showing loading
              debugPrint(
                '📱 Pull-to-refresh: Reloading existing data (sync not needed or recent sync)',
              );
              // Don't show loading indicator for refresh, just reload data
              final currentLoadingState = _isLoadingToday;
              await _loadTodayPunches();
              // Restore loading state to prevent UI flickering during refresh
              if (mounted && !currentLoadingState) {
                setState(() => _isLoadingToday = false);
              }
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildMonthSelector(),
                _buildDateSelector(),
                _buildTodayAttendance(),
                _buildPunchDetails(),
                _buildSummarySection(),
                // const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF4285F4),
            child: Text(
              widget.user.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                Text(
                  widget.user.name.split(' ').first,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: _isSyncing ? null : _syncAttendance,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF4285F4),
                          ),
                        ),
                      )
                    : const Icon(Icons.sync, color: Color(0xFF4285F4)),
                tooltip: 'Sync Attendance',
              ),
              if (_lastSyncTime != null)
                Text(
                  _getLastSyncText(),
                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ).copyWith(top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Select Month',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DateTime>(
                    value: _selectedMonth,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF4285F4),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: _onMonthChanged,
                    items: _availableMonths.map<DropdownMenuItem<DateTime>>((
                      DateTime month,
                    ) {
                      final monthName = _monthNames[month.month - 1];
                      final year = month.year;
                      final isCurrentMonth =
                          month.year == DateTime.now().year &&
                          month.month == DateTime.now().month;

                      return DropdownMenuItem<DateTime>(
                        value: month,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$monthName $year'),
                            if (isCurrentMonth) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4285F4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Current',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Text(
          //   'Showing data from ${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
          //   style: TextStyle(
          //     fontSize: 12,
          //     color: Colors.grey[600],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final today = DateTime.now();
    final selectedYear = _selectedMonth.year;
    final selectedMonthNum = _selectedMonth.month;

    // Get the last day of the selected month
    final lastDayOfMonth = DateTime(selectedYear, selectedMonthNum + 1, 0);

    // Generate all days in the selected month
    final days = <DateTime>[];
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      days.add(DateTime(selectedYear, selectedMonthNum, i));
    }

    // If showing current month, limit to current date only (exclude future dates)
    List<DateTime> filteredDays =
        selectedMonthNum == today.month && selectedYear == today.year
        ? days.where((date) => date.day <= today.day).toList()
        : days;

    // Reverse the order to show latest dates first (31, 30, 29... to 1)
    final displayDays = filteredDays.reversed.toList();
    final screenSize = MediaQuery.of(context).size;
    return Container(
      // color: Colors.black,
      height: screenSize.height * 0.125,
      // width: ,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dates in ${_monthNames[selectedMonthNum - 1]} $selectedYear',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${displayDays.length} days',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: displayDays.length,
              itemBuilder: (context, index) {
                final date = displayDays[index];
                final isToday =
                    date.day == today.day &&
                    date.month == today.month &&
                    date.year == today.year;
                final isSelected =
                    date.day == _selectedDate.day &&
                    date.month == _selectedDate.month &&
                    date.year == _selectedDate.year;

                return Container(
                  width: screenSize.width * 0.18,
                  padding: const EdgeInsets.only(bottom: 4),
                  margin: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _onDateSelected(date),
                    child: _buildDateCard(
                      date.day.toString(),
                      DateFormat('EEE').format(date),
                      isToday,
                      isSelected: isSelected,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(
    String day,
    String dayName,
    bool isToday, {
    bool isSelected = false,
  }) {
    Color backgroundColor;
    Color textColor;

    if (isToday) {
      backgroundColor = const Color(0xFF4285F4);
      textColor = Colors.white;
    } else if (isSelected) {
      backgroundColor = const Color(0xFF4285F4).withValues(alpha: 0.2);
      textColor = const Color(0xFF4285F4);
    } else {
      backgroundColor = Colors.white;
      textColor = Colors.black87;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: const Color(0xFF4285F4), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dayName,
            style: TextStyle(
              fontSize: 10,
              color: isToday
                  ? Colors.white70
                  : (isSelected
                        ? const Color(0xFF4285F4).withValues(alpha: 0.7)
                        : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayAttendance() {
    final screenSize = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isSelectedDateToday()
                ? 'Today\'s Attendance'
                : 'Selected Date Attendance',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _isLoadingToday
              ? SizedBox(
                  height: screenSize.height * 0.25,
                  child: Center(
                    child: Lottie.asset('assets/animations/sandyLoading.json'),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildAttendanceCard(
                        'Check In',
                        _todayCheckIn ?? '--:--',
                        _todayCheckIn != null
                            ? (_isCheckInLate() ? 'Late Mark' : 'On Time')
                            : 'Not Checked',
                        Icons.login,
                        _todayCheckIn != null
                            ? (_isCheckInLate()
                                  ? Colors.red
                                  : const Color(0xFF4285F4))
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAttendanceCard(
                        'Check Out',
                        _todayCheckOut ?? '--:--',
                        _todayCheckOut != null ? 'Completed' : 'Pending',
                        Icons.logout,
                        _todayCheckOut != null ? Colors.orange : Colors.grey,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 16),
          if (!_isLoadingToday)
            Row(
              children: [
                Expanded(child: _buildWorkingTimeCard()),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAttendanceCard(
                    'Punch Count',
                    _getTodayPunchCount().toString(),
                    'Total Punches',
                    Icons.touch_app,
                    Colors.purple,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWorkingTimeCard() {
    final progressPercentage = (_workingHours / _requiredHours).clamp(0.0, 1.0);
    final hoursInt = _workingHours.floor();
    final minutes = ((_workingHours - hoursInt) * 60).round();
    final timeDisplay = '${hoursInt}h ${minutes}m';
    final targetDisplay = '/ ${_requiredHours.toStringAsFixed(1)}h';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getWorkStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.access_time,
                  color: _getWorkStatusColor(),
                  size: 20,
                ),
              ),
              const Spacer(),
              Text(
                '${(progressPercentage * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getWorkStatusColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                timeDisplay,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                targetDisplay,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Working Time',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progressPercentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(_getWorkStatusColor()),
            minHeight: 4,
          ),
          const SizedBox(height: 4),
          Text(
            _workStatus,
            style: TextStyle(
              fontSize: 10,
              color: _getWorkStatusColor(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchDetails() {
    // Filter punches for only the selected date
    final selectedDatePunches = _todayPunches
        .where(
          (punch) =>
              punch.dateTime.year == _selectedDate.year &&
              punch.dateTime.month == _selectedDate.month &&
              punch.dateTime.day == _selectedDate.day,
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isSelectedDateToday()
                    ? 'Today\'s Punch Details'
                    : '${DateFormat('MMM dd').format(_selectedDate)} Punch Details',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Selected: ${selectedDatePunches.length} punches',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoadingToday
              ? SizedBox(
                  height: 100,
                  child: Center(
                    child: Lottie.asset(
                      'assets/animations/amongUs.json',
                      width: 80,
                      height: 80,
                    ),
                  ),
                )
              : selectedDatePunches.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.fingerprint_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No punch records for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap sync to fetch latest data',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedDatePunches.length,
                  itemBuilder: (context, index) {
                    final punch = selectedDatePunches[index];
                    return _buildPunchItem(punch, index);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildPunchItem(BiometricRecord punch, int index) {
    final isCheckIn = punch.type == 'IN';
    final time = DateFormat('hh:mm:ss a').format(punch.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCheckIn
                  ? const Color(0xFF4285F4).withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCheckIn ? Icons.login : Icons.logout,
              color: isCheckIn ? const Color(0xFF4285F4) : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${punch.type} Punch',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (punch.location != null) ...[
                  Text(
                    punch.location!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (punch.deviceId != null) ...[
                Text(
                  punch.deviceId!,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expandable header
          GestureDetector(
            onTap: () {
              setState(() {
                _isCalendarExpanded = !_isCalendarExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: const Color(0xFF4285F4),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year} Calendar',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    _isCalendarExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF4285F4),
                  ),
                ],
              ),
            ),
          ),

          // Expandable calendar content
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isCalendarExpanded
                ? MediaQuery.of(context).size.height * 0.6
                : 0,
            child: _isCalendarExpanded
                ? Container(
                    margin: const EdgeInsets.only(top: 16),
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
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
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
                    final dayPunches = _todayPunches
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

  // Widget _buildMonthCalendar() {
  //   final screenSize = MediaQuery.of(context).size;
  //   return Padding(
  //     padding: const EdgeInsets.all(20),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year} Calendar',
  //           style: const TextStyle(
  //             fontSize: 16,
  //             fontWeight: FontWeight.bold,
  //             color: Colors.black87,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         _isLoadingToday
  //             ? SizedBox(
  //                 height: screenSize.height * 0.1,
  //                 child: Center(
  //                   child: Lottie.asset('assets/animations/sandyLoading.json'),
  //                 ),
  //               )
  //             : Container(
  //                 padding: const EdgeInsets.all(16),
  //                 decoration: BoxDecoration(
  //                   color: Colors.white,
  //                   borderRadius: BorderRadius.circular(12),
  //                   boxShadow: [
  //                     BoxShadow(
  //                       color: Colors.black.withValues(alpha: 0.05),
  //                       blurRadius: 4,
  //                       offset: const Offset(0, 2),
  //                     ),
  //                   ],
  //                 ),
  //                 child: _buildCalendarGrid(),
  //               ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildCalendarGrid() {
  //   final year = _selectedMonth.year;
  //   final month = _selectedMonth.month;
  //   final firstDayOfMonth = DateTime(year, month, 1);
  //   final lastDayOfMonth = DateTime(year, month + 1, 0);
  //   final firstDayWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

  //   // Days of week headers
  //   final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  //   // Calculate total cells needed (including empty cells for proper alignment)
  //   final totalDays = lastDayOfMonth.day;
  //   final leadingEmptyCells =
  //       firstDayWeekday - 1; // Empty cells before first day
  //   final totalCells = leadingEmptyCells + totalDays;
  //   final rows = (totalCells / 7).ceil();

  //   return Column(
  //     children: [
  //       // Week day headers
  //       Row(
  //         children: weekDays
  //             .map(
  //               (day) => Expanded(
  //                 child: Container(
  //                   padding: const EdgeInsets.symmetric(vertical: 8),
  //                   child: Text(
  //                     day,
  //                     textAlign: TextAlign.center,
  //                     style: TextStyle(
  //                       fontSize: 12,
  //                       fontWeight: FontWeight.bold,
  //                       color: Colors.grey[600],
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //             )
  //             .toList(),
  //       ),
  //       const Divider(height: 1),
  //       const SizedBox(height: 8),

  //       // Calendar grid
  //       Column(
  //         children: List.generate(rows, (rowIndex) {
  //           return Row(
  //             children: List.generate(7, (colIndex) {
  //               final cellIndex = rowIndex * 7 + colIndex;
  //               final dayNumber = cellIndex - leadingEmptyCells + 1;

  //               if (cellIndex < leadingEmptyCells || dayNumber > totalDays) {
  //                 // Empty cell
  //                 return Expanded(child: Container(height: 40));
  //               }

  //               final date = DateTime(year, month, dayNumber);
  //               final dayPunches = _todayPunches
  //                   .where(
  //                     (p) =>
  //                         p.dateTime.year == year &&
  //                         p.dateTime.month == month &&
  //                         p.dateTime.day == dayNumber,
  //                   )
  //                   .toList();

  //               return Expanded(
  //                 child: GestureDetector(
  //                   onTap: () => _onDateSelected(date),
  //                   child: _buildCalendarCell(dayNumber, dayPunches, date),
  //                 ),
  //               );
  //             }),
  //           );
  //         }),
  //       ),

  //       const SizedBox(height: 16),
  //       // Legend
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           _buildLegendItem('Present', Colors.green),
  //           const SizedBox(width: 16),
  //           _buildLegendItem('Absent', Colors.red),
  //           const SizedBox(width: 16),
  //           _buildLegendItem('Holiday', Colors.orange),
  //           const SizedBox(width: 16),
  //           _buildLegendItem('No Data', Colors.grey[300]!),
  //         ],
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildCalendarCell(
  //   int dayNumber,
  //   List<BiometricRecord> punches,
  //   DateTime date,
  // ) {
  //   final isSelected =
  //       date.day == _selectedDate.day &&
  //       date.month == _selectedDate.month &&
  //       date.year == _selectedDate.year;

  //   // Check if it's Sunday (weekday == 7)
  //   final isSunday = date.weekday == 7;

  //   Color backgroundColor;
  //   Color textColor = Colors.black87;
  //   Color? borderColor;

  //   if (punches.isNotEmpty) {
  //     // Present - green background (this takes priority over Sunday holiday)
  //     backgroundColor = Colors.green.withValues(alpha: 0.2);
  //     borderColor = Colors.green;
  //   } else if (isSunday) {
  //     // Sunday - Holiday styling (only when not present)
  //     backgroundColor = Colors.orange.withValues(alpha: 0.3);
  //     borderColor = Colors.orange;
  //     textColor = Colors.orange[800]!;
  //   } else {
  //     // Check if it's a past date (should be red for absent) or future date (grey)
  //     final today = DateTime.now();
  //     final currentDate = DateTime(date.year, date.month, date.day);
  //     final todayDate = DateTime(today.year, today.month, today.day);

  //     if (currentDate.isBefore(todayDate)) {
  //       // Past date with no punches - absent (red)
  //       backgroundColor = Colors.red.withValues(alpha: 0.2);
  //       borderColor = Colors.red;
  //     } else {
  //       // Future date or today with no data yet - grey
  //       backgroundColor = Colors.grey.withValues(alpha: 0.1);
  //       borderColor = Colors.grey[300];
  //     }
  //   }

  //   // Override with selection style
  //   if (isSelected) {
  //     borderColor = const Color(0xFF4285F4);
  //     textColor = const Color(0xFF4285F4);
  //   }

  //   return Container(
  //     height: 40,
  //     margin: const EdgeInsets.all(1),
  //     decoration: BoxDecoration(
  //       color: backgroundColor,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(
  //         color: borderColor ?? Colors.transparent,
  //         width: isSelected ? 2 : 1,
  //       ),
  //     ),
  //     child: isSunday && punches.isEmpty
  //         ? Column(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             children: [
  //               Text(
  //                 dayNumber.toString(),
  //                 style: TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
  //                   color: textColor,
  //                 ),
  //               ),
  //               Text(
  //                 'Holiday',
  //                 style: TextStyle(
  //                   fontSize: 8,
  //                   fontWeight: FontWeight.w500,
  //                   color: textColor,
  //                 ),
  //               ),
  //             ],
  //           )
  //         : Center(
  //             child: Text(
  //               dayNumber.toString(),
  //               style: TextStyle(
  //                 fontSize: 14,
  //                 fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
  //                 color: textColor,
  //               ),
  //             ),
  //           ),
  //   );
  // }

  // Widget _buildLegendItem(String label, Color color) {
  //   return Row(
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       Container(
  //         width: 12,
  //         height: 12,
  //         decoration: BoxDecoration(
  //           color: color.withValues(alpha: 0.2),
  //           border: Border.all(color: color, width: 1),
  //           borderRadius: BorderRadius.circular(2),
  //         ),
  //       ),
  //       const SizedBox(width: 4),
  //       Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
  //     ],
  //   );
  // }
}
