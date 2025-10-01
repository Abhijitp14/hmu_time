# Firestore Rules Testing Script

## Prerequisites
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not already done)
firebase init firestore
```

## Testing with Firebase Emulators

### 1. Start Emulators
```bash
# Start Firestore emulator
firebase emulators:start --only firestore

# Or start all emulators including auth
firebase emulators:start --only firestore,auth
```

### 2. Test User Scenarios

#### Admin User Test
```javascript
// Test admin creating a new user
const adminUserId = 'admin-uid-123';
const newUserId = 'new-user-456';

// This should succeed
await db.collection('users').doc(newUserId).set({
  email: 'newuser@company.com',
  name: 'New User',
  role: 'employee',
  isActive: true,
  createdAt: firebase.firestore.FieldValue.serverTimestamp()
});

// This should succeed - admin reading all users
const users = await db.collection('users').get();
```

#### HR User Test
```javascript
// Test HR managing employee attendance
const hrUserId = 'hr-uid-789';
const employeeId = 'employee-uid-456';

// This should succeed
await db.collection('attendance').add({
  employeeId: employeeId,
  checkIn: firebase.firestore.FieldValue.serverTimestamp(),
  status: 'present'
});

// This should succeed - HR reading all attendance
const attendance = await db.collection('attendance').get();
```

#### Employee User Test
```javascript
// Test employee managing own data
const employeeUserId = 'employee-uid-456';

// This should succeed - employee reading own data
const ownData = await db.collection('users').doc(employeeUserId).get();

// This should fail - employee trying to read other user's data
const otherUserData = await db.collection('users').doc('other-user-789').get();
// Expected: Permission denied

// This should succeed - employee creating own attendance
await db.collection('attendance').add({
  employeeId: employeeUserId,
  checkIn: firebase.firestore.FieldValue.serverTimestamp(),
  status: 'present'
});
```

### 3. Rule Validation Tests

#### Test Invalid Data Creation
```javascript
// This should fail - missing required fields
await db.collection('users').doc('test-user').set({
  email: 'test@example.com'
  // Missing name, role, isActive, createdAt
});

// This should fail - invalid role
await db.collection('users').doc('test-user').set({
  email: 'test@example.com',
  name: 'Test User',
  role: 'invalid-role', // Not in allowed roles
  isActive: true,
  createdAt: firebase.firestore.FieldValue.serverTimestamp()
});
```

#### Test Unauthorized Access
```javascript
// This should fail - unauthenticated user
// (without setting auth context)
const data = await db.collection('users').get();

// This should fail - employee accessing payroll
// (with employee auth context)
const payroll = await db.collection('payroll').get();
```

## Manual Testing Checklist

### ✅ Admin Role Tests
- [ ] Can create users with all roles
- [ ] Can read all collections
- [ ] Can update any user data
- [ ] Can delete users
- [ ] Can manage holidays and settings
- [ ] Can access audit logs
- [ ] Can manage payroll data

### ✅ HR Role Tests  
- [ ] Can read all user data
- [ ] Can create employee accounts
- [ ] Can manage attendance records
- [ ] Can approve/reject leave requests
- [ ] Cannot access system settings
- [ ] Can access payroll data
- [ ] Cannot delete users

### ✅ Manager Role Tests
- [ ] Can read employee data
- [ ] Can view attendance records
- [ ] Can approve/reject leave requests
- [ ] Cannot create/delete users
- [ ] Cannot access payroll
- [ ] Cannot modify settings
- [ ] Can view reports

### ✅ Employee Role Tests
- [ ] Can read own user data only
- [ ] Can create own attendance records
- [ ] Can submit leave requests
- [ ] Can view company holidays
- [ ] Cannot access other employee data
- [ ] Cannot access payroll
- [ ] Cannot access admin features

### ❌ Security Tests (Should Fail)
- [ ] Unauthenticated access to any collection
- [ ] Employee accessing payroll data
- [ ] Employee modifying other's attendance
- [ ] Manager creating admin accounts
- [ ] HR modifying system settings
- [ ] Any user accessing undefined collections

## Sample Test Data

### Create Test Users in Firestore
```json
// Admin User (Document ID: admin-uid-123)
{
  "email": "admin@hmutime.com",
  "name": "System Admin",
  "role": "admin",
  "designation": "System Administrator",
  "isActive": true,
  "createdAt": "2024-01-15T10:00:00Z"
}

// HR User (Document ID: hr-uid-789)
{
  "email": "hr@hmutime.com",
  "name": "HR Manager",
  "role": "hr", 
  "designation": "Human Resources Manager",
  "isActive": true,
  "createdAt": "2024-01-15T10:00:00Z"
}

// Employee User (Document ID: employee-uid-456)
{
  "email": "employee@hmutime.com",
  "name": "John Employee",
  "role": "employee",
  "designation": "Software Developer",
  "isActive": true,
  "createdAt": "2024-01-15T10:00:00Z"
}
```

### Create Test Authentication Users
Use Firebase Auth to create corresponding users with the same UIDs and passwords.

## Automated Testing with Jest

```bash
# Install testing dependencies
npm install --save-dev jest @firebase/testing

# Run tests
npm test
```

### Sample Jest Test
```javascript
const firebase = require('@firebase/testing');

describe('Firestore Security Rules', () => {
  test('Admin can create users', async () => {
    const admin = firebase.firestore().connect();
    
    // Set admin auth context
    await admin.useEmulator('localhost', 8080);
    
    const result = await admin.collection('users').add({
      email: 'test@example.com',
      name: 'Test User',
      role: 'employee',
      isActive: true,
      createdAt: firebase.firestore.FieldValue.serverTimestamp()
    });
    
    expect(result.id).toBeDefined();
  });
});
```

## Deployment

```bash
# Deploy rules to production
firebase deploy --only firestore:rules

# Deploy with confirmation
firebase deploy --only firestore:rules --force
```

## Monitoring

### Firebase Console Monitoring
1. Go to Firestore Database → Usage tab
2. Monitor denied requests
3. Check performance metrics
4. Review access patterns

### Set Up Alerts
```bash
# Create alert for high denied request rate
gcloud alpha monitoring policies create --policy-from-file=alert-policy.yaml
```

## Troubleshooting

### Common Issues
1. **Permission Denied**: Check user authentication and role assignment
2. **Rules Not Applied**: Ensure rules are deployed and published
3. **Performance Issues**: Minimize get() calls in rules
4. **Testing Failures**: Verify emulator is running and auth context is set

### Debug Commands
```bash
# Check rule syntax
firebase firestore:rules:check

# View deployed rules
firebase firestore:rules:get

# Test specific rule
firebase firestore:rules:test --test-file=test.json
```
