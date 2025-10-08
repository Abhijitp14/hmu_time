import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_model.dart';
import '../models/user_model.dart';

class LeaveService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Apply for leave with policy validation
  Future<LeaveApplicationResult> applyForLeave({
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required AppUser user,
    String? medicalCertificate,
    String? selectedOptionalHolidayId, // New parameter for optional holidays
  }) async {
    try {
      print('📝 LeaveService: Starting leave application...');
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Validate leave eligibility and policy rules
      final validation = await _validateLeaveRequest(
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        user: user,
        selectedOptionalHolidayId: selectedOptionalHolidayId,
      );

      if (!validation.isValid) {
        return LeaveApplicationResult(
          success: false,
          error: validation.errorMessage!,
          suggestedLeaveType: validation.suggestedLeaveType,
        );
      }

      final totalDays = LeaveRequest.calculateLeaveDays(startDate, endDate);
      final finalLeaveType = validation.suggestedLeaveType ?? leaveType;
      
      // Calculate days to deduct from balance based on leave type policy
      final daysToDeduct = LeaveRequest.calculateLeaveDeduction(startDate, endDate, finalLeaveType);
      
      print('📊 LeaveService: Total days: $totalDays, Days to deduct: $daysToDeduct (Leave type: ${finalLeaveType.value})');
      print('📤 LeaveService: Calling Firebase Function for leave application...');
      final callable = _functions.httpsCallable('applyForLeave');
      
      final requestData = {
        'leaveType': finalLeaveType.value,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'totalDays': totalDays, // Keep for display/record purposes
        'daysToDeduct': daysToDeduct, // New field for balance deduction
        'reason': reason,
        'medicalCertificate': medicalCertificate,
        'selectedOptionalHolidayId': selectedOptionalHolidayId,
      };
      
      print('📤 LeaveService: Request data: $requestData');
      final result = await callable.call(requestData);
      
      print('📥 LeaveService: Received response: ${result.data}');
      
      return LeaveApplicationResult.fromMap(result.data);
    } on FirebaseFunctionsException catch (e) {
      print('❌ LeaveService: Firebase Functions Error: ${e.code} - ${e.message}');
      return LeaveApplicationResult(
        success: false,
        error: e.message ?? 'Failed to apply for leave',
      );
    } catch (e) {
      print('❌ LeaveService: General error: $e');
      return LeaveApplicationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Approve a leave request
  Future<bool> approveLeaveRequest({
    required String empCode,
    required String leaveType,
    required String requestId,
    String? comments,
  }) async {
    try {
      print('🟢 LeaveService: Approving leave request $requestId for employee $empCode');
      
      final callable = _functions.httpsCallable('approveLeaveRequest');
      final result = await callable.call({
        'empCode': empCode,
        'leaveType': leaveType,
        'requestId': requestId,
        'comments': comments,
      });
      
      if (result.data['success'] == true) {
        print('✅ LeaveService: Leave request approved successfully');
        return true;
      } else {
        throw Exception(result.data['message'] ?? 'Failed to approve leave request');
      }
    } catch (e) {
      print('❌ LeaveService: Error approving leave request: $e');
      throw Exception('Failed to approve leave request: $e');
    }
  }

  /// Reject a leave request
  Future<bool> rejectLeaveRequest({
    required String empCode,
    required String leaveType,
    required String requestId,
    required String reason,
  }) async {
    try {
      print('🔴 LeaveService: Rejecting leave request $requestId for employee $empCode');
      
      final callable = _functions.httpsCallable('rejectLeaveRequest');
      final result = await callable.call({
        'empCode': empCode,
        'leaveType': leaveType,
        'requestId': requestId,
        'reason': reason,
      });
      
      if (result.data['success'] == true) {
        print('✅ LeaveService: Leave request rejected successfully');
        return true;
      } else {
        throw Exception(result.data['message'] ?? 'Failed to reject leave request');
      }
    } catch (e) {
      print('❌ LeaveService: Error rejecting leave request: $e');
      throw Exception('Failed to reject leave request: $e');
    }
  }

  /// Update leave status to completed (for leaves that have ended)
  Future<bool> updateLeaveStatusToCompleted({
    required String empCode,
    required String leaveType,
    required String requestId,
  }) async {
    try {
      print('📝 LeaveService: Updating leave status to completed $requestId for employee $empCode');
      
      final callable = _functions.httpsCallable('updateLeaveStatus');
      final result = await callable.call({
        'empCode': empCode,
        'leaveType': leaveType,
        'requestId': requestId,
      });
      
      if (result.data['success'] == true) {
        print('✅ LeaveService: Leave status updated to completed successfully');
        return true;
      } else {
        throw Exception(result.data['message'] ?? 'Failed to update leave status');
      }
    } catch (e) {
      print('❌ LeaveService: Error updating leave status: $e');
      throw Exception('Failed to update leave status: $e');
    }
  }

  /// Get all employees for filtering
  Future<List<Map<String, String>>> getAllEmployees() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': (data['empCode'] ?? doc.id).toString(),  // Use empCode as ID for filtering
          'name': (data['name'] ?? 'Unknown').toString(),
          'department': (data['department'] ?? 'N/A').toString(),
          'email': (data['email'] ?? '').toString(),
          'empCode': (data['empCode'] ?? '').toString(),
        };
      }).toList();
    } catch (e) {
      print('Error getting all employees: $e');
      return [];
    }
  }

  /// Get employee's leave requests
  Future<List<LeaveRequest>> getMyLeaveRequests() async {
    try {
      print('🔍 LeaveService: Fetching leave requests...');
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final callable = _functions.httpsCallable('getMyLeaveRequests');
      final result = await callable.call();
      
      if (result.data['success'] == true) {
        final List<dynamic> requestsData = result.data['requests'] ?? [];
        
        return requestsData
            .map((data) {
              // Create a copy of the data with the corrected leaveType
              final Map<String, dynamic> requestMap = Map<String, dynamic>.from(data['data']);
              // Override with the corrected leaveType from the top level
              requestMap['leaveType'] = data['leaveType'];
              
              return LeaveRequest.fromMap(requestMap, data['id']);
            })
            .toList();
      } else {
        throw Exception(result.data['message'] ?? 'Failed to fetch leave requests');
      }
    } catch (e) {
      print('❌ LeaveService: Error fetching leave requests: $e');
      throw Exception('Failed to fetch leave requests: $e');
    }
  }

  /// Check if user has active (pending or approved) SL or CL requests
  Future<Map<LeaveType, bool>> checkActiveLeaveRestrictions() async {
    try {
      print('🔍 LeaveService: Checking active leave restrictions...');
      
      final leaveRequests = await getMyLeaveRequests();
      
      // Check for active SL and CL requests (pending or approved status)
      bool hasPendingOrApprovedSL = leaveRequests.any((request) =>
          request.leaveType == LeaveType.sick &&
          (request.status == 'pending' || request.status == 'approved'));
          
      // Check for monthly SL usage (one SL per month rule)
      // Only count SL that are not cancelled or rejected
      final currentMonth = DateTime.now().month;
      final currentYear = DateTime.now().year;
      bool hasMonthlySLUsed = leaveRequests.any((request) =>
          request.leaveType == LeaveType.sick &&
          request.startDate.month == currentMonth &&
          request.startDate.year == currentYear &&
          request.status != 'cancelled' &&
          request.status != 'rejected');
          
      bool hasPendingOrApprovedCL = leaveRequests.any((request) =>
          request.leaveType == LeaveType.casual &&
          (request.status == 'pending' || request.status == 'approved'));
      
      // Check for monthly CL usage (one CL per month rule)
      // Only count CL that are not cancelled or rejected
      bool hasMonthlyClUsed = leaveRequests.any((request) =>
          request.leaveType == LeaveType.casual &&
          request.startDate.month == currentMonth &&
          request.startDate.year == currentYear &&
          request.status != 'cancelled' &&
          request.status != 'rejected');
          
      bool hasPendingOrApprovedPL = leaveRequests.any((request) =>
          request.leaveType == LeaveType.paid &&
          (request.status == 'pending' || request.status == 'approved'));
      
      // Check for monthly PL usage (one PL per month rule)
      // Only count PL that are not cancelled or rejected
      bool hasMonthlyPlUsed = leaveRequests.any((request) =>
          request.leaveType == LeaveType.paid &&
          request.startDate.month == currentMonth &&
          request.startDate.year == currentYear &&
          request.status != 'cancelled' &&
          request.status != 'rejected');
      
      // SL is blocked if there's either an active request OR monthly limit reached
      bool slBlocked = hasPendingOrApprovedSL || hasMonthlySLUsed;
      
      // CL is blocked if there's either an active request OR monthly limit reached
      bool clBlocked = hasPendingOrApprovedCL || hasMonthlyClUsed;
      
      // PL is blocked if there's either an active request OR monthly limit reached
      bool plBlocked = hasPendingOrApprovedPL || hasMonthlyPlUsed;
      
      print('🚫 LeaveService: SL pending/approved: $hasPendingOrApprovedSL, monthly used: $hasMonthlySLUsed, total blocked: $slBlocked');
      print('🚫 LeaveService: CL pending/approved: $hasPendingOrApprovedCL, monthly used: $hasMonthlyClUsed, total blocked: $clBlocked');
      print('🚫 LeaveService: PL pending/approved: $hasPendingOrApprovedPL, monthly used: $hasMonthlyPlUsed, total blocked: $plBlocked');
      
      return {
        LeaveType.sick: slBlocked,
        LeaveType.casual: clBlocked,
        LeaveType.paid: plBlocked, // PL is now blocked based on monthly usage
        LeaveType.optionalHoliday: false, // OH is never blocked
        LeaveType.lwp: false, // LWP is never blocked
      };
    } catch (e) {
      print('❌ LeaveService: Error checking active restrictions: $e');
      // In case of error, don't block any leave types
      return {
        LeaveType.sick: false,
        LeaveType.casual: false,
        LeaveType.paid: false,
        LeaveType.optionalHoliday: false,
        LeaveType.lwp: false,
      };
    }
  }

  /// Get available optional holidays
  Future<List<OptionalHoliday>> getAvailableOptionalHolidays() async {
    try {
      final result = await _functions.httpsCallable('getOptionalHolidays').call();
      
      if (result.data != null && result.data is Map && result.data['holidays'] != null) {
        final holidaysList = result.data['holidays'] as List;
        // Convert the holidays to OptionalHoliday objects
        return holidaysList.map<OptionalHoliday>((holiday) {
          final holidayMap = Map<String, dynamic>.from(holiday as Map);
          final holidayData = Map<String, dynamic>.from(holidayMap['data'] as Map);
          
          // Handle Firestore Timestamp or string date conversion
          DateTime holidayDate;
          if (holidayData['date'] is Map && holidayData['date']['_seconds'] != null) {
            // Firestore Timestamp format - handle IST timezone properly
            final dateMap = Map<String, dynamic>.from(holidayData['date'] as Map);
            final seconds = dateMap['_seconds'] as int;
            final nanoseconds = dateMap['_nanoseconds'] as int? ?? 0;
            
            // Create datetime from timestamp and ensure it's treated as IST date
            final utcDateTime = DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + (nanoseconds / 1000000).round(),
              isUtc: true
            );
            
            // Add IST offset (5.5 hours) to get the correct local date
            holidayDate = utcDateTime.add(Duration(hours: 5, minutes: 30));
          } else if (holidayData['date'] is String) {
            // ISO string format
            holidayDate = DateTime.parse(holidayData['date']);
          } else {
            // Fallback to current date
            holidayDate = DateTime.now();
          }
          
          // Handle createdAt timestamp
          DateTime createdAt;
          if (holidayData['createdAt'] is Map && holidayData['createdAt']['_seconds'] != null) {
            final createdAtMap = Map<String, dynamic>.from(holidayData['createdAt'] as Map);
            final seconds = createdAtMap['_seconds'] as int;
            createdAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          } else {
            createdAt = DateTime.now();
          }
          
          // Create a proper map for OptionalHoliday.fromMap
          final holidayMapForParsing = {
            'name': holidayData['name'] as String,
            'description': holidayData['description'] as String? ?? '',
            'date': holidayDate.toIso8601String(),
            'isActive': true,
            'createdAt': createdAt.toIso8601String(),
            'createdBy': 'admin',
          };
          
          return OptionalHoliday.fromMap(holidayMapForParsing, holidayMap['id'] as String);
        }).where((holiday) {
          // Only show upcoming holidays (today and future dates)
          final today = DateTime.now();
          final holidayDateOnly = DateTime(holiday.date.year, holiday.date.month, holiday.date.day);
          final todayDateOnly = DateTime(today.year, today.month, today.day);
          return !holidayDateOnly.isBefore(todayDateOnly);
        }).toList();
      } else {
        print('⚠️ LeaveService: No holidays found in response or wrong format');
        return [];
      }
    } catch (e) {
      print('❌ LeaveService: Error fetching optional holidays: $e');
      return [];
    }
  }

  /// Cancel a pending leave request
  Future<bool> cancelLeaveRequest(String requestId, String leaveType) async {
    try {
      print('❌ LeaveService: Cancelling leave request: $requestId (type: $leaveType)');
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final callable = _functions.httpsCallable('cancelLeaveRequest');
      final result = await callable.call({
        'requestId': requestId,
        'leaveType': leaveType,
      });
      
      print('📥 LeaveService: Cancel response: ${result.data}');
      
      return result.data['success'] == true;
    } catch (e) {
      print('❌ LeaveService: Error cancelling leave request: $e');
      return false;
    }
  }

  /// Main validation router - delegates to specific leave type validators
  Future<LeaveValidationResult> _validateLeaveRequest({
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required AppUser user,
    String? selectedOptionalHolidayId,
  }) async {
    print('✅ LeaveService: Validating leave request for ${leaveType.displayName}...');
    
    // Route to appropriate validator based on leave type
    switch (leaveType) {
      case LeaveType.sick:
        return await _validateSickLeave(startDate, endDate, user);
      case LeaveType.casual:
        return await _validateCasualLeave(startDate, endDate, user);
      case LeaveType.paid:
        return await _validatePaidLeave(startDate, endDate, user);
      case LeaveType.optionalHoliday:
        return await _validateOptionalHoliday(startDate, endDate, user, selectedOptionalHolidayId);
      case LeaveType.lwp:
        return await _validateLwpLeave(startDate, endDate, user);
      case LeaveType.officialLeave:
        return await _validateOfficialLeave(startDate, endDate, user);
    }
  }

  /// Validate Sick Leave (SL) application
  Future<LeaveValidationResult> _validateSickLeave(DateTime startDate, DateTime endDate, AppUser user) async {
    print('🏥 LeaveService: Validating Sick Leave...');
    
    // Check for active SL restrictions
    final restrictions = await checkActiveLeaveRestrictions();
    if (restrictions[LeaveType.sick] == true) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'You have an active SL request. Cancel or wait for approval/rejection to apply again.',
      );
    }
    
    // Basic date validation
    if (startDate.isAfter(endDate)) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Start date cannot be after end date',
      );
    }

    // Calculate leave days
    final totalDays = LeaveRequest.calculateLeaveDays(startDate, endDate);
    if (totalDays == 0) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Leave request must be for at least one working day',
      );
    }

    // Check balance (SL always deducts 1 regardless of duration)
    final currentBalance = user.leaveBalance[LeaveType.sick.balanceKey] ?? 0;
    if (currentBalance < 1) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Insufficient Sick Leave balance. Available: $currentBalance, Required: 1',
      );
    }

    // Medical certificate reminder for SL > 2 days
    if (totalDays > 2) {
      print('💊 Note: Medical certificate required for Sick Leave > 2 days');
    }

    return LeaveValidationResult(isValid: true);
  }

  /// Validate Casual Leave (CL) application
  Future<LeaveValidationResult> _validateCasualLeave(DateTime startDate, DateTime endDate, AppUser user) async {
    print('🚶 LeaveService: Validating Casual Leave...');
    
    // Check for active CL restrictions
    final restrictions = await checkActiveLeaveRestrictions();
    if (restrictions[LeaveType.casual] == true) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'You have an active CL request. Cancel or wait for approval/rejection to apply again.',
      );
    }
    
    // Check service period eligibility (6 months required)
    final joiningDate = user.joiningDate;
    if (joiningDate == null) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Joining date not found. Please contact HR.',
      );
    }

    final monthsWorked = _calculateMonthsWorked(joiningDate, DateTime.now());
    if (monthsWorked < 6) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Casual Leave can only be used after 6 months of service',
      );
    }
    
    // Basic date validation
    if (!LeaveRequest.isValidDateRange(startDate, endDate)) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Cannot apply for leave in the past',
      );
    }

    if (startDate.isAfter(endDate)) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Start date cannot be after end date',
      );
    }

    // Calculate leave days
    final totalDays = LeaveRequest.calculateLeaveDays(startDate, endDate);
    if (totalDays == 0) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Leave request must be for at least one working day',
      );
    }

    // CL policy: Monthly limit validation will be handled by Firebase Functions
    if (totalDays > 1) {
      return LeaveValidationResult(
        isValid: true,
        warningMessage: 'Only 1 Casual Leave per month is allowed. 1 CL will be deducted, remaining ${totalDays - 1} day(s) will be marked as absent if you don\'t punch in at office.',
      );
    }

    return LeaveValidationResult(isValid: true);
  }

  /// Validate Paid Leave (PL) application  
  Future<LeaveValidationResult> _validatePaidLeave(DateTime startDate, DateTime endDate, AppUser user) async {
    print('💼 LeaveService: Validating Paid Leave...');
    
    // Check service period eligibility (6 months required)
    final joiningDate = user.joiningDate;
    if (joiningDate == null) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Joining date not found. Please contact HR.',
      );
    }

    final monthsWorked = _calculateMonthsWorked(joiningDate, DateTime.now());
    if (monthsWorked < 6) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Paid Leave can only be used after 6 months of service',
      );
    }
    
    // Basic date validation
    if (!LeaveRequest.isValidDateRange(startDate, endDate)) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Cannot apply for leave in the past',
      );
    }

    if (startDate.isAfter(endDate)) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Start date cannot be after end date',
      );
    }

    // Calculate leave days
    final totalDays = LeaveRequest.calculateLeaveDays(startDate, endDate);
    if (totalDays == 0) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Leave request must be for at least one working day',
      );
    }

    // PL minimum 2 days policy
    if (totalDays == 1) {
      // Convert 1-day PL to CL if balance available
      final casualBalance = user.casualLeave;
      
      if (casualBalance >= 1) {
        return LeaveValidationResult(
          isValid: true,
          suggestedLeaveType: LeaveType.casual,
          warningMessage: 'Paid Leave requires minimum 2 days. Converting your 1-day request to Casual Leave.',
        );
      } else {
        return LeaveValidationResult(
          isValid: false,
          errorMessage: 'Paid Leave requires minimum 2 days per application. Cannot convert to Casual Leave due to insufficient CL balance.',
        );
      }
    }

    // Check if applying for more days than available balance
    final currentBalance = user.leaveBalance[LeaveType.paid.balanceKey] ?? 0;
    if (totalDays > currentBalance) {
      return LeaveValidationResult(
        isValid: true,
        warningMessage: 'Requesting $totalDays days but only $currentBalance days available in balance. Extra ${totalDays - currentBalance} day(s) will be marked as absent if you don\'t punch in at office.',
      );
    }

    return LeaveValidationResult(isValid: true);
  }

  /// Validate Optional Holiday (OH) application
  Future<LeaveValidationResult> _validateOptionalHoliday(DateTime startDate, DateTime endDate, AppUser user, String? selectedOptionalHolidayId) async {
    print('🎉 LeaveService: Validating Optional Holiday...');
    
    // Basic date validation
    if (!LeaveRequest.isValidDateRange(startDate, endDate)) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Cannot apply for leave in the past',
      );
    }

    if (startDate.isAfter(endDate)) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Start date cannot be after end date',
      );
    }

    // Calculate leave days
    final totalDays = LeaveRequest.calculateLeaveDays(startDate, endDate);
    
    // Optional Holiday must be single day
    if (totalDays != 1) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Optional Holiday can only be applied for single days',
      );
    }
    
    // Must select a specific holiday
    if (selectedOptionalHolidayId == null) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Please select a specific optional holiday from the available list',
      );
    }

    // Check balance
    final currentBalance = user.leaveBalance[LeaveType.optionalHoliday.balanceKey] ?? 0;
    if (currentBalance < 1) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Insufficient Optional Holiday balance. Available: $currentBalance, Required: 1',
      );
    }

    // Additional validation would check if the selected holiday date matches the request date
    // This will be implemented in the Firebase function
    
    return LeaveValidationResult(isValid: true);
  }

  /// Validate Leave Without Pay (LWP) application
  Future<LeaveValidationResult> _validateLwpLeave(DateTime startDate, DateTime endDate, AppUser user) async {
    print('💰 LeaveService: Validating Leave Without Pay...');
    
    // Basic date validation
    if (!LeaveRequest.isValidDateRange(startDate, endDate)) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Cannot apply for leave in the past',
      );
    }

    if (startDate.isAfter(endDate)) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Start date cannot be after end date',
      );
    }

    // Calculate leave days
    final totalDays = LeaveRequest.calculateLeaveDays(startDate, endDate);
    if (totalDays == 0) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Leave request must be for at least one working day',
      );
    }

    // LWP has no balance restrictions - it's unlimited
    // No service period requirements - can be used from day one
    // No monthly limits - employees can apply multiple times
    // LWP is always valid as long as basic validations pass
    
    return LeaveValidationResult(
      isValid: true,
      warningMessage: 'This is Leave Without Pay - no salary will be paid for the requested period.',
    );
  }

  /// Validate Official Leave application
  Future<LeaveValidationResult> _validateOfficialLeave(DateTime startDate, DateTime endDate, AppUser user) async {
    print('🏢 LeaveService: Validating Official Leave...');
    
    // Basic date validation
    if (!LeaveRequest.isValidDateRange(startDate, endDate)) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Cannot apply for leave in the past',
      );
    }

    if (startDate.isAfter(endDate)) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Start date cannot be after end date',
      );
    }

    // Calculate leave days
    final totalDays = LeaveRequest.calculateLeaveDays(startDate, endDate);
    if (totalDays == 0) {
      return LeaveValidationResult(
        isValid: false,
        errorMessage: 'Leave request must be for at least one working day',
      );
    }

    // Official Leave characteristics:
    // - No balance restrictions - it's unlimited like LWP
    // - No service period requirements - can be used from day one  
    // - No monthly limits - employees can apply multiple times
    // - Requires approval (unlike LWP which is auto-approved)
    // - For office work outside office premises
    
    return LeaveValidationResult(
      isValid: true,
      warningMessage: 'This leave is for official work outside office premises and requires manager approval.',
    );
  }

  /// Common helper method for service period calculation
  int _calculateMonthsWorked(DateTime joiningDate, DateTime currentDate) {
    return (currentDate.year - joiningDate.year) * 12 + 
           currentDate.month - joiningDate.month;
  }





  /// Get monthly leave usage for policy validation


  /// Get leave balance information with policy calculations
  LeaveBalanceInfo getLeaveBalanceInfo(AppUser user) {
    if (user.joiningDate == null) {
      throw Exception('Joining date not available');
    }

    return LeaveBalanceInfo.calculateBalance(
      joiningDate: user.joiningDate!,
      currentBalance: user.leaveBalance,
      calculationDate: DateTime.now(),
    );
  }

  /// Get all employee leave requests for admin/HR/manager
  Future<AdminLeaveRequestsResult> getAllEmployeeLeaveRequests({
    String? status,
    String? employeeId,
    String? leaveType,
    String? startDate,
    String? endDate,
    int limit = 100,
  }) async {
    try {
      print('🔍 LeaveService: Fetching all employee leave requests...');
      
      final callable = _functions.httpsCallable('getAllEmployeeLeaveRequests');
      final result = await callable.call({
        'status': status,
        'employeeId': employeeId,
        'leaveType': leaveType,
        'startDate': startDate,
        'endDate': endDate,
        'limit': limit,
      });
      
      print('📥 LeaveService: Received response: ${result.data}');
      
      if (result.data['success'] == true) {
        final List<dynamic> requestsData = result.data['requests'] ?? [];
        
        final requests = requestsData
            .map((data) {
              try {
                // Properly cast the data to Map<String, dynamic>
                final Map<String, dynamic> requestData = Map<String, dynamic>.from(data as Map);
                return AdminLeaveRequest.fromMap(requestData);
              } catch (e) {
                print('❌ Error parsing admin leave request: $e');
                print('❌ Data type: ${data.runtimeType}');
                print('❌ Data content: $data');
                return null;
              }
            })
            .where((request) => request != null)
            .cast<AdminLeaveRequest>()
            .toList();

        return AdminLeaveRequestsResult(
          success: true,
          requests: requests,
          totalFound: result.data['totalFound'] ?? 0,
          returned: result.data['returned'] ?? 0,
          hasMore: result.data['hasMore'] ?? false,
        );
      } else {
        throw Exception(result.data['message'] ?? 'Failed to fetch leave requests');
      }
    } catch (e) {
      print('❌ LeaveService: Error fetching all employee leave requests: $e');
      return AdminLeaveRequestsResult(
        success: false,
        error: e.toString(),
        requests: [],
      );
    }
  }

  /// Get leave statistics for admin dashboard
  Future<Map<String, int>> getLeaveStatistics() async {
    try {
      final result = await getAllEmployeeLeaveRequests(limit: 1000);
      
      if (result.success) {
        final Map<String, int> stats = {
          'total': result.requests.length,
          'pending': 0,
          'approved': 0,
          'rejected': 0,
        };
        
        for (final request in result.requests) {
          final status = request.status.toLowerCase();
          if (stats.containsKey(status)) {
            stats[status] = (stats[status] ?? 0) + 1;
          }
        }
        
        return stats;
      }
      
      return {
        'total': 0,
        'pending': 0,
        'approved': 0,
        'rejected': 0,
      };
    } catch (e) {
      print('Error getting leave statistics: $e');
      return {
        'total': 0,
        'pending': 0,
        'approved': 0,
        'rejected': 0,
      };
    }
  }


      
}

