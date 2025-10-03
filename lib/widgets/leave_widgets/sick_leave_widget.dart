import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_model.dart';
import '../../models/user_model.dart';

class SickLeaveWidget extends StatefulWidget {
  final AppUser user;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isSingleDay;
  final Function(DateTime) onStartDateChanged;
  final Function(DateTime?) onEndDateChanged;
  final Function(bool) onSingleDayChanged;

  const SickLeaveWidget({
    super.key,
    required this.user,
    required this.startDate,
    required this.endDate,
    required this.isSingleDay,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onSingleDayChanged,
  });

  @override
  State<SickLeaveWidget> createState() => _SickLeaveWidgetState();
}

class _SickLeaveWidgetState extends State<SickLeaveWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sick Leave Duration',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Single Day'),
                        value: true,
                        groupValue: widget.isSingleDay,
                        onChanged: (value) {
                          if (value != null && value == true) {
                            widget.onSingleDayChanged(true);
                            // Set end date same as start date for single day
                            if (widget.startDate != null) {
                              widget.onEndDateChanged(widget.startDate);
                            }
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Multiple Days'),
                        value: false,
                        groupValue: widget.isSingleDay,
                        onChanged: (value) {
                          if (value != null && value == false) {
                            widget.onSingleDayChanged(false);
                            // Reset end date for multiple days selection
                            widget.onEndDateChanged(null);
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.isSingleDay) 
                  _buildSingleDaySelector()
                else 
                  _buildMultipleDaysSelector(),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, 
                               color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Sick Leave Policy:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '• Only 1 day deducted regardless of duration\n'
                        '• Sundays cannot be selected (non-working day)\n'
                        '• Single day: Today + 2 upcoming working days\n'
                        '• Multiple days: Up to 7 working days in advance\n'
                        '• Medical certificate required for >2 days\n'
                        '• Edit/cancel allowed until applied date ends\n'
                        '• Status changes to "completed" after leave ends',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sick Leave Date',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectSickLeaveDate(false),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.startDate != null
                      ? DateFormat('MMM dd, yyyy').format(widget.startDate!)
                      : 'Select Date',
                  style: TextStyle(
                    color: widget.startDate != null ? Colors.black : Colors.grey,
                  ),
                ),
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleDaysSelector() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'Start Date',
                selectedDate: widget.startDate,
                onDateSelected: widget.onStartDateChanged,
                isEndDate: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                label: 'End Date',
                selectedDate: widget.endDate,
                onDateSelected: (date) => widget.onEndDateChanged(date),
                firstDate: widget.startDate,
                isEndDate: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateField({
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
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectSickLeaveDate(isEndDate, firstDate: firstDate),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null
                      ? DateFormat('MMM dd, yyyy').format(selectedDate)
                      : 'Select Date',
                  style: TextStyle(
                    color: selectedDate != null ? Colors.black : Colors.grey,
                  ),
                ),
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectSickLeaveDate(bool isEndDate, {DateTime? firstDate}) async {
    final DateTime today = DateTime.now();
    
    DateTime maxDate = today;
    DateTime startDate;
    String helpText;
    
    if (isEndDate && firstDate != null) {
      // For end date: next day of start date + up to 7 calendar days from start date
      startDate = firstDate.add(const Duration(days: 1)); // End date starts from day after start date
      
      // For multiple days: end date can be up to 7 calendar days from start date
      maxDate = firstDate.add(const Duration(days: 7));
      helpText = 'Select End Date (working days only)';
    } else {
      // For start date or single day selection
      if (widget.isSingleDay) {
        // Single day: current date + up to 2 upcoming days (total 3 days) - for emergency situations
        startDate = today;
        maxDate = today.add(const Duration(days: 2));
        helpText = 'Select Sick Leave Date (working days only)';
      } else {
        // Multiple days start date: current date + up to 7 calendar days
        startDate = today;
        maxDate = today.add(const Duration(days: 7));
        helpText = 'Select Start Date (working days only)';
      }
    }
    
    final DateTime initialDate = startDate;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: startDate,
      lastDate: maxDate,
      helpText: helpText,
      confirmText: 'CONFIRM',
      cancelText: 'CANCEL',
      selectableDayPredicate: (DateTime date) {
        // Exclude Sundays from selection since they are non-working days
        // DateTime.weekday: Monday = 1, Sunday = 7
        return date.weekday != DateTime.sunday;
      },
    );
    
    if (picked != null) {
      if (isEndDate) {
        widget.onEndDateChanged(picked);
      } else {
        widget.onStartDateChanged(picked);
        if (widget.isSingleDay) {
          widget.onEndDateChanged(picked);
        } else {
          // For multiple days, reset end date when start date changes
          widget.onEndDateChanged(null);
        }
      }
    }
  }
}