import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BiometricService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sync biometric data for a specific employee and date range
  Future<BiometricSyncResult> syncBiometricData({
    required String empCode,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    print('🔄 BiometricService: Starting sync for empCode=$empCode, fromDate=${fromDate.toIso8601String()}, toDate=${toDate.toIso8601String()}');
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ BiometricService: User not authenticated');
        throw Exception('User not authenticated');
      }

      print('✅ BiometricService: User authenticated, calling Firebase Function...');
      final callable = _functions.httpsCallable('syncBiometricData');
      
      final requestData = {
        'empcode': empCode,
        'fromDate': fromDate.toIso8601String().split('T')[0], // YYYY-MM-DD format
        'toDate': toDate.toIso8601String().split('T')[0], // YYYY-MM-DD format
      };
      
      print('📤 BiometricService: Sending request with data: $requestData');
      final result = await callable.call(requestData);
      
      print('📥 BiometricService: Received response: ${result.data}');
      final syncResult = BiometricSyncResult.fromMap(result.data);
      print('✅ BiometricService: Sync completed - success=${syncResult.success}, recordsProcessed=${syncResult.recordsProcessed}');
      
      return syncResult;
    } on FirebaseFunctionsException catch (e) {
      print('❌ BiometricService: Firebase Functions Error: ${e.code} - ${e.message}');
      throw Exception('Firebase Functions Error: ${e.message}');
    } catch (e) {
      print('❌ BiometricService: General error during sync: $e');
      throw Exception('Failed to sync biometric data: $e');
    }
  }

  /// Get stored biometric records from Firestore (fallback method)
  Future<BiometricSyncResult> getStoredBiometricRecords({
    required String empCode,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    print('🔍 BiometricService: Getting stored records for empCode=$empCode, fromDate=${fromDate.toIso8601String()}, toDate=${toDate.toIso8601String()}');
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ BiometricService: User not authenticated for stored records');
        throw Exception('User not authenticated');
      }

      print('✅ BiometricService: User authenticated, calling getBiometricRecords...');
      final callable = _functions.httpsCallable('getBiometricRecords');
      
      final requestData = {
        'empcode': empCode,
        'fromDate': fromDate.toIso8601String().split('T')[0],
        'toDate': toDate.toIso8601String().split('T')[0],
      };
      
      print('📤 BiometricService: Sending getBiometricRecords request with data: $requestData');
      final result = await callable.call(requestData);
      
      print('📥 BiometricService: Received stored records response: ${result.data}');
      final storedResult = BiometricSyncResult.fromMap(result.data);
      print('✅ BiometricService: Stored records completed - success=${storedResult.success}, recordCount=${storedResult.records.length}');
      
      return storedResult;
    } on FirebaseFunctionsException catch (e) {
      print('❌ BiometricService: Firebase Functions Error in getStoredBiometricRecords: ${e.code} - ${e.message}');
      throw Exception('Firebase Functions Error: ${e.message}');
    } catch (e) {
      print('❌ BiometricService: General error getting stored records: $e');
      throw Exception('Failed to get stored biometric records: $e');
    }
  }
}

/// Result model for biometric sync operations
class BiometricSyncResult {
  final bool success;
  final String message;
  final int recordsProcessed;
  final List<BiometricRecord> records;

  BiometricSyncResult({
    required this.success,
    required this.message,
    required this.recordsProcessed,
    required this.records,
  });

  factory BiometricSyncResult.fromMap(dynamic map) {
    // Handle type conversion from Firebase response
    final Map<String, dynamic> data = Map<String, dynamic>.from(map);
    
    return BiometricSyncResult(
      success: data['success'] ?? false,
      message: data['message'] ?? '',
      recordsProcessed: data['recordsProcessed'] ?? 0,
      records: (data['records'] as List<dynamic>?)
              ?.map((item) => BiometricRecord.fromMap(Map<String, dynamic>.from(item)))
              .toList() ??
          [],
    );
  }
}

/// Model for individual biometric records
class BiometricRecord {
  final String empCode;
  final DateTime dateTime;
  final String type; // 'IN' or 'OUT'
  final String? deviceId;
  final String? location;

  BiometricRecord({
    required this.empCode,
    required this.dateTime,
    required this.type,
    this.deviceId,
    this.location,
  });

  factory BiometricRecord.fromMap(dynamic map) {
    // Handle type conversion from Firebase response
    final Map<String, dynamic> data = Map<String, dynamic>.from(map);
    
    DateTime parsedDateTime;
    if (data['dateTime'] != null) {
      try {
        final dateTimeStr = data['dateTime'].toString();
        // Handle MM/dd/yyyy HH:mm format (e.g., "11/10/2025 07:21")
        final parts = dateTimeStr.split(' ');
        if (parts.length == 2) {
          final dateParts = parts[0].split('/'); // [MM, dd, yyyy]
          final timeParts = parts[1].split(':'); // [HH, mm]
          
          if (dateParts.length == 3 && timeParts.length == 2) {
            final month = int.parse(dateParts[0]);
            final day = int.parse(dateParts[1]);
            final year = int.parse(dateParts[2]);
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            
            // Create in local timezone
            parsedDateTime = DateTime(year, month, day, hour, minute);
            print('📅 BiometricRecord: Parsed "$dateTimeStr" -> Year:$year Month:$month Day:$day Hour:$hour Minute:$minute -> Result: $parsedDateTime (IsUTC: ${parsedDateTime.isUtc})');
          } else {
            // Fallback to DateTime.parse for ISO formats
            parsedDateTime = DateTime.parse(dateTimeStr);
          }
        } else {
          // Fallback to DateTime.parse for ISO formats
          parsedDateTime = DateTime.parse(dateTimeStr);
        }
      } catch (e) {
        print('⚠️ BiometricRecord: Failed to parse dateTime "${data['dateTime']}", using current time: $e');
        parsedDateTime = DateTime.now();
      }
    } else {
      parsedDateTime = DateTime.now();
    }
    
    return BiometricRecord(
      empCode: data['empCode'] ?? '',
      dateTime: parsedDateTime,
      type: data['type'] ?? 'PUNCH',
      deviceId: data['deviceId'],
      location: data['location'] ?? 'Office',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empCode': empCode,
      'dateTime': dateTime.toIso8601String(),
      'type': type,
      'deviceId': deviceId,
      'location': location,
    };
  }
}
