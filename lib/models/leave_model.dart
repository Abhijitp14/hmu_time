import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for different types of leave
enum LeaveType {
  sick,
  casual,
  paid,
  optionalHoliday,
}

extension LeaveTypeExtension on LeaveType {
  String get displayName {
    switch (this) {
      case LeaveType.sick:
        return 'Sick Leave';
      case LeaveType.casual:
        return 'Casual Leave';
      case LeaveType.paid:
        return 'Paid Leave';
      case LeaveType.optionalHoliday:
        return 'Optional Holiday';
    }
  }

  String get shortName {
    switch (this) {
      case LeaveType.sick:
        return 'SL';
      case LeaveType.casual:
        return 'CL';
      case LeaveType.paid:
        return 'PL';
      case LeaveType.optionalHoliday:
        return 'OH';
    }
  }

  String get value {
    switch (this) {
      case LeaveType.sick:
        return 'sick';
      case LeaveType.casual:
        return 'casual';
      case LeaveType.paid:
        return 'paid';
      case LeaveType.optionalHoliday:
        return 'optionalHoliday';
    }
  }

  static LeaveType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'sick':
        return LeaveType.sick;
      case 'casual':
        return LeaveType.casual;
      case 'paid':
        return LeaveType.paid;
      case 'optional':
      case 'optionalHoliday':
        return LeaveType.optionalHoliday;
      default:
        return LeaveType.sick;
    }
  }

  /// Get leave balance key for user model
  String get balanceKey {
    switch (this) {
      case LeaveType.sick:
        return 'sickLeave';
      case LeaveType.casual:
        return 'casualLeave';
      case LeaveType.paid:
        return 'paidLeave';
      case LeaveType.optionalHoliday:
        return 'optionalHoliday';
    }
  }
}

/// Enum for leave request status
enum LeaveStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

extension LeaveStatusExtension on LeaveStatus {
  String get displayName {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
      case LeaveStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get value {
    switch (this) {
      case LeaveStatus.pending:
        return 'pending';
      case LeaveStatus.approved:
        return 'approved';
      case LeaveStatus.rejected:
        return 'rejected';
      case LeaveStatus.cancelled:
        return 'cancelled';
    }
  }

  static LeaveStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return LeaveStatus.pending;
      case 'approved':
        return LeaveStatus.approved;
      case 'rejected':
        return LeaveStatus.rejected;
      case 'cancelled':
        return LeaveStatus.cancelled;
      default:
        return LeaveStatus.pending;
    }
  }
}

