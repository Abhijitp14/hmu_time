import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../../models/user_model.dart';
import '../../../services/biometric_service.dart';

class EmployeeHomeScreen extends StatefulWidget {
  final AppUser user;

  const EmployeeHomeScreen({
    super.key,
    required this.user,
  });

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  final BiometricService _biometricService = BiometricService();
  List<BiometricRecord> _todayPunches = [];
  bool _isLoadingToday = false;
  bool _isSyncing = false;
  String? _todayCheckIn;
  String? _todayCheckOut;
  String? _totalWorkingTime;
  DateTime? _lastSyncTime;
  DateTime? _checkInDateTime; // Store actual check-in DateTime for late calculation
  double _workingHours = 0.0; // Store working hours as decimal for calculation
  String _workStatus = 'Total Hours'; // Store work status text
  
  // Month selection variables
  DateTime _selectedMonth = DateTime.now();
  List<DateTime> _availableMonths = [];
  DateTime _selectedDate = DateTime.now();
  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _calculateAvailableMonths();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Load existing data first
    await _loadTodayPunches();
    
    // Only auto-sync on app load if we have never synced before (first time use)
    // Remove aggressive auto-sync on every app load to prevent constant loading
    if (_isSelectedDateToday() && !_isSyncing && _lastSyncTime == null) {
      debugPrint('🚀 First time load: Auto-syncing to get initial punch data...');
      await _syncAttendance(isAutoSync: true);
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
      // Reload data for the selected month
      _loadTodayPunches();

    }
  }

  void _onDateSelected(DateTime selectedDate) {
    setState(() {
      _selectedDate = selectedDate;
    });
    // Reload data to show selected date's details
    _calculateTodayTimes();
  }

  Future<void> _loadTodayPunches() async {
    debugPrint('🔄 _loadTodayPunches started for empCode: ${widget.user.empCode}');
    
    if (widget.user.empCode == null) {
      debugPrint('❌ No empCode found, setting loading to false');
      if (mounted) {
        setState(() => _isLoadingToday = false);
      }
      return;
    }

    try {
      if (mounted) {
        setState(() => _isLoadingToday = true);
      }
      debugPrint('⏳ Loading state set to true');
      
      // Use selected month for data loading
      final today = DateTime.now();
      final isCurrentMonth = _selectedMonth.year == today.year && _selectedMonth.month == today.month;
      
      // Get date range for selected month
      final fromDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final toDate = isCurrentMonth 
          ? today 
          : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0); // Last day of month
      
      debugPrint('📅 Date range: ${fromDate.toString()} to ${toDate.toString()}');
      
      BiometricSyncResult result;
      
      try {
        // First try to get stored records (faster)
        debugPrint('🔍 Attempting to get stored records...');
        result = await _biometricService.getStoredBiometricRecords(
          empCode: widget.user.empCode!,
          fromDate: fromDate,
          toDate: toDate,
        );
        
        debugPrint('📊 Stored records result: success=${result.success}, recordCount=${result.records.length}');
        
        // Be much less aggressive about syncing - only sync when really necessary
        final shouldSync = !result.success || 
                          (result.records.isEmpty && _lastSyncTime == null); // Only sync if no data and never synced
                          
        if (shouldSync) {
          debugPrint('🔄 No stored data found or missing today\'s data, attempting sync...');
          final syncResult = await _biometricService.syncBiometricData(
            empCode: widget.user.empCode!,
            fromDate: fromDate,
            toDate: toDate,
          );
          
          debugPrint('🔄 Sync result: success=${syncResult.success}, recordsProcessed=${syncResult.recordsProcessed}');
          
          // After successful sync, add delay and reload the stored data to update UI
          if (syncResult.success) {
            debugPrint('⏱️ Sync successful, waiting 2 seconds for Firestore consistency...');
            // Wait for Firestore to be consistent after sync
            await Future.delayed(const Duration(seconds: 2));
            
            debugPrint('🔍 Retrying stored records after sync...');
            result = await _biometricService.getStoredBiometricRecords(
              empCode: widget.user.empCode!,
              fromDate: fromDate,
              toDate: toDate,
            );
            
            debugPrint('📊 After sync stored records result: success=${result.success}, recordCount=${result.records.length}');
            
            // If still no data after retry, show error
            if (!result.success || result.records.isEmpty) {
              debugPrint('⚠️ Still no data after sync retry');
              _showSnackBar('Data synced but not immediately available. Please try refreshing.', isError: true);
            }
          } else {
            debugPrint('❌ Sync failed, using sync result directly');
            result = syncResult;
          }
        }
      } catch (e) {
        debugPrint('❌ Exception during data fetch: $e');
        // Create empty result on error
        result = BiometricSyncResult(
          success: false, 
          message: 'Failed to load data: $e', 
          recordsProcessed: 0,
          records: []
        );
      }

      if (result.success) {
        debugPrint('✅ Data loaded successfully, processing ${result.records.length} records');
        if (mounted) {
          setState(() {
            // Clear existing data first to prevent duplicates
            _todayPunches.clear();
            _todayPunches = _removeDuplicateRecords(result.records);
            _calculateTodayTimes();
          });
        }
        debugPrint('📋 Today punches after processing: ${_todayPunches.length}');
      } else {
        debugPrint('❌ Failed to load data: ${result.message}');
        _showSnackBar('Failed to load data: ${result.message}', isError: true);
      }
    } catch (e) {
      // Handle errors and show feedback to user
      debugPrint('❌ Exception in _loadTodayPunches: $e');
      _showSnackBar('Failed to load today\'s data: ${e.toString()}', isError: true);
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
    final selectedDateOnly = _todayPunches.where((punch) => 
      punch.dateTime.year == _selectedDate.year &&
      punch.dateTime.month == _selectedDate.month &&
      punch.dateTime.day == _selectedDate.day
    ).toList();
    
    if (selectedDateOnly.isEmpty) {
      _todayCheckIn = null;
      _todayCheckOut = null;
      _totalWorkingTime = null;
      _checkInDateTime = null;
      _workingHours = 0.0;
      _workStatus = 'Total Hours';
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
      _todayCheckIn = DateFormat('hh:mm a').format(sortedPunches.first.dateTime);
    } else {
      _checkInDateTime = null;
    }

    // Set check-out time and calculate working hours
    if (outPunches.isNotEmpty) {
      _todayCheckOut = DateFormat('hh:mm a').format(outPunches.last.dateTime);
      
      if (inPunches.isNotEmpty) {
        final workingDuration = outPunches.last.dateTime.difference(inPunches.first.dateTime);
        final hours = workingDuration.inHours;
        final minutes = workingDuration.inMinutes % 60;
        _totalWorkingTime = '${hours}h ${minutes}m';
        
        // Calculate working hours as decimal (e.g., 8.5 hours)
        _workingHours = hours + (minutes / 60.0);
        _calculateWorkStatus();
        print('⏱️ Working Hours Debug: Duration=${workingDuration.inMinutes}min, Hours=$hours, Minutes=$minutes, TotalHours=$_workingHours, Status=$_workStatus');
      }
    } else {
      // No OUT punch found - check if there's a check-in
      _todayCheckOut = null;
      _totalWorkingTime = null;
      _workingHours = 0.0;
      
      if (inPunches.isNotEmpty) {
        // Has check-in but no check-out - mark as incomplete
        _workStatus = 'Incomplete';
        print('⏱️ Working Hours Debug: Has check-in but no check-out - Status set to Incomplete');
      } else {
        // No check-in and no check-out
        _workStatus = 'Total Hours';
      }
    }
  }

  bool _isCheckInLate() {
    if (_checkInDateTime == null) return false;
    
    // The issue is that the DateTime is stored as UTC but represents local time
    // Extract the hour/minute from the UTC DateTime but treat them as local values
    final utcHour = _checkInDateTime!.hour;
    final utcMinute = _checkInDateTime!.minute;
    
    // Late if after 10:00 AM (hour > 10 OR hour == 10 AND minute > 0)
    final isLate = utcHour > 10 || (utcHour == 10 && utcMinute > 0);
    
    print('🕐 Late Check Debug: OriginalCheckIn=${_checkInDateTime}, UTCHour=$utcHour, UTCMinute=$utcMinute, IsLate=$isLate');
    print('🕐 Expected Logic: 07:21->Hour=7,Late=false | 08:23->Hour=8,Late=false | 10:01->Hour=10,Min=1,Late=true');
    
    return isLate;
  }

  void _calculateWorkStatus() {
    if (_workingHours >= 8.0) {
      _workStatus = 'Completed';
    } else if (_workingHours >= 5.0) {
      _workStatus = 'Half Day';
    } else if (_workingHours > 0) {
      _workStatus = 'Incomplete';
    } else {
      _workStatus = 'Total Hours';
    }
    
    print('📊 Work Status Calculation: ${_workingHours}h -> $_workStatus');
  }

  Color _getWorkStatusColor() {
    switch (_workStatus) {
      case 'Completed':
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
    return _todayPunches.where((punch) => 
      punch.dateTime.year == _selectedDate.year &&
      punch.dateTime.month == _selectedDate.month &&
      punch.dateTime.day == _selectedDate.day
    ).length;
  }

  bool _isSelectedDateToday() {
    final today = DateTime.now();
    return _selectedDate.year == today.year &&
           _selectedDate.month == today.month &&
           _selectedDate.day == today.day;
  }

  Future<void> _syncAttendance({bool isAutoSync = false}) async {
    if (widget.user.empCode == null) {
      _showSnackBar('Employee code not found. Please contact HR.', isError: true);
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
      
      debugPrint('🔄 Starting sync - isAutoSync: $isAutoSync, empCode: ${widget.user.empCode}');
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
          final joiningFirstDay = DateTime(joiningDate.year, joiningDate.month, 1);
          
          // Employee must have joined on or before this month
          if (workingMonth.isAfter(joiningFirstDay) || workingMonth.isAtSameMomentAs(joiningFirstDay)) {
            monthsToSync.add(workingMonth);
          }
        }
      }

      if (!isAutoSync) {
        _showSnackBar('Syncing ${monthsToSync.length} months of data...', isError: false);
      }

      // Sync each month
      int successfulSyncs = 0;
      for (final month in monthsToSync) {
        try {
          final fromDate = DateTime(month.year, month.month, 1);
          final isCurrentMonth = month.year == today.year && month.month == today.month;
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
          _showSnackBar('Successfully synced $successfulSyncs/${monthsToSync.length} months!', isError: false);
        }
        
        // Wait for Firestore to propagate changes before reloading
        await Future.delayed(const Duration(seconds: 3));
        
        // Reload fresh data after successful sync
        debugPrint('🔄 Reloading data after successful sync...');
        await _loadTodayPunches();

        debugPrint('📊 Data reload completed. Today\'s punches: ${_getTodayPunchCount()}');
        
        if (!isAutoSync) {
          _showSnackBar('Data refreshed successfully!', isError: false);
        } else {
          debugPrint('✅ Auto-sync completed successfully - ${_getTodayPunchCount()} punches found');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // For current day, only sync if enough time has passed since last sync
            if (_isSelectedDateToday() && !_isSyncing && _shouldAutoSync(isRefresh: true)) {
              debugPrint('📱 Pull-to-refresh on current day: Syncing to get latest punch data...');
              await _syncAttendance(isAutoSync: true);
            } else {
              // For other dates or recent sync, just load existing data
              debugPrint('📱 Pull-to-refresh: Loading existing data (sync not needed or recent sync)');
              await _loadTodayPunches();
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
                _buildMonthCalendar(),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                        ),
                      )
                    : const Icon(
                        Icons.sync,
                        color: Color(0xFF4285F4),
                      ),
                tooltip: 'Sync Attendance',
              ),
              if (_lastSyncTime != null)
                Text(
                  _getLastSyncText(),
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10).copyWith(top: 0),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4285F4)),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: _onMonthChanged,
                    items: _availableMonths.map<DropdownMenuItem<DateTime>>((DateTime month) {
                      final monthName = _monthNames[month.month - 1];
                      final year = month.year;
                      final isCurrentMonth = month.year == DateTime.now().year && month.month == DateTime.now().month;
                      
                      return DropdownMenuItem<DateTime>(
                        value: month,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$monthName $year'),
                            if (isCurrentMonth) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    List<DateTime> filteredDays = selectedMonthNum == today.month && selectedYear == today.year
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
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
                final isToday = date.day == today.day && 
                               date.month == today.month && 
                               date.year == today.year;
                final isSelected = date.day == _selectedDate.day &&
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

  Widget _buildDateCard(String day, String dayName, bool isToday, {bool isSelected = false}) {
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
        border: isSelected ? Border.all(color: const Color(0xFF4285F4), width: 2) : null,
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
              color: isToday ? Colors.white70 : (isSelected ? const Color(0xFF4285F4).withValues(alpha: 0.7) : Colors.grey[600]),
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
            _isSelectedDateToday() ? 'Today\'s Attendance' : 'Selected Date Attendance',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _isLoadingToday
              ?  SizedBox(height: screenSize.height * 0.25,child: Center(child: Lottie.asset('assets/animations/sandyLoading.json',)))
              : Row(
                  children: [
                    Expanded(
                      child: _buildAttendanceCard(
                        'Check In',
                        _todayCheckIn ?? '--:--',
                        _todayCheckIn != null 
                            ? (_isCheckInLate() ? 'Late' : 'On Time') 
                            : 'Not Checked',
                        Icons.login,
                        _todayCheckIn != null 
                            ? (_isCheckInLate() ? Colors.red : const Color(0xFF4285F4))
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
          if(!_isLoadingToday)
          Row(
            children: [
              Expanded(
                child: _buildAttendanceCard(
                  'Working Time',
                  _totalWorkingTime ?? '0h 0m',
                  _workStatus,
                  Icons.access_time,
                  _getWorkStatusColor(),
                ),
              ),
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
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchDetails() {
    // Filter punches for only the selected date
    final selectedDatePunches = _todayPunches.where((punch) => 
      punch.dateTime.year == _selectedDate.year &&
      punch.dateTime.month == _selectedDate.month &&
      punch.dateTime.day == _selectedDate.day
    ).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isSelectedDateToday() ? 'Today\'s Punch Details' : '${DateFormat('MMM dd').format(_selectedDate)} Punch Details',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Selected: ${selectedDatePunches.length} punches',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoadingToday
              ?  SizedBox(height: 100, child: Center(child: Lottie.asset('assets/animations/amongUs.json', width: 80, height: 80)))
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
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap sync to fetch latest data',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
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
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar() {
    final screenSize = MediaQuery.of(context).size;
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year} Calendar',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _isLoadingToday
              ? SizedBox(height: screenSize.height * 0.1, child: Center(child: Lottie.asset('assets/animations/sandyLoading.json')))
              : Container(
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
                  child: _buildCalendarGrid(),
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
    
    // Calculate total cells needed (including empty cells for proper alignment)
    final totalDays = lastDayOfMonth.day;
    final leadingEmptyCells = firstDayWeekday - 1; // Empty cells before first day
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
        Column(
          children: List.generate(rows, (rowIndex) {
            return Row(
              children: List.generate(7, (colIndex) {
                final cellIndex = rowIndex * 7 + colIndex;
                final dayNumber = cellIndex - leadingEmptyCells + 1;
                
                if (cellIndex < leadingEmptyCells || dayNumber > totalDays) {
                  // Empty cell
                  return Expanded(child: Container(height: 40));
                }
                
                final date = DateTime(year, month, dayNumber);
                final dayPunches = _todayPunches.where((p) => 
                  p.dateTime.year == year &&
                  p.dateTime.month == month &&
                  p.dateTime.day == dayNumber
                ).toList();
                
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onDateSelected(date),
                    child: _buildCalendarCell(dayNumber, dayPunches, date),
                  ),
                );
              }),
            );
          }),
        ),
        
        const SizedBox(height: 16),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Present', Colors.green),
            const SizedBox(width: 16),
            _buildLegendItem('Absent', Colors.red),
            const SizedBox(width: 16),
            _buildLegendItem('Holiday', Colors.orange),
            const SizedBox(width: 16),
            _buildLegendItem('No Data', Colors.grey[300]!),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarCell(int dayNumber, List<BiometricRecord> punches, DateTime date) {
    final isSelected = date.day == _selectedDate.day &&
                     date.month == _selectedDate.month &&
                     date.year == _selectedDate.year;
    
    // Check if it's Sunday (weekday == 7)
    final isSunday = date.weekday == 7;
    
    Color backgroundColor;
    Color textColor = Colors.black87;
    Color? borderColor;
    
    if (punches.isNotEmpty) {
      // Present - green background (this takes priority over Sunday holiday)
      backgroundColor = Colors.green.withValues(alpha: 0.2);
      borderColor = Colors.green;
    } else if (isSunday) {
      // Sunday - Holiday styling (only when not present)
      backgroundColor = Colors.orange.withValues(alpha: 0.3);
      borderColor = Colors.orange;
      textColor = Colors.orange[800]!;
    } else {
      // Check if it's a past date (should be red for absent) or future date (grey)
      final today = DateTime.now();
      final currentDate = DateTime(date.year, date.month, date.day);
      final todayDate = DateTime(today.year, today.month, today.day);
      
      if (currentDate.isBefore(todayDate)) {
        // Past date with no punches - absent (red)
        backgroundColor = Colors.red.withValues(alpha: 0.2);
        borderColor = Colors.red;
      } else {
        // Future date or today with no data yet - grey
        backgroundColor = Colors.grey.withValues(alpha: 0.1);
        borderColor = Colors.grey[300];
      }
    }
    
    // Override with selection style
    if (isSelected) {
      borderColor = const Color(0xFF4285F4);
      textColor = const Color(0xFF4285F4);
    }
    
    return Container(
      height: 40,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor ?? Colors.transparent,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: isSunday && punches.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayNumber.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  'Holiday',
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
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
            color: color.withValues(alpha: 0.2),
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



}
