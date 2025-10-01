# HMU Time - User Setup Guide

## Firestore User Structure

To manually add users for Admin and HR/Manager roles, create documents in the `users` collection with the following structure:

### Collection: `users`
### Document ID: `{Firebase Auth UID}`

```json
{
  "email": "admin@company.com",
  "name": "John Admin",
  "designation": "System Administrator",
  "role": "admin",
  "profileImage": null,
  "createdAt": "2024-01-15T10:00:00.000Z",
  "isActive": true
}
```

### User Roles

1. **Admin Role**
   ```json
   {
     "email": "admin@company.com",
     "name": "Admin User",
     "designation": "System Administrator",
     "role": "admin",
     "isActive": true
   }
   ```

2. **HR Role**
   ```json
   {
     "email": "hr@company.com", 
     "name": "HR Manager",
     "designation": "Human Resources Manager",
     "role": "hr",
     "isActive": true
   }
   ```

3. **Manager Role**
   ```json
   {
     "email": "manager@company.com",
     "name": "Department Manager", 
     "designation": "Operations Manager",
     "role": "manager",
     "isActive": true
   }
   ```

### Setup Steps

#### Option 1: Manual Setup (Firebase Console)

1. **Create Firebase Auth User:**
   - Go to Firebase Console > Authentication > Users
   - Click "Add user"
   - Enter email and password
   - Copy the generated UID

2. **Create Firestore Document:**
   - Go to Firebase Console > Firestore Database
   - Navigate to `users` collection (create if doesn't exist)
   - Create new document with the copied UID as Document ID
   - Add the user data fields as shown above

3. **Test Login:**
   - Use the email and password created in Firebase Auth
   - The app will automatically verify the user role from Firestore

#### Option 2: Using Admin Dashboard (Recommended)

1. **Create Initial Admin User** (using Option 1 above)
2. **Login as Admin** and access the admin dashboard
3. **Use "Add HR/Manager" Feature:**
   - Click on "Add HR/Manager" card in the admin dashboard
   - Fill in all required details (same fields as employee creation)
   - Select role (HR or Manager)
   - System will automatically set default designations:
     - HR Role → "Human Resources Manager"
     - Manager Role → "Operations Manager"
   - Admin can customize the designation field if needed
   - Account will be created with temporary password
   - Welcome email sent automatically

### Important Notes

- Only users with roles `admin`, `hr`, or `manager` can access the admin portal
- Employee role users will be denied access to this app
- Make sure the document ID in Firestore matches the Firebase Auth UID exactly
- The `role` field is case-sensitive and must be lowercase

### Example Test Users

You can create these test users for development:

**Admin User:**
- Email: admin@hmutime.com
- Password: admin123456
- Role: admin

**HR User:**
- Email: hr@hmutime.com  
- Password: hr123456
- Role: hr

**Manager User:**
- Email: manager@hmutime.com
- Password: manager123456
- Role: manager
