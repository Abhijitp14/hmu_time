import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/user_model.dart';
import '../../../services/employee_service.dart';
import '../../../services/leave_service.dart';
import '../../../services/biometric_service.dart';
import 'employee_attendance_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  final AppUser user;

  const ReportsScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EmployeeService _employeeService = EmployeeService();
  final LeaveService _leaveService = LeaveService();
  final BiometricService _biometricService = BiometricService();

  List<AppUser> _employees = [];
  List<AdminLeaveRequest> _leaveRequests = [];
  List<AttendanceReportData> _attendanceData = [];

  bool _isLoadingAttendance = true;
  bool _isLoadingLeaves = true;

  DateTime _selectedMonth = DateTime.now();
  List<DateTime> _availableMonths = [];
  String? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupAvailableMonths();
    _loadEmployees();
  }

  void _setupAvailableMonths() {
    _availableMonths = [];
    final now = DateTime.now();
    for (int i = 0; i < 3; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      _availableMonths.add(month);
    }
    _selectedMonth = _availableMonths.first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoadingAttendance = true);
    try {
      final employeesData = await _employeeService.getEmployees();
      final employees = employeesData.map((data) => AppUser.fromJson(data)).toList();
      _employees = employees.where((emp) => emp.role == UserRole.employee).toList();
      _employees.sort((a, b) => a.name.compareTo(b.name));
      _loadReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading employees: $e')),
        );
      }
    }
  }

  void _loadReports() {
    _loadAttendanceReport();
    _loadLeaveReport();
  }

  Future<void> _loadAttendanceReport() async {
    setState(() => _isLoadingAttendance = true);
    try {
      final data = <AttendanceReportData>[];

      final employeesToProcess = _selectedEmployeeId != null
          ? _employees.where((e) => e.id == _selectedEmployeeId).toList()
          : _employees.toList();

      for (final employee in employeesToProcess) {
        data.add(AttendanceReportData(
          employee: employee,
          period: DateFormat('MMM yyyy').format(_selectedMonth),
        ));
      }

      setState(() {
        _attendanceData = data;
        _isLoadingAttendance = false;
      });
    } catch (e) {
      setState(() => _isLoadingAttendance = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance report: $e')),
        );
      }
    }
  }

  Future<void> _loadLeaveReport() async {
    setState(() => _isLoadingLeaves = true);
    try {
      final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      List<AdminLeaveRequest> allRequests = [];

      for (final employee in _employees) {
        if (_selectedEmployeeId != null && employee.id != _selectedEmployeeId) {
          continue;
        }

        if (employee.empCode != null) {
          final result = await _leaveService.getAllEmployeeLeaveRequests(
            employeeId: employee.empCode!,
            limit: 100,
          );

          if (result.success) {
            final filteredRequests = result.requests.where((request) {
              final requestStartDate = DateTime.parse(request.startDate);
              final requestEndDate = DateTime.parse(request.endDate);
              return !(requestStartDate.isAfter(endDate) ||
                  requestEndDate.isBefore(startDate));
            }).toList();

            allRequests.addAll(filteredRequests);
          }
        }
      }

      allRequests.sort((a, b) =>
          DateTime.parse(b.startDate).compareTo(DateTime.parse(a.startDate)));

      setState(() {
        _leaveRequests = allRequests;
        _isLoadingLeaves = false;
      });
    } catch (e) {
      setState(() => _isLoadingLeaves = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leave report: $e')),
        );
      }
    }
  }

  void _onEmployeeTap(AppUser employee) async {
    if (employee.empCode == null || employee.empCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee code not available. Cannot sync attendance data.'),
          backgroundColor: Colors.orange,
        ),
      );
      
      // Still navigate to detail screen even without sync
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmployeeAttendanceDetailScreen(
            employee: employee,
            selectedMonth: _selectedMonth,
          ),
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text('Syncing ${employee.name}\'s attendance...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Calculate date range for selected month
      final fromDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final toDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      // Sync biometric data for the selected month
      final syncResult = await _biometricService.syncBiometricData(
        empCode: employee.empCode!,
        fromDate: fromDate,
        toDate: toDate,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (syncResult.success) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Synced ${syncResult.recordsProcessed} records for ${employee.name}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Show warning but still proceed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Sync completed with issues for ${employee.name}',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message but still proceed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to sync ${employee.name}\'s attendance: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    // Navigate to detail screen regardless of sync result
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmployeeAttendanceDetailScreen(
            employee: employee,
            selectedMonth: _selectedMonth,
          ),
        ),
      );
    }
  }

  Future<void> _syncAllEmployeesAttendance() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sync All Employees'),
          content: Text(
            'This will sync attendance data for all ${_employees.length} employees for ${DateFormat('MMMM yyyy').format(_selectedMonth)}. This may take a few minutes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sync All'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Calculate date range for selected month
    final fromDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final toDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    // Show progress dialog
    int processedCount = 0;
    int successCount = 0;
    int failedCount = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text('Syncing employee attendance...'),
                    const SizedBox(height: 10),
                    Text('$processedCount / ${_employees.length}'),
                    const SizedBox(height: 10),
                    Text('Success: $successCount, Failed: $failedCount'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Process employees with valid empCode
    final validEmployees = _employees.where((emp) => 
        emp.empCode != null && emp.empCode!.isNotEmpty).toList();

    for (final employee in validEmployees) {
      try {
        final syncResult = await _biometricService.syncBiometricData(
          empCode: employee.empCode!,
          fromDate: fromDate,
          toDate: toDate,
        );

        if (syncResult.success) {
          successCount++;
        } else {
          failedCount++;
        }
      } catch (e) {
        print('Failed to sync ${employee.name}: $e');
        failedCount++;
      }

      processedCount++;

      // Update progress dialog
      if (mounted) {
        // Force rebuild of the dialog to show updated progress
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text('Syncing employee attendance...'),
                    const SizedBox(height: 10),
                    Text('$processedCount / ${validEmployees.length}'),
                    const SizedBox(height: 10),
                    Text('Success: $successCount, Failed: $failedCount'),
                  ],
                ),
              ),
            );
          },
        );
      }
    }

    // Close progress dialog
    if (mounted) {
      Navigator.of(context).pop();

      // Show completion message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync completed! Success: $successCount, Failed: $failedCount',
          ),
          backgroundColor: failedCount == 0 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync All Employee Attendance',
            onPressed: _syncAllEmployeesAttendance,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Attendance'),
            Tab(text: 'Leave'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAttendanceTab(),
                _buildLeaveTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Month:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButton<DateTime>(
                        value: _selectedMonth,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _availableMonths.map((month) {
                          return DropdownMenuItem(
                            value: month,
                            child: Text(DateFormat('MMMM yyyy').format(month)),
                          );
                        }).toList(),
                        onChanged: (DateTime? newMonth) {
                          if (newMonth != null) {
                            setState(() {
                              _selectedMonth = newMonth;
                            });
                            _loadReports();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Employee:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButton<String?>(
                        value: _selectedEmployeeId,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: const Text('All Employees'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Employees'),
                          ),
                          ..._employees.map((employee) {
                            return DropdownMenuItem(
                              value: employee.id,
                              child: Text(employee.name),
                            );
                          }).toList(),
                        ],
                        onChanged: (String? employeeId) {
                          setState(() {
                            _selectedEmployeeId = employeeId;
                          });
                          _loadReports();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    if (_isLoadingAttendance) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_attendanceData.isEmpty) {
      return const Center(
        child: Text(
          'No attendance data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _attendanceData.length,
      itemBuilder: (context, index) {
        final data = _attendanceData[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                data.employee.name.isNotEmpty
                    ? data.employee.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              data.employee.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Employee Code: ${data.employee.empCode ?? 'N/A'}'),
                Text('Department: ${data.employee.department}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.sync,
                      size: 14,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to sync & view details',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_sync,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios),
              ],
            ),
            onTap: () => _onEmployeeTap(data.employee),
          ),
        );
      },
    );
  }

  Widget _buildLeaveTab() {
    if (_isLoadingLeaves) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_leaveRequests.isEmpty) {
      return const Center(
        child: Text(
          'No leave requests found for the selected period',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaveRequests.length,
      itemBuilder: (context, index) {
        final request = _leaveRequests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      request.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(request.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        request.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Leave Type: ${request.leaveType}'),
                Text(
                    'Duration: ${DateFormat('MMM dd').format(DateTime.parse(request.startDate))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(request.endDate))}'),
                if (request.reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Reason: ${request.reason}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class AttendanceReportData {
  final AppUser employee;
  final String period;

  AttendanceReportData({
    required this.employee,
    required this.period,
  });
}
