import 'dart:core';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_model.dart';
import '../../models/user_model.dart';
import '../../services/leave_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/leave_widgets/sick_leave_widget.dart';
import '../../widgets/leave_widgets/casual_leave_widget.dart';
import '../../widgets/leave_widgets/paid_leave_widget.dart';
import '../../widgets/leave_widgets/optional_holiday_widget.dart';
import 'edit_leave_request_screen.dart';

class LeaveApplicationScreen extends StatefulWidget {
  final AppUser user;

  const LeaveApplicationScreen({
    super.key,
    required this.user,
  });

  @override
  State<LeaveApplicationScreen> createState() => _LeaveApplicationScreenState();
}

class _LeaveApplicationScreenState extends State<LeaveApplicationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final LeaveService _leaveService = LeaveService();
  final AuthService _authService = AuthService();
  
  // Tab controller
  late TabController _tabController;
  
  // My Leaves tab variables
  List<LeaveRequest>? _myLeaveRequests;
  bool _loadingLeaves = false;
  
  LeaveType _selectedLeaveType = LeaveType.sick;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  

  
  // Sick Leave specific variables
  bool _isSingleDaySL = true; // true for single day, false for multiple days
  
  // Optional Holiday specific variables
  String? _selectedOptionalHolidayId;
  
  String? _calculatedDays;
  String? _balanceInfo;
  String? _policyWarning;
  
  // Current balance tracking (can be refreshed)
  late Map<String, int> _currentLeaveBalance;
  
  // Track which leave request is being cancelled (to show loading indicator)
  String? _cancellingLeaveId;
  
  // Track active leave restrictions (SL/CL blocked by pending/approved requests)
  Map<LeaveType, bool> _activeLeaveRestrictions = {};
  bool _loadingRestrictions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentLeaveBalance = Map<String, int>.from(widget.user.leaveBalance);
    _updateBalanceInfo();
    _loadMyLeaves();
    _loadActiveLeaveRestrictions();
  }
  


  /// Load active leave restrictions (SL/CL blocked by pending/approved requests)
  Future<void> _loadActiveLeaveRestrictions() async {
    if (_loadingRestrictions) return;
    
    setState(() {
      _loadingRestrictions = true;
    });
    
    try {
      final restrictions = await _leaveService.checkActiveLeaveRestrictions();
      if (mounted) {
        setState(() {
          _activeLeaveRestrictions = restrictions;
        });
      }
    } catch (e) {
      print('❌ Failed to load active leave restrictions: $e');
      // In case of error, don't block any leave types
      if (mounted) {
        setState(() {
          _activeLeaveRestrictions = {
            LeaveType.sick: false,
            LeaveType.casual: false,
            LeaveType.paid: false,
            LeaveType.optionalHoliday: false,
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRestrictions = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.add_circle_outline),
              text: 'Apply Leave',
            ),
            Tab(
              icon: Icon(Icons.list_alt),
              text: 'My Leaves',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApplyLeaveTab(),
          _buildMyLeavesTab(),
        ],
      ),
    );
  }

  Widget _buildApplyLeaveTab() {
    return RefreshIndicator(
      onRefresh: _onRefreshApplyLeave,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works even when content doesn't fill screen
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLeaveBalanceCard(),
              const SizedBox(height: 20),
              _buildLeaveTypeSelection(),
              const SizedBox(height: 20),
              _buildDateSelection(),
              const SizedBox(height: 16),
              _buildCalculatedDaysInfo(),
              const SizedBox(height: 20),
              _buildReasonField(),
              const SizedBox(height: 16),
            _buildPolicyWarning(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildLeaveBalanceCard() {
    // Create a temporary user object with updated balance for display
    final userWithUpdatedBalance = AppUser(
      id: widget.user.id,
      name: widget.user.name,
      email: widget.user.email,
      role: widget.user.role,
      createdAt: widget.user.createdAt,
      empCode: widget.user.empCode,
      department: widget.user.department,
      designation: widget.user.designation,
      joiningDate: widget.user.joiningDate,
      phoneNumber: widget.user.phoneNumber,
      dateOfBirth: widget.user.dateOfBirth,
      address: widget.user.address,
      leaveBalance: _currentLeaveBalance, // Use the updated balance
      employmentType: widget.user.employmentType,
      workingHours: widget.user.workingHours,
      profileImage: widget.user.profileImage,
      isActive: widget.user.isActive,
    );
    
    final balance = _leaveService.getLeaveBalanceInfo(userWithUpdatedBalance);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave Balance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBalanceItem(
                  'Sick Leave',
                  balance.sickLeave.toString(),
                  Colors.red.shade100,
                  Colors.red.shade700,
                ),
                _buildBalanceItem(
                  'Casual Leave',
                  balance.casualLeave.toString(),
                  Colors.blue.shade100,
                  Colors.blue.shade700,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBalanceItem(
                  'Paid Leave',
                  balance.paidLeave.toString(),
                  Colors.green.shade100,
                  Colors.green.shade700,
                ),
                _buildBalanceItem(
                  'Optional Holiday',
                  balance.optionalHoliday.toString(),
                  Colors.purple.shade100,
                  Colors.purple.shade700,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tenure: ${balance.monthsWorked} months',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.refresh,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Pull down to refresh balance',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(String label, String value, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveTypeSelection() {
    final availableTypes = LeaveType.values.where((type) => _isLeaveTypeEligible(type)).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leave Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...LeaveType.values.map((type) => _buildLeaveTypeRadio(type)),
        if (availableTypes.isEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All leave types are currently unavailable. Please use Leave Without Pay (LWP) for future absences or contact HR.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLeaveTypeRadio(LeaveType type) {
    final balance = _currentLeaveBalance[type.balanceKey] ?? 0;
    final isEligible = _isLeaveTypeEligible(type);
    
    return RadioListTile<LeaveType>(
      value: type,
      groupValue: _selectedLeaveType,
      onChanged: isEligible ? (value) {
        setState(() {
          _selectedLeaveType = value!;
          // Reset dates and selection when changing leave type
          _startDate = null;
          _endDate = null;
          // Reset SL specific settings
          if (value != LeaveType.sick) {
            _isSingleDaySL = true; // Reset to default
          }
          // Reset OH specific settings
          if (value != LeaveType.optionalHoliday) {
            _selectedOptionalHolidayId = null; // Reset holiday selection
          }
          _updateCalculatedDays();
          _updatePolicyWarning();
          _updateBalanceInfo(); // Refresh balance when leave type changes
        });

      } : null,
      title: Row(
        children: [
          Expanded(
            child: Text(
              type.displayName,
              style: TextStyle(
                color: isEligible ? null : Colors.grey,
              ),
            ),
          ),
          Text(
            '$balance days',
            style: TextStyle(
              fontSize: 12,
              color: isEligible ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
      subtitle: !isEligible ? Text(
        _getIneligibilityReason(type),
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ) : null,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }

  bool _isLeaveTypeEligible(LeaveType type) {
    if (widget.user.joiningDate == null) return false;
    
    final monthsWorked = _calculateMonthsWorked(
      widget.user.joiningDate!, 
      DateTime.now()
    );
    
    // SL and Optional Holidays usable from day one, CL and PL after 6 months
    if ((type == LeaveType.casual || type == LeaveType.paid) && 
        monthsWorked < 6) {
      return false;
    }
    
    // Check for active leave restrictions (SL/CL blocked by pending/approved requests)
    if (_activeLeaveRestrictions[type] == true) {
      return false;
    }
    
    // Check for zero balance - block applications when balance is 0
    final balance = _currentLeaveBalance[type.balanceKey] ?? 0;
    if (balance <= 0) {
      return false;
    }
    
    return true;
  }

  String _getIneligibilityReason(LeaveType type) {
    if (widget.user.joiningDate == null) {
      return 'Joining date not available';
    }
    
    final monthsWorked = _calculateMonthsWorked(
      widget.user.joiningDate!, 
      DateTime.now()
    );
    
    if ((type == LeaveType.casual || type == LeaveType.paid) && 
        monthsWorked < 6) {
      return 'Available after 6 months (${6 - monthsWorked} months remaining)';
    }
    
    // Check for active leave restrictions
    if (_activeLeaveRestrictions[type] == true) {
      if (type == LeaveType.sick) {
        return 'SL not available: Either you have an active request or already used monthly quota (1 SL per month).';
      } else if (type == LeaveType.casual) {
        return 'CL not available: Either you have an active request or already used monthly quota (1 CL per month).';
      } else if (type == LeaveType.paid) {
        return 'PL not available: Either you have an active request or already used monthly quota (1 PL per month).';
      } else {
        final leaveTypeName = type == LeaveType.paid ? 'PL' : 'Leave';
        return 'You have an active $leaveTypeName request. Cancel or wait for approval/rejection to apply again.';
      }
    }
    
    // Check for zero balance
    final balance = _currentLeaveBalance[type.balanceKey] ?? 0;
    if (balance <= 0) {
      return 'No ${type.displayName} balance available. Please use Leave Without Pay (LWP) for future absences.';
    }
    
    return '';
  }

  int _calculateMonthsWorked(DateTime joiningDate, DateTime currentDate) {
    return (currentDate.year - joiningDate.year) * 12 + 
           currentDate.month - joiningDate.month;
  }

  Widget _buildDateSelection() {
    switch (_selectedLeaveType) {
      case LeaveType.sick:
        return SickLeaveWidget(
          user: widget.user,
          startDate: _startDate,
          endDate: _endDate,
          isSingleDay: _isSingleDaySL,
          onSingleDayChanged: (value) {
            setState(() {
              _isSingleDaySL = value;
              if (_isSingleDaySL) {
                _endDate = _startDate;
              } else {
                _endDate = null;
              }
              _updateCalculatedDays();
              _updatePolicyWarning();
            });
          },
          onStartDateChanged: (date) {
            setState(() {
              _startDate = date;
              if (_isSingleDaySL || (_endDate != null && _endDate!.isBefore(date))) {
                _endDate = _isSingleDaySL ? date : null;
              }
              _updateCalculatedDays();
              _updatePolicyWarning();
            });
          },
          onEndDateChanged: (date) {
            setState(() {
              _endDate = date;
              _updateCalculatedDays();
              _updatePolicyWarning();
            });
          },
        );
      case LeaveType.casual:
        return CasualLeaveWidget(
          user: widget.user,
          startDate: _startDate,
          endDate: _endDate,
          onStartDateChanged: (date) {
            setState(() {
              _startDate = date;
              if (_endDate != null && _endDate!.isBefore(date)) {
                _endDate = null;
              }
              _updateCalculatedDays();
              _updatePolicyWarning();
            });
          },
          onEndDateChanged: (date) {
            setState(() {
              _endDate = date;
              _updateCalculatedDays();
              _updatePolicyWarning();
            });
          },
        );
      case LeaveType.paid:
        return PaidLeaveWidget(
          user: widget.user,
          startDate: _startDate,
          endDate: _endDate,
          onStartDateChanged: (date) {
            setState(() {
              _startDate = date;
              if (_endDate != null && _endDate!.isBefore(date)) {
                _endDate = null;
              }
              _updateCalculatedDays();
              _updatePolicyWarning();
            });
          },
          onEndDateChanged: (date) {
            setState(() {
              _endDate = date;
              _updateCalculatedDays();
              _updatePolicyWarning();
            });
          },
        );
      case LeaveType.optionalHoliday:
        return OptionalHolidayWidget(
          user: widget.user,
          startDate: _startDate,
          selectedOptionalHolidayId: _selectedOptionalHolidayId,
          onStartDateChanged: (date) {
            setState(() {
              _startDate = date;
              _endDate = date; // OH is always single day
              _updateCalculatedDays();
              _updatePolicyWarning();
            });
          },
          onHolidaySelected: (holidayId) {
            setState(() {
              _selectedOptionalHolidayId = holidayId;
            });
          },
        );
    }
  }



  Widget _buildCalculatedDaysInfo() {
    if (_calculatedDays == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _calculatedDays!,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (_balanceInfo != null) ...[
            const SizedBox(height: 4),
            Text(
              _balanceInfo!,
              style: TextStyle(
                color: Colors.blue.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Medical Certificate Note for Sick Leave
        if (_selectedLeaveType == LeaveType.sick && 
            _startDate != null && _endDate != null) ...[
          Builder(
            builder: (context) {
              final days = LeaveRequest.calculateLeaveDays(_startDate!, _endDate!);
              if (days > 2) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.medical_services, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: Medical certificate required for Sick Leave exceeding 2 days. Please bring it to the office.',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        
        Text(
          _selectedLeaveType == LeaveType.optionalHoliday 
              ? 'Reason for Leave (Optional)'
              : 'Reason for Leave',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: _selectedLeaveType == LeaveType.optionalHoliday 
                ? 'Enter reason (optional)...' 
                : 'Enter reason for your leave request...',
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            // Trigger rebuild to update submit button state
            setState(() {});
          },
          validator: (value) {
            // For optional holidays, reason is not required
            if (_selectedLeaveType == LeaveType.optionalHoliday) {
              return null;
            }
            
            if (value == null || value.trim().isEmpty) {
              return 'Please enter reason for leave';
            }
            if (value.trim().length < 10) {
              return 'Please provide a detailed reason (minimum 10 characters)';
            }
            return null;
          },
        ),
      ],
    );
  }



  Widget _buildPolicyWarning() {
    if (_policyWarning == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_outlined, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _policyWarning!,
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _canSubmit() ? _submitLeaveRequest : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text(
              'Submit Leave Request',
              style: TextStyle(fontSize: 16),
            ),
    );
  }

  bool _canSubmit() {
    // First check if selected leave type is eligible (not blocked by zero balance or other restrictions)
    if (!_isLeaveTypeEligible(_selectedLeaveType)) {
      return false;
    }
    
    bool hasValidDates = _startDate != null && _endDate != null;
    
    // For optional holidays, reason is not required but holiday must be selected
    if (_selectedLeaveType == LeaveType.optionalHoliday) {
      return !_isLoading && hasValidDates && _selectedOptionalHolidayId != null;
    }
    
    // For PL, check minimum 2 days requirement
    if (_selectedLeaveType == LeaveType.paid && hasValidDates) {
      final totalDays = LeaveRequest.calculateLeaveDays(_startDate!, _endDate!);
      if (totalDays < 2) {
        return false; // PL requires minimum 2 days
      }
    }
    
    // For other leave types, reason is required
    return !_isLoading &&
           hasValidDates &&
           _reasonController.text.trim().isNotEmpty;
  }

  void _updateCalculatedDays() {
    if (_startDate != null && _endDate != null) {
      final days = LeaveRequest.calculateLeaveDays(_startDate!, _endDate!);
      final daysToDeduct = LeaveRequest.calculateLeaveDeduction(_startDate!, _endDate!, _selectedLeaveType);
      final balance = _currentLeaveBalance[_selectedLeaveType.balanceKey] ?? 0;
      
      String calculatedInfo;
      String balanceInfo;
      String? policyWarning;
      
      // Calculate actual deduction based on policy
      int actualDeduction = daysToDeduct;
      
      if (_selectedLeaveType == LeaveType.casual) {
        // CL Policy: Always deduct only 1 day regardless of request duration
        actualDeduction = 1;
        if (days > 1) {
          calculatedInfo = 'Total Leave Days: $days (Only 1 CL deducted, ${days - 1} days marked absent)';
          policyWarning = 'Casual Leave Policy: Only 1 CL per month allowed. Extra days will be marked as absent if you don\'t punch in at office.';
        } else {
          calculatedInfo = 'Total Leave Days: $days';
          policyWarning = 'Casual Leave Policy: 1 per month limit. Usable after 6 months of service.';
        }
        balanceInfo = 'Remaining Casual Leave: ${balance - actualDeduction} days';
      } else if (_selectedLeaveType == LeaveType.paid) {
        // PL Policy: Minimum 2 days, excess days marked absent
        if (days == 1) {
          calculatedInfo = 'Total Leave Days: $days';
          policyWarning = 'Paid Leave requires minimum 2 days. Consider using Casual Leave for single day requests.';
        } else if (days > balance) {
          calculatedInfo = 'Total Leave Days: $days (${balance} PL deducted, ${days - balance} days marked absent)';
          policyWarning = 'Requesting more days than available balance. Extra days will be marked as absent if you don\'t punch in at office.';
          actualDeduction = balance;
        } else {
          calculatedInfo = 'Total Leave Days: $days';
          policyWarning = 'Paid Leave Policy: Minimum 2 days per application. Usable after 6 months of service.';
        }
        balanceInfo = 'Remaining Paid Leave: ${balance - actualDeduction} days';
      } else if (_selectedLeaveType == LeaveType.sick && days > 1) {
        // SL Policy: Only 1 day deducted regardless of duration
        calculatedInfo = 'Total Leave Days: $days (Only 1 SL deducted, ${days - 1} days marked absent)';
        balanceInfo = 'Remaining Sick Leave: ${balance - actualDeduction} days';
        if (days > 2) {
          policyWarning = 'Medical certificate required for Sick Leave exceeding 2 days.';
        }
      } else if (_selectedLeaveType == LeaveType.optionalHoliday) {
        calculatedInfo = 'Total Leave Days: $days';
        balanceInfo = 'Remaining Optional Holiday: ${balance - actualDeduction} days';
        policyWarning = 'Optional Holiday Policy: Auto-approved for predefined holidays only.';
      } else {
        calculatedInfo = 'Total Leave Days: $days';
        balanceInfo = 'Remaining ${_selectedLeaveType.displayName}: ${balance - actualDeduction} days';
      }
      
      // Check service period eligibility
      if (widget.user.joiningDate != null) {
        final monthsWorked = _calculateMonthsWorked(widget.user.joiningDate!, DateTime.now());
        if ((_selectedLeaveType == LeaveType.casual || _selectedLeaveType == LeaveType.paid) && monthsWorked < 6) {
          policyWarning = '${_selectedLeaveType.displayName} can only be used after 6 months of service. You have worked $monthsWorked months.';
        }
      }
      
      setState(() {
        _calculatedDays = calculatedInfo;
        _balanceInfo = balanceInfo;
        _policyWarning = policyWarning;
      });
    } else {
      setState(() {
        _calculatedDays = null;
        _balanceInfo = null;
        _policyWarning = null;
      });
    }
  }

  void _updateBalanceInfo() {
    // Check if current selected leave type is still eligible
    if (!_isLeaveTypeEligible(_selectedLeaveType)) {
      // Find the first available leave type
      LeaveType? availableType;
      for (final type in LeaveType.values) {
        if (_isLeaveTypeEligible(type)) {
          availableType = type;
          break;
        }
      }
      
      // Switch to the first available leave type if one exists
      if (availableType != null) {
        _selectedLeaveType = availableType;
        // Reset form when switching leave type
        _startDate = null;
        _endDate = null;
        _isSingleDaySL = true;
      }
    }
    
    final balance = _currentLeaveBalance[_selectedLeaveType.balanceKey] ?? 0;
    setState(() {
      _balanceInfo = 'Available ${_selectedLeaveType.displayName}: $balance days';
    });
  }



  /// Clears all form fields after successful leave submission
  void _clearFormFields() {
    setState(() {
      // Clear date selections
      _startDate = null;
      _endDate = null;
      
      // Clear reason text
      _reasonController.clear();
      

      
      // Reset sick leave to single day mode
      _isSingleDaySL = true;
      
      // Reset optional holiday selection
      _selectedOptionalHolidayId = null;
      
      // Clear calculated info
      _calculatedDays = null;
      _balanceInfo = null;
      _policyWarning = null;
      
      // Refresh balance info for current leave type
      _updateBalanceInfo();
    });
  }

  /// Refreshes the user balance from the database and updates the UI
  Future<AppUser?> _refreshUserBalance() async {
    try {
      final updatedUser = await AuthService().getCurrentUser();
      if (updatedUser != null && mounted) {
        // Update the local balance with fresh data
        _currentLeaveBalance = Map<String, int>.from(updatedUser.leaveBalance);
        setState(() {
          // Trigger UI refresh with updated balance
          _updateBalanceInfo();
        });
        return updatedUser;
      }
      return null;
    } catch (e) {
      print('❌ Error refreshing user balance: $e');
      return null;
    }
  }

  /// Pull-to-refresh handler for Apply Leave tab
  Future<void> _onRefreshApplyLeave() async {
    try {
      // Refresh user balance from database
      await _refreshUserBalance();
      

      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Balance refreshed successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to refresh balance'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Pull-to-refresh handler for My Leaves tab
  Future<void> _onRefreshMyLeaves() async {
    print('🔄 Pull-to-refresh triggered on My Leaves tab');
    
    try {
      // Refresh both user balance and leave requests
      await Future.wait([
        _refreshUserBalance(),
        _loadMyLeaves(),
      ]);
      
      print('✅ My Leaves tab refresh completed');
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data refreshed successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error during My Leaves refresh: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to refresh data'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updatePolicyWarning() {
    // This function is now handled by _updateCalculatedDays() 
    // which provides comprehensive policy warnings based on leave type and dates
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {

      
      final result = await _leaveService.applyForLeave(
        leaveType: _selectedLeaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
        user: widget.user,
        selectedOptionalHolidayId: _selectedOptionalHolidayId,
      );

      if (result.success) {
        // Refresh both balance and leave list after successful submission
        await Future.wait([
          _refreshUserBalance(),
          _loadMyLeaves(),
        ]);
        
        // Clear form after successful submission
        _clearFormFields();
        
        _showSuccessDialog(
          '${result.message ?? 'Leave request submitted successfully!'}\n\nThe form has been cleared for your next request.'
        );
      } else {
        _showErrorDialog(result.error ?? 'Failed to submit leave request');
      }
    } catch (e) {
      _showErrorDialog('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              // Close dialog first
              Navigator.of(context).pop();
              
              // Refresh user data and leaves list
              try {
                final updatedUser = await _authService.getCurrentUser();
                // Refresh the leaves list and switch to My Leaves tab
                _loadMyLeaves();
                _tabController.animateTo(1);
                
                if (updatedUser != null) {
                  // Update widget with new user data (if needed)
                  // For now, we'll continue using the original user since balance is refreshed via _loadMyLeaves
                }
              } catch (e) {
                print('Error refreshing user data: $e');
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 48),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }



  /// Load user's leave requests
  Future<void> _loadMyLeaves() async {
    setState(() {
      _loadingLeaves = true;
    });

    try {
      final leaves = await _leaveService.getMyLeaveRequests();
      setState(() {
        _myLeaveRequests = leaves;
      });
      
      // Refresh active leave restrictions after loading leaves
      await _loadActiveLeaveRestrictions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load leave requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingLeaves = false;
        });
      }
    }
  }

  Widget _buildMyLeavesTab() {
    if (_loadingLeaves) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_myLeaveRequests == null || _myLeaveRequests!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Leave Requests Found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Apply for your first leave using the Apply Leave tab',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(0); // Switch to Apply Leave tab
              },
              icon: const Icon(Icons.add),
              label: const Text('Apply for Leave'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefreshMyLeaves,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myLeaveRequests!.length,
        itemBuilder: (context, index) {
          final leave = _myLeaveRequests![index];
          return _buildLeaveRequestCard(leave);
        },
      ),
    );
  }

  Widget _buildLeaveRequestCard(LeaveRequest leave) {
    final startDate = DateFormat('MMM dd, yyyy').format(leave.startDate);
    final endDate = DateFormat('MMM dd, yyyy').format(leave.endDate);
    
    // Determine the display status - show "completed" for approved leaves that have ended
    String displayStatus = leave.status.toLowerCase();
    if (displayStatus == 'approved') {
      final DateTime today = DateTime.now();
      final DateTime todayStart = DateTime(today.year, today.month, today.day);
      
      if (leave.leaveType == LeaveType.sick) {
        // For SL: show "completed" if the applied date (first day) has ended
        // Since only 1 day is deducted regardless of duration
        final DateTime appliedDate = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
        if (todayStart.isAfter(appliedDate)) {
          displayStatus = 'completed';
        }
      } else {
        // For other leave types: show "completed" if the entire leave period has ended
        final DateTime leaveEndDate = DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
        if (todayStart.isAfter(leaveEndDate)) {
          displayStatus = 'completed';
        }
      }
    }
    
    Color statusColor;
    IconData statusIcon;
    
    switch (displayStatus) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with leave type and status
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getLeaveTypeColor(leave.leaveType).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getLeaveTypeColor(leave.leaveType).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          leave.leaveType.displayName,
                          style: TextStyle(
                            color: _getLeaveTypeColor(leave.leaveType),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      displayStatus.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Leave type indicator (Single Day vs Multiple Days)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: leave.totalDays == 1 ? Colors.blue.shade50 : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: leave.totalDays == 1 ? Colors.blue.shade200 : Colors.purple.shade200,
                ),
              ),
              child: Text(
                leave.totalDays == 1 ? 'Single Day Leave' : 'Multiple Days Leave',
                style: TextStyle(
                  color: leave.totalDays == 1 ? Colors.blue.shade700 : Colors.purple.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Dates and duration
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leave.totalDays == 1 ? 'Leave Date' : 'Duration',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        leave.totalDays == 1 
                          ? startDate  // Show only start date for single day
                          : '$startDate - $endDate',  // Show range for multiple days
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Days',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${leave.totalDays} day${leave.totalDays > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Show deducted days info for sick leave when different from total
                        if (leave.leaveType == LeaveType.sick && leave.daysToDeduct != leave.totalDays) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Deducted: ${leave.daysToDeduct} day${leave.daysToDeduct > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
            
            if (leave.reason?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                'Reason',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                leave.reason!,
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),
            ],
            
            // Action buttons for pending requests and modifiable leaves
            if (_canModifyLeave(leave)) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  // Show edit button only for pending requests or approved SL
                  if (_canEditLeave(leave)) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editLeaveRequest(leave),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancellingLeaveId == leave.id 
                        ? null  // Disable button while cancelling
                        : () => _cancelLeaveRequest(leave),
                      icon: _cancellingLeaveId == leave.id
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel, size: 16),
                      label: Text(
                        _cancellingLeaveId == leave.id
                          ? 'Cancelling...'
                          : (leave.status == 'approved' ? 'Cancel Leave' : 'Cancel')
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            // Applied and approved date information
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Applied on ${leave.submittedDate != null ? DateFormat('MMM dd, yyyy \'at\' hh:mm a').format(leave.submittedDate!) : 'Unknown date'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
                if (leave.approvedDate != null && leave.status.toLowerCase() == 'approved') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Approved on ${DateFormat('MMM dd, yyyy \'at\' hh:mm a').format(leave.approvedDate!)}',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (leave.approvedBy != null && leave.approvedBy != 'system') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Approved by ${leave.approvedBy}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ] else if (leave.approvedBy == 'system' && leave.status == 'approved') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Auto-approved (Company Policy)',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Check if a leave request can be modified (edit/delete)
  bool _canModifyLeave(LeaveRequest leave) {
    final DateTime today = DateTime.now();
    final DateTime todayStart = DateTime(today.year, today.month, today.day);
    
    // For pending requests, always allow modification
    if (leave.status.toLowerCase() == 'pending') {
      return true;
    }
    
    // For approved requests: check specific rules based on leave type
    if (leave.status.toLowerCase() == 'approved') {
      if (leave.leaveType == LeaveType.sick) {
        // For SL: Allow edit/cancel until the applied date ends (first day for SL)
        // Since SL only deducts 1 day regardless of duration, the "applied date" is the first day
        final DateTime leaveStartDate = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
        
        // Allow modification until the end of the first day (not just before it starts)
        return todayStart.isAtSameMomentAs(leaveStartDate) || todayStart.isBefore(leaveStartDate);
      } else if (leave.leaveType == LeaveType.optionalHoliday) {
        // For OH: Allow cancel until the optional holiday day ends
        final DateTime leaveStartDate = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
        
        // Allow modification until the end of the holiday day (not just before it starts)
        return todayStart.isAtSameMomentAs(leaveStartDate) || todayStart.isBefore(leaveStartDate);
      } else {
        // For other leave types (CL, PL): only allow before start date
        final DateTime leaveStartDate = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
        return todayStart.isBefore(leaveStartDate);
      }
    }
    
    // For other statuses (rejected, cancelled), no modification allowed
    return false;
  }

  bool _canEditLeave(LeaveRequest leave) {
    final DateTime today = DateTime.now();
    final DateTime todayStart = DateTime(today.year, today.month, today.day);
    
    // For pending requests, always allow editing
    if (leave.status.toLowerCase() == 'pending') {
      return true;
    }
    
    // For approved requests: only allow editing for Sick Leave and until applied date ends
    if (leave.status.toLowerCase() == 'approved') {
      if (leave.leaveType == LeaveType.sick) {
        final DateTime leaveStartDate = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
        
        // For SL: allow editing until the applied date ends (same day or before start date)
        // Since SL only deducts 1 day regardless of duration, modification allowed on the first day
        return todayStart.isAtSameMomentAs(leaveStartDate) || todayStart.isBefore(leaveStartDate);
      }
      
      // For approved CL, PL, OH - no editing allowed
      return false;
    }
    
    // For other statuses (rejected, cancelled), no editing allowed
    return false;
  }

  Color _getLeaveTypeColor(LeaveType type) {
    switch (type) {
      case LeaveType.sick:
        return Colors.red;
      case LeaveType.casual:
        return Colors.blue;
      case LeaveType.paid:
        return Colors.green;
      case LeaveType.optionalHoliday:
        return Colors.purple;
    }
  }

  void _editLeaveRequest(LeaveRequest leave) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditLeaveRequestScreen(
          request: leave,
        ),
      ),
    );
    
    // If the edit was successful, reload balance and leave list
    if (result == true) {
      await Future.wait([
        _refreshUserBalance(),
        _loadMyLeaves(),
      ]);
    }
  }

  Future<void> _cancelLeaveRequest(LeaveRequest leave) async {
    String dialogContent = 'Are you sure you want to cancel this ${leave.leaveType.displayName} request?';
    
    // Add specific information for approved leaves about balance restoration
    if (leave.status.toLowerCase() == 'approved') {
      final deductedDays = leave.daysToDeduct;
      dialogContent += '\n\nThis will restore $deductedDays day${deductedDays > 1 ? 's' : ''} to your ${leave.leaveType.displayName} balance.';
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Leave Request'),
        content: Text(dialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Set loading state for this specific leave request
      setState(() {
        _cancellingLeaveId = leave.id;
      });
      
      try {
        // Get the leave type for the new collection structure
        String leaveTypeKey;
        switch (leave.leaveType) {
          case LeaveType.sick:
            leaveTypeKey = 'SL';
            break;
          case LeaveType.casual:
            leaveTypeKey = 'CL';
            break;
          case LeaveType.paid:
            leaveTypeKey = 'PL';
            break;
          case LeaveType.optionalHoliday:
            leaveTypeKey = 'OH';
            break;
        }

        final success = await _leaveService.cancelLeaveRequest(leave.id, leaveTypeKey);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(leave.status.toLowerCase() == 'approved' ? 'Leave request deleted successfully' : 'Leave request cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload both balance and leaves
          await Future.wait([
            _refreshUserBalance(),
            _loadMyLeaves(),
          ]);
        } else {
          throw Exception('Failed to cancel leave request');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling leave request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        // Clear loading state
        setState(() {
          _cancellingLeaveId = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}