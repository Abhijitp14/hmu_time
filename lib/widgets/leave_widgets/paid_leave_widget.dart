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
                        '• Can apply at least 2 working days in advance',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      Text(
                        '• Maximum 5 consecutive days per application',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      Text(
                        '• Cannot exceed annual entitlement',
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
    // For PL, ensure at least 2 working days in advance
    final DateTime today = DateTime.now();
    int workingDaysAdded = 0;
    DateTime calculatedFirstDate = today;
    
    // Calculate minimum date (2 working days from today)
    while (workingDaysAdded < 2) {
      calculatedFirstDate = calculatedFirstDate.add(const Duration(days: 1));
      // Skip weekends (Saturday = 6, Sunday = 7)
      if (calculatedFirstDate.weekday != DateTime.saturday && 
          calculatedFirstDate.weekday != DateTime.sunday) {
        workingDaysAdded++;
      }
    }
    
    // Use firstDate if it's later than the calculated minimum
    if (firstDate != null && firstDate.isAfter(calculatedFirstDate)) {
      calculatedFirstDate = firstDate;
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: calculatedFirstDate,
      firstDate: calculatedFirstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      onDateSelected(picked);
    }
  }
}