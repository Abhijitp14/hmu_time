import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../models/holiday_model.dart';
import '../../../services/holiday_service.dart';
import 'add_holiday_screen.dart';

class HolidayManagementScreen extends StatefulWidget {
  const HolidayManagementScreen({super.key});

  @override
  State<HolidayManagementScreen> createState() => _HolidayManagementScreenState();
}

class _HolidayManagementScreenState extends State<HolidayManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HolidayService _holidayService = HolidayService();
  
  List<Holiday> _holidays = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHolidays();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHolidays() async {
    try {
      setState(() => _isLoading = true);
      final holidays = await _holidayService.getHolidays();
      setState(() => _holidays = holidays);
    } catch (e) {
      _showErrorSnackBar('Failed to load holidays: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Holiday Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Government', icon: Icon(Icons.account_balance)),
            Tab(text: 'Optional', icon: Icon(Icons.event_available)),
            Tab(text: 'Uncertain', icon: Icon(Icons.help_outline)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHolidayList(HolidayType.government),
                _buildHolidayList(HolidayType.optional),
                _buildHolidayList(HolidayType.uncertain),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddHolidayDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHolidayList(HolidayType type) {
    final filteredHolidays = _holidays.where((h) => h.type == type).toList();
    
    if (filteredHolidays.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getHolidayIcon(type),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type.displayName.toLowerCase()} holidays',
              style: AppTextStyles.bodyLarge.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add a holiday',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHolidays,
      child: ListView.builder(
        padding: AppSpacing.paddingLG,
        itemCount: filteredHolidays.length,
        itemBuilder: (context, index) {
          final holiday = filteredHolidays[index];
          return _buildHolidayCard(holiday);
        },
      ),
    );
  }

  Widget _buildHolidayCard(Holiday holiday) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isUpcoming = holiday.date.isAfter(DateTime.now());
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getHolidayColor(holiday.type).withValues(alpha: 0.1),
          child: Icon(
            _getHolidayIcon(holiday.type),
            color: _getHolidayColor(holiday.type),
          ),
        ),
        title: Text(
          holiday.name,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(holiday.date)),
            if (holiday.description?.isNotEmpty ?? false)
              Text(
                holiday.description!,
                style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: const Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: const Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditHolidayDialog(holiday);
            } else if (value == 'delete') {
              _showDeleteConfirmDialog(holiday);
            }
          },
        ),
        tileColor: isUpcoming ? null : Colors.grey[50],
      ),
    );
  }

  void _showAddHolidayDialog() {
    final currentTabType = HolidayType.values[_tabController.index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddHolidayCalendarScreen(
          defaultType: currentTabType,
          existingHolidays: _holidays,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadHolidays(); // Refresh the list
      }
    });
  }



  void _showEditHolidayDialog(Holiday holiday) {
    showDialog(
      context: context,
      builder: (context) => HolidayDialog(
        holiday: holiday,
        defaultType: holiday.type,
        onSave: (savedHoliday) async {
          try {
            await _holidayService.updateHoliday(savedHoliday);
            _showSuccessSnackBar('Holiday updated successfully');
            _loadHolidays();
          } catch (e) {
            _showErrorSnackBar('Failed to update holiday: $e');
          }
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(Holiday holiday) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: Text('Are you sure you want to delete "${holiday.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _holidayService.deleteHoliday(holiday.id, holiday.type);
                _showSuccessSnackBar('Holiday deleted successfully');
                _loadHolidays();
              } catch (e) {
                _showErrorSnackBar('Failed to delete holiday: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
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



class HolidayDialog extends StatefulWidget {
  final Holiday? holiday;
  final HolidayType? defaultType;
  final Function(Holiday) onSave;

  const HolidayDialog({
    super.key,
    this.holiday,
    this.defaultType,
    required this.onSave,
  });

  @override
  State<HolidayDialog> createState() => _HolidayDialogState();
}



class _HolidayDialogState extends State<HolidayDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _selectedDate;
  HolidayType _selectedType = HolidayType.government;

  @override
  void initState() {
    super.initState();
    
    if (widget.holiday != null) {
      _nameController.text = widget.holiday!.name;
      _descriptionController.text = widget.holiday!.description ?? '';
      _selectedDate = widget.holiday!.date;
      _selectedType = widget.holiday!.type;
    } else {
      _selectedType = widget.defaultType ?? HolidayType.government;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.holiday != null ? 'Edit Holiday' : 'Add Holiday'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Holiday Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter holiday name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<HolidayType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Holiday Type',
                  border: OutlineInputBorder(),
                ),
                items: HolidayType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(_getHolidayIcon(type), size: 20),
                        const SizedBox(width: 8),
                        Text(type.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedType = value!);
                },
              ),
              const SizedBox(height: 16),
              
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                        : 'Select Date',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveHoliday,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  void _saveHoliday() {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      final holiday = Holiday(
        id: widget.holiday?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        date: _selectedDate!,
        type: _selectedType,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
      );
      
      widget.onSave(holiday);
      Navigator.pop(context);
    } else if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
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
}
