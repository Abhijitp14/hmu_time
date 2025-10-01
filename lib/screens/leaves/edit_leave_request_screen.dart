import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_model.dart';

class EditLeaveRequestScreen extends StatefulWidget {
  final LeaveRequest request;

  const EditLeaveRequestScreen({
    super.key,
    required this.request,
  });

  @override
  State<EditLeaveRequestScreen> createState() => _EditLeaveRequestScreenState();
}

class _EditLeaveRequestScreenState extends State<EditLeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = false;
  
  // Sick Leave specific variables
  bool _isSingleDaySL = true;
  
  String? _calculatedDays;
  String? _balanceInfo;
  String? _policyWarning;

  @override
  void initState() {
    super.initState();
    _initializeFromRequest();
  }

  void _initializeFromRequest() {
    _reasonController.text = widget.request.reason ?? '';
    _startDate = widget.request.startDate;
    _endDate = widget.request.endDate;

    
    // For sick leave, determine if it's single day
    if (widget.request.leaveType == LeaveType.sick) {
      _isSingleDaySL = widget.request.startDate.day == widget.request.endDate.day &&
                      widget.request.startDate.month == widget.request.endDate.month &&
                      widget.request.startDate.year == widget.request.endDate.year;
    }
    
    _updateCalculatedDays();
    _updatePolicyWarning();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.request.leaveType.displayName}'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRequestInfoCard(),
            const SizedBox(height: 20),
            _buildDateSelection(),
            const SizedBox(height: 16),
            _buildCalculatedDaysInfo(),
            const SizedBox(height: 20),
            _buildReasonField(),

            const SizedBox(height: 16),
            _buildPolicyWarning(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Edit Leave Request',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leave Type',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        widget.request.leaveType.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Applied On',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        widget.request.submittedDate != null 
                            ? DateFormat('MMM dd, yyyy').format(widget.request.submittedDate!)
                            : 'Unknown date',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelection() {
    // For Sick Leave, show specialized SL date selection
    if (widget.request.leaveType == LeaveType.sick) {
      return _buildSickLeaveDateSelection();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leave Dates',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'Start Date',
                selectedDate: _startDate,
                onDateSelected: (date) {
                  setState(() {
                    _startDate = date;
                    if (_endDate != null && _endDate!.isBefore(date)) {
                      _endDate = null;
                    }
                    _updateCalculatedDays();
                    _updatePolicyWarning();
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                label: 'End Date',
                selectedDate: _endDate,
                onDateSelected: (date) {
                  setState(() {
                    _endDate = date;
                    _updateCalculatedDays();
                    _updatePolicyWarning();
                  });
                },
                firstDate: _startDate,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSickLeaveDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sick Leave Duration',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        
        // Single vs Multiple day selection
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: Column(
            children: [
              RadioListTile<bool>(
                value: true,
                groupValue: _isSingleDaySL,
                onChanged: (value) {
                  setState(() {
                    _isSingleDaySL = value!;
                    if (value && _startDate != null) {
                      _endDate = _startDate; // Set end date same as start date for single day
                    }
                    _updateCalculatedDays();
                    _updatePolicyWarning();
                  });
                },
                title: const Text('Single Day', style: TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              RadioListTile<bool>(
                value: false,
                groupValue: _isSingleDaySL,
                onChanged: (value) {
                  setState(() {
                    _isSingleDaySL = value!;
                    _updateCalculatedDays();
                    _updatePolicyWarning();
                  });
                },
                title: const Text('Multiple Days', style: TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Date selection based on single/multiple choice
        if (_isSingleDaySL) ...[
          _buildSickLeaveDateField(
            label: 'Sick Leave Date',
            selectedDate: _startDate,
            onDateSelected: (date) {
              setState(() {
                _startDate = date;
                _endDate = date; // For single day, end date is same as start date
                _updateCalculatedDays();
                _updatePolicyWarning();
              });
            },
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildSickLeaveDateField(
                  label: 'Start Date',
                  selectedDate: _startDate,
                  onDateSelected: (date) {
                    setState(() {
                      _startDate = date;
                      if (_endDate != null && _endDate!.isBefore(date)) {
                        _endDate = null;
                      }
                      _updateCalculatedDays();
                      _updatePolicyWarning();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSickLeaveDateField(
                  label: 'End Date',
                  selectedDate: _endDate,
                  onDateSelected: (date) {
                    setState(() {
                      _endDate = date;
                      _updateCalculatedDays();
                      _updatePolicyWarning();
                    });
                  },
                  firstDate: _startDate,
                  isEndDate: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSickLeaveDateField({
    required String label,
    required DateTime? selectedDate,
    required Function(DateTime) onDateSelected,
    DateTime? firstDate,
    bool isEndDate = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _selectSickLeaveDate(onDateSelected, firstDate, isEndDate: isEndDate),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  selectedDate != null 
                      ? DateFormat('MMM dd, yyyy').format(selectedDate)
                      : 'Select Date',
                  style: TextStyle(
                    color: selectedDate != null ? null : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? selectedDate,
    required Function(DateTime) onDateSelected,
    DateTime? firstDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _selectDate(onDateSelected, firstDate),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  selectedDate != null 
                      ? DateFormat('MMM dd, yyyy').format(selectedDate)
                      : 'Select Date',
                  style: TextStyle(
                    color: selectedDate != null ? null : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(Function(DateTime) onDateSelected, DateTime? firstDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Future<void> _selectSickLeaveDate(Function(DateTime) onDateSelected, DateTime? firstDate, {bool isEndDate = false}) async {
    final DateTime today = DateTime.now();
    
    DateTime maxDate;
    DateTime startDate;
    String helpText;
    
    if (isEndDate && firstDate != null) {
      // For end date: up to 7 days from start date
      startDate = firstDate;
      maxDate = firstDate.add(const Duration(days: 7));
      helpText = 'Select End Date (up to 7 days from start)';
    } else {
      // For start date or single day: allow past 7 days + today + next 2 working days (excluding Sunday)
      startDate = today.subtract(const Duration(days: 7));
      
      // Calculate next 2 working days excluding Sunday for the max date
      DateTime currentDate = today;
      int workingDaysFound = 0;
      DateTime lastWorkingDay = today;
      
      while (workingDaysFound < 3) { // Today + next 2 = 3 total days
        if (currentDate.weekday != DateTime.sunday) {
          lastWorkingDay = currentDate;
          workingDaysFound++;
        }
        if (workingDaysFound < 3) {
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }
      
      maxDate = lastWorkingDay;
      helpText = _isSingleDaySL ? 'Select Sick Leave Date (past 7 days to next 2 days)' : 'Select Start Date (past 7 days to next 2 working days)';
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: startDate,
      lastDate: maxDate,
      helpText: helpText,
      confirmText: 'CONFIRM',
      cancelText: 'CANCEL',
      selectableDayPredicate: (DateTime date) {
        // For start date selection, exclude Sundays
        if (!isEndDate && date.weekday == DateTime.sunday) {
          return false;
        }
        return true;
      },
    );
    
    if (picked != null) {
      onDateSelected(picked);
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
        if (widget.request.leaveType == LeaveType.sick && 
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
        
        const Text(
          'Reason for Leave',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter reason for your leave request...',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _canSubmit() ? _updateLeaveRequest : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Update Request'),
          ),
        ),
      ],
    );
  }

  bool _canSubmit() {
    return !_isLoading &&
           _startDate != null &&
           _endDate != null &&
           _reasonController.text.trim().isNotEmpty;
  }

  void _updateCalculatedDays() {
    if (_startDate != null && _endDate != null) {
      final days = LeaveRequest.calculateLeaveDays(_startDate!, _endDate!);
      final daysToDeduct = LeaveRequest.calculateLeaveDeduction(_startDate!, _endDate!, widget.request.leaveType);
      
      String calculatedInfo;
      String balanceInfo;
      
      if (widget.request.leaveType == LeaveType.sick && days > 1) {
        calculatedInfo = 'Total Leave Days: $days (Only 1 day deducted from balance, ${days - 1} days marked absent)';
        balanceInfo = 'Days to deduct from balance: $daysToDeduct';
      } else {
        calculatedInfo = 'Total Leave Days: $days';
        balanceInfo = 'Days to deduct from balance: $daysToDeduct';
      }
      
      setState(() {
        _calculatedDays = calculatedInfo;
        _balanceInfo = balanceInfo;
      });
    } else {
      setState(() {
        _calculatedDays = null;
        _balanceInfo = null;
      });
    }
  }

  void _updatePolicyWarning() {
    String? warning;
    
    if (widget.request.leaveType == LeaveType.paid && 
        _startDate != null && _endDate != null) {
      final days = LeaveRequest.calculateLeaveDays(_startDate!, _endDate!);
      if (days == 1) {
        warning = 'Company Policy: Paid Leave requires minimum 2 days. Consider using Casual Leave for single day.';
      }
    }
    
    if (widget.request.leaveType == LeaveType.sick && 
        _startDate != null && _endDate != null) {
      final days = LeaveRequest.calculateLeaveDays(_startDate!, _endDate!);
      if (days > 1) {
        warning = 'Company Policy: For Sick Leave, only 1 day is deducted from balance regardless of duration. Additional days are marked as absent.';
      }
    }
    
    // Prior approval validation for non-Sick leaves
    if (widget.request.leaveType != LeaveType.sick && _startDate != null && 
        _startDate!.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      warning = 'Company Policy: Prior approval required for same-day or past date requests.';
    }
    
    setState(() {
      _policyWarning = warning;
    });
  }

  Future<void> _updateLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // For now, we'll show a placeholder message since the actual update functionality
      // would need to be implemented in the backend
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      
      // TODO: Implement actual leave request update logic
      // This would involve calling a Firebase function to update the leave request
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request edit functionality will be implemented in the backend'),
          backgroundColor: Colors.orange,
        ),
      );
      
      // For now, just return success
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating leave request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}