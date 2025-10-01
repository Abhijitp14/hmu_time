# Biometric API Integration Guide

## Overview

This integration connects the HMU Time Flutter application with external biometric attendance machines via Firebase Cloud Functions. The system allows employees to sync their attendance data from biometric devices and provides admins/HR with processing capabilities.

## Architecture

```
Flutter App (Employee Dashboard)
         ↓
Firebase Cloud Functions
         ↓  
External Biometric API (etimeoffice.com)
         ↓
Firestore Database (Storage)
```

## Firebase Functions

### 1. syncBiometricData
**Purpose**: Sync attendance data for a specific employee and date range

**Endpoint**: `https://us-central1-hmu-time.cloudfunctions.net/syncBiometricData`

**Authentication**: Firebase Auth required

**Parameters**:
- `empcode` (string): Employee code
- `fromDate` (string): Start date in YYYY-MM-DD format
- `toDate` (string): End date in YYYY-MM-DD format

**Response**:
```json
{
  "success": true,
  "message": "Sync completed successfully",
  "recordsProcessed": 5,
  "records": [
    {
      "empCode": "EMP001",
      "dateTime": "2024-01-15T09:00:00.000Z",
      "type": "IN",
      "deviceId": "DEV001",
      "location": "Main Office"
    }
  ]
}
```

### 2. getBiometricSyncHistory
**Purpose**: Retrieve sync history for an employee

**Parameters**:
- `empcode` (string): Employee code
- `limit` (number): Maximum number of records to return (default: 10)

**Response**:
```json
{
  "history": [
    {
      "id": "sync001",
      "empCode": "EMP001", 
      "syncDate": "2024-01-15T10:00:00.000Z",
      "fromDate": "2024-01-08T00:00:00.000Z",
      "toDate": "2024-01-14T23:59:59.000Z",
      "success": true,
      "message": "Successfully synced",
      "recordsProcessed": 10
    }
  ]
}
```

### 3. processBiometricData
**Purpose**: Process/approve biometric data (Admin/HR only)

**Parameters**:
- `empcode` (string): Employee code
- `date` (string): Date to process in YYYY-MM-DD format
- `action` (string): Action to take ('approve', 'reject', 'modify')
- `notes` (string, optional): Processing notes
- `modifications` (object, optional): Data modifications

## External API Integration

### API Details
- **URL**: `https://api.etimeoffice.com/api/DownloadInOutPunchData`
- **Method**: POST
- **Authentication**: Basic Auth with format: `corporateid:username:password:true`

### API Request Format
```json
{
  "Empcode": "EMP001",
  "FromDate": "2024-01-08",
  "ToDate": "2024-01-15"
}
```

### API Response Format
The external API returns attendance punch data which is then processed and stored in Firestore.

## Flutter Integration

### BiometricService Class
Located in: `lib/services/biometric_service.dart`

**Key Methods**:
- `syncBiometricData()`: Sync attendance data
- `getBiometricSyncHistory()`: Get sync history
- `processBiometricData()`: Process attendance data (Admin/HR)

### Employee Dashboard Integration
Location: `lib/screens/dashboard/employee/employee_dashboard_screen.dart`

**Features Added**:
- Sync button in "Attendance Sync" section
- Loading indicator during sync
- Success/error messages via SnackBar
- Navigation to sync history screen

### Sync History Screen
Location: `lib/screens/dashboard/employee/biometric_sync_history_screen.dart`

**Features**:
- Display sync history with success/failure status
- Show processed record counts
- Pull-to-refresh functionality
- Empty state handling

## Data Models

### BiometricSyncResult
```dart
class BiometricSyncResult {
  final bool success;
  final String message;
  final int recordsProcessed;
  final List<BiometricRecord> records;
}
```

### BiometricRecord
```dart
class BiometricRecord {
  final String empCode;
  final DateTime dateTime;
  final String type; // 'IN' or 'OUT'
  final String? deviceId;
  final String? location;
}
```

### BiometricSyncHistory
```dart
class BiometricSyncHistory {
  final String id;
  final String empCode;
  final DateTime syncDate;
  final DateTime fromDate;
  final DateTime toDate;
  final bool success;
  final String message;
  final int recordsProcessed;
}
```

## Setup Instructions

### 1. Firebase Functions Setup
```bash
cd functions
npm install
firebase deploy --only functions
```

### 2. Environment Variables
Set these in Firebase Functions environment:
```bash
firebase functions:config:set biometric.api_url="https://api.etimeoffice.com/api/DownloadInOutPunchData"
firebase functions:config:set biometric.corporate_id="YOUR_CORPORATE_ID"
firebase functions:config:set biometric.username="YOUR_USERNAME" 
firebase functions:config:set biometric.password="YOUR_PASSWORD"
```

### 3. Flutter Dependencies
Ensure these are in `pubspec.yaml`:
```yaml
dependencies:
  cloud_functions: ^6.0.1
  firebase_auth: ^6.0.2
  cloud_firestore: ^6.0.1
```

## Security Considerations

1. **Authentication**: All Firebase functions require user authentication
2. **Authorization**: Employees can only sync their own data
3. **API Credentials**: Stored securely in Firebase environment variables
4. **Data Validation**: Input validation on both client and server side
5. **Error Handling**: Comprehensive error handling for network/API failures

## Testing

### Manual Testing
1. Login as employee with valid `empCode`
2. Navigate to Employee Dashboard
3. Click sync button in "Attendance Sync" section
4. Verify success/error messages
5. Check "Sync History" for results

### Unit Tests
Run tests: `flutter test test/biometric_service_test.dart`

### Function Testing
Test functions locally:
```bash
cd functions
npm run build
firebase emulators:start --only functions
```

## Troubleshooting

### Common Issues

1. **"Employee code not found"**
   - Ensure user has `empCode` field in Firestore user document
   
2. **"Sync failed: Authentication error"**
   - Verify Firebase user is logged in
   - Check function permissions
   
3. **"External API timeout"**
   - Verify network connectivity
   - Check API credentials in environment variables
   
4. **"No sync history"**
   - Perform at least one sync operation
   - Check Firestore `biometric_sync_history` collection

### Debug Commands
```bash
# View function logs
firebase functions:log

# Check function status
firebase functions:list

# Test locally
firebase emulators:start --only functions

# Check Firestore data
# Navigate to Firebase Console > Firestore Database
```

## Future Enhancements

1. **Real-time Sync**: Implement periodic background sync
2. **Offline Support**: Cache data for offline viewing
3. **Bulk Processing**: Admin tools for bulk data processing
4. **Analytics**: Attendance analytics and reporting
5. **Notifications**: Push notifications for sync status
6. **Multi-device Support**: Support multiple biometric devices
