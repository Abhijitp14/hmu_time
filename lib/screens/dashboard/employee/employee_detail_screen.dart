import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../admin/edit_employee_screen.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final AppUser employee;

  const EmployeeDetailScreen({Key? key, required this.employee})
    : super(key: key);

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late AppUser currentEmployee;

  @override
  void initState() {
    super.initState();
    currentEmployee = widget.employee;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          currentEmployee.displayName,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () async {
              final updatedEmployee = await Navigator.push<AppUser>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditEmployeeScreen(employee: currentEmployee),
                ),
              );

              // Update the state if employee was updated
              if (updatedEmployee != null) {
                setState(() {
                  currentEmployee = updatedEmployee;
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card with Profile
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF4A90E2).withOpacity(0.1),
                    child: Text(
                      currentEmployee.name.isNotEmpty
                          ? currentEmployee.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    currentEmployee.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Employee ID
                  Text(
                    'ID: ${currentEmployee.displayEmpCode}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Department
                  Text(
                    currentEmployee.displayDepartment,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: currentEmployee.isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: currentEmployee.isActive
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: currentEmployee.isActive
                                ? Colors.green
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentEmployee.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: currentEmployee.isActive
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Contact Information
            _buildInfoSection('Contact Information', [
              _buildInfoRow('Email', currentEmployee.email, Icons.email),
              if (currentEmployee.phoneNumber != null &&
                  currentEmployee.phoneNumber!.isNotEmpty)
                _buildInfoRow(
                  'Phone',
                  currentEmployee.phoneNumber!,
                  Icons.phone,
                ),
              if (currentEmployee.address != null &&
                  currentEmployee.address!.isNotEmpty)
                _buildInfoRow(
                  'Address',
                  currentEmployee.address!,
                  Icons.location_on,
                ),
            ]),

            // Work Information
            _buildInfoSection('Work Information', [
              _buildInfoRow(
                'Role',
                currentEmployee.role.toString().split('.').last.toUpperCase(),
                Icons.work,
              ),
              if (currentEmployee.designation != null &&
                  currentEmployee.designation!.isNotEmpty)
                _buildInfoRow(
                  'Designation',
                  currentEmployee.designation!,
                  Icons.badge,
                ),
              _buildInfoRow(
                'Department',
                currentEmployee.displayDepartment,
                Icons.business,
              ),
              _buildInfoRow(
                'Employment Type',
                currentEmployee.displayEmploymentType,
                Icons.work_history_outlined,
              ),
              _buildInfoRow(
                'Working Hours',
                currentEmployee.displayWorkingHours,
                Icons.access_time_outlined,
              ),
              if (currentEmployee.salary != null)
                _buildInfoRow(
                  'Salary',
                  currentEmployee.displaySalary,
                  Icons.currency_rupee_outlined,
                ),
              if (currentEmployee.companyName != null &&
                  currentEmployee.companyName!.isNotEmpty)
                _buildInfoRow(
                  'Company',
                  currentEmployee.displayCompanyName,
                  Icons.domain,
                ),
              if (currentEmployee.joiningDate != null)
                _buildInfoRow(
                  'Joining Date',
                  currentEmployee.displayJoiningDateFormatted,
                  Icons.calendar_today,
                ),
            ]),

            // Personal Information
            _buildInfoSection('Personal Information', [
              if (currentEmployee.dateOfBirth != null) ...[
                _buildInfoRow(
                  'Date of Birth',
                  _formatDate(currentEmployee.dateOfBirth!),
                  Icons.cake,
                ),
                _buildInfoRow(
                  'Age',
                  '${_calculateAge(currentEmployee.dateOfBirth!)} years old',
                  Icons.person,
                ),
              ] else ...[
                _buildInfoRow('Date of Birth', 'Not specified', Icons.cake),
              ],
            ]),

            // Leave Balance
            if (currentEmployee.leaveBalance.isNotEmpty)
              _buildLeaveBalanceSection(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4A90E2)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leave Balance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: currentEmployee.leaveBalance.entries.map((entry) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4A90E2).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatLeaveType(entry.key),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatLeaveType(String leaveType) {
    switch (leaveType.toLowerCase()) {
      case 'sickleave':
      case 'sick':
        return 'Sick Leave';
      case 'casualleave':
      case 'casual':
        return 'Casual Leave';
      case 'paidleave':
      case 'paid':
        // Keep for backward compatibility with old data
        return 'Paid Leave';
      case 'optionalholiday':
      case 'optional':
        return 'Optional Holiday';
      default:
        // Convert camelCase to readable format
        return leaveType.replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        );
    }
  }

  String _formatDate(DateTime date) {
    List<String> months = [
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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