/// Result model for leave application
class LeaveApplicationResult {
  final bool success;
  final String? error;
  final String? leaveRequestId;
  final String? message;
  final LeaveType? suggestedLeaveType;

  LeaveApplicationResult({
    required this.success,
    this.error,
    this.leaveRequestId,
    this.message,
    this.suggestedLeaveType,
  });

  factory LeaveApplicationResult.fromMap(Map<String, dynamic> map) {
    return LeaveApplicationResult(
      success: map['success'] ?? false,
      error: map['error'],
      leaveRequestId: map['leaveRequestId'],
      message: map['message'],
      suggestedLeaveType: map['suggestedLeaveType'] != null 
          ? LeaveTypeExtension.fromString(map['suggestedLeaveType'])
          : null,
    );
  }
}



/// Admin leave request model with additional employee information
class AdminLeaveRequest {
  final String id;
  final String empCode;
  final String employeeName;
  final String employeeEmail;
  final String department;
  final String designation;
  final String leaveType;
  final String status;
  final String reason;
  final String startDate;
  final String endDate;
  final int totalDays;
  final int daysToDeduct;
  final String? submittedDate;
  final String? approvedDate;
  final String? approvedBy;
  final String? rejectedDate;
  final String? rejectedBy;
  final String? rejectionReason;
  final String? medicalCertificate;
  final String? selectedOptionalHolidayId;
  final String? createdAt;
  final String? updatedAt;

