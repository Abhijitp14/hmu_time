// import 'package:flutter/material.dart';
// import 'package:hmu_time/screens/leaves/leave_application_screen.dart';
// import 'package:hmu_time/screens/leaves/leave_history_screen.dart';
// import '../../models/leave_model.dart';
// import '../../models/user_model.dart';
// import '../../services/leave_service.dart';


// class LeaveBalanceWidget extends StatefulWidget {
//   final AppUser user;
//   final bool showActions;

//   const LeaveBalanceWidget({
//     super.key,
//     required this.user,
//     this.showActions = true,
//   });

//   @override
//   State<LeaveBalanceWidget> createState() => _LeaveBalanceWidgetState();
// }

// class _LeaveBalanceWidgetState extends State<LeaveBalanceWidget> {
//   final LeaveService _leaveService = LeaveService();
//   LeaveBalanceInfo? _balanceInfo;

//   @override
//   void initState() {
//     super.initState();
//     _loadBalanceInfo();
//   }

//   void _loadBalanceInfo() {
//     try {
//       setState(() {
//         _balanceInfo = _leaveService.getLeaveBalanceInfo(widget.user);
//       });
//     } catch (e) {
//       // Handle error - maybe user doesn't have joining date
//       print('Error loading balance info: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildHeader(),
//             const SizedBox(height: 16),
//             _buildBalanceDisplay(),
//             if (_balanceInfo != null) ...[
//               const SizedBox(height: 16),
//               _buildAccrualInfo(),
//             ],
//             if (widget.showActions) ...[
//               const SizedBox(height: 16),
//               _buildActionButtons(),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return Row(
//       children: [
//         Icon(
//           Icons.event_available,
//           color: Theme.of(context).primaryColor,
//           size: 24,
//         ),
//         const SizedBox(width: 8),
//         const Expanded(
//           child: Text(
//             'Leave Balance',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//         if (widget.showActions)
//           IconButton(
//             onPressed: () => Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => const LeaveHistoryScreen(),
//               ),
//             ),
//             icon: const Icon(Icons.history),
//             tooltip: 'View Leave History',
//           ),
//       ],
//     );
//   }

//   Widget _buildBalanceDisplay() {
//     if (_balanceInfo == null) {
//       return _buildErrorBalance();
//     }

