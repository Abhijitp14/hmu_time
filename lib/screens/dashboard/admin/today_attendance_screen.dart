import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../services/attendance_service.dart';
import '../../../theme/theme.dart';

class TodayAttendanceScreen extends StatefulWidget {
  const TodayAttendanceScreen({super.key});

  @override
  State<TodayAttendanceScreen> createState() => _TodayAttendanceScreenState();
}

class _TodayAttendanceScreenState extends State<TodayAttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();

  List<TodayAttendanceRecord> _attendanceRecords = [];
  Map<String, int> _summary = {};
  bool _isLoading = true;
  bool _isSyncing = false;
  String _syncStatus = '';
  String _searchQuery = '';
  String _filterStatus = 'All'; // All, Present, Absent, Half Day, Late

  Timer? _refreshTimer;
  // bool _autoRefreshEnabled = true;
  // DateTime? _lastRefreshTime;
  // int _refreshCountdown = 60; // Reduced to 1 minute for real-time updates
  bool _isBackgroundRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadTodayAttendance();
    // _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // void _startPeriodicRefresh() {
  //   // Refresh every 1 minute (60 seconds) to get real-time check-out updates
  //   _refreshCountdown = 60;
  //   _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
  //     if (_autoRefreshEnabled && mounted) {
  //       setState(() {
  //         _refreshCountdown--;
  //       });

  //       if (_refreshCountdown <= 0 && !_isLoading && !_isBackgroundRefreshing) {
  //         _refreshDataQuietly();
  //         _refreshCountdown = 60; // Reset countdown to 1 minute
  //       }
  //     }
  //   });
  // }

  // void _toggleAutoRefresh() {
  //   setState(() {
  //     _autoRefreshEnabled = !_autoRefreshEnabled;
  //   });

  //   if (_autoRefreshEnabled) {
  //     _startPeriodicRefresh();
  //   } else {
  //     _refreshTimer?.cancel();
  //     _refreshCountdown = 60; // Reset countdown when disabled
  //   }
  // }

  // Future<void> _refreshDataQuietly() async {
  //   if (_isBackgroundRefreshing) return; // Prevent overlapping refreshes

  //   setState(() => _isBackgroundRefreshing = true);

  //   try {
  //     // Background refresh WITH sync to get real-time data
  //     print('🔄 Background refresh: Syncing real-time attendance data...');
  //     final records = await _attendanceService.getTodayAttendance(
  //       autoSync: true,
  //     );
  //     final summary = _attendanceService.calculateSummary(records);

  //     if (mounted) {
  //       setState(() {
  //         _attendanceRecords = records;
  //         _summary = summary;
  //         _lastRefreshTime = DateTime.now();
  //       });
  //       print(
  //         '✅ Background refresh completed: ${records.length} records updated',
  //       );

  //       // Show subtle success indicator
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: const Row(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               Icon(Icons.check_circle, color: Colors.white, size: 16),
  //               SizedBox(width: 8),
  //               Text('Attendance data updated'),
  //             ],
  //           ),
  //           backgroundColor: Colors.green,
  //           duration: const Duration(seconds: 2),
  //           behavior: SnackBarBehavior.floating,
  //           margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     // Log error but don't show UI notifications for background refresh
  //     print('❌ Background refresh failed: $e');

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Row(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               const Icon(Icons.warning, color: Colors.white, size: 16),
  //               const SizedBox(width: 8),
  //               Text(
  //                 'Auto-refresh failed: ${e.toString().length > 30 ? e.toString().substring(0, 30) + '...' : e}',
  //               ),
  //             ],
  //           ),
  //           backgroundColor: Colors.orange,
  //           duration: const Duration(seconds: 2),
  //           behavior: SnackBarBehavior.floating,
  //           margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
  //         ),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isBackgroundRefreshing = false);
  //     }
  //   }
  // }

  Future<void> _loadTodayAttendance({bool? quickLoad}) async {
    final bool shouldAutoSync = quickLoad == null ? true : !quickLoad;

    setState(() {
      _isLoading = true;
      _isSyncing = shouldAutoSync;
      _syncStatus = quickLoad == true
          ? 'Loading existing attendance data...'
          : shouldAutoSync
          ? 'Syncing employees with stale data...'
          : 'Fetching all employees\' attendance data...';
    });

    try {
      print(
        '🔄 Starting to load today\'s attendance (autoSync: $shouldAutoSync)...',
      );

      if (shouldAutoSync && mounted) {
        setState(
          () => _syncStatus = 'Checking which employees need data sync...',
        );
      }

      final records = await _attendanceService.getTodayAttendance(
        autoSync: shouldAutoSync,
      );

      if (mounted) {
        setState(() => _syncStatus = 'Processing attendance records...');
      }

      final summary = _attendanceService.calculateSummary(records);

      print('📊 Loaded ${records.length} attendance records');
      for (final record in records.take(3)) {
        print(
          '👤 ${record.employeeName} (${record.empCode}): ${record.status} - CheckIn: ${record.checkIn}, CheckOut: ${record.checkOut}',
        );
      }

      if (mounted) {
        setState(() {
          _attendanceRecords = records;
          _summary = summary;
          _isLoading = false;
          _isSyncing = false;
          _syncStatus = '';
          //_lastRefreshTime = DateTime.now();
        });

        // Show success message with appropriate text
        final message = quickLoad == true
            ? '⚡ Quick loaded ${records.length} employees (existing data)'
            : quickLoad == false
            ? '🔄 Force synced and loaded ${records.length} employees'
            : '✅ Smart loaded ${records.length} employees';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('❌ Error loading attendance: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSyncing = false;
          _syncStatus = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<TodayAttendanceRecord> get _filteredRecords {
    var filtered = _attendanceRecords.where((record) {
      // Search filter
      final matchesSearch =
          _searchQuery.isEmpty ||
          record.employeeName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          record.empCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          record.department.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      // Status filter
      switch (_filterStatus) {
        case 'Present':
          return record.isPresent;
        case 'Absent':
          return !record.isPresent;
        case 'Half Day':
          return record.status == 'Half Day';
        case 'Late':
          return record.isLate;
        default:
          return true;
      }
    }).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Attendance - ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            // if (_lastRefreshTime != null)
            //   Text(
            //     'Last updated: ${DateFormat('HH:mm:ss').format(_lastRefreshTime!)}',
            //     style: const TextStyle(
            //       fontSize: 12,
            //       fontWeight: FontWeight.w400,
            //     ),
            //   ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Auto-refresh toggle
          // IconButton(
          //   icon: Icon(
          //     _autoRefreshEnabled ? Icons.sync : Icons.sync_disabled,
          //     color: _autoRefreshEnabled ? Colors.white : Colors.white70,
          //   ),
          //   tooltip: _autoRefreshEnabled
          //       ? 'Auto-refresh ON (1min)'
          //       : 'Auto-refresh OFF',
          //   onPressed: _toggleAutoRefresh,
          // ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'quick_load':
                  _loadTodayAttendance(quickLoad: true);
                  break;
                case 'full_sync':
                  _loadTodayAttendance(quickLoad: false);
                  break;
                case 'refresh':
                  _loadTodayAttendance();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'quick_load',
                child: Row(
                  children: [
                    Icon(Icons.flash_on, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Quick Load'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'full_sync',
                child: Row(
                  children: [
                    Icon(Icons.sync, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Full Sync'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Smart Refresh'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          _buildSummarySection(),

          // Search and Filter
          _buildSearchAndFilter(),

          // Attendance List
          Expanded(
            child: _isLoading ? _buildLoadingState() : _buildAttendanceList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isBackgroundRefreshing
            ? null
            : () => _loadTodayAttendance(quickLoad: false),
        tooltip: _isBackgroundRefreshing ? 'Refreshing...' : 'Refresh Now',
        backgroundColor: _isBackgroundRefreshing
            ? Colors.grey
            : AppColors.primary,
        child: _isBackgroundRefreshing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Today\'s Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              // if (_autoRefreshEnabled && _lastRefreshTime != null)
              //   Column(
              //     crossAxisAlignment: CrossAxisAlignment.end,
              //     children: [
              //       Row(
              //         children: [
              //           if (_isBackgroundRefreshing) ...[
              //             SizedBox(
              //               width: 12,
              //               height: 12,
              //               child: CircularProgressIndicator(
              //                 strokeWidth: 2,
              //                 valueColor: AlwaysStoppedAnimation<Color>(
              //                   Colors.green.shade600,
              //                 ),
              //               ),
              //             ),
              //             const SizedBox(width: 4),
              //             Text(
              //               'Updating...',
              //               style: TextStyle(
              //                 fontSize: 12,
              //                 color: Colors.green.shade600,
              //                 fontWeight: FontWeight.w500,
              //               ),
              //             ),
              //           ] else ...[
              //             Icon(
              //               Icons.sync,
              //               size: 14,
              //               color: Colors.green.shade600,
              //             ),
              //             const SizedBox(width: 4),
              //             Text(
              //               'Auto-refresh',
              //               style: TextStyle(
              //                 fontSize: 12,
              //                 color: Colors.green.shade600,
              //                 fontWeight: FontWeight.w500,
              //               ),
              //             ),
              //           ],
              //         ],
              //       ),
              //       if (!_isBackgroundRefreshing)
              //         Text(
              //           'Next in ${_refreshCountdown}s',
              //           style: TextStyle(
              //             fontSize: 10,
              //             color: Colors.grey.shade600,
              //           ),
              //         ),
              //     ],
              //   ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total',
                  _summary['total']?.toString() ?? '0',
                  Colors.blue,
                  Icons.people,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Present',
                  _summary['present']?.toString() ?? '0',
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Absent',
                  _summary['absent']?.toString() ?? '0',
                  Colors.red,
                  Icons.cancel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Late',
                  _summary['late']?.toString() ?? '0',
                  Colors.orange,
                  Icons.schedule,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String count,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, emp code, or department...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Present', 'Absent', 'Half Day', 'Late'].map((
                filter,
              ) {
                final isSelected = _filterStatus == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _filterStatus = filter);
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: AppColors.primary.withOpacity(0.2),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _isSyncing ? _syncStatus : 'Loading today\'s attendance...',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (_isSyncing) ...[
            const SizedBox(height: 8),
            const Text(
              'This may take a few moments...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    final filteredRecords = _filteredRecords;

    if (filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _filterStatus != 'All'
                  ? 'No employees match the current filters'
                  : 'No attendance records found for today',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadTodayAttendance(quickLoad: true);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredRecords.length,
        itemBuilder: (context, index) {
          final record = filteredRecords[index];
          return _buildAttendanceCard(record);
        },
      ),
    );
  }

  Widget _buildAttendanceCard(TodayAttendanceRecord record) {
    final statusColor = _getStatusColor(record);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee Info Row
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Text(
                    record.employeeName.isNotEmpty
                        ? record.employeeName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${record.empCode} • ${record.department}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        record.designation,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(record),
              ],
            ),

            if (record.isPresent) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Punch Times
              Row(
                children: [
                  Expanded(
                    child: _buildTimeInfo(
                      'Check In',
                      record.checkIn,
                      Icons.login,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeInfo(
                      'Check Out',
                      record.checkOut,
                      Icons.logout,
                      record.checkOut != null ? Colors.orange : Colors.grey,
                      isCheckOut: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Total Hours and Status Details
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Total: ${record.totalHours.toStringAsFixed(1)}h',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  if (record.isLate)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LATE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),

              if (record.punches.length > 2) ...[
                const SizedBox(height: 8),
                Text(
                  '${record.punches.length} punch records',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(TodayAttendanceRecord record) {
    final statusColor = _getStatusColor(record);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        record.status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: statusColor,
        ),
      ),
    );
  }

  Widget _buildTimeInfo(
    String label,
    DateTime? time,
    IconData icon,
    Color color, {
    bool isCheckOut = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isCheckOut && time == null)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PENDING',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          time != null
              ? DateFormat('HH:mm').format(time)
              : isCheckOut
              ? 'Pending'
              : '--:--',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: time != null
                ? color
                : (isCheckOut ? Colors.blue.shade600 : Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(TodayAttendanceRecord record) {
    if (!record.isPresent) return Colors.red;

    switch (record.status) {
      case 'Full Day':
        return Colors.green;
      case 'Half Day':
        return Colors.orange;
      case 'Incomplete':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
