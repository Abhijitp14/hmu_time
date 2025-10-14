import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/user_model.dart';

class PersonalInformationScreen extends StatefulWidget {
  final AppUser user;

  const PersonalInformationScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Information'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Picture Section
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFF4285F4),
                    child: Text(
                      widget.user.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Color(0xFF4285F4),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Information Cards
            _buildInfoCard('Full Name', widget.user.displayName, Icons.person),
            _buildInfoCard('Email Address', widget.user.email, Icons.email),
            _buildInfoCard('Employee ID', widget.user.displayEmpCode, Icons.badge),
            _buildInfoCard('Department', widget.user.department ?? 'Not specified', Icons.business),
            _buildInfoCard('Designation', widget.user.designation ?? 'Not specified', Icons.work),
            _buildInfoCard('Phone Number', widget.user.phoneNumber ?? 'Not provided', Icons.phone),
            if (widget.user.joiningDate != null)
              _buildInfoCard('Joining Date', DateFormat('MMM dd, yyyy').format(widget.user.joiningDate!), Icons.calendar_today),
            if (widget.user.dateOfBirth != null)
              _buildInfoCard('Date of Birth', DateFormat('MMM dd, yyyy').format(widget.user.dateOfBirth!), Icons.cake),
            _buildInfoCard('Employment Type', widget.user.employmentType ?? 'Not specified', Icons.work_outline),
            if (widget.user.workingHours != null)
              _buildInfoCard('Working Hours', '${widget.user.workingHours} hours/day', Icons.schedule),
            
            const SizedBox(height: 30),
            
            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _requestProfileUpdate,
                icon: const Icon(Icons.edit),
                label: const Text('Request Profile Update'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4285F4),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _requestProfileUpdate() {
    setState(() {
      _isLoading = true;
    });

    // Show info dialog about profile update request
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Update Request'),
        content: const Text(
          'To update your profile information, please contact your HR department or system administrator. They will assist you with updating your personal details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) {
      setState(() {
        _isLoading = false;
      });
    });
  }

}