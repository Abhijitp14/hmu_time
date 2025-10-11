import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_model.dart';
import '../../models/user_model.dart';

class PaidLeaveWidget extends StatelessWidget {
  final AppUser user;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime) onStartDateChanged;
  final Function(DateTime) onEndDateChanged;

  const PaidLeaveWidget({
    super.key,
    required this.user,
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paid Leave Dates',
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
                      child: _buildDateField(
                        context: context,
                        label: 'Start Date',
                        selectedDate: startDate,
                        onDateSelected: onStartDateChanged,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDateField(
                        context: context,
                        label: 'End Date',
                        selectedDate: endDate,
                        onDateSelected: onEndDateChanged,
                        firstDate: startDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paid Leave Policy:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Must apply at least 2 days in advance (no current/next day applications)',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      Text(
                        '• Minimum 2 days required per application',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      Text(
                        '• Only one PL application allowed per month',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      Text(
                        '• Start date: 2 days from today to next 4 weeks',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      Text(
                        '• End date: Next day from start date to next 4 weeks',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      Text(
                        '• Sundays are excluded from selection',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
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

  Widget _buildDateField({
    required BuildContext context,
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
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context, onDateSelected, firstDate),
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

  Future<void> _selectDate(BuildContext context, Function(DateTime) onDateSelected, DateTime? firstDate) async {
    final DateTime today = DateTime.now();
    
    // Helper function to find the next valid (non-Sunday) date
    DateTime findNextValidDate(DateTime date) {
      DateTime validDate = date;
      while (validDate.weekday == DateTime.sunday) {
        validDate = validDate.add(const Duration(days: 1));
      }
      return validDate;
    }
    
    // For start date: 2 days from current date till next 4 weeks
    // For end date: from selected start date till next 4 weeks
    DateTime calculatedFirstDate;
    DateTime calculatedLastDate;
    DateTime initialDate;
    
    if (firstDate == null) {
      // This is start date selection
      // Start from 2 days ahead (cannot apply for current day or next day)
      calculatedFirstDate = today.add(const Duration(days: 2));
      calculatedLastDate = today.add(const Duration(days: 28)); // 4 weeks
      
      // Ensure initial date is not a Sunday
      initialDate = findNextValidDate(calculatedFirstDate);
      // If initial date moves beyond the first date, update first date as well
      if (initialDate != calculatedFirstDate) {
        calculatedFirstDate = initialDate;
      }
    } else {
      // This is end date selection (firstDate is the selected start date)
      // Minimum 2 days for paid leave - end date starts from next day of start date
      calculatedFirstDate = firstDate.add(const Duration(days: 1)); // Next day from start date
      calculatedLastDate = firstDate.add(const Duration(days: 28)); // 4 weeks from start date
      
      // Ensure initial date is not a Sunday
      initialDate = findNextValidDate(calculatedFirstDate);
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: calculatedFirstDate,
      lastDate: calculatedLastDate,
      selectableDayPredicate: (DateTime day) {
        // Exclude Sundays (weekday 7 = Sunday)
        return day.weekday != DateTime.sunday;
      },
    );
    
    if (picked != null) {
      onDateSelected(picked);
    }
  }
}