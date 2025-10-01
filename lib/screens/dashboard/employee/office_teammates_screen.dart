import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/employee_service.dart';

class OfficeTeammatesScreen extends StatefulWidget {
  const OfficeTeammatesScreen({super.key});

  @override
  State<OfficeTeammatesScreen> createState() => _OfficeTeammatesScreenState();
}

class _OfficeTeammatesScreenState extends State<OfficeTeammatesScreen> {
  final EmployeeService _employeeService = EmployeeService();
  List<Map<String, dynamic>> _teammates = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredTeammates = [];

  @override
  void initState() {
    super.initState();
    _loadTeammates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeammates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final employeesList = await _employeeService.getTeammates();
      
      if (mounted) {
        // Filter only active employees (exclude admin, hr, manager)
        final activeTeammates = employeesList.where((teammate) => 
          teammate['isActive'] == true && 
          teammate['role']?.toString().toLowerCase() == 'employee'
        ).toList();
        
        setState(() {
          _teammates = activeTeammates;
          _filteredTeammates = activeTeammates;
          _errorMessage = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading teammates: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _filterTeammates(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTeammates = _teammates;
      } else {
        _filteredTeammates = _teammates.where((teammate) {
          final name = teammate['name']?.toString().toLowerCase() ?? '';
          final email = teammate['email']?.toString().toLowerCase() ?? '';
          final empCode = teammate['empCode']?.toString().toLowerCase() ?? '';
          final role = teammate['role']?.toString().toLowerCase() ?? '';
          final department = teammate['department']?.toString().toLowerCase() ?? '';
          
          return name.contains(query.toLowerCase()) ||
              email.contains(query.toLowerCase()) ||
              empCode.contains(query.toLowerCase()) ||
              role.contains(query.toLowerCase()) ||
              department.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _showSnackBar('Phone number not available', Colors.orange);
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showSnackBar('Cannot make phone calls on this device', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error making phone call: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Office Teammates',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeammates,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterTeammates,
              decoration: InputDecoration(
                hintText: 'Search teammates...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // Team Count Info
          if (!_isLoading && _teammates.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_filteredTeammates.length} of ${_teammates.length} teammates',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // Teammates List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTeammates,
              color: const Color(0xFF4285F4),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/loading.json',
              height: 100,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading teammates...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading teammates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTeammates,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_filteredTeammates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty ? 'No teammates found' : 'No active teammates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _searchController.text.isNotEmpty 
                    ? 'Try adjusting your search criteria'
                    : 'No active team members found in the system',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: ListView.builder(
        itemCount: _filteredTeammates.length,
        itemBuilder: (context, index) {
          final teammate = _filteredTeammates[index];
          return _buildTeammateListItem(teammate);
        },
      ),
    );
  }

  Widget _buildTeammateListItem(Map<String, dynamic> teammate) {
    final name = teammate['name']?.toString() ?? 'Unknown';
    final email = teammate['email']?.toString() ?? 'No email';
    final phone = teammate['phone']?.toString() ?? 'No phone';
    final department = teammate['department']?.toString() ?? 'No department';
    final designation = teammate['designation']?.toString() ?? 'No designation';
    final empCode = teammate['empCode']?.toString() ?? 'N/A';
    final role = teammate['role']?.toString() ?? 'employee';
    
    return InkWell(
      onTap: () {
        _showTeammateDetails(teammate);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 28,
              backgroundColor: _getAvatarColor(name),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Teammate Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: $empCode • Dept: $department',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (designation != 'No designation') ...[
                    const SizedBox(height: 2),
                    Text(
                      'Designation: $designation',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Call Button
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: phone != 'No phone' ? () => _makePhoneCall(phone) : null,
                icon: Icon(
                  Icons.call,
                  color: phone != 'No phone' ? const Color(0xFF4285F4) : Colors.grey[400],
                  size: 22,
                ),
                tooltip: phone != 'No phone' ? 'Call $name' : 'No phone number',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTeammateDetails(Map<String, dynamic> teammate) {
    final name = teammate['name']?.toString() ?? 'Unknown';
    final email = teammate['email']?.toString() ?? 'No email';
    final phone = teammate['phone']?.toString() ?? 'No phone';
    final department = teammate['department']?.toString() ?? 'No department';
    final designation = teammate['designation']?.toString() ?? 'No designation';
    final empCode = teammate['empCode']?.toString() ?? 'N/A';
    final role = teammate['role']?.toString() ?? 'employee';
    final dateOfBirth = teammate['dateOfBirth']?.toString();
    
    String formattedDOB = 'Not available';
    if (dateOfBirth != null && dateOfBirth.isNotEmpty) {
      try {
        final date = DateTime.parse(dateOfBirth);
        formattedDOB = '${date.day}/${date.month}/${date.year}';
      } catch (e) {
        formattedDOB = 'Invalid date';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _getAvatarColor(name),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Details
            _buildDetailRow('Employee ID', empCode),
            _buildDetailRow('Email', email),
            _buildDetailRow('Phone', phone),
            _buildDetailRow('Department', department),
            _buildDetailRow('Designation', designation),
            _buildDetailRow('Date of Birth', formattedDOB),
            const SizedBox(height: 24),
            // Action Buttons
            Row(
              children: [
                if (phone != 'No phone') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _makePhoneCall(phone);
                      },
                      icon: const Icon(Icons.call),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String name) {
    // Generate a color based on the first letter of the name
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFEA4335),
      const Color(0xFFFBBC05),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFFF9800),
      const Color(0xFF795548),
    ];
    
    if (name.isEmpty) return colors[0];
    
    final index = name.toUpperCase().codeUnitAt(0) % colors.length;
    return colors[index];
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFFEA4335); // Red
      case 'hr':
        return const Color(0xFF9C27B0); // Purple
      case 'manager':
        return const Color(0xFFFF9800); // Orange
      case 'employee':
      default:
        return const Color(0xFF4285F4); // Blue
    }
  }
}
