import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Data model classes
class TimeRange {
  final double start;
  final double end;

  TimeRange({
    required this.start,
    required this.end,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      start: (json['start'] ?? 0.0).toDouble(),
      end: (json['end'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
    };
  }
}

class FullTimeEmployeeSettings {
  final double workingHours;
  final TimeRange halfDayRange;
  final TimeRange incompleteRange;
  final String lateThresholdTime; // Time string like "10:00"

  FullTimeEmployeeSettings({
    required this.workingHours,
    required this.halfDayRange,
    required this.incompleteRange,
    required this.lateThresholdTime,
  });

  factory FullTimeEmployeeSettings.fromJson(Map<String, dynamic> json) {
    return FullTimeEmployeeSettings(
      workingHours: (json['workingHours'] ?? 8.0).toDouble(),
      halfDayRange: TimeRange.fromJson(Map<String, dynamic>.from(json['halfDayRange'] ?? {'start': 0.0, 'end': 4.0})),
      incompleteRange: TimeRange.fromJson(Map<String, dynamic>.from(json['incompleteRange'] ?? {'start': 6.0, 'end': 7.5})),
      lateThresholdTime: json['lateThresholdTime'] ?? '10:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workingHours': workingHours,
      'halfDayRange': halfDayRange.toJson(),
      'incompleteRange': incompleteRange.toJson(),
      'lateThresholdTime': lateThresholdTime,
    };
  }
}

class PartTimeEmployeeSettings {
  final double workingHours;
  final TimeRange incompleteRange;

  PartTimeEmployeeSettings({
    required this.workingHours,
    required this.incompleteRange,
  });

  factory PartTimeEmployeeSettings.fromJson(Map<String, dynamic> json) {
    return PartTimeEmployeeSettings(
      workingHours: (json['workingHours'] ?? 4.0).toDouble(),
      incompleteRange: TimeRange.fromJson(Map<String, dynamic>.from(json['incompleteRange'] ?? {'start': 0.0, 'end': 3.5})),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workingHours': workingHours,
      'incompleteRange': incompleteRange.toJson(),
    };
  }
}

class ConsultantEmployeeSettings {
  final double workingHours;

  ConsultantEmployeeSettings({
    required this.workingHours,
  });

  factory ConsultantEmployeeSettings.fromJson(Map<String, dynamic> json) {
    return ConsultantEmployeeSettings(
      workingHours: (json['workingHours'] ?? 6.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workingHours': workingHours,
    };
  }
}

class WorkingHoursSettings {
  final FullTimeEmployeeSettings fullTimeEmployee;
  final PartTimeEmployeeSettings partTimeEmployee;
  final ConsultantEmployeeSettings consultantEmployee;

  WorkingHoursSettings({
    required this.fullTimeEmployee,
    required this.partTimeEmployee,
    required this.consultantEmployee,
  });

  factory WorkingHoursSettings.fromJson(Map<String, dynamic> json) {
    // Handle both v3.0 structured format and legacy format
    if (json['version'] == '3.0' || (json.containsKey('fullTimeEmployee') && json.containsKey('partTimeEmployee'))) {
      // New v3.0 structured format
      return WorkingHoursSettings(
        fullTimeEmployee: FullTimeEmployeeSettings.fromJson(Map<String, dynamic>.from(json['fullTimeEmployee'] ?? {})),
        partTimeEmployee: PartTimeEmployeeSettings.fromJson(Map<String, dynamic>.from(json['partTimeEmployee'] ?? {})),
        consultantEmployee: ConsultantEmployeeSettings.fromJson(Map<String, dynamic>.from(json['consultantEmployee'] ?? {})),
      );
    } else {
      // Legacy format conversion (v2.0 or older)
      return WorkingHoursSettings(
        fullTimeEmployee: FullTimeEmployeeSettings(
          workingHours: (json['workingHoursPerDay'] ?? json['workingHours']?['fullTime'] ?? 8.0).toDouble(),
          halfDayRange: TimeRange(start: 0.0, end: (json['halfDayThreshold'] ?? json['attendanceRanges']?['halfDay']?['end'] ?? 4.0).toDouble()),
          incompleteRange: TimeRange(start: 6.0, end: (json['incompleteHoursThreshold'] ?? json['attendanceRanges']?['incomplete']?['end'] ?? 7.5).toDouble()),
          lateThresholdTime: '10:00', // Default late threshold
        ),
        partTimeEmployee: PartTimeEmployeeSettings(
          workingHours: (json['partTimeWorkingHours'] ?? json['workingHours']?['partTime'] ?? 4.0).toDouble(),
          incompleteRange: TimeRange(start: 0.0, end: (json['partTimeIncompleteThreshold'] ?? json['attendanceRanges']?['partTimeIncomplete']?['end'] ?? 3.5).toDouble()),
        ),
        consultantEmployee: ConsultantEmployeeSettings(
          workingHours: (json['consultantWorkingHours'] ?? json['workingHours']?['consultant'] ?? 6.0).toDouble(),
        ),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'version': '3.0',
      'fullTimeEmployee': fullTimeEmployee.toJson(),
      'partTimeEmployee': partTimeEmployee.toJson(),
      'consultantEmployee': consultantEmployee.toJson(),
    };
  }

  // Backward compatibility getters for existing code
  double get workingHoursPerDay => fullTimeEmployee.workingHours;
  double get partTimeWorkingHours => partTimeEmployee.workingHours;
  double get consultantWorkingHours => consultantEmployee.workingHours;
  double get halfDayThreshold => fullTimeEmployee.halfDayRange.end;
  double get incompleteHoursThreshold => fullTimeEmployee.incompleteRange.end;
  double get partTimeIncompleteThreshold => partTimeEmployee.incompleteRange.end;
  
  // New getters for ranges
  TimeRange get halfDayRange => fullTimeEmployee.halfDayRange;
  TimeRange get incompleteHoursRange => fullTimeEmployee.incompleteRange;
  TimeRange get partTimeIncompleteRange => partTimeEmployee.incompleteRange;
  
  // Late threshold getter
  String get lateThresholdTime => fullTimeEmployee.lateThresholdTime;
}

class WorkingHoursUpdateResult {
  final bool success;
  final String? message;
  final String? error;
  final WorkingHoursSettings? settings;

  WorkingHoursUpdateResult({
    required this.success,
    this.message,
    this.error,
    this.settings,
  });
}

class AttendanceStatus {
  final String status; // 'present_full', 'present_partial', 'present_half', 'incomplete', 'absent'
  final String statusDetails;
  final double workingHours;
  final double overtimeHours;
  final double requiredHours;
  final Map<String, double> thresholds;

  AttendanceStatus({
    required this.status,
    required this.statusDetails,
    required this.workingHours,
    required this.overtimeHours,
    required this.requiredHours,
    required this.thresholds,
  });

  factory AttendanceStatus.fromJson(Map<String, dynamic> json) {
    return AttendanceStatus(
      status: json['status'] as String,
      statusDetails: json['statusDetails'] as String,
      workingHours: (json['workingHours'] ?? 0.0).toDouble(),
      overtimeHours: (json['overtimeHours'] ?? 0.0).toDouble(),
      requiredHours: (json['requiredHours'] ?? 8.0).toDouble(),
      thresholds: Map<String, double>.from(json['thresholds'] ?? {}),
    );
  }

  // Helper methods for UI display
  bool get isFullDay => status == 'present_full';
  bool get isPartialDay => status == 'present_partial';
  bool get isHalfDay => status == 'present_half';
  bool get isIncomplete => status == 'incomplete';
  bool get isAbsent => status == 'absent';
  
  String get displayStatus {
    switch (status) {
      case 'present_full':
        return 'Full Day';
      case 'present_partial':
        return 'Partial Day';
      case 'present_half':
        return 'Half Day';
      case 'incomplete':
        return 'Incomplete Hours';
      case 'absent':
        return 'Absent';
      default:
        return 'Unknown';
    }
  }
}

class WorkingHoursService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseAuth _auth = FirebaseAuth.instance;



  /// Get current working hours settings (multiple fallback methods)
  Future<WorkingHoursSettings> getWorkingHoursSettings() async {
    // Try HTTP request first (no auth headers)
    try {
      const String functionUrl = 'https://us-central1-hmu-time.cloudfunctions.net/getSystemSettings';
      
      final response = await http.get(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['success'] == true) {
          final settingsData = data['settings'];
          final Map<String, dynamic> settings = Map<String, dynamic>.from(settingsData as Map);
          print('✅ Loaded settings via HTTP');
          return WorkingHoursSettings.fromJson(settings);
        }
      }
    } catch (e) {
      print('🌐 HTTP request failed: $e, trying callable function...');
    }

    // Fallback to callable function (should return defaults on any error)
    try {
      final callable = _functions.httpsCallable('getWorkingHoursSettings');
      final result = await callable.call().timeout(const Duration(seconds: 10));

      if (result.data['success'] == true) {
        final settingsData = result.data['settings'];
        final Map<String, dynamic> settings = Map<String, dynamic>.from(settingsData as Map);
        print('✅ Loaded settings via callable function');
        return WorkingHoursSettings.fromJson(settings);
      }
    } catch (e) {
      print('📞 Callable function failed: $e');
    }

    // Final fallback to default settings
    print('📋 Using default settings as final fallback');
    return _getDefaultSettings();
  }

  /// Update working hours settings (requires authentication)
  Future<WorkingHoursUpdateResult> updateWorkingHoursSettings(WorkingHoursSettings settings) async {
    try {
      // Ensure user is authenticated for updates
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return WorkingHoursUpdateResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      final callable = _functions.httpsCallable('updateWorkingHoursSettings');
      final dataToSend = settings.toJson();
      print('🔄 Sending to cloud function: ${dataToSend}');
      final result = await callable.call(dataToSend);

      if (result.data['success'] == true) {
        final updatedSettingsData = result.data['settings'];
        final Map<String, dynamic> updatedSettings = Map<String, dynamic>.from(updatedSettingsData as Map);
        
        return WorkingHoursUpdateResult(
          success: true,
          message: result.data['message'] ?? 'Settings updated successfully',
          settings: WorkingHoursSettings.fromJson(updatedSettings),
        );
      } else {
        return WorkingHoursUpdateResult(
          success: false,
          error: result.data['error'] ?? 'Failed to update settings',
        );
      }
    } catch (e) {
      print('❌ Error updating working hours settings: $e');
      return WorkingHoursUpdateResult(
        success: false,
        error: 'Failed to update settings: ${e.toString()}',
      );
    }
  }

  /// Calculate attendance status based on working hours and settings
  Future<AttendanceStatus> calculateAttendanceStatus({
    required double workingHours,
    required String employeeType, // 'full_time', 'part_time', 'consultant'
  }) async {
    try {
      final settings = await getWorkingHoursSettings();
      
      // Determine required hours based on employee type
      double requiredHours;
      TimeRange? incompleteRange;
      TimeRange? halfDayRange;
      
      switch (employeeType.toLowerCase()) {
        case 'part_time':
          requiredHours = settings.partTimeEmployee.workingHours;
          incompleteRange = settings.partTimeEmployee.incompleteRange;
          break;
        case 'consultant':
          requiredHours = settings.consultantEmployee.workingHours;
          // Consultant doesn't have incomplete range
          break;
        default: // full_time
          requiredHours = settings.fullTimeEmployee.workingHours;
          incompleteRange = settings.fullTimeEmployee.incompleteRange;
          halfDayRange = settings.fullTimeEmployee.halfDayRange;
          break;
      }

      // Calculate status based on employee type
      String status = 'absent';
      String statusDetails = 'No working hours recorded';
      double overtimeHours = 0.0;

      if (workingHours == 0.0) {
        status = 'absent';
        statusDetails = 'No working hours recorded';
      } else if (employeeType.toLowerCase() == 'part_time') {
        // Part-time: Only Complete or Incomplete (NO half-day)
        if (workingHours >= requiredHours) {
          status = 'present_full';
          statusDetails = 'Completed part-time day';
        } else {
          status = 'incomplete';
          statusDetails = 'Incomplete part-time hours';
        }
      } else if (employeeType.toLowerCase() == 'consultant') {
        // Consultant: Only Complete or Incomplete (NO half-day)
        if (workingHours >= requiredHours) {
          status = 'present_full';
          statusDetails = 'Completed consultant day';
        } else {
          status = 'incomplete';
          statusDetails = 'Incomplete consultant hours';
        }
      } else {
        // Full-time: Complete, Incomplete, or Half-day
        if (workingHours >= requiredHours) {
          status = 'present_full';
          statusDetails = 'Full day attendance';
          overtimeHours = workingHours - requiredHours;
        } else if (incompleteRange != null && 
                   workingHours >= incompleteRange.start && 
                   workingHours < requiredHours) {
          status = 'incomplete';
          statusDetails = 'Incomplete working hours';
        } else if (halfDayRange != null && 
                   workingHours > 0 && 
                   workingHours <= halfDayRange.end) {
          status = 'present_half';
          statusDetails = 'Half day attendance';
        } else if (workingHours > 0) {
          status = 'present_partial';
          statusDetails = 'Partial day attendance';
        }
      }

      return AttendanceStatus(
        status: status,
        statusDetails: statusDetails,
        workingHours: workingHours,
        overtimeHours: overtimeHours,
        requiredHours: requiredHours,
        thresholds: {
          'halfDayMin': halfDayRange?.start ?? 0.0,
          'halfDayMax': halfDayRange?.end ?? 0.0,
          'incompleteMin': incompleteRange?.start ?? 0.0,
          'incompleteMax': incompleteRange?.end ?? 0.0,
          'fullDay': requiredHours,
          'overtime': requiredHours,
        },
      );
    } catch (e) {
      print('Error calculating attendance status: $e');
      return AttendanceStatus(
        status: 'unknown',
        statusDetails: 'Error calculating status: ${e.toString()}',
        workingHours: workingHours,
        overtimeHours: 0.0,
        requiredHours: 8.0,
        thresholds: {},
      );
    }
  }

  /// Get default settings
  WorkingHoursSettings _getDefaultSettings() {
    return WorkingHoursSettings(
      fullTimeEmployee: FullTimeEmployeeSettings(
        workingHours: 8.0,
        halfDayRange: TimeRange(start: 0.0, end: 4.0),
        incompleteRange: TimeRange(start: 6.0, end: 7.5),
        lateThresholdTime: '10:00',
      ),
      partTimeEmployee: PartTimeEmployeeSettings(
        workingHours: 4.0,
        incompleteRange: TimeRange(start: 0.0, end: 3.5),
      ),
      consultantEmployee: ConsultantEmployeeSettings(
        workingHours: 6.0,
      ),
    );
  }

  /// Recalculate all attendance statuses based on current working hours settings
  /// 
  /// This method is used when working hours settings are changed and you need to
  /// update existing attendance records to reflect the new thresholds.
  Future<RecalculationResult> recalculateAllAttendanceStatuses() async {
    try {
      // Ensure user is authenticated for recalculation
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return RecalculationResult(
          success: false,
          recordsUpdated: 0,
          error: 'User not authenticated',
        );
      }

      final callable = _functions.httpsCallable('recalculateAllAttendanceStatuses');
      final result = await callable.call();

      if (result.data['success'] == true) {
        return RecalculationResult(
          success: true,
          recordsUpdated: (result.data['recordsUpdated'] ?? 0).toInt(),
          message: result.data['message'] ?? 'Recalculation completed successfully',
        );
      } else {
        return RecalculationResult(
          success: false,
          recordsUpdated: 0,
          error: result.data['error'] ?? 'Failed to recalculate attendance',
        );
      }
    } catch (e) {
      print('❌ Error during attendance recalculation: $e');
      return RecalculationResult(
        success: false,
        recordsUpdated: 0,
        error: 'Failed to recalculate attendance: ${e.toString()}',
      );
    }
  }
}

/// Result of attendance recalculation operation
class RecalculationResult {
  final bool success;
  final int recordsUpdated;
  final String? message;
  final String? error;

  RecalculationResult({
    required this.success,
    required this.recordsUpdated,
    this.message,
    this.error,
  });
}