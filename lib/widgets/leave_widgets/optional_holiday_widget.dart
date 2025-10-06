import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_model.dart';
import '../../models/user_model.dart';
import '../../services/leave_service.dart';

class OptionalHolidayWidget extends StatefulWidget {
  final AppUser user;
  final DateTime? startDate;
  final Function(DateTime) onStartDateChanged;
  final Function(String?) onHolidaySelected;
  final String? selectedOptionalHolidayId;

  const OptionalHolidayWidget({
    super.key,
    required this.user,
    required this.startDate,
    required this.onStartDateChanged,
    required this.onHolidaySelected,
    this.selectedOptionalHolidayId,
  });

  @override
  State<OptionalHolidayWidget> createState() => _OptionalHolidayWidgetState();
}

class _OptionalHolidayWidgetState extends State<OptionalHolidayWidget> {
  final LeaveService _leaveService = LeaveService();
  List<OptionalHoliday> _availableHolidays = [];
  bool _loadingHolidays = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOptionalHolidays();
  }

  Future<void> _loadOptionalHolidays() async {
    setState(() {
      _loadingHolidays = true;
      _errorMessage = null;
    });

    try {
      final holidays = await _leaveService.getAvailableOptionalHolidays();
      setState(() {
        _availableHolidays = holidays;
        _loadingHolidays = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load optional holidays: $e';
        _loadingHolidays = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Optional Holiday',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadingHolidays) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Loading optional holidays...'),
                        ],
                      ),
                    ),
                  ),
                ] else if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadOptionalHolidays,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ] else if (_availableHolidays.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange.shade600),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No optional holidays are available at the moment. Please contact HR for more information.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Available Optional Holidays',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  ...(_availableHolidays.map((holiday) => _buildHolidayTile(holiday))),
                ],
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
                        '• Must select from company-designated optional holidays',
                        style: TextStyle(fontSize: 12, color: Colors.purple),
                      ),
                      Text(
                        '• Auto-approved upon selection',
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

  Widget _buildHolidayTile(OptionalHoliday holiday) {
    final isSelected = widget.selectedOptionalHolidayId == holiday.id;
    final formattedDate = DateFormat('MMM dd, yyyy (EEEE)').format(holiday.date);
    
    // Check if holiday is in the past
    final isPastDate = holiday.isPastDate;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: isPastDate ? null : () {
          print('OH Selected: ${holiday.id} -> ${holiday.date.toIso8601String()}');
          widget.onHolidaySelected(holiday.id);
          widget.onStartDateChanged(holiday.date);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPastDate 
                ? Colors.grey.shade100 
                : isSelected 
                    ? Colors.purple.shade100 
                    : Colors.white,
            border: Border.all(
              color: isPastDate 
                  ? Colors.grey.shade300 
                  : isSelected 
                      ? Colors.purple.shade400 
                      : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: holiday.id,
                groupValue: widget.selectedOptionalHolidayId,
                onChanged: isPastDate ? null : (value) {
                  print('OH Radio Selected: $value -> ${holiday.date.toIso8601String()}');
                  widget.onHolidaySelected(value);
                  widget.onStartDateChanged(holiday.date);
                },
                activeColor: Colors.purple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holiday.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isPastDate ? Colors.grey : Colors.black,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 13,
                        color: isPastDate ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                    if (holiday.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        holiday.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: isPastDate ? Colors.grey : Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (isPastDate) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Past Date',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}