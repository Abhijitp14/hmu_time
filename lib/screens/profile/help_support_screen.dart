import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/user_model.dart';

class HelpSupportScreen extends StatelessWidget {
  final AppUser user;

  const HelpSupportScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Help Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4285F4).withValues(alpha: 0.1),
                    const Color(0xFF4285F4).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.help_center,
                        color: const Color(0xFF4285F4),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Need Quick Help?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Browse our FAQ section or contact support directly. We\'re here to help you with any questions about the HMU Time app.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // FAQ Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildFAQItem(
              question: 'How do I mark my attendance?',
              answer: 'Use the biometric machine in your office to punch in when you arrive and punch out when you leave. Then go to the Home tab in the app and tap the sync button to download your attendance records. The app will automatically show your check-in and check-out times.',
            ),
            
            _buildFAQItem(
              question: 'How can I apply for leave?',
              answer: 'Navigate to the Leaves tab, tap the "+" button, select your leave type, choose dates, and submit your application with the required details.',
            ),
            
            _buildFAQItem(
              question: 'Why is my check-in marked as "Late"?',
              answer: 'Check-ins after 10:00 AM are automatically marked as late. If you believe this is incorrect, please contact your HR department.',
            ),
            
            _buildFAQItem(
              question: 'How do I change my password?',
              answer: 'Go to Profile > Security Settings, enter your current password, then set a new password. Make sure it\'s at least 6 characters long.',
            ),
            
            _buildFAQItem(
              question: 'Can I view my colleagues\' information?',
              answer: 'Yes, you can view basic information of your teammates in the Office tab. This helps you connect with your colleagues.',
            ),
            
            const SizedBox(height: 30),
            
            // Contact Support
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildContactOption(
              icon: Icons.email,
              title: 'Email Support',
              subtitle: 'hr@homesbuildings.com',
              onTap: () => _sendEmail(context, 'hr@homesbuildings.com'),
            ),
            
            _buildContactOption(
              icon: Icons.phone,
              title: 'Phone Support',
              subtitle: '+918793641948',
              onTap: () => _makePhoneCall(context, '+918793641948'),
            ),
            
            _buildContactOption(
              icon: Icons.bug_report,
              title: 'Report a Bug',
              subtitle: 'Help us improve the app',
              onTap: () => _reportBug(context),
            ),
            
            const SizedBox(height: 30),
            
            // App Information
            const Text(
              'App Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildInfoTile('App Version', '0.1.0'),
            _buildInfoTile('Last Updated', 'October 2025'),
            _buildInfoTile('Developer', 'HMU Time Team'),
            
            const SizedBox(height: 20),
            
            // Additional Resources
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Additional Resources',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildResourceLink('Privacy Policy', () => _openPrivacyPolicy(context)),
                  _buildResourceLink('Terms of Service', () => _openTermsOfService(context)),
                  _buildResourceLink('User Manual', () => _openUserManual(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4285F4).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF4285F4),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[600],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceLink(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4285F4),
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: const Color(0xFF4285F4),
            ),
          ],
        ),
      ),
    );
  }

  void _sendEmail(BuildContext context, String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'HMU Time App Support Request',
        'body': 'Hi Support Team,\n\nI need help with...\n\nUser ID: ${user.displayEmpCode}\nDevice: Mobile App\n\nThanks!',
      },
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        // Show manual email information if no email app is available
        _showEmailInfo(context, email);
      }
    } catch (e) {
      // If launching fails, show manual email information
      _showEmailInfo(context, email);
    }
  }

  void _showEmailInfo(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No email app found. Please send an email manually to:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          email,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Subject: HMU Time App Support Request'),
                  const SizedBox(height: 4),
                  Text('User ID: ${user.displayEmpCode}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _makePhoneCall(BuildContext context, String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      } else {
        _showPhoneInfo(context, phone);
      }
    } catch (e) {
      _showPhoneInfo(context, phone);
    }
  }

  void _showPhoneInfo(BuildContext context, String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unable to make call directly. Please call us at:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      phone,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Support Hours: Monday - Friday, 9 AM - 6 PM', 
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _reportBug(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report a Bug'),
        content: const Text(
          'Thank you for helping us improve! Please email us at hr@homesbuildings.com with details about the bug you encountered, including:\n\n• What you were trying to do\n• What went wrong\n• Steps to reproduce the issue\n\nWe\'ll investigate and fix it as soon as possible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendEmail(context, 'hr@homesbuildings.com');
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _openPrivacyPolicy(BuildContext context) async {
    const url = 'https://hmutime.com/privacy';
    await _launchUrl(context, url, 'Privacy Policy');
  }

  void _openTermsOfService(BuildContext context) async {
    const url = 'https://hmutime.com/terms';
    await _launchUrl(context, url, 'Terms of Service');
  }

  void _openUserManual(BuildContext context) async {
    const url = 'https://hmutime.com/manual';
    await _launchUrl(context, url, 'User Manual');
  }

  Future<void> _launchUrl(BuildContext context, String url, String title) async {
    final Uri uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showUrlError(context, url, title);
      }
    } catch (e) {
      _showUrlError(context, url, title);
    }
  }

  void _showUrlError(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unable to open $title. Please visit the link manually:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}