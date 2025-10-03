import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_model.dart';
import '../../models/user_model.dart';

class CasualLeaveWidget extends StatelessWidget {
  final AppUser user;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime) onStartDateChanged;
  final Function(DateTime) onEndDateChanged;

  const CasualLeaveWidget({
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
          'Casual Leave Dates',
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
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Casual Leave Policy:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Only 1 CL per month is allowed',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                      Text(
                        '• Available after 6 months of service',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                      Text(
                        '• Extra days will be marked as absent',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
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
    final DateTime calculatedFirstDate = firstDate ?? DateTime.now();
    final DateTime today = DateTime.now();
    
    // Ensure initialDate is not before firstDate
    final DateTime initialDate = calculatedFirstDate.isAfter(today) ? calculatedFirstDate : today;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: calculatedFirstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      onDateSelected(picked);
    }
  }
}