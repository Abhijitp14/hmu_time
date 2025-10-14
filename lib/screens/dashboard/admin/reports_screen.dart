import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../models/user_model.dart';
import '../../../services/employee_service.dart';

class ReportsScreen extends StatefulWidget {
  final AppUser user;

  const ReportsScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EmployeeService _employeeService = EmployeeService();
  
  // Date Range Selection
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Report Data
  List<AttendanceReportData> _attendanceData = [];
  List<LeaveReportData> _leaveData = [];
  List<WorkingHoursReportData> _workingHoursData = [];
  List<AppUser> _employees = [];
  
  bool _isLoadingAttendance = false;
  bool _isLoadingLeaves = false;
  bool _isLoadingWorkingHours = false;
  String? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEmployees();
    _loadAllReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final employeesData = await _employeeService.getEmployees();
      final employees = employeesData.map((data) => AppUser.fromJson(data)).toList();
      setState(() => _employees = employees);
    } catch (e) {
      _showMessage('Failed to load employees: $e', isError: true);
    }
  }

  Future<void> _loadAllReports() async {
    await Future.wait([
      _loadAttendanceReport(),
      _loadLeaveReport(),
      _loadWorkingHoursReport(),
    ]);
  }

  Future<void> _loadAttendanceReport() async {
    setState(() => _isLoadingAttendance = true);
    try {
      Query query = _firestore.collection('attendance')
          .where('date', isGreaterThanOrEqualTo: _startDate)
          .where('date', isLessThanOrEqualTo: _endDate);
      
      if (_selectedEmployeeId != null) {
        query = query.where('employeeId', isEqualTo: _selectedEmployeeId);
      }

      final snapshot = await query.get();
      final data = <String, AttendanceReportData>{};

      for (final doc in snapshot.docs) {
        final docData = doc.data() as Map<String, dynamic>;
        final employeeId = docData['employeeId'] as String;
        final date = (docData['date'] as Timestamp).toDate();

        final isPresent = docData['isPresent'] ?? false;
        final isLate = docData['isLate'] ?? false;
        final workingHours = (docData['workingHours'] ?? 0.0).toDouble();

        final key = _selectedEmployeeId != null ? employeeId : '$employeeId-${DateFormat('yyyy-MM').format(date)}';
        
        if (!data.containsKey(key)) {
          final employee = _employees.firstWhere((e) => e.id == employeeId, orElse: () => AppUser(
            id: employeeId,
            name: 'Unknown Employee',
            email: '',
            role: UserRole.employee,
            createdAt: DateTime.now(),
          ));
          
          data[key] = AttendanceReportData(
            employee: employee,
            period: _selectedEmployeeId != null ? 'Selected Period' : DateFormat('MMM yyyy').format(date),
            totalDays: 0,
            presentDays: 0,
            absentDays: 0,
            lateDays: 0,
            totalWorkingHours: 0.0,
            averageWorkingHours: 0.0,
            attendancePercentage: 0.0,
          );
        }

        data[key]!.totalDays++;
        if (isPresent) {
          data[key]!.presentDays++;
          data[key]!.totalWorkingHours += workingHours;
        } else {
          data[key]!.absentDays++;
        }
        if (isLate) {
          data[key]!.lateDays++;
        }
      }

      // Calculate percentages and averages
      for (final reportData in data.values) {
        reportData.attendancePercentage = reportData.totalDays > 0 
            ? (reportData.presentDays / reportData.totalDays) * 100 
            : 0.0;
        reportData.averageWorkingHours = reportData.presentDays > 0 
            ? reportData.totalWorkingHours / reportData.presentDays 
            : 0.0;
      }

      setState(() => _attendanceData = data.values.toList()..sort((a, b) => b.attendancePercentage.compareTo(a.attendancePercentage)));
    } catch (e) {
      _showMessage('Failed to load attendance report: $e', isError: true);
    } finally {
      setState(() => _isLoadingAttendance = false);
    }
  }

  Future<void> _loadLeaveReport() async {
    setState(() => _isLoadingLeaves = true);
    try {
      Query query = _firestore.collection('leaves')
          .where('startDate', isGreaterThanOrEqualTo: _startDate)
          .where('startDate', isLessThanOrEqualTo: _endDate);
      
      if (_selectedEmployeeId != null) {
        query = query.where('employeeId', isEqualTo: _selectedEmployeeId);
      }

      final snapshot = await query.get();
      final data = <String, LeaveReportData>{};

      for (final doc in snapshot.docs) {
        final docData = doc.data() as Map<String, dynamic>;
        final employeeId = docData['employeeId'] as String;
        final leaveType = docData['leaveType'] as String;
        final status = docData['status'] as String;
        final days = (docData['days'] ?? 1).toDouble();

        if (!data.containsKey(employeeId)) {
          final employee = _employees.firstWhere((e) => e.id == employeeId, orElse: () => AppUser(
            id: employeeId,
            name: 'Unknown Employee',
            email: '',
            role: UserRole.employee,
            createdAt: DateTime.now(),
          ));
          
          data[employeeId] = LeaveReportData(
            employee: employee,
            casualLeaves: 0,
            sickLeaves: 0,
            paidLeaves: 0,
            optionalHolidays: 0,
            totalLeaves: 0,
            approvedLeaves: 0,
            pendingLeaves: 0,
            rejectedLeaves: 0,
          );
        }

        final leaveData = data[employeeId]!;
        leaveData.totalLeaves += days;

        switch (leaveType.toLowerCase()) {
          case 'casual':
          case 'casual leave':
            leaveData.casualLeaves += days;
            break;
          case 'sick':
          case 'sick leave':
            leaveData.sickLeaves += days;
            break;
          case 'paid':
          case 'paid leave':
            leaveData.paidLeaves += days;
            break;
          case 'optional':
          case 'optional holiday':
            leaveData.optionalHolidays += days;
            break;
        }

        switch (status.toLowerCase()) {
          case 'approved':
            leaveData.approvedLeaves += days;
            break;
          case 'pending':
            leaveData.pendingLeaves += days;
            break;
          case 'rejected':
            leaveData.rejectedLeaves += days;
            break;
        }
      }

      setState(() => _leaveData = data.values.toList()..sort((a, b) => b.totalLeaves.compareTo(a.totalLeaves)));
    } catch (e) {
      _showMessage('Failed to load leave report: $e', isError: true);
    } finally {
      setState(() => _isLoadingLeaves = false);
    }
  }

  Future<void> _loadWorkingHoursReport() async {
    setState(() => _isLoadingWorkingHours = true);
    try {
      Query query = _firestore.collection('attendance')
          .where('date', isGreaterThanOrEqualTo: _startDate)
          .where('date', isLessThanOrEqualTo: _endDate)
          .where('isPresent', isEqualTo: true);
      
      if (_selectedEmployeeId != null) {
        query = query.where('employeeId', isEqualTo: _selectedEmployeeId);
      }

      final snapshot = await query.get();
      final data = <String, WorkingHoursReportData>{};

      for (final doc in snapshot.docs) {
        final docData = doc.data() as Map<String, dynamic>;
        final employeeId = docData['employeeId'] as String;
        final workingHours = (docData['workingHours'] ?? 0.0).toDouble();
        final overtimeHours = (docData['overtimeHours'] ?? 0.0).toDouble();
        final isLate = docData['isLate'] ?? false;

        if (!data.containsKey(employeeId)) {
          final employee = _employees.firstWhere((e) => e.id == employeeId, orElse: () => AppUser(
            id: employeeId,
            name: 'Unknown Employee',
            email: '',
            role: UserRole.employee,
            createdAt: DateTime.now(),
          ));
          
          data[employeeId] = WorkingHoursReportData(
            employee: employee,
            totalWorkingHours: 0.0,
            totalOvertimeHours: 0.0,
            averageWorkingHours: 0.0,
            workingDays: 0,
            lateDays: 0,
            productivityScore: 0.0,
          );
        }

        final workingData = data[employeeId]!;
        workingData.totalWorkingHours += workingHours;
        workingData.totalOvertimeHours += overtimeHours;
        workingData.workingDays++;
        if (isLate) {
          workingData.lateDays++;
        }
      }

      // Calculate averages and productivity scores
      for (final workingData in data.values) {
        workingData.averageWorkingHours = workingData.workingDays > 0 
            ? workingData.totalWorkingHours / workingData.workingDays 
            : 0.0;
        
        // Productivity score based on average hours and punctuality
        final hoursScore = (workingData.averageWorkingHours / 8.0) * 70; // 70% weight for hours
        final punctualityScore = workingData.workingDays > 0 
            ? ((workingData.workingDays - workingData.lateDays) / workingData.workingDays) * 30 // 30% weight for punctuality
            : 0.0;
        workingData.productivityScore = (hoursScore + punctualityScore).clamp(0.0, 100.0);
      }

      setState(() => _workingHoursData = data.values.toList()..sort((a, b) => b.productivityScore.compareTo(a.productivityScore)));
    } catch (e) {
      _showMessage('Failed to load working hours report: $e', isError: true);
    } finally {
      setState(() => _isLoadingWorkingHours = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAllReports();
    }
  }

  Future<void> _exportReport() async {
    try {
      // This is a simplified export - in a real app, you'd use a proper CSV/Excel library
      final csvData = _generateCSVData();
      
      // Show export success message
      _showMessage('Report data ready for export (${csvData.length} records)', isError: false);
      
      // In a real implementation, you'd save this to a file or share it
      print('CSV Data:\n$csvData');
      
    } catch (e) {
      _showMessage('Failed to export report: $e', isError: true);
    }
  }

  String _generateCSVData() {
    final buffer = StringBuffer();
    
    // Add header
    buffer.writeln('Employee Name,Period,Attendance %,Present Days,Absent Days,Late Days,Working Hours,Avg Hours');
    
    // Add attendance data
    for (final data in _attendanceData) {
      buffer.writeln('${data.employee.name},${data.period},${data.attendancePercentage.toStringAsFixed(1)}%,'
          '${data.presentDays},${data.absentDays},${data.lateDays},'
          '${data.totalWorkingHours.toStringAsFixed(1)},${data.averageWorkingHours.toStringAsFixed(1)}');
    }
    
    return buffer.toString();
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _exportReport,
            icon: const Icon(Icons.download),
            tooltip: 'Export Report',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Attendance', icon: Icon(Icons.fingerprint, size: 20)),
            Tab(text: 'Leaves', icon: Icon(Icons.event_busy, size: 20)),
            Tab(text: 'Working Hours', icon: Icon(Icons.access_time, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFiltersSection(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAttendanceReport(),
                _buildLeaveReport(),
                _buildWorkingHoursReport(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildEmployeeFilter(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateRangeSelector(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadAllReports,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportReport,
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeFilter() {
    return DropdownButtonFormField<String?>(
      value: _selectedEmployeeId,
      decoration: const InputDecoration(
        labelText: 'Employee',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All Employees'),
        ),
        ..._employees.map((employee) => DropdownMenuItem<String?>(
          value: employee.id,
          child: Text(employee.name),
        )),
      ],
      onChanged: (value) {
        setState(() => _selectedEmployeeId = value);
        _loadAllReports();
      },
    );
  }

  Widget _buildDateRangeSelector() {
    return InkWell(
      onTap: _selectDateRange,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date Range',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceReport() {
    if (_isLoadingAttendance) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_attendanceData.isEmpty) {
      return _buildEmptyState('No attendance data found for the selected period.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _attendanceData.length,
      itemBuilder: (context, index) {
        final data = _attendanceData[index];
        return _buildAttendanceCard(data);
      },
    );
  }

  Widget _buildAttendanceCard(AttendanceReportData data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF4285F4),
                  child: Text(
                    data.employee.name.isNotEmpty ? data.employee.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.employee.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        data.period,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getAttendanceColor(data.attendancePercentage),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${data.attendancePercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Present',
                    '${data.presentDays}/${data.totalDays}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Absent',
                    '${data.absentDays}',
                    Icons.cancel,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Late',
                    '${data.lateDays}',
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Avg Hours',
                    '${data.averageWorkingHours.toStringAsFixed(1)}h',
                    Icons.access_time,
                    const Color(0xFF4285F4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveReport() {
    if (_isLoadingLeaves) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_leaveData.isEmpty) {
      return _buildEmptyState('No leave data found for the selected period.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaveData.length,
      itemBuilder: (context, index) {
        final data = _leaveData[index];
        return _buildLeaveCard(data);
      },
    );
  }

  Widget _buildLeaveCard(LeaveReportData data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF4285F4),
                  child: Text(
                    data.employee.name.isNotEmpty ? data.employee.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.employee.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Total: ${data.totalLeaves.toStringAsFixed(1)} days',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Casual',
                    '${data.casualLeaves.toStringAsFixed(0)}',
                    Icons.event,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Sick',
                    '${data.sickLeaves.toStringAsFixed(0)}',
                    Icons.local_hospital,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Paid',
                    '${data.paidLeaves.toStringAsFixed(0)}',
                    Icons.monetization_on,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Optional',
                    '${data.optionalHolidays.toStringAsFixed(0)}',
                    Icons.celebration,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Approved',
                    '${data.approvedLeaves.toStringAsFixed(0)}',
                    Icons.check,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Pending',
                    '${data.pendingLeaves.toStringAsFixed(0)}',
                    Icons.hourglass_empty,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Rejected',
                    '${data.rejectedLeaves.toStringAsFixed(0)}',
                    Icons.close,
                    Colors.red,
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingHoursReport() {
    if (_isLoadingWorkingHours) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_workingHoursData.isEmpty) {
      return _buildEmptyState('No working hours data found for the selected period.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workingHoursData.length,
      itemBuilder: (context, index) {
        final data = _workingHoursData[index];
        return _buildWorkingHoursCard(data);
      },
    );
  }

  Widget _buildWorkingHoursCard(WorkingHoursReportData data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF4285F4),
                  child: Text(
                    data.employee.name.isNotEmpty ? data.employee.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.employee.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Productivity: ${data.productivityScore.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: _getProductivityColor(data.productivityScore),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getProductivityColor(data.productivityScore),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${data.productivityScore.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Total Hours',
                    '${data.totalWorkingHours.toStringAsFixed(1)}h',
                    Icons.access_time,
                    const Color(0xFF4285F4),
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Avg/Day',
                    '${data.averageWorkingHours.toStringAsFixed(1)}h',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Overtime',
                    '${data.totalOvertimeHours.toStringAsFixed(1)}h',
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Late Days',
                    '${data.lateDays}/${data.workingDays}',
                    Icons.schedule_outlined,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadAllReports,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 75) return Colors.orange;
    return Colors.red;
  }

  Color _getProductivityColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}

// Data Models for Reports
class AttendanceReportData {
  final AppUser employee;
  final String period;
  int totalDays;
  int presentDays;
  int absentDays;
  int lateDays;
  double totalWorkingHours;
  double averageWorkingHours;
  double attendancePercentage;

  AttendanceReportData({
    required this.employee,
    required this.period,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.totalWorkingHours,
    required this.averageWorkingHours,
    required this.attendancePercentage,
  });
}

class LeaveReportData {
  final AppUser employee;
  double casualLeaves;
  double sickLeaves;
  double paidLeaves;
  double optionalHolidays;
  double totalLeaves;
  double approvedLeaves;
  double pendingLeaves;
  double rejectedLeaves;

  LeaveReportData({
    required this.employee,
    required this.casualLeaves,
    required this.sickLeaves,
    required this.paidLeaves,
    required this.optionalHolidays,
    required this.totalLeaves,
    required this.approvedLeaves,
    required this.pendingLeaves,
    required this.rejectedLeaves,
  });
}

class WorkingHoursReportData {
  final AppUser employee;
  double totalWorkingHours;
  double totalOvertimeHours;
  double averageWorkingHours;
  int workingDays;
  int lateDays;
  double productivityScore;

  WorkingHoursReportData({
    required this.employee,
    required this.totalWorkingHours,
    required this.totalOvertimeHours,
    required this.averageWorkingHours,
    required this.workingDays,
    required this.lateDays,
    required this.productivityScore,
  });
}