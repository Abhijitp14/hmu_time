import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/leave_service.dart';

class AdminLeaveRequestsScreen extends StatefulWidget {
  const AdminLeaveRequestsScreen({super.key});

  @override
  State<AdminLeaveRequestsScreen> createState() => _AdminLeaveRequestsScreenState();
}

class _AdminLeaveRequestsScreenState extends State<AdminLeaveRequestsScreen>
    with SingleTickerProviderStateMixin {
  final LeaveService _leaveService = LeaveService();
  
  late TabController _tabController;
  
  List<AdminLeaveRequest> _allRequests = [];
  List<AdminLeaveRequest> _filteredRequests = [];
  List<Map<String, String>> _employees = [];
  Map<String, int> _statistics = {};
  
  bool _isLoading = false;
  
  // Filter controls
  String _selectedStatus = 'all';
  String _selectedEmployee = 'all';
  String _selectedLeaveType = 'all';
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();

  // Helper method to safely format dates
  String _formatDate(dynamic date, String pattern) {
    if (date == null) return 'Unknown';
    
    DateTime dateTime;
    if (date is String) {
      try {
        dateTime = DateTime.parse(date);
        // If parsed as UTC, convert to local time
        if (dateTime.isUtc) {
          dateTime = dateTime.toLocal();
        }
      } catch (e) {
        return 'Invalid date';
      }
    } else if (date is DateTime) {
      dateTime = date;
      // If it's UTC, convert to local time
      if (dateTime.isUtc) {
        dateTime = dateTime.toLocal();
      }
    } else {
      return 'Invalid date format';
    }
    
    return DateFormat(pattern).format(dateTime);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadLeaveRequests(),
      _loadEmployees(),
      _loadStatistics(),
    ]);
  }

  Future<void> _loadLeaveRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _leaveService.getAllEmployeeLeaveRequests(
        limit: 500, // Load more data for filtering
      );

      if (result.success) {
        setState(() {
          _allRequests = result.requests;
          _filteredRequests = result.requests;
        });
      } else {
        _showErrorSnackBar('Failed to load leave requests: ${result.error}');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading leave requests: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await _leaveService.getAllEmployees();
      setState(() {
        _employees = employees;
      });
    } catch (e) {
      print('Error loading employees: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _leaveService.getLeaveStatistics();
      setState(() {
        _statistics = stats;
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredRequests = _allRequests.where((request) {
        // Status filter
        if (_selectedStatus != 'all' && request.status.toLowerCase() != _selectedStatus) {
          return false;
        }
        
        // Employee filter
        if (_selectedEmployee != 'all' && request.empCode != _selectedEmployee) {
          return false;
        }
        
        // Leave type filter
        if (_selectedLeaveType != 'all' && request.leaveType != _selectedLeaveType) {
          return false;
        }
        
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return request.employeeName.toLowerCase().contains(query) ||
                 request.empCode.toLowerCase().contains(query) ||
                 request.department.toLowerCase().contains(query) ||
                 request.reason.toLowerCase().contains(query);
        }
        
        return true;
      }).toList();
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Leave Requests'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          // isScrollable: true,
          tabs: [
            Tab(
              text: 'All Requests',
              icon: Badge(
                label: Text('${_allRequests.length}'),
                child: const Icon(Icons.list_alt),
              ),
            ),
            Tab(
              text: 'Pending',
              icon: Badge(
                label: Text('${_statistics['pending'] ?? 0}'),
                child: const Icon(Icons.pending_actions),
              ),
            ),
            Tab(
              text: 'Approved',
              icon: Badge(
                label: Text('${_statistics['approved'] ?? 0}'),
                child: const Icon(Icons.check_circle),
              ),
            ),
            Tab(
              text: 'Rejected',
              icon: Badge(
                label: Text('${_statistics['rejected'] ?? 0}'),
                child: const Icon(Icons.cancel),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Data'),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'refresh') {
                _refreshData();
              }
              // Add export functionality as needed
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllRequestsTab(),
          _buildPendingRequestsTab(),
          _buildApprovedRequestsTab(),
          _buildRejectedRequestsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _refreshData,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildApprovedRequestsTab() {
    final approvedRequests = _allRequests.where((r) => r.status.toLowerCase() == 'approved').toList();
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.shade50,
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${approvedRequests.length} approved leave request${approvedRequests.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: approvedRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pending_actions,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No approved requests',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Approved leave requests will appear here',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView.builder(
                    itemCount: approvedRequests.length,
                    itemBuilder: (context, index) {
                      return _buildLeaveRequestCard(approvedRequests[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRejectedRequestsTab() {
    final rejectedRequests = _allRequests.where((r) => r.status.toLowerCase() == 'rejected').toList();
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.red.shade50,
          child: Row(
            children: [
              Icon(Icons.cancel, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${rejectedRequests.length} rejected leave request${rejectedRequests.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: rejectedRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sentiment_satisfied,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No rejected requests',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Great! No leave requests have been rejected',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView.builder(
                    itemCount: rejectedRequests.length,
                    itemBuilder: (context, index) {
                      return _buildLeaveRequestCard(rejectedRequests[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAllRequestsTab() {
    return Column(
      children: [
        _buildFiltersSection(),
        Expanded(
          child: _buildLeaveRequestsList(),
        ),
      ],
    );
  }

  Widget _buildPendingRequestsTab() {
    final pendingRequests = _allRequests.where((r) => r.status.toLowerCase() == 'pending').toList();
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange.shade50,
          child: Row(
            children: [
              Icon(Icons.pending_actions, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${pendingRequests.length} pending leave request${pendingRequests.length != 1 ? 's' : ''} require${pendingRequests.length == 1 ? 's' : ''} attention',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: pendingRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pending requests',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All leave requests have been processed',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView.builder(
                    itemCount: pendingRequests.length,
                    itemBuilder: (context, index) {
                      return _buildLeaveRequestCard(pendingRequests[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, emp code, department, reason...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        _applyFilters();
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _applyFilters();
            },
          ),
          
          const SizedBox(height: 12),
          
          // Filter dropdowns row
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Status',
                  _selectedStatus,
                  [
                    {'value': 'all', 'label': 'All Status'},
                    {'value': 'pending', 'label': 'Pending'},
                    {'value': 'approved', 'label': 'Approved'},
                    {'value': 'rejected', 'label': 'Rejected'},
                  ],
                  (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  'Leave Type',
                  _selectedLeaveType,
                  [
                    {'value': 'all', 'label': 'All Types'},
                    {'value': 'SL', 'label': 'Sick Leave'},
                    {'value': 'CL', 'label': 'Casual Leave'},
                    {'value': 'PL', 'label': 'Paid Leave'},
                    {'value': 'OH', 'label': 'Optional Holiday'},
                    {'value': 'OL', 'label': 'Official Leave'},
                  ],
                  (value) {
                    setState(() {
                      _selectedLeaveType = value!;
                    });
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Employee dropdown
          _buildEmployeeDropdown(),
          
          // Results count
          const SizedBox(height: 8),
          Text(
            'Showing ${_filteredRequests.length} of ${_allRequests.length} requests',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String selectedValue,
    List<Map<String, String>> options,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: selectedValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: options.map((option) {
        return DropdownMenuItem(
          value: option['value'],
          child: Text(
            option['label']!,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      isDense: true,
    );
  }

  Widget _buildEmployeeDropdown() {
    final employeeOptions = [
      {'value': 'all', 'label': 'All Employees'},
      ..._employees.map((emp) => {
        'value': emp['empCode'] ?? '',
        'label': '${emp['name']} (${emp['empCode']} - ${emp['department']})',
      }),
    ];

    return DropdownButtonFormField<String>(
      value: _selectedEmployee,
      decoration: const InputDecoration(
        labelText: 'Employee',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: employeeOptions.map((option) {
        return DropdownMenuItem(
          value: option['value'],
          child: Text(
            option['label']!,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedEmployee = value!;
        });
        _applyFilters();
      },
      isExpanded: true,
    );
  }

  Widget _buildLeaveRequestsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No leave requests found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or refresh the data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: _filteredRequests.length,
        itemBuilder: (context, index) {
          return _buildLeaveRequestCard(_filteredRequests[index]);
        },
      ),
    );
  }

  Widget _buildLeaveRequestCard(AdminLeaveRequest request) {
    DateTime? startDate;
    DateTime? endDate;
    
    try {
      startDate = DateTime.parse(request.startDate);
      endDate = DateTime.parse(request.endDate);
    } catch (e) {
      print('Error parsing dates for request ${request.id}: $e');
      // Use fallback dates if parsing fails
      startDate = DateTime.now();
      endDate = DateTime.now();
    }
    
    Color statusColor = _getStatusColor(request.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showLeaveRequestDetails(request),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with employee info and status
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Text(
                      request.employeeName.substring(0, 1).toUpperCase(),
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
                          request.employeeName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${request.empCode} • ${request.department}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
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
              
              const SizedBox(height: 12),
              
              // Dates and duration
              Row(
                children: [
                  Icon(Icons.event, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${request.totalDays} day${request.totalDays > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Leave type and reason
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getLeaveTypeColor(request.leaveType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getLeaveTypeDisplayName(request.leaveType),
                      style: TextStyle(
                        color: _getLeaveTypeColor(request.leaveType),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (request.reason.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        request.reason,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Submitted date
              Text(
                'Submitted ${_formatDate(request.submittedDate, 'MMM d, yyyy h:mm a')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              
              // Action buttons for pending requests
              if (request.status.toLowerCase() == 'pending') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showRejectDialog(request),
                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showApproveDialog(request),
                      icon: const Icon(Icons.check, color: Colors.white, size: 18),
                      label: const Text('Accept', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getLeaveTypeColor(String leaveType) {
    switch (leaveType) {
      case 'SL':
        return Colors.red;
      case 'CL':
        return Colors.blue;
      case 'PL':
        return Colors.green;
      case 'OH':
        return Colors.purple;
      case 'OL':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _getLeaveTypeDisplayName(String leaveType) {
    switch (leaveType) {
      case 'SL':
        return 'Sick Leave';
      case 'CL':
        return 'Casual Leave';
      case 'PL':
        return 'Paid Leave';
      case 'OH':
        return 'Optional Holiday';
      case 'OL':
        return 'Official Leave';
      default:
        return leaveType;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showLeaveRequestDetails(AdminLeaveRequest request) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Leave Request Details',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Employee', request.employeeName),
                      _buildDetailRow('Employee Code', request.empCode),
                      _buildDetailRow('Department', request.department),
                      _buildDetailRow('Designation', request.designation),
                      _buildDetailRow('Leave Type', _getLeaveTypeDisplayName(request.leaveType)),
                      _buildDetailRow('Status', request.status.toUpperCase()),
                      _buildDetailRow('Start Date', _formatDate(request.startDate, 'EEEE, MMMM d, yyyy')),
                      _buildDetailRow('End Date', _formatDate(request.endDate, 'EEEE, MMMM d, yyyy')),
                      _buildDetailRow('Total Days', '${request.totalDays} day${request.totalDays > 1 ? 's' : ''}'),
                      _buildDetailRow('Days Deducted', '${request.daysToDeduct}'),
                      
                      if (request.reason.isNotEmpty)
                        _buildDetailRow('Reason', request.reason),
                      
                      if (request.submittedDate != null)
                        _buildDetailRow('Submitted', _formatDate(request.submittedDate, 'MMM d, yyyy h:mm a')),
                      
                      if (request.approvedDate != null)
                        _buildDetailRow('Approved On', _formatDate(request.approvedDate, 'MMM d, yyyy h:mm a')),
                      
                      if (request.approvedBy != null)
                        _buildDetailRow('Approved By', request.approvedBy!),
                      
                      if (request.rejectedDate != null)
                        _buildDetailRow('Rejected On', _formatDate(request.rejectedDate, 'MMM d, yyyy h:mm a')),
                      
                      if (request.rejectedBy != null)
                        _buildDetailRow('Rejected By', request.rejectedBy!),
                      
                      if (request.rejectionReason != null)
                        _buildDetailRow('Rejection Reason', request.rejectionReason!),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
    _applyFilters();
  }

  void _showApproveDialog(AdminLeaveRequest request) {
    final commentsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee: ${request.employeeName}'),
            Text('Leave Type: ${_getLeaveTypeDisplayName(request.leaveType)}'),
            Text('Duration: ${_formatDateRange(request.startDate, request.endDate)} (${request.totalDays} day${request.totalDays > 1 ? 's' : ''})'),
            const SizedBox(height: 16),
            TextField(
              controller: commentsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comments (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Add any comments for the approval...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _approveRequest(request, commentsController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(AdminLeaveRequest request) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee: ${request.employeeName}'),
            Text('Leave Type: ${_getLeaveTypeDisplayName(request.leaveType)}'),
            Text('Duration: ${_formatDateRange(request.startDate, request.endDate)} (${request.totalDays} day${request.totalDays > 1 ? 's' : ''})'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                border: OutlineInputBorder(),
                hintText: 'Please provide a reason for rejection...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a rejection reason')),
                );
                return;
              }
              Navigator.pop(context);
              await _rejectRequest(request, reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(AdminLeaveRequest request, String comments) async {
    try {
      setState(() => _isLoading = true);
      
      final success = await _leaveService.approveLeaveRequest(
        empCode: request.empCode,
        leaveType: request.leaveType,
        requestId: request.id,
        comments: comments.isNotEmpty ? comments : null,
      );
      
      if (success) {
        _showSuccessMessage('Leave request approved successfully');
        await _refreshData();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to approve request: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectRequest(AdminLeaveRequest request, String reason) async {
    try {
      setState(() => _isLoading = true);
      
      final success = await _leaveService.rejectLeaveRequest(
        empCode: request.empCode,
        leaveType: request.leaveType,
        requestId: request.id,
        reason: reason,
      );
      
      if (success) {
        _showSuccessMessage('Leave request rejected');
        await _refreshData();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to reject request: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Helper method to safely format date ranges
  String _formatDateRange(String startDateStr, String endDateStr) {
    try {
      final startDate = DateTime.parse(startDateStr);
      final endDate = DateTime.parse(endDateStr);
      return '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}';
    } catch (e) {
      print('Error parsing dates: $e');
      return 'Invalid dates';
    }
  }



  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}