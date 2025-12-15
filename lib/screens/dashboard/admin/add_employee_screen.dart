import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/custom_widgets.dart';
import '../../../utils/validators.dart';
import '../../../services/employee_service.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _empCodeController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _designationController = TextEditingController();
  final _addressController = TextEditingController();
  final _sickLeaveController = TextEditingController(text: '6');
  final _casualLeaveController = TextEditingController(text: '6');
  final _paidLeaveController = TextEditingController(text: '6');
  final _optionalHolidayController = TextEditingController(text: '3');
  final _workingHoursController = TextEditingController(text: '8:00');
  final _salaryController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _selectedJoiningDate;
  DateTime? _selectedDateOfBirth;
  TimeOfDay? _selectedWorkingHours = const TimeOfDay(hour: 8, minute: 0);

  // Company options
  final List<String> _companies = [
    'Urban Acres Infomediatech Pvt. Ltd',
    'Media Guardians Pvt. Ltd.',
    'Ecorenew Homes & Buildings Infomedia Pvt. Ltd.',
  ];

  // Department options (you can customize these)
  final List<String> _departments = [
    'Production',
    'Human Resources',
    'Creatives',
    'Marketing',
    'Sales',
    'Operations',
    'Editorial',
    'IT',
    'Legal',
    'Administration',
  ];

  // Employment type options
  final List<String> _employmentTypes = [
    'Full Time',
    'Part Time',
    'Consultant',
  ];

  String? _selectedDepartment;
  String? _selectedEmploymentType;
  String? _selectedCompany;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _empCodeController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _addressController.dispose();
    _sickLeaveController.dispose();
    _casualLeaveController.dispose();
    _paidLeaveController.dispose();
    _optionalHolidayController.dispose();
    _workingHoursController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _createEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate working hours selection
    if (_selectedWorkingHours == null) {
      setState(() {
        _errorMessage = 'Please select working hours';
      });
      return;
    }

    // Validate department selection
    final department = _selectedDepartment ?? _departmentController.text.trim();
    if (department.isEmpty) {
      setState(() {
        _errorMessage =
            'Please select a department or enter a custom department';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final employeeService = EmployeeService();

      final result = await employeeService.createEmployee(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        empCode: _empCodeController.text.trim(),
        department: _selectedDepartment ?? _departmentController.text.trim(),
        designation: _designationController.text.trim().isEmpty
            ? null
            : _designationController.text.trim(),
        joiningDate: _selectedJoiningDate,
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        sickLeave: int.tryParse(_sickLeaveController.text) ?? 6,
        casualLeave: int.tryParse(_casualLeaveController.text) ?? 6,
        paidLeave: int.tryParse(_paidLeaveController.text) ?? 6,
        optionalHoliday: int.tryParse(_optionalHolidayController.text) ?? 3,
        employmentType: _selectedEmploymentType,
        workingHours: _selectedWorkingHours != null
            ? _selectedWorkingHours!.hour +
                  (_selectedWorkingHours!.minute / 60.0)
            : null,
        salary: double.tryParse(_salaryController.text.trim()),
        companyName: _selectedCompany,
      );

      if (!mounted) return;

      if (result.success) {
        // Store values before clearing form
        final employeeName = _nameController.text;
        final employeeEmail = _emailController.text;

        // Clear form after successful creation
        _clearForm();

        // Show password dialog to admin
        if (result.tempPassword != null) {
          _showPasswordDialog(
            result.tempPassword!,
            employeeName,
            employeeEmail,
          );
        } else {
          // Show success message if no password returned
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Employee $employeeName created successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Failed to create employee';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error creating employee: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectJoiningDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedJoiningDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ), // Allow future dates up to 1 year
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedJoiningDate) {
      setState(() {
        _selectedJoiningDate = picked;
      });
    }
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  Future<void> _selectWorkingHours(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.access_time_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Set Working Hours',
              style: AppTextStyles.h6.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select the daily working hours for this employee',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Use hours and minutes to specify working duration\n(e.g., 8:30 = 8 hours and 30 minutes per day)',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime:
                    _selectedWorkingHours ??
                    const TimeOfDay(hour: 8, minute: 0),
                helpText: 'Select Working Hours',
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                        surface: AppColors.surface,
                        onSurface: AppColors.textPrimary,
                      ),
                    ),
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    ),
                  );
                },
              );

              if (picked != null && picked != _selectedWorkingHours) {
                setState(() {
                  _selectedWorkingHours = picked;
                  _workingHoursController.text =
                      '${picked.hour}:${picked.minute.toString().padLeft(2, '0')}';
                });
              }
            },
            child: const Text('Select Time'),
          ),
        ],
      ),
    );
  }

  void _onEmploymentTypeChanged(String? value) {
    setState(() {
      _selectedEmploymentType = value;
      // Set default working hours based on employment type
      if (value == 'Full Time') {
        _selectedWorkingHours = const TimeOfDay(hour: 8, minute: 0);
        _workingHoursController.text = '8:00';
      } else if (value == 'Part Time') {
        _selectedWorkingHours = const TimeOfDay(hour: 5, minute: 0);
        _workingHoursController.text = '5:00';
      } else if (value == 'Consultant') {
        _selectedWorkingHours = const TimeOfDay(hour: 2, minute: 30);
        _workingHoursController.text = '2:30';
      }
    });
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _empCodeController.clear();
    _departmentController.clear();
    _phoneController.clear();
    _designationController.clear();
    _addressController.clear();
    _salaryController.clear();
    _sickLeaveController.text = '6';
    _casualLeaveController.text = '6';
    _paidLeaveController.text = '6';
    _optionalHolidayController.text = '3';
    _workingHoursController.text = '8:00';
    setState(() {
      _selectedDepartment = null;
      _selectedEmploymentType = null;
      _selectedCompany = null;
      _selectedJoiningDate = null;
      _selectedDateOfBirth = null;
      _selectedWorkingHours = const TimeOfDay(hour: 8, minute: 0);
      _errorMessage = null;
    });
  }

  void _showPasswordDialog(
    String password,
    String employeeName,
    String employeeEmail,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Employee Created Successfully!',
                style: AppTextStyles.h6.copyWith(color: Colors.green),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employee "$employeeName" has been created successfully.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Temporary Password:',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.borderLight),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            password,
                            style: AppTextStyles.h6.copyWith(
                              fontFamily: 'Courier',
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, color: AppColors.primary),
                          onPressed: () {
                            // Copy to clipboard
                            Clipboard.setData(ClipboardData(text: password));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please share this password securely with the employee. They will be required to change it on first login.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Employee Details:', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Text('• Email: $employeeEmail', style: AppTextStyles.bodySmall),
            Text('• Name: $employeeName', style: AppTextStyles.bodySmall),
            Text(
              '• Must change password on first login',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear form after successful creation - use the proper clear method
              _clearForm();
              // Return true to indicate successful creation
              Navigator.pop(context, true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Employee',
          style: AppTextStyles.h2.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create New Employee Account', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                'Fill in the employee details to create their account',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Full Name Field
              CustomTextField(
                controller: _nameController,
                labelText: 'Full Name',
                hintText: 'Enter employee full name',
                validator: Validators.name,
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 24),

              // Email Field
              CustomTextField(
                controller: _emailController,
                labelText: 'Email Address',
                hintText: 'Enter employee email',
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                prefixIcon: Icons.email_outlined,
              ),
              const SizedBox(height: 24),

              // Employee Code Field
              CustomTextField(
                controller: _empCodeController,
                labelText: 'Employee Code',
                hintText: 'Enter unique employee code (e.g., EMP001)',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Employee code is required';
                  }
                  // if (value.length < 2) {
                  //   return 'Employee code must be at least 3 characters';
                  // }
                  return null;
                },
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: 24),

              // Department Field
              Text('Department', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: InputDecoration(
                  hintText: 'Select department',
                  prefixIcon: Icon(
                    Icons.business_outlined,
                    color: AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                items: _departments.map((String department) {
                  return DropdownMenuItem<String>(
                    value: department,
                    child: Text(department),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedDepartment = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a department';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Or enter custom department:',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _departmentController,
                labelText: 'Custom Department',
                hintText: 'Enter custom department name',
                prefixIcon: Icons.business_outlined,
                enabled: _selectedDepartment == null,
              ),
              const SizedBox(height: 24),

              // Employment Type Field
              Text('Employment Type', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedEmploymentType,
                decoration: InputDecoration(
                  hintText: 'Select employment type',
                  prefixIcon: Icon(
                    Icons.work_history_outlined,
                    color: AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                items: _employmentTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: _onEmploymentTypeChanged,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select employment type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Working Hours Field
              Text('Working Hours per Day', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectWorkingHours(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          _selectedWorkingHours == null &&
                              _errorMessage?.contains('working hours') == true
                          ? Colors.red.shade300
                          : AppColors.borderLight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.surface,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedWorkingHours != null
                              ? '${_selectedWorkingHours!.hour}:${_selectedWorkingHours!.minute.toString().padLeft(2, '0')} hours/day'
                              : 'Select working hours',
                          style: _selectedWorkingHours != null
                              ? AppTextStyles.bodyMedium
                              : AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                        ),
                      ),
                      if (_selectedWorkingHours != null)
                        IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              // Reset to default 8:00 instead of null to avoid validation issues
                              _selectedWorkingHours = const TimeOfDay(
                                hour: 8,
                                minute: 0,
                              );
                              _workingHoursController.text = '8:00';
                            });
                          },
                        ),
                      Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (_selectedEmploymentType != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Default for $_selectedEmploymentType: ${_selectedEmploymentType == 'Full Time'
                        ? '8:00'
                        : _selectedEmploymentType == 'Part Time'
                        ? '5:00'
                        : '2:30'} hours',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Joining Date Field
              Text('Joining Date', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectJoiningDate(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.surface,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedJoiningDate != null
                              ? '${_selectedJoiningDate!.day}/${_selectedJoiningDate!.month}/${_selectedJoiningDate!.year}'
                              : 'Select joining date',
                          style: _selectedJoiningDate != null
                              ? AppTextStyles.bodyMedium
                              : AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                        ),
                      ),
                      if (_selectedJoiningDate != null)
                        IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedJoiningDate = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Phone Number Field
              CustomTextField(
                controller: _phoneController,
                labelText: 'Phone Number',
                hintText: 'Enter phone number',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (value.length < 10) {
                      return 'Phone number must be at least 10 digits';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Date of Birth Field
              Text('Date of Birth', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDateOfBirth(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.surface,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cake_outlined, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDateOfBirth != null
                              ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                              : 'Select date of birth',
                          style: _selectedDateOfBirth != null
                              ? AppTextStyles.bodyMedium
                              : AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                        ),
                      ),
                      if (_selectedDateOfBirth != null)
                        IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedDateOfBirth = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Designation Field
              CustomTextField(
                controller: _designationController,
                labelText: 'Designation',
                hintText: 'Enter job designation (e.g., Software Engineer)',
                prefixIcon: Icons.work_outline,
              ),
              const SizedBox(height: 24),

              // Address Field
              CustomTextField(
                controller: _addressController,
                labelText: 'Address',
                hintText: 'Enter complete address',
                prefixIcon: Icons.location_on_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Company Name Field
              Text('Company Name', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCompany,
                isExpanded: true, // Important: This fixes the overflow issue
                decoration: InputDecoration(
                  hintText: 'Select company',
                  prefixIcon: Icon(
                    Icons.business_center_outlined,
                    color: AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                items: _companies.map((String company) {
                  return DropdownMenuItem<String>(
                    value: company,
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        company,
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2, // Allow 2 lines for long company names
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedCompany = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a company';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Salary Field
              CustomTextField(
                controller: _salaryController,
                labelText: 'Monthly Salary (₹)',
                hintText: 'Enter monthly salary amount',
                prefixIcon: Icons.currency_rupee_outlined,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter salary amount';
                  }
                  final salary = double.tryParse(value.trim());
                  if (salary == null || salary < 0) {
                    return 'Please enter a valid salary amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Leave Balance Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_available_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Leave Balance',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _sickLeaveController,
                            labelText: 'Sick Leave',
                            hintText: '6',
                            prefixIcon: Icons.local_hospital_outlined,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final num = int.tryParse(value);
                                if (num == null || num < 0) {
                                  return 'Enter valid number';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomTextField(
                            controller: _casualLeaveController,
                            labelText: 'Casual Leave',
                            hintText: '6',
                            prefixIcon: Icons.beach_access_outlined,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final num = int.tryParse(value);
                                if (num == null || num < 0) {
                                  return 'Enter valid number';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _paidLeaveController,
                            labelText: 'Paid Leave',
                            hintText: '6',
                            prefixIcon: Icons.card_giftcard_outlined,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final num = int.tryParse(value);
                                if (num == null || num < 0) {
                                  return 'Enter valid number';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomTextField(
                            controller: _optionalHolidayController,
                            labelText: 'Optional Holiday',
                            hintText: '3',
                            prefixIcon: Icons.event_note_outlined,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final num = int.tryParse(value);
                                if (num == null || num < 0) {
                                  return 'Enter valid number';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Default values: Sick Leave (6), Casual Leave (6), Paid Leave (6), Optional Holidays (3). Admin can modify these values.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Role Information
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Employee Account',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will create an employee account with the specified details. A temporary password will be generated and displayed to you. The employee will also receive a welcome email with their login credentials.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Create Employee Button
              CustomButton(
                text: 'Create Employee Account',
                onPressed: _createEmployee,
                isLoading: _isLoading,
                type: ButtonType.primary,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
