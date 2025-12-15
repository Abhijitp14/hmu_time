import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';

class EmployeeService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Create a new employee account
  Future<CreateEmployeeResult> createEmployee({
    required String name,
    required String email,
    required String empCode,
    required String department,
    String? designation,
    DateTime? joiningDate,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? address,
    int? sickLeave,
    int? casualLeave,
    int? paidLeave,
    int? optionalHoliday,
    String? employmentType,
    double? workingHours,
    double? salary,
    String? companyName,
  }) async {
    try {
      final callable = _functions.httpsCallable('createEmployee');

      final result = await callable.call({
        'name': name,
        'email': email,
        'empCode': empCode,
        'department': department,
        'designation': designation,
        'joiningDate': joiningDate?.toIso8601String(),
        'phoneNumber': phoneNumber,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'address': address,
        'role': 'employee', // Always create as employee role
        'employmentType': employmentType,
        'workingHours': workingHours,
        'salary': salary,
        'companyName': companyName,
        'leaveBalance': {
          'sickLeave': sickLeave ?? 6,
          'casualLeave': casualLeave ?? 6,
          'paidLeave': paidLeave ?? 6,
          'optionalHoliday': optionalHoliday ?? 3,
        },
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return CreateEmployeeResult(
          success: true,
          uid: data['uid'] as String?,
          tempPassword: data['tempPassword'] as String?,
          message: data['message'] as String?,
        );
      } else {
        return CreateEmployeeResult(
          success: false,
          error: data['error'] as String? ?? 'Unknown error occurred',
        );
      }
    } catch (e) {
      print('Error creating employee: $e');
      return CreateEmployeeResult(success: false, error: _getErrorMessage(e));
    }
  }

  /// Get list of employees (for Admin/HR/Manager)
  Future<List<Map<String, dynamic>>> getEmployees() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getEmployees');
      final result = await callable.call();

      if (result.data['success']) {
        final List<dynamic> employeesList = result.data['employees'];
        return employeesList.map((e) {
          // Safe conversion handling nested objects
          return _deepConvertMap(e);
        }).toList();
      } else {
        throw Exception(result.data['message'] ?? 'Failed to fetch employees');
      }
    } catch (e) {
      print('Error fetching employees: $e');
      throw Exception('Failed to fetch employees: $e');
    }
  }

  /// Recursively convert nested objects to proper Map<String, dynamic>
  Map<String, dynamic> _deepConvertMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.fromEntries(
        data.entries.map(
          (entry) =>
              MapEntry(entry.key.toString(), _deepConvertValue(entry.value)),
        ),
      );
    }
    throw ArgumentError('Expected Map but got ${data.runtimeType}');
  }

  /// Recursively convert values handling different types
  dynamic _deepConvertValue(dynamic value) {
    if (value is Map) {
      return _deepConvertMap(value);
    } else if (value is List) {
      return value.map(_deepConvertValue).toList();
    } else {
      return value;
    }
  }

  /// Get list of teammates (for all authenticated users with limited info)
  Future<List<Map<String, dynamic>>> getTeammates() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getTeammates');
      final result = await callable.call();

      if (result.data['success']) {
        final List<dynamic> teammatesList = result.data['employees'];
        return teammatesList.map((e) => _deepConvertMap(e)).toList();
      } else {
        throw Exception(result.data['message'] ?? 'Failed to fetch teammates');
      }
    } catch (e) {
      print('Error fetching teammates: $e');
      throw Exception('Failed to fetch teammates: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'getAdminUsers',
      );
      final result = await callable.call();

      if (result.data['success']) {
        final List<dynamic> adminUsersList = result.data['adminUsers'];
        return adminUsersList.map((e) => _deepConvertMap(e)).toList();
      } else {
        throw Exception(
          result.data['message'] ?? 'Failed to fetch admin users',
        );
      }
    } catch (e) {
      print('Error fetching admin users: $e');
      throw Exception('Failed to fetch admin users: $e');
    }
  }

  /// Update employee information
  Future<UpdateEmployeeResult> updateEmployee({
    required String uid,
    required String name,
    required String email,
    String? empCode,
    String? department,
    String? designation,
    DateTime? joiningDate,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? address,
    int? sickLeave,
    int? casualLeave,
    int? paidLeave,
    int? optionalHoliday,
    String? employmentType,
    double? workingHours,
    double? salary,
    String? companyName,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateEmployee');
      final result = await callable.call({
        'uid': uid,
        'name': name,
        'email': email,
        'empCode': empCode,
        'department': department,
        'designation': designation,
        'joiningDate': joiningDate?.toIso8601String(),
        'phoneNumber': phoneNumber,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'address': address,
        'employmentType': employmentType,
        'workingHours': workingHours,
        'salary': salary,
        'companyName': companyName,
        'leaveBalance': {
          'sickLeave': sickLeave,
          'casualLeave': casualLeave,
          'paidLeave': paidLeave,
          'optionalHoliday': optionalHoliday,
        },
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return UpdateEmployeeResult(success: true);
      } else {
        return UpdateEmployeeResult(
          success: false,
          error: data['error'] as String? ?? 'Unknown error occurred',
        );
      }
    } catch (e) {
      print('Error updating employee: $e');
      return UpdateEmployeeResult(success: false, error: _getErrorMessage(e));
    }
  }

  /// Delete employee
  Future<DeleteEmployeeResult> deleteEmployee({required String uid}) async {
    try {
      final callable = _functions.httpsCallable('deleteEmployee');
      final result = await callable.call({'uid': uid});

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return DeleteEmployeeResult(success: true);
      } else {
        return DeleteEmployeeResult(
          success: false,
          error: data['error'] as String? ?? 'Unknown error occurred',
        );
      }
    } catch (e) {
      print('Error deleting employee: $e');
      return DeleteEmployeeResult(success: false, error: _getErrorMessage(e));
    }
  }

  /// Update employee status (activate/deactivate)
  Future<UpdateEmployeeStatusResult> updateEmployeeStatus({
    required String uid,
    required bool isActive,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateEmployeeStatus');

      final result = await callable.call({'uid': uid, 'isActive': isActive});

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return UpdateEmployeeStatusResult(success: true);
      } else {
        return UpdateEmployeeStatusResult(
          success: false,
          error: data['error'] as String? ?? 'Failed to update employee status',
        );
      }
    } catch (e) {
      print('Error updating employee status: $e');
      return UpdateEmployeeStatusResult(
        success: false,
        error: _getErrorMessage(e),
      );
    }
  }

  /// Create a new HR/Manager user account
  Future<CreateEmployeeResult> createAdminUser({
    required String name,
    required String email,
    required String empCode,
    required String department,
    required String designation,
    required UserRole role,
    DateTime? joiningDate,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? address,
    String? employmentType,
    double? workingHours,
    int? sickLeave,
    int? casualLeave,
    int? paidLeave,
  }) async {
    try {
      final callable = _functions.httpsCallable('createEmployee');

      final result = await callable.call({
        'name': name,
        'email': email,
        'empCode': empCode,
        'department': department,
        'designation': designation,
        'joiningDate': joiningDate?.toIso8601String(),
        'phoneNumber': phoneNumber,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'address': address,
        'role': role.value, // Use the actual role (hr/manager)
        'employmentType': employmentType,
        'workingHours': workingHours,
        'leaveBalance': {
          'sickLeave': sickLeave ?? 6,
          'casualLeave': casualLeave ?? 6,
          'paidLeave': paidLeave ?? 6,
          'optionalHoliday': 3, // Add missing optional holiday balance
        },
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return CreateEmployeeResult(
          success: true,
          uid: data['uid'] as String?,
          tempPassword: data['tempPassword'] as String?,
          message: data['message'] as String?,
        );
      } else {
        return CreateEmployeeResult(
          success: false,
          error: data['error'] as String? ?? 'Unknown error occurred',
        );
      }
    } catch (e) {
      print('Error creating admin user: $e');
      return CreateEmployeeResult(success: false, error: _getErrorMessage(e));
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'You must be logged in to perform this action';
        case 'permission-denied':
          return 'You don\'t have permission to perform this action';
        case 'invalid-argument':
          return 'Invalid input provided';
        case 'already-exists':
          return 'Employee with this email or code already exists';
        case 'internal':
          return 'An internal error occurred. Please try again';
        default:
          return error.message ?? 'An error occurred';
      }
    }
    return error.toString();
  }
}

// Result classes
class CreateEmployeeResult {
  final bool success;
  final String? error;
  final String? uid;
  final String? tempPassword;
  final String? message;

  CreateEmployeeResult({
    required this.success,
    this.error,
    this.uid,
    this.tempPassword,
    this.message,
  });
}

class GetEmployeesResult {
  final bool success;
  final String? error;
  final List<AppUser> employees;

  GetEmployeesResult({
    required this.success,
    this.error,
    required this.employees,
  });
}

class UpdateEmployeeStatusResult {
  final bool success;
  final String? error;

  UpdateEmployeeStatusResult({required this.success, this.error});
}

class UpdateEmployeeResult {
  final bool success;
  final String? error;

  UpdateEmployeeResult({required this.success, this.error});
}

class DeleteEmployeeResult {
  final bool success;
  final String? error;

  DeleteEmployeeResult({required this.success, this.error});
}
