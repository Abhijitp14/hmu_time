import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ensure user is properly authenticated and token is valid
  Future<void> _ensureAuthenticated() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Force refresh the ID token to ensure it's valid
    try {
      await currentUser.getIdToken(true);
      // Additional delay to ensure token propagation
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      throw Exception('Failed to refresh authentication token: $e');
    }
  }

  /// Retry mechanism for cloud function calls
  Future<T> _retryCloudFunction<T>(Future<T> Function() operation, {int maxRetries = 3}) async {
    dynamic lastException;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e;
        print('Cloud function attempt $attempt failed: $e');
        
        // If it's an authentication error and not the last attempt, retry after delay
        if (e.toString().contains('unauthenticated') && attempt < maxRetries) {
          print('Retrying authentication in ${attempt * 1000}ms...');
          await Future.delayed(Duration(milliseconds: attempt * 1000));
          // Try refreshing auth token again
          try {
            await _ensureAuthenticated();
          } catch (authError) {
            print('Failed to re-authenticate: $authError');
          }
          continue;
        }
        
        // For non-auth errors or last attempt, rethrow
        rethrow;
      }
    }
    
    throw lastException ?? Exception('Unknown error occurred');
  }

  /// Get current working hours settings with Firestore fallback
  Future<WorkingHoursSettings> getWorkingHoursSettings() async {
    try {
      // First, try the cloud function
      return await _retryCloudFunction(() async {
        final callable = _functions.httpsCallable('getWorkingHoursSettings');
        final result = await callable.call();

        if (result.data['success'] == true) {
          final settingsData = result.data['settings'];
          // Convert to Map<String, dynamic> to avoid type casting issues
          final Map<String, dynamic> settings = Map<String, dynamic>.from(settingsData as Map);
          return WorkingHoursSettings.fromJson(settings);
        } else {
          throw Exception('Failed to get working hours settings');
        }
      });
    } catch (e) {
      print('Error getting working hours settings via cloud function: $e');
      
      // If cloud function fails, try direct Firestore access
      try {
        print('🔄 Falling back to direct Firestore access');
        
        // Ensure user is authenticated for Firestore access
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          throw Exception('User not authenticated for Firestore access');
        }

        final settingsDoc = await _firestore
            .collection('system_settings')
            .doc('config')
            .get();

        if (!settingsDoc.exists) {
          print('📋 No system settings found in Firestore, using defaults');
          return _getDefaultSettings();
        }

        final data = settingsDoc.data();
        if (data == null) {
          print('📋 System settings document is null, using defaults');
          return _getDefaultSettings();
        }

        print('✅ Successfully retrieved settings from Firestore');
        return WorkingHoursSettings.fromJson(data);
        
      } catch (firestoreError) {
        print('❌ Firestore fallback also failed: $firestoreError');
        print('📋 Using default settings as last resort');
        return _getDefaultSettings();
      }
    }
  }

  /// Update working hours settings with Firestore fallback
  Future<WorkingHoursUpdateResult> updateWorkingHoursSettings(WorkingHoursSettings settings) async {
    try {
      await _ensureAuthenticated();

      // First, try the cloud function
      try {
        return await _retryCloudFunction(() async {
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
            throw Exception(result.data['error'] ?? 'Failed to update settings');
          }
        });
      } catch (e) {
        print('Cloud function failed, falling back to Firestore: $e');
        
        // Fallback to direct Firestore access
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          throw Exception('User not authenticated for Firestore access');
        }

        final settingsData = {
          // v3.0 Employee-specific structure
          'fullTimeEmployee': settings.fullTimeEmployee.toJson(),
          'partTimeEmployee': settings.partTimeEmployee.toJson(),
          'consultantEmployee': settings.consultantEmployee.toJson(),
          
          // Metadata
          'version': '3.0',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': currentUser.email,
        };

        await _firestore
            .collection('system_settings')
            .doc('config')
            .set(settingsData, SetOptions(merge: true));

        print('✅ Successfully updated settings via Firestore');
        
        return WorkingHoursUpdateResult(
          success: true,
          message: 'Settings updated successfully via direct database access',
          settings: settings,
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

      // Calculate status
      String status;
      String statusDetails;
      double overtimeHours = 0.0;

      if (workingHours == 0.0) {
        status = 'absent';
        statusDetails = 'No working hours recorded';
      } else if (halfDayRange != null && 
                 workingHours >= halfDayRange.start && 
                 workingHours <= halfDayRange.end) {
        status = 'present_half';
        statusDetails = 'Half day attendance';
      } else if (incompleteRange != null &&
                 workingHours >= incompleteRange.start && 
                 workingHours < incompleteRange.end) {
        status = 'incomplete';
        statusDetails = 'Incomplete working hours';
      } else if (workingHours >= requiredHours) {
        status = 'present_full';
        statusDetails = 'Full day attendance';
        // Only calculate overtime for full-time employees (simplified)
        if (employeeType.toLowerCase() == 'full_time' && workingHours > requiredHours) {
          overtimeHours = workingHours - requiredHours;
        }
      } else {
        status = 'present_partial';
        statusDetails = 'Partial day attendance';
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
  /// 
  /// Example use cases:
  /// - Admin changes the half-day threshold from 4.0 to 4.5 hours
  /// - Incomplete hours threshold is updated from 7.5 to 8.0 hours
  /// - Part-time working hours are changed from 4.0 to 6.0 hours
  /// 
  /// The system will re-evaluate all attendance records and update their status
  /// (full day, half day, incomplete, etc.) based on the new settings.
  Future<RecalculationResult> recalculateAllAttendanceStatuses() async {
    try {
      await _ensureAuthenticated();

      // Try cloud function first
      try {
        return await _retryCloudFunction(() async {
          final callable = _functions.httpsCallable('recalculateAllAttendanceStatuses');
          final result = await callable.call();

          if (result.data['success'] == true) {
            return RecalculationResult(
              success: true,
              recordsUpdated: (result.data['recordsUpdated'] ?? 0).toInt(),
              message: result.data['message'] ?? 'Recalculation completed successfully',
            );
          } else {
            throw Exception(result.data['error'] ?? 'Failed to recalculate attendance');
          }
        });
      } catch (e) {
        print('Cloud function recalculation failed: $e');
        
        // For now, return a message indicating this feature needs cloud function support
        return RecalculationResult(
          success: false,
          recordsUpdated: 0,
          error: 'Recalculation requires cloud function support. Please ensure the recalculateAllAttendanceStatuses cloud function is deployed.',
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