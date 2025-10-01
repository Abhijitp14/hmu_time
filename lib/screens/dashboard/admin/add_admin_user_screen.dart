import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/custom_widgets.dart';
import '../../../utils/validators.dart';
import '../../../services/employee_service.dart';
import '../../../models/user_model.dart';

class AddAdminUserScreen extends StatefulWidget {
  const AddAdminUserScreen({super.key});

  @override
  State<AddAdminUserScreen> createState() => _AddAdminUserScreenState();
}

class _AddAdminUserScreenState extends State<AddAdminUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _empCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _designationController = TextEditingController();
  final _addressController = TextEditingController();
  final _sickLeaveController = TextEditingController(text: '6');
  final _casualLeaveController = TextEditingController(text: '6');
  final _paidLeaveController = TextEditingController(text: '6');
  
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _selectedJoiningDate;
  DateTime? _selectedDateOfBirth;

  // Role options for admin users (HR and Manager only)
  final List<UserRole> _roles = [
    UserRole.hr,
    UserRole.manager,
  ];

  UserRole _selectedRole = UserRole.hr;

  @override
  void initState() {
    super.initState();
    // Set default designations based on role
    _updateDesignationForRole(_selectedRole);
  }

  void _updateDesignationForRole(UserRole role) {
    switch (role) {
      case UserRole.hr:
        _designationController.text = 'Human Resources Manager';
        break;
      case UserRole.manager:
        _designationController.text = 'Operations Manager';
        break;
      default:
        _designationController.text = '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _empCodeController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _addressController.dispose();
    _sickLeaveController.dispose();
    _casualLeaveController.dispose();
    _paidLeaveController.dispose();
    super.dispose();
  }

  Future<void> _createAdminUser() async {
    if (!_formKey.currentState!.validate()) return;



    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final employeeService = EmployeeService();
      
      final result = await employeeService.createAdminUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        empCode: _empCodeController.text.trim(),
        department: _selectedRole == UserRole.hr ? 'Human Resources' : 'Administration',
        designation: _designationController.text.trim(),
        role: _selectedRole,
        joiningDate: _selectedJoiningDate,
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        sickLeave: int.tryParse(_sickLeaveController.text) ?? 6,
        casualLeave: int.tryParse(_casualLeaveController.text) ?? 6,
        paidLeave: int.tryParse(_paidLeaveController.text) ?? 6,
      );

      if (!mounted) return;

      if (result.success) {
        // Store values before clearing form
        final userName = _nameController.text;
        final userEmail = _emailController.text;
        final userRole = _selectedRole.displayName;
        
        // Clear form after successful creation
        _clearForm();
        
        // Show password dialog to admin
        if (result.tempPassword != null) {
          _showPasswordDialog(result.tempPassword!, userName, userEmail, userRole);
        } else {
          // Show success message if no password returned
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userRole user $userName created successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Failed to create user';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error creating user: ${e.toString()}';
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
      lastDate: DateTime.now().add(const Duration(days: 365)), // Allow future dates up to 1 year
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

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _empCodeController.clear();
    _phoneController.clear();
    _addressController.clear();
    _sickLeaveController.text = '6';
    _casualLeaveController.text = '6';
    _paidLeaveController.text = '6';
    setState(() {
      _selectedRole = UserRole.hr;
      _selectedJoiningDate = null;
      _selectedDateOfBirth = null;
      _errorMessage = null;
    });
    _updateDesignationForRole(_selectedRole);
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.hr:
        return Icons.people;
      case UserRole.manager:
        return Icons.supervisor_account;
      default:
        return Icons.person;
    }
  }

  void _showPasswordDialog(String password, String userName, String userEmail, String userRole) {
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
                '$userRole User Created Successfully!',
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
              '$userRole "$userName" has been created successfully.',
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
                      'Please share this password securely with the $userRole. They will be required to change it on first login.',
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'User Details:',
              style: AppTextStyles.labelMedium,
            ),
            const SizedBox(height: 8),
            Text('• Email: $userEmail', style: AppTextStyles.bodySmall),
            Text('• Name: $userName', style: AppTextStyles.bodySmall),
            Text('• Role: $userRole', style: AppTextStyles.bodySmall),
            Text('• Must change password on first login', style: AppTextStyles.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
          'Add HR/Manager User',
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
              Text(
                'Create New HR/Manager Account',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 8),
              Text(
                'Fill in the user details to create their HR/Manager account',
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

              // Role Selection (First Field)
              Text('User Role', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.surface,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<UserRole>(
                    value: _selectedRole,
                    isExpanded: true,
                    onChanged: (UserRole? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRole = newValue;
                          _updateDesignationForRole(newValue);
                        });
                      }
                    },
                    items: _roles.map<DropdownMenuItem<UserRole>>((UserRole role) {
                      return DropdownMenuItem<UserRole>(
                        value: role,
                        child: Row(
                          children: [
                            Icon(
                              _getRoleIcon(role),
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(role.displayName, style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Full Name Field
              CustomTextField(
                controller: _nameController,
                labelText: 'Full Name',
                hintText: 'Enter full name',
                validator: Validators.name,
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 24),

              // Email Field
              CustomTextField(
                controller: _emailController,
                labelText: 'Email Address',
                hintText: 'Enter email address',
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                prefixIcon: Icons.email_outlined,
              ),
              const SizedBox(height: 24),

              // Employee Code Field
              CustomTextField(
                controller: _empCodeController,
                labelText: 'Employee Code',
                hintText: 'Enter unique employee code (e.g., HR001, MGR001)',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Employee code is required';
                  }
                  return null;
                },
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: 24),

              // Designation Field (Auto-filled based on role)
              CustomTextField(
                controller: _designationController,
                labelText: 'Designation',
                hintText: 'Job designation',
                prefixIcon: Icons.work_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Designation is required';
                  }
                  return null;
                },
              ),
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
                          icon: Icon(Icons.clear, color: AppColors.textSecondary),
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
                      Icon(
                        Icons.cake_outlined,
                        color: AppColors.textSecondary,
                      ),
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
                          icon: Icon(Icons.clear, color: AppColors.textSecondary),
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

              // Address Field
              CustomTextField(
                controller: _addressController,
                labelText: 'Address',
                hintText: 'Enter complete address',
                prefixIcon: Icons.location_on_outlined,
                maxLines: 3,
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
                        Icon(Icons.event_available_outlined, color: AppColors.primary),
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
                    
                    CustomTextField(
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
                    const SizedBox(height: 8),
                    Text(
                      'Default values are 6 for each leave type. Admin can modify these values.',
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
                          'Administrative Account',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will create an administrative account with the selected role (HR/Manager). A temporary password will be generated and displayed to you. The user will also receive a welcome email with their login credentials.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Create User Button
              CustomButton(
                text: 'Create ${_selectedRole.displayName} Account',
                onPressed: _createAdminUser,
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
