# Firestore Security Rules Documentation

## Overview
These Firestore security rules implement role-based access control for the HMU Time attendance management system. The rules ensure that users can only access data appropriate to their role and permissions.

## User Roles Hierarchy

```
Admin (Highest Privileges)
├── Can manage all users, settings, and data
├── Full CRUD access to most collections
└── Can create HR/Manager accounts

HR (High Privileges)  
├── Can manage employees and attendance
├── Can approve/reject leave requests
├── Cannot modify system settings
└── Cannot access payroll (unless specifically granted)

Manager (Moderate Privileges)
├── Can view employee data in their department
├── Can approve/reject leave requests
├── Limited employee management
└── Cannot create/delete users

Employee (Basic Privileges)
├── Can manage their own attendance
├── Can submit leave requests
├── Can view their own data only
└── Read-only access to company holidays
```

## Collection Access Rules

### 📋 `/users/{userId}`
- **Read**: Users can read their own data; Admin/HR can read all users
- **Create**: Only Admin can create new users
- **Update**: Admin can update any user; Users can update their profile (except role/status)
- **Delete**: Only Admin can delete users

### ⏰ `/attendance/{attendanceId}`
- **Read**: Admin/HR/Manager see all; Employees see only their records
- **Create**: Employees create their own; Admin/HR can create for anyone
- **Update**: Employees update their own; Admin/HR update any
- **Delete**: Only Admin/HR can delete

### 🏖️ `/leaveRequests/{requestId}`
- **Read**: Admin/HR/Manager see all; Employees see only their requests
- **Create**: Employees create their own (status: pending); Admin/HR create for anyone
- **Update**: Employees update their pending requests; Admin/HR/Manager can approve/reject
- **Delete**: Only Admin/HR can delete

### 🎉 `/holidays/{holidayId}`
- **Read**: All authenticated users
- **Create/Update/Delete**: Only Admin

### 🏢 `/departments/{departmentId}`
- **Read**: All authenticated users
- **Create/Update/Delete**: Only Admin

### ⚙️ `/settings/{settingId}`
- **Read**: Admin/HR/Manager only
- **Create/Update/Delete**: Only Admin

### 🔔 `/notifications/{notificationId}`
- **Read**: Users read their own; Admin/HR read all
- **Create**: Admin/HR only
- **Update**: Users can mark their notifications as read; Admin/HR can update any
- **Delete**: Only Admin

### 📊 `/reports/{reportId}`
- **Read**: Admin/HR/Manager see all; Employees see reports containing their data
- **Create**: Admin/HR only
- **Update/Delete**: Only Admin

### 📝 `/auditLogs/{logId}`
- **Read/Create**: Only Admin
- **Update/Delete**: Not allowed (audit integrity)

### 👤 `/employeeProfiles/{employeeId}`
- **Read**: Users read their own; Admin/HR read all
- **Create**: Admin/HR only
- **Update**: Users update their own (limited fields); Admin/HR update any
- **Delete**: Only Admin

### 💰 `/payroll/{payrollId}`
- **All Operations**: Only Admin and HR (highly sensitive data)

## Security Features

### 🔐 Authentication Requirements
```javascript
function isAuthenticated() {
  return request.auth != null;
}
```
All rules require user authentication as the base requirement.

### 🎭 Role-Based Access
```javascript
function getUserRole() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
}
```
User roles are dynamically fetched from the users collection for each request.

### 📊 Data Validation
- User creation requires specific fields: `email`, `name`, `role`, `isActive`, `createdAt`
- Role values must be one of: `admin`, `hr`, `manager`, `employee`
- Timestamps and data types are validated

### 🛡️ Ownership Validation
```javascript
function isOwner(userId) {
  return isAuthenticated() && request.auth.uid == userId;
}
```
Ensures users can only access their own data where appropriate.

### 🚫 Default Deny
```javascript
match /{document=**} {
  allow read, write: if false;
}
```
Any collection not explicitly defined is denied by default.

## Implementation Steps

### 1. Deploy Rules to Firebase
```bash
# Using Firebase CLI
firebase deploy --only firestore:rules

# Or copy the rules to Firebase Console
# Go to Firestore Database > Rules tab
# Paste the rules and publish
```

### 2. Test Rules
```bash
# Install Firebase emulators
firebase emulators:start --only firestore

# Test rules with different user roles
firebase emulators:exec --only firestore "npm run test"
```

### 3. Monitor Access
- Use Firebase Console to monitor rule usage
- Set up alerts for denied requests
- Review audit logs regularly

## Common Use Cases

### ✅ Allowed Operations
- Employee checks in/out (own attendance)
- HR approves leave request
- Manager views team attendance
- Admin creates new user account
- Employee views company holidays

### ❌ Denied Operations  
- Employee views other employee's salary
- Manager deletes attendance records
- Employee creates admin account
- Unauthenticated access to any data
- HR modifies system settings (admin only)

## Best Practices

### 🔒 Security
- Always validate user roles server-side
- Use Cloud Functions for complex business logic
- Implement audit logging for sensitive operations
- Regular security reviews and updates

### 📈 Performance
- Minimize `get()` calls in rules
- Cache user role data when possible
- Use compound queries efficiently
- Monitor rule evaluation costs

### 🧪 Testing
- Test all user role combinations
- Verify edge cases and error conditions
- Use Firebase Emulator Suite for testing
- Implement automated rule testing

## Emergency Procedures

### 🚨 If Rules Need Quick Update
1. Use Firebase Console for immediate changes
2. Test in staging environment first
3. Deploy via CLI for production
4. Monitor for any access issues
5. Have rollback plan ready

### 📞 Support Contacts
- Firebase Console: https://console.firebase.google.com
- Documentation: https://firebase.google.com/docs/firestore/security
- Community: https://stackoverflow.com/questions/tagged/firebase

---

**Note**: These rules provide a secure foundation but should be customized based on your specific business requirements and compliance needs.
