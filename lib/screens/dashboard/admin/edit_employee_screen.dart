import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/custom_widgets.dart';
import '../../../utils/validators.dart';
import '../../../models/user_model.dart';
import '../../../services/employee_service.dart';

class EditEmployeeScreen extends StatefulWidget {
  final AppUser employee;

  const EditEmployeeScreen({Key? key, required this.employee})
    : super(key: key);

  @override
  State<EditEmployeeScreen> createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _empCodeController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _designationController = TextEditingController();
  final _addressController = TextEditingController();
  final _sickLeaveController = TextEditingController();
  final _casualLeaveController = TextEditingController();
  final _paidLeaveController = TextEditingController();
  final _optionalHolidayController = TextEditingController();
  final _workingHoursController = TextEditingController();
  final _salaryController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _selectedJoiningDate;
  DateTime? _selectedDateOfBirth;
  TimeOfDay? _selectedWorkingHours;

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
  void initState() {
    super.initState();
    _initializeFromEmployee();
  }

  void _initializeFromEmployee() {
    final employee = widget.employee;

    // Initialize controllers with existing data
    _nameController.text = employee.name;
    _emailController.text = employee.email;
    _empCodeController.text = employee.empCode ?? '';
    _phoneController.text = employee.phoneNumber ?? '';
    _designationController.text = employee.designation ?? '';
    _addressController.text = employee.address ?? '';
    _sickLeaveController.text = employee.sickLeave.toString();
    _casualLeaveController.text = employee.casualLeave.toString();
    _paidLeaveController.text = employee.paidLeave.toString();
    _optionalHolidayController.text = employee.optionalHoliday.toString();

    // Set dates
    _selectedJoiningDate = employee.joiningDate;
    _selectedDateOfBirth = employee.dateOfBirth;

    // Set department
    if (_departments.contains(employee.department)) {
      _selectedDepartment = employee.department;
    } else {
      _selectedDepartment = null;
      _departmentController.text = employee.department ?? '';
    }

    // Set employment type
    _selectedEmploymentType = employee.employmentType;

    // Set working hours
    if (employee.workingHours != null) {
      final hours = employee.workingHours!.floor();
      final minutes = ((employee.workingHours! - hours) * 60).round();
      _selectedWorkingHours = TimeOfDay(hour: hours, minute: minutes);
      _workingHoursController.text =
          '${hours}:${minutes.toString().padLeft(2, '0')}';
    } else {
      _selectedWorkingHours = const TimeOfDay(hour: 8, minute: 0);
      _workingHoursController.text = '8:00';
    }

    // Set salary
    _salaryController.text = employee.salary?.toString() ?? '';

    // Set company
    if (_companies.contains(employee.companyName)) {
      _selectedCompany = employee.companyName;
    } else {
      _selectedCompany = null;
    }
  }

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

  Future<void> _updateEmployee() async {
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

      final result = await employeeService.updateEmployee(
        uid: widget.employee.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        empCode: _empCodeController.text.trim(),
        department: _selectedDepartment ?? _departmentController.text.trim(),
        designation: _designationController.text.trim().isNotEmpty
            ? _designationController.text.trim()
            : null,
        joiningDate: _selectedJoiningDate,
        phoneNumber: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        dateOfBirth: _selectedDateOfBirth,
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        sickLeave: int.tryParse(_sickLeaveController.text) ?? 6,
        casualLeave: int.tryParse(_casualLeaveController.text) ?? 6,
        paidLeave: int.tryParse(_paidLeaveController.text) ?? 6,
        optionalHoliday: int.tryParse(_optionalHolidayController.text) ?? 3,
        employmentType: _selectedEmploymentType,
        workingHours: _selectedWorkingHours != null
            ? _selectedWorkingHours!.hour +
                  (_selectedWorkingHours!.minute / 60.0)
            : null,
        salary: double.tryParse(_salaryController.text),
        companyName: _selectedCompany,
      );

      if (!mounted) return;

      if (result.success) {
        // Create updated employee object with new data
        final updatedEmployee = widget.employee.copyWith(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().toLowerCase(),
          empCode: _empCodeController.text.trim(),
          department: _selectedDepartment ?? _departmentController.text.trim(),
          designation: _designationController.text.trim().isNotEmpty
              ? _designationController.text.trim()
              : null,
          joiningDate: _selectedJoiningDate,
          phoneNumber: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          dateOfBirth: _selectedDateOfBirth,
          address: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
          leaveBalance: {
            'sickLeave': int.tryParse(_sickLeaveController.text) ?? 6,
            'casualLeave': int.tryParse(_casualLeaveController.text) ?? 6,
            'paidLeave': int.tryParse(_paidLeaveController.text) ?? 6,
            'optionalHoliday':
                int.tryParse(_optionalHolidayController.text) ?? 3,
          },
          employmentType: _selectedEmploymentType,
          workingHours: _selectedWorkingHours != null
              ? _selectedWorkingHours!.hour +
                    (_selectedWorkingHours!.minute / 60.0)
              : null,
          salary: double.tryParse(_salaryController.text),
          companyName: _selectedCompany,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Employee ${_nameController.text} updated successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(
          context,
          updatedEmployee,
        ); // Return the updated employee object
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Failed to update employee';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error updating employee: ${e.toString()}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Employee',
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
              Text('Edit Employee Details', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                'Update employee information and settings',
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

              // Email Field (Read-only)
              CustomTextField(
                controller: _emailController,
                labelText: 'Email Address',
                hintText: 'Employee email address',
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                prefixIcon: Icons.email_outlined,
                enabled: false,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Email address cannot be changed after account creation',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.orange.shade700,
                  ),
                ),
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
                  if (value != null && value.trim().isNotEmpty) {
                    final salary = double.tryParse(value.trim());
                    if (salary == null || salary < 0) {
                      return 'Please enter a valid salary amount';
                    }
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
                            prefixIcon: Icons.event_outlined,
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
                      'Admin can modify leave balances as needed.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Update Information
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
                          'Update Employee Information',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Changes will be saved immediately and will be reflected in the employee\'s profile. The employee will be notified of any updates made to their information.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Update Employee Button
              CustomButton(
                text: 'Update Employee Information',
                onPressed: _updateEmployee,
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
