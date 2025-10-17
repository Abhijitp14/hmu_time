import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

import '../../../models/user_model.dart';
import '../../../services/employee_service.dart';
import 'employee_attendance_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  final AppUser user;

  const ReportsScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EmployeeService _employeeService = EmployeeService();
  
  // Month Selection (current month and past 3 months)
  late DateTime _selectedMonth;
  late List<DateTime> _availableMonths;
  
  // Report Data
  List<AttendanceReportData> _attendanceData = [];
  List<LeaveReportData> _leaveData = [];
  List<WorkingHoursReportData> _workingHoursData = [];
  List<AppUser> _employees = [];
  
  bool _isLoadingAttendance = false;
  bool _isLoadingLeaves = false;
  bool _isLoadingWorkingHours = false;
  String? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupAvailableMonths();
    _initializeReports();
  }

  Future<void> _initializeReports() async {
    await _loadEmployees();
    await _loadAllReports();
  }

  void _setupAvailableMonths() {
    _availableMonths = [];
    final now = DateTime.now();
    
    // Add current month and past 3 months - normalize to first day of month
    for (int i = 0; i < 4; i++) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final month = DateTime(targetDate.year, targetDate.month, 1);
      _availableMonths.add(month);
    }
    
    // Set the selected month to the first available month (current month)
    _selectedMonth = _availableMonths.first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final employeesData = await _employeeService.getEmployees();
      final employees = employeesData.map((data) {
        // Fix the ID mapping issue - Firebase returns 'uid' but AppUser expects 'id'
        final correctedData = Map<String, dynamic>.from(data);
        if (correctedData['uid'] != null && (correctedData['id'] == null || correctedData['id'] == '')) {
          correctedData['id'] = correctedData['uid'];
        }
        return AppUser.fromJson(correctedData);
      }).toList();
      
      setState(() => _employees = employees);
    } catch (e) {
      _showMessage('Failed to load employees: $e', isError: true);
    }
  }

  Future<void> _loadAllReports() async {
    if (_employees.isEmpty) return;
    
    await Future.wait([
      _loadAttendanceReport(),
      _loadLeaveReport(),
      _loadWorkingHoursReport(),
    ]);
  }

  Future<void> _loadAttendanceReport() async {
    setState(() => _isLoadingAttendance = true);
    try {
      final dateRange = _monthDateRange;
      final data = <String, AttendanceReportData>{};
      
      // Get employees to process based on selection
      final employeesToProcess = _selectedEmployeeId != null 
          ? _employees.where((e) => e.id == _selectedEmployeeId).toList()
          : _employees.toList();
      
      if (employeesToProcess.isEmpty) {
        setState(() {
          _attendanceData = [];
          _isLoadingAttendance = false;
        });
        return;
      }
      
      for (final employee in employeesToProcess) {
        final empCode = employee.empCode;
        
        if (empCode == null) {
          // Create zero-data entry for employees without empCode
          data[employee.id] = AttendanceReportData(
            employee: employee,
            totalDays: 0,
            presentDays: 0,
            absentDays: 0,
            lateDays: 0,
            totalWorkingHours: 0.0,
            averageWorkingHours: 0.0,
            attendancePercentage: 0.0,
            period: DateFormat('MMM yyyy').format(_selectedMonth),
          );
          continue;
        }
        
        try {
          // Get attendance data for this employee
          final attendanceDoc = await _firestore
              .collection('attendance')
              .doc(empCode)
              .get();
          
          if (!attendanceDoc.exists) {
            // Create zero-data entry for employees without attendance data
            data[employee.id] = AttendanceReportData(
              employee: employee,
              totalDays: 0,
              presentDays: 0,
              absentDays: 0,
              lateDays: 0,
              totalWorkingHours: 0.0,
              averageWorkingHours: 0.0,
              attendancePercentage: 0.0,
              period: DateFormat('MMM yyyy').format(_selectedMonth),
            );
            continue;
          }
          
          // Get active months for this employee
          final attendanceData = attendanceDoc.data()!;
          final activeMonths = (attendanceData['activeMonths'] as List<dynamic>?)?.cast<String>() ?? [];
          
          int totalDays = 0;
          int presentDays = 0;
          int absentDays = 0;
          int lateDays = 0;
          double totalWorkingHours = 0.0;
          
          // Process each month within the date range
          for (final monthCollection in activeMonths) {
            // Get documents from this month collection
            final monthDocs = await _firestore
                .collection('attendance')
                .doc(empCode)
                .collection(monthCollection)
                .get();
            
            for (final dayDoc in monthDocs.docs) {
              final dayData = dayDoc.data();
              
              // Parse the date from the document
              final dateStr = dayData['date'] as String?;
              if (dateStr == null) continue;
              
              // Parse date format: "16-10-2025"
              final dateParts = dateStr.split('-');
              if (dateParts.length != 3) continue;
              
              final day = int.tryParse(dateParts[0]);
              final month = int.tryParse(dateParts[1]);
              final year = int.tryParse(dateParts[2]);
              
              if (day == null || month == null || year == null) continue;
              
              final recordDate = DateTime(year, month, day);
              
              // Check if this record falls within our date range
              if (recordDate.isBefore(dateRange.start) || recordDate.isAfter(dateRange.end)) {
                continue;
              }
              
              totalDays++;
              
              // Process punches to determine attendance status
              final punches = (dayData['punches'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
              
              if (punches.isNotEmpty) {
                presentDays++;
                
                // Calculate working hours from punches
                DateTime? checkIn;
                DateTime? checkOut;
                
                for (final punch in punches) {
                  final type = punch['type'] as String?;
                  final datetime = punch['datetime'] as String?;
                  
                  if (datetime != null) {
                    try {
                      // Parse datetime: "16/10/2025 09:30"
                      final parts = datetime.split(' ');
                      if (parts.length >= 2) {
                        final datePart = parts[0]; // "16/10/2025"
                        final timePart = parts[1]; // "09:30"
                        
                        final dateParts = datePart.split('/');
                        final timeParts = timePart.split(':');
                        
                        if (dateParts.length == 3 && timeParts.length >= 2) {
                          final punchDay = int.parse(dateParts[0]);
                          final punchMonth = int.parse(dateParts[1]);
                          final punchYear = int.parse(dateParts[2]);
                          final hour = int.parse(timeParts[0]);
                          final minute = int.parse(timeParts[1]);
                          
                          final punchTime = DateTime(punchYear, punchMonth, punchDay, hour, minute);
                          
                          if (type == 'IN' && checkIn == null) {
                            checkIn = punchTime;
                          } else if (type == 'OUT') {
                            checkOut = punchTime;
                          }
                        }
                      }
                    } catch (e) {
                      // Skip invalid punch times
                    }
                  }
                }
                
                // Calculate working hours
                if (checkIn != null && checkOut != null) {
                  final workingMinutes = checkOut.difference(checkIn).inMinutes;
                  totalWorkingHours += workingMinutes / 60.0;
                }
                
                // Check if late (after 9:00 AM)
                if (checkIn != null) {
                  final standardTime = DateTime(checkIn.year, checkIn.month, checkIn.day, 9, 0);
                  if (checkIn.isAfter(standardTime)) {
                    lateDays++;
                  }
                }
              } else {
                absentDays++;
              }
            }
          }
          
          // Create report data for this employee
          if (totalDays > 0) {
            final key = _selectedEmployeeId != null ? employee.id : '${employee.id}-${DateFormat('yyyy-MM').format(DateTime.now())}';
            
            data[key] = AttendanceReportData(
              employee: employee,
              period: _selectedEmployeeId != null ? 'Selected Period' : DateFormat('MMM yyyy').format(DateTime.now()),
              totalDays: totalDays,
              presentDays: presentDays,
              absentDays: absentDays,
              lateDays: lateDays,
              totalWorkingHours: totalWorkingHours,
              averageWorkingHours: presentDays > 0 ? totalWorkingHours / presentDays : 0.0,
              attendancePercentage: totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0,
            );
          }
          
        } catch (e) {
          // Skip employee if error processing their data
        }
      }

      setState(() => _attendanceData = data.values.toList()..sort((a, b) => b.attendancePercentage.compareTo(a.attendancePercentage)));
    } catch (e) {
      _showMessage('Failed to load attendance report: $e', isError: true);
    } finally {
      setState(() => _isLoadingAttendance = false);
    }
  }

  Future<void> _loadLeaveReport() async {
    setState(() => _isLoadingLeaves = true);
    try {
      final dateRange = _monthDateRange;
      final data = <String, LeaveReportData>{};
      
      // Get employees to process based on selection
      final employeesToProcess = _selectedEmployeeId != null 
          ? _employees.where((e) => e.id == _selectedEmployeeId).toList()
          : _employees.toList();
      
      if (employeesToProcess.isEmpty) {
        setState(() {
          _leaveData = [];
          _isLoadingLeaves = false;
        });
        return;
      }
      
      // Define leave type collections
      final leaveCollections = [
        'sick_leave_requests',
        'casual_leave_requests', 
        'paid_leave_requests',
        'optional_holiday_requests',
        'lwp_requests',
        'official_leave_requests'
      ];
      
      for (final employee in employeesToProcess) {
        final employeeUid = employee.id;
        
        if (!data.containsKey(employeeUid)) {
          data[employeeUid] = LeaveReportData(
            employee: employee,
            casualLeaves: 0,
            sickLeaves: 0,
            paidLeaves: 0,
            optionalHolidays: 0,
            totalLeaves: 0,
            approvedLeaves: 0,
            pendingLeaves: 0,
            rejectedLeaves: 0,
          );
        }
        
        final leaveData = data[employeeUid]!;
        
        // Process each leave type collection
        for (final collectionName in leaveCollections) {
          try {
            final leaveRequests = await _firestore
                .collection(collectionName)
                .where('userId', isEqualTo: employeeUid)
                .get();
            
            for (final doc in leaveRequests.docs) {
              final requestData = doc.data();
              
              // Parse dates
              final startDateTimestamp = requestData['startDate'] as Timestamp?;
              final endDateTimestamp = requestData['endDate'] as Timestamp?;
              
              if (startDateTimestamp == null || endDateTimestamp == null) continue;
              
              final startDate = startDateTimestamp.toDate();
              final endDate = endDateTimestamp.toDate();
              
              // Check if leave falls within our date range
              if (startDate.isAfter(dateRange.end) || endDate.isBefore(dateRange.start)) {
                continue;
              }
              
              final status = requestData['status'] as String? ?? 'pending';
              final totalDays = (requestData['totalDays'] ?? 1).toDouble();
              
              // Count by leave type
              switch (collectionName) {
                case 'sick_leave_requests':
                  leaveData.sickLeaves += totalDays;
                  break;
                case 'casual_leave_requests':
                  leaveData.casualLeaves += totalDays;
                  break;
                case 'paid_leave_requests':
                  leaveData.paidLeaves += totalDays;
                  break;
                case 'optional_holiday_requests':
                  leaveData.optionalHolidays += totalDays;
                  break;
                case 'lwp_requests':
                case 'official_leave_requests':
                  // These don't count towards regular leave balances
                  break;
              }
              
              // Count by status
              switch (status.toLowerCase()) {
                case 'approved':
                case 'completed':
                  leaveData.approvedLeaves += totalDays;
                  break;
                case 'pending':
                  leaveData.pendingLeaves += totalDays;
                  break;
                case 'rejected':
                case 'cancelled':
                  leaveData.rejectedLeaves += totalDays;
                  break;
              }
              
              leaveData.totalLeaves += totalDays;
            }
          } catch (e) {
            // Skip errors for this leave collection
          }
        }
      }
      
      // Remove employees with no leave data
      data.removeWhere((key, value) => value.totalLeaves == 0);

      setState(() => _leaveData = data.values.toList()..sort((a, b) => b.totalLeaves.compareTo(a.totalLeaves)));
    } catch (e) {
      _showMessage('Failed to load leave report: $e', isError: true);
    } finally {
      setState(() => _isLoadingLeaves = false);
    }
  }

  Future<void> _loadWorkingHoursReport() async {
    setState(() => _isLoadingWorkingHours = true);
    try {
      final dateRange = _monthDateRange;
      final data = <String, WorkingHoursReportData>{};
      
      // Get employees to process based on selection
      final employeesToProcess = _selectedEmployeeId != null 
          ? _employees.where((e) => e.id == _selectedEmployeeId).toList()
          : _employees.toList();
      
      if (employeesToProcess.isEmpty) {
        setState(() {
          _workingHoursData = [];
          _isLoadingWorkingHours = false;
        });
        return;
      }
      
      for (final employee in employeesToProcess) {
        final empCode = employee.empCode;
        
        if (empCode == null) {
          // Create zero-data entry for employees without empCode
          data[employee.id] = WorkingHoursReportData(
            employee: employee,
            totalWorkingHours: 0.0,
            totalOvertimeHours: 0.0,
            averageWorkingHours: 0.0,
            workingDays: 0,
            lateDays: 0,
            productivityScore: 0.0,
          );
          continue;
        }
        
        try {
          // Get attendance data for this employee
          final attendanceDoc = await _firestore
              .collection('attendance')
              .doc(empCode)
              .get();
          
          if (!attendanceDoc.exists) {
            // No attendance data found
            data[employee.id] = WorkingHoursReportData(
              employee: employee,
              totalWorkingHours: 0.0,
              totalOvertimeHours: 0.0,
              averageWorkingHours: 0.0,
              workingDays: 0,
              lateDays: 0,
              productivityScore: 0.0,
            );
            continue;
          }
          
          final attendanceData = attendanceDoc.data()!;
          final activeMonths = (attendanceData['activeMonths'] as List<dynamic>?)?.cast<String>() ?? [];
          
          double totalWorkingHours = 0.0;
          double totalOvertimeHours = 0.0;
          int workingDays = 0;
          int lateDays = 0;
          
          // Process each month within the date range
          for (final monthCollection in activeMonths) {
            final monthDocs = await _firestore
                .collection('attendance')
                .doc(empCode)
                .collection(monthCollection)
                .get();
            
            for (final dayDoc in monthDocs.docs) {
              final dayData = dayDoc.data();
              
              // Parse the date
              final dateStr = dayData['date'] as String?;
              if (dateStr == null) continue;
              
              final dateParts = dateStr.split('-');
              if (dateParts.length != 3) continue;
              
              final day = int.tryParse(dateParts[0]);
              final month = int.tryParse(dateParts[1]);
              final year = int.tryParse(dateParts[2]);
              
              if (day == null || month == null || year == null) continue;
              
              final recordDate = DateTime(year, month, day);
              
              // Check if within date range
              if (recordDate.isBefore(dateRange.start) || recordDate.isAfter(dateRange.end)) {
                continue;
              }
              
              // Process punches
              final punches = (dayData['punches'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
              
              if (punches.isEmpty) continue; // No punches = not present
              
              DateTime? checkIn;
              DateTime? checkOut;
              
              // Extract check-in and check-out times
              for (final punch in punches) {
                final type = punch['type'] as String?;
                final datetime = punch['datetime'] as String?;
                
                if (datetime != null) {
                  try {
                    final parts = datetime.split(' ');
                    if (parts.length >= 2) {
                      final datePart = parts[0];
                      final timePart = parts[1];
                      
                      final dateParts = datePart.split('/');
                      final timeParts = timePart.split(':');
                      
                      if (dateParts.length == 3 && timeParts.length >= 2) {
                        final punchDay = int.parse(dateParts[0]);
                        final punchMonth = int.parse(dateParts[1]);
                        final punchYear = int.parse(dateParts[2]);
                        final hour = int.parse(timeParts[0]);
                        final minute = int.parse(timeParts[1]);
                        
                        final punchTime = DateTime(punchYear, punchMonth, punchDay, hour, minute);
                        
                        if (type == 'IN' && checkIn == null) {
                          checkIn = punchTime;
                        } else if (type == 'OUT') {
                          checkOut = punchTime;
                        }
                      }
                    }
                  } catch (e) {
                    // Skip invalid punch times
                  }
                }
              }
              
              // Calculate working hours if both check-in and check-out exist
              if (checkIn != null && checkOut != null) {
                workingDays++;
                final workingMinutes = checkOut.difference(checkIn).inMinutes;
                final dayWorkingHours = workingMinutes / 60.0;
                totalWorkingHours += dayWorkingHours;
                
                // Calculate overtime (hours beyond 8)
                if (dayWorkingHours > 8.0) {
                  totalOvertimeHours += (dayWorkingHours - 8.0);
                }
                
                // Check if late (after 9:00 AM)
                final standardTime = DateTime(checkIn.year, checkIn.month, checkIn.day, 9, 0);
                if (checkIn.isAfter(standardTime)) {
                  lateDays++;
                }
              } else if (checkIn != null) {
                // Only check-in, still count as working day but incomplete
                workingDays++;
                
                // Check if late
                final standardTime = DateTime(checkIn.year, checkIn.month, checkIn.day, 9, 0);
                if (checkIn.isAfter(standardTime)) {
                  lateDays++;
                }
              }
            }
          }
          
          // Create report data if employee has working days
          if (workingDays > 0) {
            final averageWorkingHours = totalWorkingHours / workingDays;
            
            // Calculate productivity score
            final hoursScore = (averageWorkingHours / 8.0) * 70; // 70% weight for hours
            final punctualityScore = ((workingDays - lateDays) / workingDays) * 30; // 30% weight for punctuality
            final productivityScore = (hoursScore + punctualityScore).clamp(0.0, 100.0);
            
            data[employee.id] = WorkingHoursReportData(
              employee: employee,
              totalWorkingHours: totalWorkingHours,
              totalOvertimeHours: totalOvertimeHours,
              averageWorkingHours: averageWorkingHours,
              workingDays: workingDays,
              lateDays: lateDays,
              productivityScore: productivityScore,
            );
          }
          
        } catch (e) {
          // Skip employee if error processing their data
        }
      }

      setState(() => _workingHoursData = data.values.toList()..sort((a, b) => b.productivityScore.compareTo(a.productivityScore)));
    } catch (e) {
      _showMessage('Failed to load working hours report: $e', isError: true);
    } finally {
      setState(() => _isLoadingWorkingHours = false);
    }
  }

  Future<void> _syncThreeMonthsData() async {
    try {
      // Show confirmation dialog with detailed information
      final shouldSync = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sync 3 Months Attendance Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will sync attendance data for the past 3 months for ALL employees:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text('• ${_employees.length} employees will be processed'),
              const Text('• Data for past 90 days will be synced'),
              const Text('• This process may take 10-15 minutes'),
              const Text('• Existing data will not be duplicated'),
              const SizedBox(height: 16),
              const Text(
                'Please ensure you have a stable internet connection before proceeding.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Sync'),
            ),
          ],
        ),
      );

      if (shouldSync != true) return;

      // Calculate date range for past 3 months
      final now = DateTime.now();
      final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
      final fromDate = '${threeMonthsAgo.year}-${threeMonthsAgo.month.toString().padLeft(2, '0')}-${threeMonthsAgo.day.toString().padLeft(2, '0')}';
      final toDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      print('📅 Syncing data from $fromDate to $toDate for ${_employees.length} employees');

      // Show progress dialog
      int processedCount = 0;
      final totalEmployees = _employees.where((e) => e.empCode != null).length;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Syncing Attendance Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text('Processing employee $processedCount of $totalEmployees'),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: totalEmployees > 0 ? processedCount / totalEmployees : 0,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(totalEmployees > 0 ? (processedCount / totalEmployees * 100) : 0).toStringAsFixed(1)}% Complete',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );

      // Process employees in batches to avoid overwhelming the system
      final List<String> successfulSyncs = [];
      final List<String> failedSyncs = [];
      const batchSize = 5; // Process 5 employees at a time
      
      final employeesWithCodes = _employees.where((e) => e.empCode != null).toList();
      
      for (int i = 0; i < employeesWithCodes.length; i += batchSize) {
        final batch = employeesWithCodes.skip(i).take(batchSize).toList();
        
        // Process batch in parallel
        final batchFutures = batch.map((employee) async {
          try {
            final callable = FirebaseFunctions.instance.httpsCallable('syncBiometricData');
            final result = await callable.call({
              'empcode': employee.empCode,
              'fromDate': fromDate,
              'toDate': toDate,
            });
            
            if (result.data['success'] == true) {
              final recordsCount = result.data['recordsProcessed'] ?? 0;
              print('✅ Synced ${employee.empCode} (${employee.name}): $recordsCount records');
              return '${employee.name}: $recordsCount records';
            } else {
              print('❌ Failed to sync ${employee.empCode} (${employee.name}): ${result.data['message'] ?? 'Unknown error'}');
              return null;
            }
          } catch (e) {
            print('❌ Error syncing ${employee.empCode} (${employee.name}): $e');
            return null;
          }
        });

        final batchResults = await Future.wait(batchFutures);
        
        // Update progress
        for (int j = 0; j < batchResults.length; j++) {
          processedCount++;
          final result = batchResults[j];
          final employee = batch[j];
          
          if (result != null) {
            successfulSyncs.add(result);
          } else {
            failedSyncs.add(employee.name);
          }
        }

        // Update progress dialog (if still open)
        if (context.mounted) {
          // Force rebuild of dialog to show progress
          Navigator.pop(context);
          
          if (processedCount < totalEmployees) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Syncing Attendance Data'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text('Processing employee $processedCount of $totalEmployees'),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: processedCount / totalEmployees,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(processedCount / totalEmployees * 100).toStringAsFixed(1)}% Complete',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
        }

        // Small delay between batches to avoid rate limiting
        if (i + batchSize < employeesWithCodes.length) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      // Close progress dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show completion summary
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  successfulSyncs.isNotEmpty ? Icons.check_circle : Icons.warning,
                  color: successfulSyncs.isNotEmpty ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text('Sync Complete'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ Successfully synced: ${successfulSyncs.length} employees',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                  if (failedSyncs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '❌ Failed to sync: ${failedSyncs.length} employees',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text('Failed employees: ${failedSyncs.join(', ')}'),
                  ],
                  const SizedBox(height: 12),
                  const Text('Date range: Past 3 months'),
                  Text('Period: $fromDate to $toDate'),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadAllReports(); // Refresh reports to show new data
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      print('🏁 3-Month bulk sync completed: ${successfulSyncs.length} successful, ${failedSyncs.length} failed');

    } catch (e) {
      // Close any open dialogs
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showMessage('Failed to sync 3-month data: $e', isError: true);
      print('❌ 3-Month sync error: $e');
    }
  }

  Future<void> _exportReport() async {
    try {
      // This is a simplified export - in a real app, you'd use a proper CSV/Excel library
      final csvData = _generateCSVData();
      
      // Show export success message
      _showMessage('Report data ready for export (${csvData.length} records)', isError: false);
      
      // In a real implementation, you'd save this to a file or share it
      // CSV data is ready for export
      
    } catch (e) {
      _showMessage('Failed to export report: $e', isError: true);
    }
  }

  String _generateCSVData() {
    final buffer = StringBuffer();
    
    // Add header
    buffer.writeln('Employee Name,Period,Attendance %,Present Days,Absent Days,Late Days,Working Hours,Avg Hours');
    
    // Add attendance data
    for (final data in _attendanceData) {
      buffer.writeln('${data.employee.name},${data.period},${data.attendancePercentage.toStringAsFixed(1)}%,'
          '${data.presentDays},${data.absentDays},${data.lateDays},'
          '${data.totalWorkingHours.toStringAsFixed(1)},${data.averageWorkingHours.toStringAsFixed(1)}');
    }
    
    return buffer.toString();
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _exportReport,
            icon: const Icon(Icons.download),
            tooltip: 'Export Report',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Attendance', icon: Icon(Icons.fingerprint, size: 20)),
            Tab(text: 'Leaves', icon: Icon(Icons.event_busy, size: 20)),
            Tab(text: 'Working Hours', icon: Icon(Icons.access_time, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFiltersSection(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAttendanceReport(),
                _buildLeaveReport(),
                _buildWorkingHoursReport(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
         _buildEmployeeFilter(),
         const SizedBox(height: 12),
         _buildDateRangeSelector(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadAllReports,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _syncThreeMonthsData,
                  icon: const Icon(Icons.cloud_sync),
                  label: const Text('Sync 3 Months'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportReport,
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeFilter() {
    // Remove duplicates and sort employees
    final uniqueEmployees = <String, AppUser>{};
    for (final employee in _employees) {
      uniqueEmployees[employee.id] = employee;
    }
    final employeesList = uniqueEmployees.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return DropdownButtonFormField<String?>(
      value: _selectedEmployeeId,
      decoration: const InputDecoration(
        labelText: 'Employee',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All Employees'),
        ),
        ...employeesList.map((employee) => DropdownMenuItem<String?>(
          value: employee.id,
          child: Text('${employee.name} (${employee.empCode ?? 'No Code'})'),
        )),
      ],
      onChanged: (value) {
        setState(() => _selectedEmployeeId = value);
        _loadAllReports();
      },
    );
  }

  Widget _buildDateRangeSelector() {
    // Find the matching month or reset to first available
    DateTime? validSelectedMonth;
    
    for (final month in _availableMonths) {
      if (month.year == _selectedMonth.year && month.month == _selectedMonth.month) {
        validSelectedMonth = month;
        break;
      }
    }
    
    // If no valid month found, use the first available
    final dropdownValue = validSelectedMonth ?? _availableMonths.first;
    
    // Update selected month if it changed
    if (_selectedMonth != dropdownValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _selectedMonth = dropdownValue);
      });
    }

    return DropdownButtonFormField<DateTime>(
      value: dropdownValue,
      decoration: const InputDecoration(
        labelText: 'Month',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _availableMonths.map((month) {
        return DropdownMenuItem<DateTime>(
          value: month,
          child: Text(DateFormat('MMMM yyyy').format(month)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedMonth = value);
          _loadAllReports();
        }
      },
    );
  }

  // Helper method to get date range for the selected month
  DateTimeRange get _monthDateRange {
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    return DateTimeRange(start: startOfMonth, end: endOfMonth);
  }

  Widget _buildAttendanceReport() {
    if (_isLoadingAttendance) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_attendanceData.isEmpty) {
      return _buildEmptyState('No attendance data found for the selected period.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _attendanceData.length,
      itemBuilder: (context, index) {
        final data = _attendanceData[index];
        return _buildAttendanceCard(data);
      },
    );
  }

  Widget _buildAttendanceCard(AttendanceReportData data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeAttendanceDetailScreen(
                employee: data.employee,
                selectedMonth: _selectedMonth,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF4285F4),
                    child: Text(
                      data.employee.name.isNotEmpty ? data.employee.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.employee.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          data.period,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getAttendanceColor(data.attendancePercentage),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data.attendancePercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Present',
                      '${data.presentDays}/${data.totalDays}',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Absent',
                      '${data.absentDays}',
                      Icons.cancel,
                      Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Late',
                      '${data.lateDays}',
                      Icons.schedule,
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Avg Hours',
                      '${data.averageWorkingHours.toStringAsFixed(1)}h',
                      Icons.access_time,
                      const Color(0xFF4285F4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveReport() {
    if (_isLoadingLeaves) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_leaveData.isEmpty) {
      return _buildEmptyState('No leave data found for the selected period.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaveData.length,
      itemBuilder: (context, index) {
        final data = _leaveData[index];
        return _buildLeaveCard(data);
      },
    );
  }

  Widget _buildLeaveCard(LeaveReportData data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeAttendanceDetailScreen(
                employee: data.employee,
                selectedMonth: _selectedMonth,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF4285F4),
                    child: Text(
                      data.employee.name.isNotEmpty ? data.employee.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.employee.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Total: ${data.totalLeaves.toStringAsFixed(1)} days',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Casual',
                      '${data.casualLeaves.toStringAsFixed(0)}',
                      Icons.event,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Sick',
                      '${data.sickLeaves.toStringAsFixed(0)}',
                      Icons.local_hospital,
                      Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Paid',
                      '${data.paidLeaves.toStringAsFixed(0)}',
                      Icons.monetization_on,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Optional',
                      '${data.optionalHolidays.toStringAsFixed(0)}',
                      Icons.celebration,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Approved',
                      '${data.approvedLeaves.toStringAsFixed(0)}',
                      Icons.check,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Pending',
                      '${data.pendingLeaves.toStringAsFixed(0)}',
                      Icons.hourglass_empty,
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Rejected',
                      '${data.rejectedLeaves.toStringAsFixed(0)}',
                      Icons.close,
                      Colors.red,
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkingHoursReport() {
    if (_isLoadingWorkingHours) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_workingHoursData.isEmpty) {
      return _buildEmptyState('No working hours data found for the selected period.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workingHoursData.length,
      itemBuilder: (context, index) {
        final data = _workingHoursData[index];
        return _buildWorkingHoursCard(data);
      },
    );
  }

  Widget _buildWorkingHoursCard(WorkingHoursReportData data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeAttendanceDetailScreen(
                employee: data.employee,
                selectedMonth: _selectedMonth,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF4285F4),
                    child: Text(
                      data.employee.name.isNotEmpty ? data.employee.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.employee.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Productivity: ${data.productivityScore.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            color: _getProductivityColor(data.productivityScore),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getProductivityColor(data.productivityScore),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data.productivityScore.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Total Hours',
                      '${data.totalWorkingHours.toStringAsFixed(1)}h',
                      Icons.access_time,
                      const Color(0xFF4285F4),
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Avg/Day',
                      '${data.averageWorkingHours.toStringAsFixed(1)}h',
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Overtime',
                      '${data.totalOvertimeHours.toStringAsFixed(1)}h',
                      Icons.schedule,
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Late Days',
                      '${data.lateDays}/${data.workingDays}',
                      Icons.schedule_outlined,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadAllReports,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 75) return Colors.orange;
    return Colors.red;
  }

  Color _getProductivityColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}

// Data Models for Reports
class AttendanceReportData {
  final AppUser employee;
  final String period;
  int totalDays;
  int presentDays;
  int absentDays;
  int lateDays;
  double totalWorkingHours;
  double averageWorkingHours;
  double attendancePercentage;

  AttendanceReportData({
    required this.employee,
    required this.period,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.totalWorkingHours,
    required this.averageWorkingHours,
    required this.attendancePercentage,
  });
}

class LeaveReportData {
  final AppUser employee;
  double casualLeaves;
  double sickLeaves;
  double paidLeaves;
  double optionalHolidays;
  double totalLeaves;
  double approvedLeaves;
  double pendingLeaves;
  double rejectedLeaves;

  LeaveReportData({
    required this.employee,
    required this.casualLeaves,
    required this.sickLeaves,
    required this.paidLeaves,
    required this.optionalHolidays,
    required this.totalLeaves,
    required this.approvedLeaves,
    required this.pendingLeaves,
    required this.rejectedLeaves,
  });
}

class WorkingHoursReportData {
  final AppUser employee;
  double totalWorkingHours;
  double totalOvertimeHours;
  double averageWorkingHours;
  int workingDays;
  int lateDays;
  double productivityScore;

  WorkingHoursReportData({
    required this.employee,
    required this.totalWorkingHours,
    required this.totalOvertimeHours,
    required this.averageWorkingHours,
    required this.workingDays,
    required this.lateDays,
    required this.productivityScore,
  });
}