/// Model for leave request
class LeaveRequest {
  final String id;
  final String employeeId;
  final String empCode;
  final String? employeeName;
  final String? employeeDepartment; // Changed from department for clarity
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final int daysToDeduct; // Days actually deducted from balance
  final String? reason;
  final String status; // Changed to String for flexibility
  final DateTime? submittedDate; // Changed from appliedDate for clarity
  final String? approvedBy;
  final DateTime? approvedDate;
  final String? rejectedBy; // Added for admin tracking
  final DateTime? rejectedDate; // Added for admin tracking
  final String? rejectionReason;
  final String? adminComments; // Added for admin comments
  final DateTime? processedDate; // Added for tracking when action was taken
  final String? medicalCertificate; // URL or path to uploaded certificate
  final Map<String, dynamic>? leaveBalance; // Balance at time of application

  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.empCode,
    this.employeeName,
    this.employeeDepartment,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.daysToDeduct,
    this.reason,
    required this.status,
    this.submittedDate,
    this.approvedBy,
    this.approvedDate,
    this.rejectedBy,
    this.rejectedDate,
    this.rejectionReason,
    this.adminComments,
    this.processedDate,
    this.medicalCertificate,
    this.leaveBalance,
  });

  /// Calculate leave duration in days (excluding only Sunday, Saturday is a working day)
  static int calculateLeaveDays(DateTime startDate, DateTime endDate) {
    int totalDays = 0;
    DateTime current = startDate;
    
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      // Skip only Sunday (Sunday = 7), Saturday is a working day
      if (current.weekday != DateTime.sunday) {
        totalDays++;
      }
      current = current.add(const Duration(days: 1));
    }
    
    return totalDays;
  }

  /// Calculate leave days to deduct from balance based on leave type
  /// For Sick Leave: Only 1 day is deducted regardless of duration
  /// For other leaves: Full duration is deducted
  static int calculateLeaveDeduction(DateTime startDate, DateTime endDate, LeaveType leaveType) {
    final totalDays = calculateLeaveDays(startDate, endDate);
    
    switch (leaveType) {
      case LeaveType.sick:
        // For Sick Leave: Only 1 day is deducted from balance regardless of duration
        // This is because only one sick leave per month is allowed
        // Other days will be automatically marked as absent
        return totalDays > 0 ? 1 : 0;
      
      case LeaveType.casual:
      case LeaveType.paid:
      case LeaveType.optionalHoliday:
        // For other leave types: Deduct full duration
        return totalDays;
    }
  }

  /// Check if dates are valid for leave request
  static bool isValidDateRange(DateTime startDate, DateTime endDate) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    // Start date should not be in the past
    return startDate.isAfter(todayStart) || startDate.isAtSameMomentAs(todayStart);
  }

  /// Factory method to create from Firestore document
  factory LeaveRequest.fromMap(Map<String, dynamic> map, String documentId) {
    // Handle date parsing with improved debugging
    DateTime parseDate(dynamic dateData, String fieldName) {
      if (dateData == null) {
        print('⚠️ $fieldName is null, using current date');
        return DateTime.now();
      }
      
      if (dateData is Timestamp) {
        return dateData.toDate();
      } else if (dateData is String) {
        try {
          return DateTime.parse(dateData);
        } catch (e) {
          print('❌ Failed to parse $fieldName string: $dateData, error: $e');
          return DateTime.now();
        }
      } else if (dateData is Map) {
        // Handle Firebase timestamp objects that come as maps
        try {
          if (dateData.containsKey('_seconds') && dateData.containsKey('_nanoseconds')) {
            final seconds = dateData['_seconds'] as int;
            final nanoseconds = dateData['_nanoseconds'] as int;
            return DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + (nanoseconds / 1000000).round()
            );
          } else if (dateData.containsKey('seconds') && dateData.containsKey('nanoseconds')) {
            final seconds = dateData['seconds'] as int;
            final nanoseconds = dateData['nanoseconds'] as int;
            return DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + (nanoseconds / 1000000).round()
            );
          }
        } catch (e) {
          print('❌ Failed to parse $fieldName map: $dateData, error: $e');
        }
      } else if (dateData is int) {
        // Handle milliseconds timestamp
        try {
          return DateTime.fromMillisecondsSinceEpoch(dateData);
        } catch (e) {
          print('❌ Failed to parse $fieldName int: $dateData, error: $e');
        }
      }
      
      print('⚠️ Unknown date format for $fieldName: ${dateData.runtimeType} - $dateData, using current date');
      return DateTime.now();
    }

    return LeaveRequest(
      id: documentId,
      employeeId: map['employeeId'] ?? '',
      empCode: map['empCode'] ?? '',
      employeeName: map['employeeName'] ?? '',
      employeeDepartment: map['employeeDepartment'] ?? map['department'] ?? '',
      leaveType: LeaveTypeExtension.fromString(map['leaveType'] ?? 'sick'),
      startDate: parseDate(map['startDate'], 'startDate'),
      endDate: parseDate(map['endDate'], 'endDate'),
      totalDays: map['totalDays'] ?? 0,
      daysToDeduct: map['daysToDeduct'] ?? map['totalDays'] ?? 0, // Fallback to totalDays if not present
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      submittedDate: (map['submittedDate'] ?? map['appliedAt'] ?? map['appliedDate']) != null 
          ? parseDate(map['submittedDate'] ?? map['appliedAt'] ?? map['appliedDate'], 'submittedDate') 
          : null,
      approvedBy: map['approvedBy'],
      approvedDate: (map['approvedAt'] ?? map['approvedDate']) != null 
          ? parseDate(map['approvedAt'] ?? map['approvedDate'], 'approvedDate') 
          : null,
      rejectedBy: map['rejectedBy'],
      rejectedDate: map['rejectedDate'] != null 
          ? parseDate(map['rejectedDate'], 'rejectedDate') 
          : null,
      rejectionReason: map['rejectionReason'],
      adminComments: map['adminComments'],
      processedDate: map['processedDate'] != null 
          ? parseDate(map['processedDate'], 'processedDate') 
          : null,
      medicalCertificate: map['medicalCertificate'],
      leaveBalance: map['leaveBalance'] != null 
          ? Map<String, dynamic>.from(map['leaveBalance']) 
          : null,
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'empCode': empCode,
      'employeeName': employeeName,
      'employeeDepartment': employeeDepartment,
      'leaveType': leaveType.value,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalDays': totalDays,
      'daysToDeduct': daysToDeduct,
      'reason': reason,
      'status': status,
      'submittedDate': submittedDate != null ? Timestamp.fromDate(submittedDate!) : null,
      'approvedBy': approvedBy,
      'approvedDate': approvedDate != null ? Timestamp.fromDate(approvedDate!) : null,
      'rejectedBy': rejectedBy,
      'rejectedDate': rejectedDate != null ? Timestamp.fromDate(rejectedDate!) : null,
      'rejectionReason': rejectionReason,
      'adminComments': adminComments,
      'processedDate': processedDate != null ? Timestamp.fromDate(processedDate!) : null,
      'medicalCertificate': medicalCertificate,
      'leaveBalance': leaveBalance,
    };
  }

  /// Copy with method for updates
  LeaveRequest copyWith({
    String? id,
    String? userId,
    String? empCode,
    String? employeeName,
    String? employeeDepartment,
    LeaveType? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    int? totalDays,
    int? daysToDeduct,
    String? reason,
    String? status,
    DateTime? submittedDate,
    String? approvedBy,
    DateTime? approvedDate,
    String? rejectedBy,
    DateTime? rejectedDate,
    String? rejectionReason,
    String? adminComments,
    DateTime? processedDate,
    String? medicalCertificate,
    Map<String, dynamic>? leaveBalance,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      employeeId: userId ?? this.employeeId,
      empCode: empCode ?? this.empCode,
      employeeName: employeeName ?? this.employeeName,
      employeeDepartment: employeeDepartment ?? this.employeeDepartment,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      daysToDeduct: daysToDeduct ?? this.daysToDeduct,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      submittedDate: submittedDate ?? this.submittedDate,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedDate: approvedDate ?? this.approvedDate,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedDate: rejectedDate ?? this.rejectedDate,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      adminComments: adminComments ?? this.adminComments,
      processedDate: processedDate ?? this.processedDate,
      medicalCertificate: medicalCertificate ?? this.medicalCertificate,
      leaveBalance: leaveBalance ?? this.leaveBalance,
    );
  }
}

