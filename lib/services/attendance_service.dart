import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TodayAttendanceRecord {
  final String empCode;
  final String employeeName;
  final String department;
  final String designation;
  final String employmentType;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double totalHours;
  final String status; // Present, Absent, Half Day, etc.
  final String statusDetails;
  final List<PunchRecord> punches;
  final bool isLate;
  final DateTime? lastSyncTime;

  TodayAttendanceRecord({
    required this.empCode,
    required this.employeeName,
    required this.department,
    required this.designation,
    required this.employmentType,
    this.checkIn,
    this.checkOut,
    required this.totalHours,
    required this.status,
    required this.statusDetails,
    required this.punches,
    required this.isLate,
    this.lastSyncTime,
  });

  factory TodayAttendanceRecord.fromFirestore(Map<String, dynamic> data, String empCode, Map<String, dynamic> employeeData) {
    final punches = (data['punches'] as List<dynamic>?)?.map((punch) => 
      PunchRecord.fromFirestorePunch(punch as Map<String, dynamic>, data['date'] ?? '')
    ).toList() ?? [];

    // Calculate check-in and check-out from punches
    DateTime? checkIn;
    DateTime? checkOut;
    
    for (final punch in punches) {
      if (punch.type == 'IN' && checkIn == null) {
        checkIn = punch.dateTime;
      } else if (punch.type == 'OUT') {
        checkOut = punch.dateTime; // Take the latest OUT punch
      }
    }

    // Calculate total hours
    double totalHours = 0.0;
    if (checkIn != null && checkOut != null) {
      totalHours = checkOut.difference(checkIn).inMinutes / 60.0;
    }

    // Determine status based on punches
    String status = 'Absent';
    String statusDetails = 'No punch records found';
    
    if (checkIn != null) {
      if (checkOut != null) {
        if (totalHours >= 8.0) {
          status = 'Full Day';
          statusDetails = 'Complete working day';
        } else if (totalHours >= 4.0) {
          status = 'Half Day';
          statusDetails = 'Partial working day';
        } else {
          status = 'Incomplete';
          statusDetails = 'Insufficient working hours';
        }
      } else {
        status = 'Incomplete';
        statusDetails = 'No checkout time recorded';
      }
    }

    // Check if late (assuming 9:00 AM is the standard time)
    bool isLate = false;
    if (checkIn != null) {
      final standardTime = DateTime(checkIn.year, checkIn.month, checkIn.day, 9, 0);
      isLate = checkIn.isAfter(standardTime);
    }

    return TodayAttendanceRecord(
      empCode: empCode,
      employeeName: data['employeeName'] ?? employeeData['name'] ?? 'Unknown',
      department: employeeData['department'] ?? 'Unknown',
      designation: employeeData['designation'] ?? 'Unknown',
      employmentType: employeeData['employmentType'] ?? 'Full Time',
      checkIn: checkIn,
      checkOut: checkOut,
      totalHours: totalHours,
      status: status,
      statusDetails: statusDetails,
      punches: punches,
      isLate: isLate,
      lastSyncTime: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  bool get isPresent => checkIn != null;
  bool get hasCheckedOut => checkOut != null;
}

class PunchRecord {
  final DateTime dateTime;
  final String type; // IN or OUT
  final String location;
  final String deviceId;

  PunchRecord({
    required this.dateTime,
    required this.type,
    required this.location,
    required this.deviceId,
  });

  factory PunchRecord.fromJson(Map<String, dynamic> json) {
    return PunchRecord(
      dateTime: (json['dateTime'] as Timestamp).toDate(),
      type: json['type'] ?? 'IN',
      location: json['location'] ?? 'Unknown',
      deviceId: json['deviceId'] ?? 'Unknown',
    );
  }

  factory PunchRecord.fromFirestorePunch(Map<String, dynamic> punch, String dateStr) {
    // Parse the datetime from Firebase format: "16/10/2025 09:30"
    final datetime = punch['datetime'] as String? ?? '';
    DateTime parsedDateTime = DateTime.now();
    
    try {
      if (datetime.isNotEmpty) {
        // Split datetime: "16/10/2025 09:30"
        final parts = datetime.split(' ');
        if (parts.length >= 2) {
          final datePart = parts[0]; // "16/10/2025"
          final timePart = parts[1]; // "09:30"
          
          final dateParts = datePart.split('/');
          final timeParts = timePart.split(':');
          
          if (dateParts.length == 3 && timeParts.length >= 2) {
            final day = int.parse(dateParts[0]);
            final month = int.parse(dateParts[1]);
            final year = int.parse(dateParts[2]);
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            
            parsedDateTime = DateTime(year, month, day, hour, minute);
          }
        }
      }
    } catch (e) {
      print('Error parsing datetime: $datetime - $e');
    }
    
    return PunchRecord(
      dateTime: parsedDateTime,
      type: punch['type'] ?? 'IN',
      location: 'Office', // Default location from biometric machine
      deviceId: punch['deviceId'] ?? 'biometric_machine',
    );
  }
}

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;



  /// Check if employee needs sync (hasn't been synced in the last 30 minutes)
  Future<bool> _needsSync(String empCode) async {
    try {
      final today = DateTime.now();
      final monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                         'July', 'August', 'September', 'October', 'November', 'December'];
      final monthName = monthNames[today.month - 1];
      final todayStr = '${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}-${today.year}';
      
      final todayDoc = await _firestore
          .collection('attendance')
          .doc(empCode)
          .collection('${empCode}_${monthName}')
          .doc('${empCode}_${todayStr}')
          .get();
      
      if (!todayDoc.exists) return true; // No data, definitely needs sync
      
      final data = todayDoc.data()!;
      final updatedAt = data['updatedAt'] as Timestamp?;
      
      if (updatedAt == null) return true; // No timestamp, needs sync
      
      // Check if last sync was more than 30 minutes ago
      final lastSync = updatedAt.toDate();
      final thirtyMinutesAgo = DateTime.now().subtract(const Duration(minutes: 30));
      
      return lastSync.isBefore(thirtyMinutesAgo);
    } catch (e) {
      print('Error checking sync status for $empCode: $e');
      return true; // If we can't check, better to sync
    }
  }

  /// Sync all employees' attendance data for today (optimized with parallel processing)
  Future<List<String>> syncAllEmployeesToday() async {
    try {
      print('🔄 Starting optimized bulk sync for all employees...');
      
      // Get all active employees
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .where('isActive', isEqualTo: true)
          .get();
      
      final today = DateTime.now();
      final fromDate = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final toDate = fromDate; // Same date for today only
      
      print('📊 Found ${usersSnapshot.docs.length} active employees');
      
      // Filter employees that need syncing
      List<Map<String, dynamic>> employeesToSync = [];
      
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final empCode = userData['empCode']?.toString();
        
        if (empCode != null) {
          final needsSync = await _needsSync(empCode);
          if (needsSync) {
            employeesToSync.add({
              'empCode': empCode,
              'name': userData['name'] ?? 'Unknown',
              'userData': userData,
            });
          } else {
            print('⏩ Skipping ${userData['name']} ($empCode) - recently synced');
          }
        }
      }
      
      print('🔄 ${employeesToSync.length} employees need syncing (${usersSnapshot.docs.length - employeesToSync.length} already recent)');
      
      if (employeesToSync.isEmpty) {
        return ['✅ All employees have recent data - no sync needed'];
      }
      
      // Process in batches of 5 to avoid overwhelming the system
      const batchSize = 5;
      List<String> syncResults = [];
      
      for (int i = 0; i < employeesToSync.length; i += batchSize) {
        final batch = employeesToSync.skip(i).take(batchSize).toList();
        print('🔄 Processing batch ${(i ~/ batchSize) + 1}/${(employeesToSync.length / batchSize).ceil()} (${batch.length} employees)');
        
        // Process batch in parallel
        final batchFutures = batch.map((employee) async {
          final empCode = employee['empCode'] as String;
          final name = employee['name'] as String;
          
          try {
            final callable = _functions.httpsCallable('syncBiometricData');
            final result = await callable.call({
              'empcode': empCode,
              'fromDate': fromDate,
              'toDate': toDate,
            });
            
            if (result.data['success'] == true) {
              final recordsProcessed = result.data['recordsProcessed'] ?? 0;
              return '✅ $name ($empCode): $recordsProcessed records';
            } else {
              return '❌ $name ($empCode): ${result.data['error'] ?? 'Unknown error'}';
            }
          } catch (e) {
            return '❌ $name ($empCode): $e';
          }
        }).toList();
        
        // Wait for batch to complete
        final batchResults = await Future.wait(batchFutures);
        syncResults.addAll(batchResults);
        
        // Log batch completion
        for (final result in batchResults) {
          print(result);
        }
        
        // Small delay between batches to avoid rate limiting
        if (i + batchSize < employeesToSync.length) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
      
      print('🏁 Optimized bulk sync completed. Synced: ${employeesToSync.length}, Total results: ${syncResults.length}');
      return syncResults;
      
    } catch (e) {
      print('❌ Error in optimized bulk sync: $e');
      return ['❌ Bulk sync failed: $e'];
    }
  }

  /// Get today's attendance for all employees (with optional automatic sync)
  Future<List<TodayAttendanceRecord>> getTodayAttendance({bool autoSync = true}) async {
    try {
      // First, sync all employees' data if autoSync is enabled
      if (autoSync) {
        print('🔄 Auto-syncing employees with stale data...');
        final syncResults = await syncAllEmployeesToday();
        
        if (syncResults.isNotEmpty && !syncResults.first.contains('no sync needed')) {
          // Only wait if we actually synced some data
          print('⏳ Sync completed, waiting for Firestore propagation...');
          await Future.delayed(const Duration(seconds: 2));
        }
        print('📊 Loading attendance data...');
      }
      
      final today = DateTime.now();
      final todayStr = '${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}-${today.year}';
      
      print('🗓️ Today date string: $todayStr');
      print('🗓️ Today: ${today.day}/${today.month}/${today.year}');
      
      // Get all employee documents from attendance collection
      final attendanceSnapshot = await _firestore.collection('attendance').get();
      
      print('📊 Found ${attendanceSnapshot.docs.length} employee documents in attendance collection');
      
      List<TodayAttendanceRecord> todayRecords = [];
      
      for (final empDoc in attendanceSnapshot.docs) {
        final empCode = empDoc.id;
        
        try {
          // Get current month name
          final monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                             'July', 'August', 'September', 'October', 'November', 'December'];
          final monthName = monthNames[today.month - 1];
          
          // Query today's attendance record
          final todayDocRef = _firestore
              .collection('attendance')
              .doc(empCode)
              .collection('${empCode}_${monthName}')
              .doc('${empCode}_${todayStr}');
          
          print('🔍 Looking for attendance record at: attendance/${empCode}/${empCode}_${monthName}/${empCode}_${todayStr}');
          
          final todayDoc = await todayDocRef.get();
          print('📊 Attendance doc exists for ${empCode}: ${todayDoc.exists}');
          
          if (todayDoc.exists) {
            print('📄 Attendance data: ${todayDoc.data()}');
          }
          
          // First, get employee details from users collection
          final userDoc = await _firestore.collection('users').where('empCode', isEqualTo: empCode).limit(1).get();
          
          if (userDoc.docs.isNotEmpty) {
            final userData = userDoc.docs.first.data();
            
            if (todayDoc.exists) {
              // Employee has attendance record for today
              final record = TodayAttendanceRecord.fromFirestore(todayDoc.data()!, empCode, userData);
              todayRecords.add(record);
            } else {
              // Employee has no attendance record for today - create absent record
              todayRecords.add(TodayAttendanceRecord(
                empCode: empCode,
                employeeName: userData['name'] ?? 'Unknown',
                department: userData['department'] ?? 'Unknown',
                designation: userData['designation'] ?? 'Unknown',
                employmentType: userData['employmentType'] ?? 'Full Time',
                checkIn: null,
                checkOut: null,
                totalHours: 0.0,
                status: 'Absent',
                statusDetails: 'No punch records found for today',
                punches: [],
                isLate: false,
                lastSyncTime: null,
              ));
            }
          }
        } catch (e) {
          print('Error processing attendance for empCode $empCode: $e');
        }
      }
      
      // Also check for employees who might not have any attendance collection yet
      await _addMissingEmployees(todayRecords);
      
      // Sort by employee name
      todayRecords.sort((a, b) => a.employeeName.compareTo(b.employeeName));
      
      return todayRecords;
    } catch (e) {
      print('Error fetching today\'s attendance: $e');
      return [];
    }
  }

  /// Add employees who don't have any attendance records yet
  Future<void> _addMissingEmployees(List<TodayAttendanceRecord> existingRecords) async {
    try {
      // Get all employees from users collection
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .where('isActive', isEqualTo: true)
          .get();
      
      final existingEmpCodes = existingRecords.map((r) => r.empCode).toSet();
      
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final empCode = userData['empCode']?.toString();
        
        if (empCode != null && !existingEmpCodes.contains(empCode)) {
          existingRecords.add(TodayAttendanceRecord(
            empCode: empCode,
            employeeName: userData['name'] ?? 'Unknown',
            department: userData['department'] ?? 'Unknown',
            designation: userData['designation'] ?? 'Unknown',
            employmentType: userData['employmentType'] ?? 'Full Time',
            checkIn: null,
            checkOut: null,
            totalHours: 0.0,
            status: 'Absent',
            statusDetails: 'No attendance records found',
            punches: [],
            isLate: false,
            lastSyncTime: null,
          ));
        }
      }
    } catch (e) {
      print('Error adding missing employees: $e');
    }
  }

  /// Get attendance summary from existing records
  Map<String, int> calculateSummary(List<TodayAttendanceRecord> records) {
    int present = 0;
    int absent = 0;
    int halfDay = 0;
    int late = 0;
    
    for (final record in records) {
      if (record.isPresent) {
        present++;
        if (record.isLate) late++;
        if (record.status == 'Half Day') halfDay++;
      } else {
        absent++;
      }
    }
    
    return {
      'total': records.length,
      'present': present,
      'absent': absent,
      'halfDay': halfDay,
      'late': late,
    };
  }

  /// Get attendance summary for today (deprecated - use calculateSummary instead)
  @Deprecated('Use calculateSummary with existing records to avoid double loading')
  Future<Map<String, int>> getTodayAttendanceSummary() async {
    final records = await getTodayAttendance(autoSync: false);
    return calculateSummary(records);
  }
}