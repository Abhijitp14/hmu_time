import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../models/holiday_model.dart';
import '../../../services/holiday_service.dart';
import '../../../theme/theme.dart';

class EmployeeHolidaysScreen extends StatefulWidget {
  const EmployeeHolidaysScreen({super.key});

  @override
  State<EmployeeHolidaysScreen> createState() => _EmployeeHolidaysScreenState();
}

class _EmployeeHolidaysScreenState extends State<EmployeeHolidaysScreen> {
  final HolidayService _holidayService = HolidayService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Holiday> _allHolidays = [];
  List<Holiday> _monthHolidays = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    try {
      setState(() => _isLoading = true);
      final holidays = await _holidayService.getHolidays();
      setState(() {
        _allHolidays = holidays;
        _filterHolidaysForMonth(_focusedDay);
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load holidays: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterHolidaysForMonth(DateTime month) {
    final monthHolidays = _allHolidays.where((holiday) {
      return holiday.date.year == month.year &&
          holiday.date.month == month.month;
    }).toList();

    setState(() {
      _monthHolidays = monthHolidays;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  List<Holiday> _getHolidaysForDay(DateTime day) {
    return _allHolidays.where((holiday) {
      return isSameDay(holiday.date, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Holidays'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHolidays,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height:
                      MediaQuery.of(context).size.height -
                      160, // Adjust for AppBar
                  child: MediaQuery.of(context).size.width > 600
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _buildCalendar()),
                            Expanded(flex: 3, child: _buildHolidaysList()),
                          ],
                        )
                      : Column(
                          children: [
                            _buildCalendar(),
                            Expanded(child: _buildHolidaysList()),
                          ],
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildCalendar() {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Container(
      margin: isWideScreen
          ? const EdgeInsets.fromLTRB(16, 16, 8, 16)
          : const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar<Holiday>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: _getHolidaysForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        // Only Sunday is considered weekend (Saturday is working day)
        weekendDays: const [DateTime.sunday],
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          // Only Sunday will be colored red (Saturday is working day)
          weekendTextStyle: const TextStyle(color: Colors.red),
          holidayTextStyle: const TextStyle(color: Colors.red),
          selectedDecoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: AppColors.warning,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 1,
        ),
        calendarBuilders: CalendarBuilders(
          // Custom builder to only color Sunday as red
          dowBuilder: (context, day) {
            if (day.weekday == DateTime.sunday) {
              return Center(
                child: Text(
                  DateFormat.E().format(day),
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            return null; // Use default for other days
          },
          // Custom builder for individual days to color only Sunday
          defaultBuilder: (context, day, focusedDay) {
            if (day.weekday == DateTime.sunday) {
              return Container(
                margin: const EdgeInsets.all(4.0),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            return null; // Use default for other days
          },
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.primary),
          rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.primary),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
          _filterHolidaysForMonth(focusedDay);
        },
      ),
    );
  }

  Widget _buildHolidaysList() {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Container(
      margin: isWideScreen
          ? const EdgeInsets.fromLTRB(8, 16, 16, 16)
          : const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.event_note, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Holidays in ${DateFormat('MMMM yyyy').format(_focusedDay)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _monthHolidays.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _monthHolidays.length,
                    itemBuilder: (context, index) {
                      final holiday = _monthHolidays[index];
                      return _buildHolidayCard(holiday);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No holidays in ${DateFormat('MMMM yyyy').format(_focusedDay)}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy your regular work days!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayCard(Holiday holiday) {
    final isUpcoming = holiday.date.isAfter(DateTime.now());
    final daysDifference = holiday.date.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Holiday Type Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getHolidayColor(holiday.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getHolidayIcon(holiday.type),
                  color: _getHolidayColor(holiday.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Holiday Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holiday.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMM dd, yyyy').format(holiday.date),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    if (holiday.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        holiday.description!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Holiday Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getHolidayColor(holiday.type),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      holiday.type.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isUpcoming && daysDifference >= 0) ...[
                    Text(
                      daysDifference == 0
                          ? 'Today'
                          : daysDifference == 1
                          ? 'Tomorrow'
                          : 'In $daysDifference days',
                      style: TextStyle(
                        fontSize: 12,
                        color: daysDifference <= 7
                            ? AppColors.primary
                            : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else if (!isUpcoming) ...[
                    Text(
                      'Past',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getHolidayIcon(HolidayType type) {
    switch (type) {
      case HolidayType.government:
        return Icons.account_balance;
      case HolidayType.optional:
        return Icons.event_available;
      case HolidayType.uncertain:
        return Icons.help_outline;
    }
  }

  Color _getHolidayColor(HolidayType type) {
    switch (type) {
      case HolidayType.government:
        return AppColors.error;
      case HolidayType.optional:
        return AppColors.success;
      case HolidayType.uncertain:
        return AppColors.warning;
    }
  }
}
