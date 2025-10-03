import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_model.dart';
import '../../models/user_model.dart';

class OptionalHolidayWidget extends StatelessWidget {
  final AppUser user;
  final DateTime? startDate;
  final Function(DateTime) onStartDateChanged;

  const OptionalHolidayWidget({
    super.key,
    required this.user,
    required this.startDate,
    required this.onStartDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Optional Holiday Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateField(
                  context: context,
                  label: 'Holiday Date',
                  selectedDate: startDate,
                  onDateSelected: onStartDateChanged,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    border: Border.all(color: Colors.purple.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Optional Holiday Policy:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Only 1 day at a time',
                        style: TextStyle(fontSize: 12, color: Colors.purple),
                      ),
                      Text(
                        '• Must be applied at least 1 day in advance',
                        style: TextStyle(fontSize: 12, color: Colors.purple),
                      ),
                      Text(
                        '• Limited to company-designated optional holidays',
                        style: TextStyle(fontSize: 12, color: Colors.purple),
                      ),
                      Text(
                        '• Cannot exceed annual optional holiday quota',
                        style: TextStyle(fontSize: 12, color: Colors.purple),
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
          onTap: () => _selectDate(context, onDateSelected),
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

  Future<void> _selectDate(BuildContext context, Function(DateTime) onDateSelected) async {
    // For OH, must be applied at least 1 day in advance
    final DateTime firstDate = DateTime.now().add(const Duration(days: 1));
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: firstDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      onDateSelected(picked);
    }
  }
}