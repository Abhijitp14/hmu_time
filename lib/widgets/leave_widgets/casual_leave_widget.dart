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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, 
                               color: Colors.orange.shade700, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Casual Leave Policy:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '• Only 1 CL per month is allowed\n'
                        '• Available after 6 months of service\n'
                        '• Sundays cannot be selected (non-working day)\n'
                        '• Start date: Today to next 2 weeks\n'
                        '• End date: From start date to next 2 weeks\n'
                        '• Extra days will be marked as absent\n'
                        '• CL remains locked entire month after one use',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
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
    
    // For start date: current date to next 2 weeks
    // For end date: from selected start date to next 2 weeks
    final DateTime calculatedFirstDate = firstDate ?? today;
    final DateTime lastDate = (firstDate ?? today).add(const Duration(days: 14));
    
    // Ensure initialDate is not before firstDate
    final DateTime initialDate = calculatedFirstDate.isAfter(today) ? calculatedFirstDate : today;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: calculatedFirstDate,
      lastDate: lastDate,
      selectableDayPredicate: (DateTime date) {
        // Exclude Sundays (weekday 7 = Sunday)
        return date.weekday != DateTime.sunday;
      },
    );
    
    if (picked != null) {
      onDateSelected(picked);
    }
  }
}