import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final Map<String, dynamic> adminUser;

  const AdminUserDetailScreen({
    super.key,
    required this.adminUser,
  });

  @override
  Widget build(BuildContext context) {
    final name = adminUser['name'] ?? '';
    final email = adminUser['email'] ?? '';
    final role = adminUser['role'] ?? '';
    final phoneNumber = adminUser['phoneNumber'] ?? '';
    final designation = adminUser['designation'] ?? '';
    final address = adminUser['address'] ?? '';
    final employeeId = adminUser['employeeId'] ?? '';
    final isActive = adminUser['isActive'] ?? true;
    
    // Handle date fields
    DateTime? dateOfBirth;
    DateTime? createdAt;
    
    if (adminUser['dateOfBirth'] != null) {
      if (adminUser['dateOfBirth'] is Timestamp) {
        dateOfBirth = (adminUser['dateOfBirth'] as Timestamp).toDate();
      }
    }
    
    if (adminUser['createdAt'] != null) {
      if (adminUser['createdAt'] is Timestamp) {
        createdAt = (adminUser['createdAt'] as Timestamp).toDate();
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              // TODO: Navigate to edit admin user screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit admin user functionality - Coming Soon!'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card with Profile
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: role == 'hr' 
                        ? const Color(0xFF4A90E2).withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: role == 'hr' 
                            ? const Color(0xFF4A90E2)
                            : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Employee ID
                  if (employeeId.isNotEmpty)
                    Text(
                      'ID: $employeeId',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Role and Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: role == 'hr' 
                              ? const Color(0xFF4A90E2).withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: role == 'hr' 
                                ? const Color(0xFF4A90E2)
                                : Colors.orange,
                          ),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            color: role == 'hr' 
                                ? const Color(0xFF4A90E2)
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Contact Information
            _buildInfoSection(
              'Contact Information',
              [
                _buildInfoRow('Email', email, Icons.email),
                if (phoneNumber.isNotEmpty)
                  _buildInfoRow('Phone', phoneNumber, Icons.phone),
                if (address.isNotEmpty)
                  _buildInfoRow('Address', address, Icons.location_on),
              ],
            ),

            // Work Information
            _buildInfoSection(
              'Work Information',
              [
                _buildInfoRow('Role', role.toUpperCase(), Icons.work),
                if (designation.isNotEmpty)
                  _buildInfoRow('Designation', designation, Icons.badge),
                if (createdAt != null)
                  _buildInfoRow(
                    'Created Date',
                    '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                    Icons.calendar_today,
                  ),
              ],
            ),

            // Personal Information
            if (dateOfBirth != null)
              _buildInfoSection(
                'Personal Information',
                [
                  _buildInfoRow(
                    'Date of Birth',
                    '${dateOfBirth.day}/${dateOfBirth.month}/${dateOfBirth.year}',
                    Icons.cake,
                  ),
                  _buildInfoRow(
                    'Age',
                    _calculateAge(dateOfBirth).toString(),
                    Icons.person,
                  ),
                ],
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF4A90E2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