  AdminLeaveRequest({
    required this.id,
    required this.empCode,
    required this.employeeName,
    required this.employeeEmail,
    required this.department,
    required this.designation,
    required this.leaveType,
    required this.status,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.daysToDeduct,
    this.submittedDate,
    this.approvedDate,
    this.approvedBy,
    this.rejectedDate,
    this.rejectedBy,
    this.rejectionReason,
    this.medicalCertificate,
    this.selectedOptionalHolidayId,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminLeaveRequest.fromMap(Map<String, dynamic> map) {
    return AdminLeaveRequest(
      id: map['id'] ?? '',
      empCode: map['empCode'] ?? '',
      employeeName: map['employeeName'] ?? '',
      employeeEmail: map['employeeEmail'] ?? '',
      department: map['department'] ?? '',
      designation: map['designation'] ?? '',
      leaveType: map['leaveType'] ?? '',
      status: map['status'] ?? '',
      reason: map['reason'] ?? '',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
      totalDays: map['totalDays'] ?? 0,
      daysToDeduct: map['daysToDeduct'] ?? 0,
      submittedDate: map['submittedDate'],
      approvedDate: map['approvedDate'],
      approvedBy: map['approvedBy'],
      rejectedDate: map['rejectedDate'],
      rejectedBy: map['rejectedBy'],
      rejectionReason: map['rejectionReason'],
      medicalCertificate: map['medicalCertificate'],
      selectedOptionalHolidayId: map['selectedOptionalHolidayId'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  String get leaveTypeDisplayName {
    switch (leaveType) {
      case 'SL':
        return 'Sick Leave';
      case 'CL':
        return 'Casual Leave';
      case 'PL':
        return 'Paid Leave';
      case 'OH':
        return 'Optional Holiday';
      case 'LWP':
        return 'Leave Without Pay';
      default:
        return leaveType;
    }
  }
}

/// Result model for admin leave requests query
class AdminLeaveRequestsResult {
  final bool success;
  final List<AdminLeaveRequest> requests;
  final int totalFound;
  final int returned;
  final bool hasMore;
  final String? error;

  AdminLeaveRequestsResult({
    required this.success,
    required this.requests,
    this.totalFound = 0,
    this.returned = 0,
    this.hasMore = false,
    this.error,
  });
}