/// Model for leave application validation result
class LeaveValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? warningMessage; // For policy warnings like CL monthly limits
  final LeaveType? suggestedLeaveType; // For when PL 1-day becomes CL

  LeaveValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warningMessage,
    this.suggestedLeaveType,
  });
}

/// Model for leave balance calculation
class LeaveBalanceInfo {
  final Map<String, double> accrued; // Total accrued till date
  final Map<String, int> used; // Total used this year
  final Map<String, double> available; // Available balance
  final DateTime calculationDate;
  final DateTime joiningDate;
  final int monthsWorked;

  LeaveBalanceInfo({
    required this.accrued,
    required this.used,
    required this.available,
    required this.calculationDate,
    required this.joiningDate,
    required this.monthsWorked,
  });

  /// Calculate monthly accrued balance based on joining date
  static LeaveBalanceInfo calculateBalance({
    required DateTime joiningDate,
    required Map<String, int> currentBalance,
    required DateTime calculationDate,
  }) {
    // Calculate months worked
    final monthsWorked = (calculationDate.year - joiningDate.year) * 12 + 
                        calculationDate.month - joiningDate.month + 1;
    
    // Each leave type accrues 0.5 days per month
    final accrualPerMonth = 0.5;
    
    Map<String, double> accrued = {};
    Map<String, double> available = {};
    Map<String, int> used = {};
    
    for (LeaveType type in LeaveType.values) {
      // Optional Holiday has different max than other leaves (3 per year, no monthly accrual)
      final maxLeave = type == LeaveType.optionalHoliday ? 3.0 : 6.0;
      final totalAccrued = type == LeaveType.optionalHoliday 
          ? 3.0  // Fixed 3 optional holidays per year
          : (monthsWorked * accrualPerMonth).clamp(0.0, maxLeave);
      final currentAvailable = currentBalance[type.balanceKey] ?? (type == LeaveType.optionalHoliday ? 3 : 6);
      
      accrued[type.balanceKey] = totalAccrued;
      available[type.balanceKey] = currentAvailable.toDouble();
      used[type.balanceKey] = (totalAccrued - currentAvailable).round().clamp(0, maxLeave.toInt());
    }
    
    return LeaveBalanceInfo(
      accrued: accrued,
      used: used,
      available: available,
      calculationDate: calculationDate,
      joiningDate: joiningDate,
      monthsWorked: monthsWorked,
    );
  }

  // Convenience getters for specific leave types
  double get sickLeave => available['sickLeave'] ?? 0.0;
  double get casualLeave => available['casualLeave'] ?? 0.0;
  double get paidLeave => available['paidLeave'] ?? 0.0;
  double get optionalHoliday => available['optionalHoliday'] ?? 0.0;
  
  double get totalBalance => sickLeave + casualLeave + paidLeave + optionalHoliday;
}

/// Optional Holiday model for admin-defined holidays
class OptionalHoliday {
  final String id;
  final String name;
  final String description;
  final DateTime date;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  OptionalHoliday({
    required this.id,
    required this.name,
    required this.description,
    required this.date,
    this.isActive = true,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'date': date.toIso8601String(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory OptionalHoliday.fromMap(Map<String, dynamic> map, String docId) {
    return OptionalHoliday(
      id: docId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      date: DateTime.parse(map['date']),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
      createdBy: map['createdBy'] ?? '',
    );
  }

  OptionalHoliday copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? date,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return OptionalHoliday(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      date: date ?? this.date,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool get isPastDate => date.isBefore(DateTime.now());
  bool get isToday => 
    date.year == DateTime.now().year &&
    date.month == DateTime.now().month &&
    date.day == DateTime.now().day;
}