//     return Column(
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             _buildBalanceItem(
//               'Sick Leave',
//               _balanceInfo!.sickLeave,
//               Colors.red.shade100,
//               Colors.red.shade700,
//               'SL',
//             ),
//             _buildBalanceItem(
//               'Casual Leave',
//               _balanceInfo!.casualLeave,
//               Colors.blue.shade100,
//               Colors.blue.shade700,
//               'CL',
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             _buildBalanceItem(
//               'Paid Leave',
//               _balanceInfo!.paidLeave,
//               Colors.green.shade100,
//               Colors.green.shade700,
//               'PL',
//             ),
//             _buildBalanceItem(
//               'Optional Holiday',
//               _balanceInfo!.optionalHoliday,
//               Colors.purple.shade100,
//               Colors.purple.shade700,
//               'OL',
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: Colors.grey.shade100,
//             borderRadius: BorderRadius.circular(20),
//           ),
//           child: Text(
//             'Total: ${_balanceInfo!.totalBalance} days',
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//               color: Colors.grey.shade700,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildErrorBalance() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.orange.shade50,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.orange.shade200),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.warning_outlined, color: Colors.orange.shade700, size: 20),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Balance calculation unavailable',
//                   style: TextStyle(
//                     color: Colors.orange.shade700,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 Text(
//                   'Please contact HR to update your joining date',
//                   style: TextStyle(
//                     color: Colors.orange.shade600,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBalanceItem(
//     String label,
//     double balance,
//     Color bgColor,
//     Color textColor,
//     String shortName,
//   ) {
//     return Expanded(
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 4),
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//         decoration: BoxDecoration(
//           color: bgColor,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Column(
//           children: [
//             Text(
//               balance.toString(),
//               style: TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: textColor,
//               ),
//             ),
//             Text(
//               shortName,
//               style: TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//                 color: textColor,
//               ),
//             ),
//             Text(
//               label.split(' ')[0], // First word only
//               style: TextStyle(
//                 fontSize: 10,
//                 color: textColor.withOpacity(0.8),
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAccrualInfo() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade50,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.blue.shade200),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
//               const SizedBox(width: 6),
//               Text(
//                 'Leave Information',
//                 style: TextStyle(
//                   color: Colors.blue.shade700,
//                   fontWeight: FontWeight.w500,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           _buildInfoRow('Service Period', '${_balanceInfo!.monthsWorked} months'),
//           _buildInfoRow('Monthly Accrual', '0.5 days per month'),
//           _buildInfoRow('Next Accrual', _getNextAccrualDate()),
//           if (_balanceInfo!.monthsWorked < 6)
//             _buildInfoRow('CL/PL Available From', _getCLPLAvailableDate()),
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 2),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.blue.shade600,
//             ),
//           ),
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.blue.shade700,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _getNextAccrualDate() {
//     if (widget.user.joiningDate == null) return 'N/A';
    
//     final now = DateTime.now();
//     final joiningDate = widget.user.joiningDate!;
    
//     // Calculate next month from joining date
//     final nextAccrualMonth = DateTime(
//       now.year,
//       now.month + 1,
//       joiningDate.day,
//     );
    
//     final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
//                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
//     return '${nextAccrualMonth.day} ${months[nextAccrualMonth.month - 1]}';
//   }

//   String _getCLPLAvailableDate() {
//     if (widget.user.joiningDate == null) return 'N/A';
    
//     final availableDate = widget.user.joiningDate!.add(const Duration(days: 180)); // 6 months
//     final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
//                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
//     return '${availableDate.day} ${months[availableDate.month - 1]} ${availableDate.year}';
//   }

//   Widget _buildActionButtons() {
//     return Row(
//       children: [
//         Expanded(
//           child: ElevatedButton.icon(
//             onPressed: _balanceInfo != null ? () => _navigateToApplyLeave() : null,
//             icon: const Icon(Icons.add, size: 18),
//             label: const Text('Apply Leave'),
//             style: ElevatedButton.styleFrom(
//               padding: const EdgeInsets.symmetric(vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: OutlinedButton.icon(
//             onPressed: () => _navigateToHistory(),
//             icon: const Icon(Icons.history, size: 18),
//             label: const Text('View History'),
//             style: OutlinedButton.styleFrom(
//               padding: const EdgeInsets.symmetric(vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   void _navigateToApplyLeave() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => LeaveApplicationScreen(user: widget.user),
//       ),
//     );
//   }

//   void _navigateToHistory() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const LeaveHistoryScreen(),
//       ),
//     );
//   }
// }

// /// Compact version for dashboard summary
// class CompactLeaveBalanceWidget extends StatelessWidget {
//   final AppUser user;
//   final VoidCallback? onTap;

//   const CompactLeaveBalanceWidget({
//     super.key,
//     required this.user,
//     this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(12),
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.grey.shade200),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(
//                   Icons.event_available,
//                   color: Theme.of(context).primaryColor,
//                   size: 20,
//                 ),
//                 const SizedBox(width: 8),
//                 const Text(
//                   'Leave Balance',
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 const Spacer(),
//                 if (onTap != null)
//                   Icon(
//                     Icons.arrow_forward_ios,
//                     size: 14,
//                     color: Colors.grey.shade400,
//                   ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Column(
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceAround,
//                   children: [
//                     _buildCompactBalanceItem('SL', user.sickLeave, Colors.red),
//                     _buildCompactBalanceItem('CL', user.casualLeave, Colors.blue),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceAround,
//                   children: [
//                     _buildCompactBalanceItem('PL', user.paidLeave, Colors.green),
//                     _buildCompactBalanceItem('OH', user.optionalHoliday, Colors.purple),
//                   ],
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCompactBalanceItem(String label, int balance, MaterialColor color) {
//     return Column(
//       children: [
//         Container(
//           width: 36,
//           height: 36,
//           decoration: BoxDecoration(
//             color: color.shade100,
//             shape: BoxShape.circle,
//           ),
//           child: Center(
//             child: Text(
//               balance.toString(),
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: color.shade700,
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 11,
//             color: Colors.grey.shade600,
//           ),
//         ),
//       ],
//     );
//   }
// }