import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  admin,
  hr,
  manager,
  employee,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.hr:
        return 'HR';
      case UserRole.manager:
        return 'Manager';
      case UserRole.employee:
        return 'Employee';
    }
  }

  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.hr:
        return 'hr';
      case UserRole.manager:
        return 'manager';
      case UserRole.employee:
        return 'employee';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'hr':
        return UserRole.hr;
      case 'manager':
        return UserRole.manager;
      case 'employee':
        return UserRole.employee;
      default:
        return UserRole.employee;
    }
  }
}

class AppUser {
  final String id;
  final String email;
  final String name;
  final String? designation;
  final UserRole role;
  final String? profileImage;
  final DateTime createdAt;
  final bool isActive;
  final String? department;
  final String? empCode; // Employee code - only for employees
  final DateTime? joiningDate; // Employee joining date - only for employees
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final String? address;
  final String? employmentType; // Full Time, Part Time, Consultant
  final double? workingHours; // Working hours per day
  final Map<String, int> leaveBalance;
  final String? fcmToken;  // Add this field

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.designation,
    required this.role,
    this.profileImage,
    required this.createdAt,
    this.isActive = true,
    this.department,
    this.empCode,
    this.joiningDate,
    this.phoneNumber,
    this.dateOfBirth,
    this.address,
    this.employmentType,
    this.workingHours,
    Map<String, int>? leaveBalance,
    this.fcmToken,  // Add this parameter
  }) : leaveBalance = leaveBalance ?? {
    'sickLeave': 6,
    'casualLeave': 6,
    'paidLeave': 6,
    'optionalHoliday': 3,
  };

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'designation': designation,
      'role': role.value,
      'profileImage': profileImage,
      'createdAt': Timestamp.fromDate(createdAt), // Use Firestore Timestamp
      'isActive': isActive,
      'department': department,
      'empCode': empCode,
      'joiningDate': joiningDate != null ? Timestamp.fromDate(joiningDate!) : null,
      'phoneNumber': phoneNumber,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'address': address,
      'employmentType': employmentType,
      'workingHours': workingHours,
      'leaveBalance': leaveBalance,
      'fcmToken': fcmToken,  // Add this line
    };
  }

  // Convert to JSON with ISO string for API calls
  Map<String, dynamic> toJsonWithIsoDate() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'designation': designation,
      'role': role.value,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'department': department,
      'empCode': empCode,
      'joiningDate': joiningDate?.toIso8601String(),
      'phoneNumber': phoneNumber,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'address': address,
      'employmentType': employmentType,
      'workingHours': workingHours,
      'leaveBalance': leaveBalance,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreatedAt;
    
    // Handle both Timestamp and String formats
    if (json['createdAt'] != null) {
      if (json['createdAt'] is String) {
        parsedCreatedAt = DateTime.parse(json['createdAt']);
      } else if (json['createdAt'] is Timestamp) {
        // Handle Firestore Timestamp
        parsedCreatedAt = (json['createdAt'] as Timestamp).toDate();
      } else {
        // Fallback for other types
        parsedCreatedAt = DateTime.now();
      }
    } else {
      parsedCreatedAt = DateTime.now();
    }

    // Handle joiningDate parsing
    DateTime? parsedJoiningDate;
    if (json['joiningDate'] != null) {
      if (json['joiningDate'] is String) {
        parsedJoiningDate = DateTime.parse(json['joiningDate']);
      } else if (json['joiningDate'] is Timestamp) {
        // Handle Firestore Timestamp
        parsedJoiningDate = (json['joiningDate'] as Timestamp).toDate();
      }
    }

    // Handle dateOfBirth parsing
    DateTime? parsedDateOfBirth;
    if (json['dateOfBirth'] != null) {
      if (json['dateOfBirth'] is String) {
        parsedDateOfBirth = DateTime.parse(json['dateOfBirth']);
      } else if (json['dateOfBirth'] is Timestamp) {
        // Handle Firestore Timestamp
        parsedDateOfBirth = (json['dateOfBirth'] as Timestamp).toDate();
      }
    }
    
    return AppUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      designation: json['designation'],
      role: UserRoleExtension.fromString(json['role'] ?? 'employee'),
      profileImage: json['profileImage'],
      createdAt: parsedCreatedAt,
      isActive: json['isActive'] ?? true,
      department: json['department'],
      empCode: json['empCode'],
      joiningDate: parsedJoiningDate,
      phoneNumber: json['phoneNumber'],
      dateOfBirth: parsedDateOfBirth,
      address: json['address'],
      employmentType: json['employmentType'],
      workingHours: json['workingHours']?.toDouble(),
      leaveBalance: json['leaveBalance'] != null 
        ? Map<String, int>.from(
            (json['leaveBalance'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, (value is double) ? value.round() : value as int)
            )
          )
        : {
            'sickLeave': json['sickLeave'] ?? 6,
            'casualLeave': json['casualLeave'] ?? 6,
            'paidLeave': json['paidLeave'] ?? 6, // Handle legacy data
            'optionalHoliday': json['optionalHoliday'] ?? json['optionalLeave'] ?? 3, // Handle legacy data
            'lwp': 0, // LWP has no balance limit
          },
      fcmToken: json['fcmToken'],  // Add this line
    );
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? designation,
    UserRole? role,
    String? profileImage,
    DateTime? createdAt,
    bool? isActive,
    String? department,
    String? empCode,
    DateTime? joiningDate,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? address,
    String? employmentType,
    double? workingHours,
    Map<String, int>? leaveBalance,
    String? fcmToken,  // Add this parameter
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      department: department ?? this.department,
      empCode: empCode ?? this.empCode,
      joiningDate: joiningDate ?? this.joiningDate,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      employmentType: employmentType ?? this.employmentType,
      workingHours: workingHours ?? this.workingHours,
      leaveBalance: leaveBalance ?? this.leaveBalance,
      fcmToken: fcmToken ?? this.fcmToken,  // Add this line
    );
  }

  // Helper methods
  bool get isEmployee => role == UserRole.employee;
  bool get isAdmin => role == UserRole.admin;
  bool get isHR => role == UserRole.hr;
  bool get isManager => role == UserRole.manager;
  
  bool get canManageEmployees => isAdmin || isHR;
  bool get canApproveLeave => isAdmin || isHR || isManager;
  bool get hasEmpCode => empCode != null && empCode!.isNotEmpty;
  bool get hasDepartment => department != null && department!.isNotEmpty;
  bool get hasJoiningDate => joiningDate != null;
  
  String get displayRole => role.displayName;
  String get displayName => name;
  String get displayEmpCode => empCode ?? 'N/A';
  String get displayDepartment => department ?? 'Unassigned';
  String get displayJoiningDate {
    if (joiningDate == null) return 'Not specified';
    return '${joiningDate!.day}/${joiningDate!.month}/${joiningDate!.year}';
  }
  
  String get displayJoiningDateFormatted {
    if (joiningDate == null) return 'Not specified';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${joiningDate!.day} ${months[joiningDate!.month - 1]} ${joiningDate!.year}';
  }
  
  String get displayDateOfBirth {
    if (dateOfBirth == null) return 'Not specified';
    return '${dateOfBirth!.day}/${dateOfBirth!.month}/${dateOfBirth!.year}';
  }
  
  String get displayDateOfBirthFormatted {
    if (dateOfBirth == null) return 'Not specified';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dateOfBirth!.day} ${months[dateOfBirth!.month - 1]} ${dateOfBirth!.year}';
  }
  
  String get displayPhoneNumber => phoneNumber ?? 'Not provided';
  String get displayAddress => address ?? 'Not provided';
  String get displayEmploymentType => employmentType ?? 'Not specified';
  String get displayWorkingHours {
    if (workingHours == null) return 'Not specified';
    final hours = workingHours!.floor();
    final minutes = ((workingHours! - hours) * 60).round();
    if (minutes == 0) {
      return '${hours}:00 hours/day';
    } else {
      return '${hours}:${minutes.toString().padLeft(2, '0')} hours/day';
    }
  }
  
  // Calculate age from date of birth
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month || 
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }
  
  String get displayAge {
    final ageValue = age;
    return ageValue != null ? '$ageValue years' : 'N/A';
  }
  
  // Leave balance getters
  int get sickLeave => leaveBalance['sickLeave'] ?? 6;
  int get casualLeave => leaveBalance['casualLeave'] ?? 6;
  int get paidLeave => leaveBalance['paidLeave']  ?? 6; // Handle legacy data
  int get optionalHoliday => leaveBalance['optionalHoliday'] ?? leaveBalance['optionalLeave'] ?? 3; // Handle legacy data
  
  // Total leave balance
  int get totalLeaveBalance => sickLeave + casualLeave + paidLeave + optionalHoliday;
  
  // Validation method for employee data
  bool get isEmployeeDataComplete {
    if (!isEmployee) return true; // Non-employees don't need empCode/department/joiningDate
    return hasEmpCode && hasDepartment && hasJoiningDate;
  }
  
  // Get initials for avatar
  String get initials {
    final names = name.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0].toUpperCase()}${names[1][0].toUpperCase()}';
    } else {
      return names[0][0].toUpperCase();
    }
  }
}
