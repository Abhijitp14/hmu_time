import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../services/employee_service.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersListScreen extends StatefulWidget {
  const AdminUsersListScreen({Key? key}) : super(key: key);

  @override
  State<AdminUsersListScreen> createState() => _AdminUsersListScreenState();
}

class _AdminUsersListScreenState extends State<AdminUsersListScreen> {
  final EmployeeService _employeeService = EmployeeService();
  List<Map<String, dynamic>> _adminUsers = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredAdminUsers = [];

  @override
  void initState() {
    super.initState();
    _loadAdminUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final adminUsers = await _employeeService.getAdminUsers();
      setState(() {
        _adminUsers = adminUsers;
        _filteredAdminUsers = adminUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterAdminUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAdminUsers = _adminUsers;
      } else {
        _filteredAdminUsers = _adminUsers.where((user) {
          final name = user['name']?.toLowerCase() ?? '';
          final email = user['email']?.toLowerCase() ?? '';
          final role = user['role']?.toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) ||
              email.contains(query.toLowerCase()) ||
              role.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Admin Users',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              // TODO: Add app-level options
            },
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
              onChanged: _filterAdminUsers,
              decoration: InputDecoration(
                hintText: 'Search',
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
          // Admin Users List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAdminUsers,
              color: const Color(0xFF4A90E2),
              child: _buildBody(),
            ),
          ),
          // Add Admin Button
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to add admin user screen
                  Navigator.pushNamed(context, '/add-admin-user').then((_) {
                    _loadAdminUsers();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add Admin',
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
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Lottie.asset(
          'assets/animations/loading.json',
          height: 100,
          // fit: BoxFit.cover,
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
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
              'Error Loading Admin Users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAdminUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredAdminUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty ? 'No admin users found' : 'No HR or Managers Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty 
                  ? 'Try adjusting your search criteria'
                  : 'No HR or Manager accounts have been created yet.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: ListView.builder(
        itemCount: _filteredAdminUsers.length,
        itemBuilder: (context, index) {
          final adminUser = _filteredAdminUsers[index];
          return _buildAdminUserListItem(adminUser);
        },
      ),
    );
  }

  Widget _buildAdminUserListItem(Map<String, dynamic> adminUserData) {
    // Extract data directly from the map
    final name = adminUserData['name'] ?? '';
    final email = adminUserData['email'] ?? '';
    final role = adminUserData['role'] ?? '';
    final isActive = adminUserData['isActive'] ?? true;
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminUserDetailScreen(adminUser: adminUserData),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
          ),
        ),
        child: Row(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 24,
            backgroundColor: role == 'hr' 
                ? const Color(0xFF4A90E2).withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: role == 'hr' 
                    ? const Color(0xFF4A90E2)
                    : Colors.orange,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Admin User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: role == 'hr' 
                        ? const Color(0xFF4A90E2).withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      color: role == 'hr' 
                          ? const Color(0xFF4A90E2)
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Status Indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Three Dots Menu
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _editAdminUser(adminUserData);
                  break;
                case 'deactivate':
                  _showToggleStatusDialog(adminUserData);
                  break;
                case 'delete':
                  _showDeleteDialog(adminUserData);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'deactivate',
                child: Row(
                  children: [
                    Icon(
                      isActive ? Icons.block : Icons.check_circle,
                      size: 18,
                      color: isActive ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Text(isActive ? 'Deactivate' : 'Activate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
            icon: const Icon(
              Icons.more_vert,
              color: Colors.grey,
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _editAdminUser(Map<String, dynamic> adminUserData) {
    // TODO: Navigate to edit admin user screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit admin user functionality - Coming Soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showToggleStatusDialog(Map<String, dynamic> adminUserData) {
    final name = adminUserData['name'] ?? '';
    final isActive = adminUserData['isActive'] ?? true;
    final action = isActive ? 'deactivate' : 'activate';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.toUpperCase()} Admin User'),
        content: Text(
          'Are you sure you want to $action $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleAdminUserStatus(adminUserData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red : Colors.green,
            ),
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> adminUserData) {
    final name = adminUserData['name'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Admin User'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete $name?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All admin user data will be permanently deleted.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
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
            onPressed: () {
              Navigator.pop(context);
              _deleteAdminUser(adminUserData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleAdminUserStatus(Map<String, dynamic> adminUserData) {
    // TODO: Implement toggle admin user status
    final name = adminUserData['name'] ?? '';
    final isActive = adminUserData['isActive'] ?? true;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${isActive ? 'Deactivated' : 'Activated'} $name - Coming Soon!'),
        backgroundColor: isActive ? Colors.orange : Colors.green,
      ),
    );
  }

  void _deleteAdminUser(Map<String, dynamic> adminUserData) {
    // TODO: Implement delete admin user
    final name = adminUserData['name'] ?? '';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delete $name - Coming Soon!'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
