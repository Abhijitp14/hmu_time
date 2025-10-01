import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../models/holiday_model.dart';
import '../../../services/holiday_service.dart';

class AddHolidayCalendarScreen extends StatefulWidget {
  final HolidayType defaultType;
  final List<Holiday> existingHolidays;

  const AddHolidayCalendarScreen({
    super.key,
    required this.defaultType,
    required this.existingHolidays,
  });

  @override
  State<AddHolidayCalendarScreen> createState() => _AddHolidayCalendarScreenState();
}

class _AddHolidayCalendarScreenState extends State<AddHolidayCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  HolidayType _selectedType = HolidayType.government;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.defaultType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add ${_selectedType.displayName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<HolidayType>(
              value: _selectedType,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              dropdownColor: AppColors.primary,
              style: const TextStyle(color: Colors.white),
              items: HolidayType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getHolidayIcon(type),
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type.displayName,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedType = value!);
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Type indicator banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _getHolidayColor(_selectedType).withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  _getHolidayIcon(_selectedType),
                  color: _getHolidayColor(_selectedType),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adding ${_selectedType.displayName}',
                        style: AppTextStyles.h6.copyWith(
                          color: _getHolidayColor(_selectedType),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Select a date from the calendar below',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Calendar
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.shadowDark,
                borderRadius: AppRadius.radiusLG,
                boxShadow: AppShadows.card,
              ),
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
                onDateChanged: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              ),
            ),
          ),
          
          // Selected date info and continue button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Selected date display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getHolidayColor(_selectedType).withValues(alpha: 0.1),
                      border: Border.all(
                        color: _getHolidayColor(_selectedType).withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Selected Date',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _getHolidayColor(_selectedType),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: _getHolidayColor(_selectedType),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate),
                              style: AppTextStyles.h6.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        // Show existing holiday warning if any
                        _buildExistingHolidayWarning(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _proceedToHolidayForm(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getHolidayColor(_selectedType),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_forward),
                          const SizedBox(width: 8),
                          const Text(
                            'Continue to Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingHolidayWarning() {
    final existingHoliday = _getExistingHolidayForDate(_selectedDate);
    
    if (existingHoliday != null) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber,
              color: Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Holiday "${existingHoliday.name}" already exists on this date',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Holiday? _getExistingHolidayForDate(DateTime date) {
    try {
      return widget.existingHolidays.firstWhere(
        (holiday) =>
            holiday.date.year == date.year &&
            holiday.date.month == date.month &&
            holiday.date.day == date.day,
      );
    } catch (e) {
      return null;
    }
  }

  void _proceedToHolidayForm() {
    final existingHoliday = _getExistingHolidayForDate(_selectedDate);
    
    if (existingHoliday != null) {
      // Show replacement confirmation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace Existing Holiday?'),
          content: Text(
            'There is already a holiday "${existingHoliday.name}" on ${DateFormat('MMM dd, yyyy').format(_selectedDate)}.\n\nDo you want to replace it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToHolidayForm();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
    } else {
      _navigateToHolidayForm();
    }
  }

  void _navigateToHolidayForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddHolidayFormScreen(
          selectedDate: _selectedDate,
          selectedType: _selectedType,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // Holiday was saved, return to holiday management with refresh signal
        Navigator.pop(context, true);
      }
    });
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

class AddHolidayFormScreen extends StatefulWidget {
  final DateTime selectedDate;
  final HolidayType selectedType;

  const AddHolidayFormScreen({
    super.key,
    required this.selectedDate,
    required this.selectedType,
  });

  @override
  State<AddHolidayFormScreen> createState() => _AddHolidayFormScreenState();
}

class _AddHolidayFormScreenState extends State<AddHolidayFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final HolidayService _holidayService = HolidayService();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Holiday Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Date confirmation banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: _getHolidayColor(widget.selectedType).withValues(alpha: 0.1),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 48,
                    color: _getHolidayColor(widget.selectedType),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DateFormat('EEEE').format(widget.selectedDate),
                    style: AppTextStyles.h5.copyWith(
                      color: _getHolidayColor(widget.selectedType),
                    ),
                  ),
                  Text(
                    DateFormat('MMMM dd, yyyy').format(widget.selectedDate),
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getHolidayColor(widget.selectedType),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.selectedType.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Form fields
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Holiday Information',
                      style: AppTextStyles.h6.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Holiday name field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Holiday Name *',
                        hintText: 'e.g., New Year\'s Day, Diwali, Company Day',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          _getHolidayIcon(widget.selectedType),
                          color: _getHolidayColor(widget.selectedType),
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter holiday name';
                        }
                        return null;
                      },
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 20),
                    
                    // Description field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Add details about this holiday...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 30),
                    
                    // Holiday type info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Holiday Type Information',
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getTypeDescription(widget.selectedType),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Save button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveHoliday,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getHolidayColor(widget.selectedType),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Saving Holiday...'),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save),
                              SizedBox(width: 8),
                              Text(
                                'Save Holiday',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeDescription(HolidayType type) {
    switch (type) {
      case HolidayType.government:
        return 'National and federal holidays that are mandatory for all employees.';
      case HolidayType.optional:
        return 'Holidays that employees can choose to observe based on their allocated quota.';
      case HolidayType.uncertain:
        return 'Tentative holidays with dates or observance that may change.';
    }
  }

  Future<void> _saveHoliday() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final holiday = Holiday(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          date: widget.selectedDate,
          type: widget.selectedType,
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
        );
        
        await _holidayService.addHoliday(holiday);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Holiday "${holiday.name}" added successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save holiday: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
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
