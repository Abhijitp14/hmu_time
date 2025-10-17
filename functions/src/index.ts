import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";
import fetch from "node-fetch";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Email configuration
const createEmailTransporter = () => {
  // Use environment variables (modern approach)
  const emailUser = process.env.EMAIL_USER;
  const emailPassword = process.env.EMAIL_PASSWORD;
  
  if (!emailUser || !emailPassword) {
    functions.logger.warn('Email configuration missing. Please set EMAIL_USER and EMAIL_PASSWORD environment variables.');
    throw new Error('Email configuration not found');
  }
  
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: emailUser,
      pass: emailPassword
    }
  });
};

// Function to send welcome email with credentials
async function sendWelcomeEmail(
  employeeEmail: string,
  employeeName: string,
  empCode: string,
  tempPassword: string,
  department: string
): Promise<void> {
  try {
    const transporter = createEmailTransporter();
    
    const mailOptions = {
      from: process.env.COMPANY_EMAIL || process.env.EMAIL_USER || 'noreply@hmutime.com',
      to: employeeEmail,
      subject: 'Welcome to HMU Time - Your Account Details',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Welcome to HMU Time</title>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #2f86fe; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
            .content { background: #f8f9fa; padding: 20px; border-radius: 0 0 8px 8px; }
            .credentials { background: white; padding: 15px; border-radius: 8px; border-left: 4px solid #2f86fe; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 14px; }
            .important { color: #e74c3c; font-weight: bold; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>Welcome to HMU Time! 🎉</h1>
            </div>
            <div class="content">
              <h2>Hello ${employeeName},</h2>
              <p>Welcome to HMU Time Attendance Management System! Your employee account has been successfully created.</p>
              
              <h3>Your Account Details:</h3>
              <div class="credentials">
                <p><strong>Employee Code:</strong> ${empCode}</p>
                <p><strong>Department:</strong> ${department}</p>
                <p><strong>Email:</strong> ${employeeEmail}</p>
                <p><strong>Temporary Password:</strong> <span style="background: #e8f4f8; padding: 4px 8px; border-radius: 4px; font-family: monospace;">${tempPassword}</span></p>
              </div>
              
              <h3>Next Steps:</h3>
              <ol>
                <li>Download the HMU Time mobile app or access the web portal</li>
                <li>Log in using your email and temporary password</li>
                <li><span class="important">You will be required to change your password on first login</span></li>
                <li>Complete your profile setup</li>
                <li>Start tracking your attendance!</li>
              </ol>
              
              <p><strong>Important Security Note:</strong><br>
              • Please keep your credentials secure<br>
              • Change your password immediately after first login<br>
              • Never share your login details with anyone</p>
              
              <p>If you have any questions or need assistance, please contact your HR department or system administrator.</p>
              
              <p>Best regards,<br>
              <strong>HMU Time Team</strong></p>
            </div>
            <div class="footer">
              <p>This is an automated message. Please do not reply to this email.</p>
            </div>
          </div>
        </body>
        </html>
      `
    };

    await transporter.sendMail(mailOptions);
    functions.logger.info(`Welcome email sent successfully to ${employeeEmail}`);
  } catch (error) {
    functions.logger.error(`Failed to send welcome email to ${employeeEmail}:`, error);
    // Don't throw error here as account creation was successful
    // Just log the email failure
  }
}

interface CreateEmployeeRequest {
  name: string;
  email: string;
  empCode: string;
  department: string;
  designation?: string;
  role: string;
  joiningDate?: string;
  phoneNumber?: string;
  dateOfBirth?: string;
  address?: string;
  employmentType?: string;
  workingHours?: number;
  leaveBalance?: {
    sickLeave: number;
    casualLeave: number;
    paidLeave: number;
    optionalHoliday: number;
  };
}

interface CreateEmployeeResponse {
  success: boolean;
  error?: string;
  uid?: string;
  tempPassword?: string;
  message?: string;
}

/**
 * Cloud Function to create a new employee account
 * This function:
 * 1. Creates a Firebase Auth account with a temporary password
 * 2. Sets custom claims (role: employee)
 * 3. Creates a user document in Firestore
 * 4. Sends the temporary password to the employee's email
 */
export const createEmployee = functions.https.onCall(
  async (
    data: CreateEmployeeRequest,
    context
  ): Promise<CreateEmployeeResponse> => {
    try {
      // Verify that the request is authenticated and from an admin/HR
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "The function must be called while authenticated."
        );
      }

      // Get the current user's document to verify role
      const callerUid = context.auth.uid;
      const callerDoc = await admin
        .firestore()
        .collection("users")
        .doc(callerUid)
        .get();

      if (!callerDoc.exists) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Caller user document not found."
        );
      }

      const callerData = callerDoc.data();
      const callerRole = callerData?.role;

      // Only admin and hr roles can create employees
      if (callerRole !== "admin" && callerRole !== "hr") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only admin and HR can create employee accounts."
        );
      }

      // Validate input data
      if (!data.name || !data.email || !data.empCode || !data.department) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required fields: name, email, empCode, or department."
        );
      }

      // Validate email format
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(data.email)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Invalid email format."
        );
      }

      // Check if employee code already exists
      const existingEmpCodeQuery = await admin
        .firestore()
        .collection("users")
        .where("empCode", "==", data.empCode)
        .get();

      if (!existingEmpCodeQuery.empty) {
        throw new functions.https.HttpsError(
          "already-exists",
          "Employee code already exists."
        );
      }

      // Generate a temporary password (8 characters)
      const tempPassword = generateTempPassword();

      // Create Firebase Auth user
      const userRecord = await admin.auth().createUser({
        email: data.email.toLowerCase(),
        password: tempPassword,
        displayName: data.name,
        emailVerified: false,
      });

      // Set custom claims
      await admin.auth().setCustomUserClaims(userRecord.uid, {
        role: data.role || "employee",
        empCode: data.empCode,
      });

      // Parse joining date if provided
      let joiningDate = null;
      if (data.joiningDate) {
        joiningDate = admin.firestore.Timestamp.fromDate(new Date(data.joiningDate));
      }

      // Parse date of birth if provided
      let dateOfBirth = null;
      if (data.dateOfBirth) {
        dateOfBirth = admin.firestore.Timestamp.fromDate(new Date(data.dateOfBirth));
      }

      // Create user document in Firestore
      const userData = {
        uid: userRecord.uid,
        name: data.name,
        email: data.email.toLowerCase(),
        designation: data.designation || null,
        role: data.role || "employee",
        empCode: data.empCode,
        department: data.department,
        joiningDate: joiningDate,
        phoneNumber: data.phoneNumber || null,
        dateOfBirth: dateOfBirth,
        address: data.address || null,
        employmentType: data.employmentType || null,
        workingHours: data.workingHours || null,
        leaveBalance: data.leaveBalance || {
          sickLeave: 6,
          casualLeave: 6,
          paidLeave: 6,
          optionalHoliday: 3,
        },
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: callerUid,
        // Employee will be forced to change password on first login
        mustChangePassword: true,
      };

      await admin
        .firestore()
        .collection("users")
        .doc(userRecord.uid)
        .set(userData);

      // Send welcome email with credentials
      await sendWelcomeEmail(
        data.email.toLowerCase(),
        data.name,
        data.empCode,
        tempPassword,
        data.department
      );

      functions.logger.info(`Employee account created successfully`, {
        uid: userRecord.uid,
        email: data.email,
        empCode: data.empCode,
        createdBy: callerUid,
      });

      return {
        success: true,
        uid: userRecord.uid,
        tempPassword: tempPassword, // Return password to show to admin
        message: `Employee account created successfully. Temporary password: ${tempPassword}`,
      };
    } catch (error: any) {
      functions.logger.error("Error creating employee:", error);

      // Handle specific Firebase Auth errors
      if (error.code === "auth/email-already-exists") {
        throw new functions.https.HttpsError(
          "already-exists",
          "An account with this email already exists."
        );
      }

      if (error.code === "auth/invalid-email") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Invalid email address."
        );
      }

      // Re-throw HttpsErrors as-is
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Handle any other errors
      throw new functions.https.HttpsError(
        "internal",
        "An error occurred while creating the employee account."
      );
    }
  }
);

/**
 * Generate a secure temporary password
 */
function generateTempPassword(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let result = "";
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * Cloud Function to get employee list (for Admin/HR)
 */
export const getEmployees = functions.https.onCall(
  async (data, context) => {
    try {
      // Verify authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "The function must be called while authenticated."
        );
      }

      // Verify caller role
      const callerUid = context.auth.uid;
      const callerDoc = await admin
        .firestore()
        .collection("users")
        .doc(callerUid)
        .get();

      if (!callerDoc.exists) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Caller user document not found."
        );
      }

      const callerRole = callerDoc.data()?.role;

      if (callerRole !== "admin" && callerRole !== "hr" && callerRole !== "manager") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only admin, HR, and managers can view employee lists."
        );
      }

      // Get employees list - remove orderBy to avoid index issues
      const employeesQuery = await admin
        .firestore()
        .collection("users")
        .where("role", "==", "employee")
        .get();

      const employees = employeesQuery.docs.map((doc) => {
        const data = doc.data();
        
        // Convert Firestore Timestamps to ISO strings for proper serialization
        const processedData = { ...data };
        if (data.dateOfBirth && data.dateOfBirth.toDate) {
          processedData.dateOfBirth = data.dateOfBirth.toDate().toISOString();
        }
        if (data.joiningDate && data.joiningDate.toDate) {
          processedData.joiningDate = data.joiningDate.toDate().toISOString();
        }
        if (data.createdAt && data.createdAt.toDate) {
          processedData.createdAt = data.createdAt.toDate().toISOString();
        }
        if (data.updatedAt && data.updatedAt.toDate) {
          processedData.updatedAt = data.updatedAt.toDate().toISOString();
        }
        
        return {
          uid: doc.id,
          ...processedData,
        };
      });

      // Sort in memory instead of using Firestore orderBy
      employees.sort((a: any, b: any) => (a.name || '').localeCompare(b.name || ''));

      return {
        success: true,
        employees: employees,
      };
    } catch (error: any) {
      functions.logger.error("Error getting employees:", error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "An error occurred while fetching employees."
      );
    }
  }
);

/**
 * Cloud Function to get teammates list (limited info for all authenticated users)
 */
export const getTeammates = functions.https.onCall(
  async (data, context) => {
    try {
      // Verify authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "The function must be called while authenticated."
        );
      }

      // Get all active users (no role restriction for teammates)
      const usersQuery = await admin
        .firestore()
        .collection("users")
        .where("isActive", "==", true)
        .get();

      const teammates = usersQuery.docs.map((doc) => {
        const data = doc.data();
        
        // Return only the requested fields for teammates
        return {
          uid: doc.id,
          name: data.name || '',
          email: data.email || '',
          phone: data.phone || data.phoneNumber || '',
          role: data.role || 'employee',
          department: data.department || '',
          designation: data.designation || data.jobTitle || '',
          empCode: data.empCode || '',
          isActive: data.isActive || false,
          // Convert timestamps to ISO strings if they exist
          dateOfBirth: data.dateOfBirth && data.dateOfBirth.toDate ? data.dateOfBirth.toDate().toISOString() : null,
          createdAt: data.createdAt && data.createdAt.toDate ? data.createdAt.toDate().toISOString() : null,
        };
      });

      // Sort by name
      teammates.sort((a: any, b: any) => (a.name || '').localeCompare(b.name || ''));

      return {
        success: true,
        employees: teammates, // Keep the same property name for compatibility
        message: `Retrieved ${teammates.length} teammates`
      };

    } catch (error: any) {
      functions.logger.error("Error getting teammates:", error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "An error occurred while fetching teammates."
      );
    }
  }
);

/**
 * Cloud Function to get admin users list (HR and Managers) - for Admin only
 */
export const getAdminUsers = functions.https.onCall(
  async (data, context) => {
    try {
      // Verify authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "The function must be called while authenticated."
        );
      }

      // Verify caller role - only admin can view admin users
      const callerUid = context.auth.uid;
      const callerDoc = await admin
        .firestore()
        .collection("users")
        .doc(callerUid)
        .get();

      if (!callerDoc.exists) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Caller user document not found."
        );
      }

      const callerRole = callerDoc.data()?.role;

      if (callerRole !== "admin") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only admin can view HR and Manager lists."
        );
      }

      // Get HR and Manager users
      const adminUsersQuery = await admin
        .firestore()
        .collection("users")
        .where("role", "in", ["hr", "manager"])
        .get();

      const adminUsers = adminUsersQuery.docs.map((doc) => ({
        uid: doc.id,
        ...doc.data(),
      }));

      // Sort in memory by name
      adminUsers.sort((a: any, b: any) => (a.name || '').localeCompare(b.name || ''));

      return {
        success: true,
        adminUsers: adminUsers,
      };
    } catch (error: any) {
      functions.logger.error("Error getting admin users:", error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "An error occurred while fetching admin users."
      );
    }
  }
);

/**
 * Cloud Function to update employee information
 */
export const updateEmployee = functions.https.onCall(
  async (data, context) => {
    try {
      // Verify authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "The function must be called while authenticated."
        );
      }

      // Verify caller role - only admin/hr/manager can update employees
      const callerUid = context.auth.uid;
      const callerDoc = await admin
        .firestore()
        .collection("users")
        .doc(callerUid)
        .get();

      if (!callerDoc.exists) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Caller user document not found."
        );
      }

      const callerRole = callerDoc.data()?.role;

      if (!["admin", "hr", "manager"].includes(callerRole)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only admin, HR, and managers can update employees."
        );
      }

      const { 
        uid, 
        name, 
        email, 
        empCode,
        department,
        designation, 
        joiningDate, 
        phoneNumber, 
        dateOfBirth, 
        address, 
        employmentType,
        workingHours,
        leaveBalance 
      } = data;

      if (!uid || !name || !email) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required fields: uid, name, email."
        );
      }

      const updateData: any = {
        name,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Update optional fields only if provided
      if (empCode !== undefined) updateData.empCode = empCode;
      if (department !== undefined) updateData.department = department;
      if (designation !== undefined) updateData.designation = designation;
      if (phoneNumber !== undefined) updateData.phoneNumber = phoneNumber;
      if (address !== undefined) updateData.address = address;
      if (employmentType !== undefined) updateData.employmentType = employmentType;
      if (workingHours !== undefined) updateData.workingHours = workingHours;

      // Handle date fields
      if (joiningDate) {
        updateData.joiningDate = admin.firestore.Timestamp.fromDate(new Date(joiningDate));
      }
      if (dateOfBirth) {
        updateData.dateOfBirth = admin.firestore.Timestamp.fromDate(new Date(dateOfBirth));
      }

      // Handle leave balance updates - only update the leaveBalance map
      if (leaveBalance) {
        // Get current leave balance and merge with new values
        const currentUserDoc = await admin.firestore().collection("users").doc(uid).get();
        const currentData = currentUserDoc.data();
        const currentLeaveBalance = currentData?.leaveBalance || {};
        
        const newLeaveBalance = {
          ...currentLeaveBalance,
          ...(leaveBalance.sickLeave !== undefined && { sickLeave: leaveBalance.sickLeave }),
          ...(leaveBalance.casualLeave !== undefined && { casualLeave: leaveBalance.casualLeave }),
          ...(leaveBalance.paidLeave !== undefined && { paidLeave: leaveBalance.paidLeave }), 
          ...(leaveBalance.optionalHoliday !== undefined && { optionalHoliday: leaveBalance.optionalHoliday }), // Fix key name
        };
        
        updateData.leaveBalance = newLeaveBalance;
      }

      // Update employee in Firestore
      await admin.firestore().collection("users").doc(uid).update(updateData);

      return {
        success: true,
        message: "Employee updated successfully.",
      };
    } catch (error: any) {
      functions.logger.error("Error updating employee:", error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "An error occurred while updating employee."
      );
    }
  }
);

/**
 * Cloud Function to delete employee
 * Only deletes from users collection and Firebase Auth
 * Other data cleanup can be implemented separately when needed
 */
export const deleteEmployee = functions.https.onCall(
  async (data, context) => {
    try {
      // Validate authentication
      if (!context.auth?.uid) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "Authentication required to delete employees."
        );
      }

      // Validate input
      const { uid } = data;
      if (!uid || typeof uid !== "string" || uid.trim() === "") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Valid employee UID is required."
        );
      }

      const callerUid = context.auth.uid;
      const normalizedUid = uid.trim();

      // Verify caller permissions
      const callerDoc = await admin.firestore()
        .collection("users")
        .doc(callerUid)
        .get();

      if (!callerDoc.exists || callerDoc.data()?.role !== "admin") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only administrators can delete employee accounts."
        );
      }

      // Verify target employee exists
      const employeeDoc = await admin.firestore()
        .collection("users")
        .doc(normalizedUid)
        .get();

      if (!employeeDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Employee account not found."
        );
      }

      const employeeData = employeeDoc.data();

      // Safety validations
      if (employeeData?.role === "admin") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Administrator accounts cannot be deleted for security reasons."
        );
      }

      if (normalizedUid === callerUid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You cannot delete your own account."
        );
      }

      functions.logger.info(`Admin ${callerUid} deleting employee ${normalizedUid} (${employeeData?.name || 'Unknown'})`);

      const deletedCollections: string[] = [];
      const batch = admin.firestore().batch();

      // Delete from users collection
      batch.delete(admin.firestore().collection("users").doc(normalizedUid));
      deletedCollections.push("users");

      // Commit Firestore changes
      await batch.commit();
      functions.logger.info(`Firestore deletion completed for ${normalizedUid}`);

      // Delete from Firebase Auth
      let authDeleted = false;
      try {
        await admin.auth().deleteUser(normalizedUid);
        deletedCollections.push("Firebase Auth");
        authDeleted = true;
        functions.logger.info(`Firebase Auth deletion completed for ${normalizedUid}`);
      } catch (authError: any) {
        functions.logger.warn(`Firebase Auth deletion failed for ${normalizedUid}: ${authError.message || authError}`);
        // Don't fail the entire operation if Auth deletion fails
      }

      const message = authDeleted 
        ? "Employee account deleted successfully from all systems."
        : "Employee account deleted from database. Authentication cleanup may require manual intervention.";

      return {
        success: true,
        message,
        deletedFrom: deletedCollections,
        uid: normalizedUid,
        employeeName: employeeData?.name || "Unknown"
      };

    } catch (error: any) {
      functions.logger.error("Employee deletion failed:", error);

      // Re-throw HttpsErrors as-is
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Handle unexpected errors
      throw new functions.https.HttpsError(
        "internal",
        `Employee deletion failed: ${error.message || 'Unknown error'}`
      );
    }
  }
);

/**
 * Cloud Function to update employee status (activate/deactivate)
 */
export const updateEmployeeStatus = functions.https.onCall(
  async (data, context) => {
    try {
      // Verify authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "The function must be called while authenticated."
        );
      }

      const { uid, isActive } = data;

      if (!uid || typeof isActive !== "boolean") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing or invalid required fields."
        );
      }

      // Update employee status in Firestore
      await admin.firestore().collection("users").doc(uid).update({
        isActive: isActive,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        message: `Employee ${isActive ? "activated" : "deactivated"} successfully.`,
      };
    } catch (error: any) {
      functions.logger.error("Error updating employee status:", error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "An error occurred while updating employee status."
      );
    }
  }
);

// Biometric API Integration Function
export const syncBiometricData = functions.https.onCall(
  async (data, context) => {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to sync biometric data."
      );
    }

    try {
      // Get user data to check role permissions
      const uid = context.auth.uid;
      const userDoc = await admin.firestore().collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "User not found."
        );
      }

      const userData = userDoc.data();
      const userRole = userData?.role?.toLowerCase();

      // Extract parameters from request
      const { 
        empcode, 
        fromDate, 
        toDate 
      } = data;

      // Check if user has permission to sync biometric data
      // Employees can only sync their own data, admins/HR/managers can sync any data
      if (userRole === 'employee') {
        // For employees, check if they're syncing their own data
        const userEmpCode = userData?.empCode;
        if (!userEmpCode || empcode !== userEmpCode) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "Employees can only sync their own biometric data."
          );
        }
      } else if (!['admin', 'hr', 'manager'].includes(userRole)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only employees (own data), admins, HR, or managers can sync biometric data."
        );
      }

      // Get biometric API credentials from environment
      const corporateId = functions.config().biometric?.corporate_id;
      const username = functions.config().biometric?.username;
      const password = functions.config().biometric?.password;

      // Validate required parameters
      if (!corporateId || !username || !password) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Corporate ID, username, and password are required."
        );
      }

      if (!fromDate || !toDate) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "FromDate and ToDate are required."
        );
      }

      // Convert date format from YYYY-MM-DD to DD/MM/YYYY for biometric API
      const convertDateFormat = (dateStr: string): string => {
        const date = new Date(dateStr);
        const day = date.getDate().toString().padStart(2, '0');
        const month = (date.getMonth() + 1).toString().padStart(2, '0');
        const year = date.getFullYear();
        return `${day}/${month}/${year}`;
      };

      const formattedFromDate = convertDateFormat(fromDate);
      const formattedToDate = convertDateFormat(toDate);

      // Call biometric API directly without rate limiting
      const biometricData = await callBiometricAPI({
        empCode: empcode,
        fromDate: formattedFromDate,
        toDate: formattedToDate,
        corporateId,
        username,
        password
      });

      // Store the synced data in Firestore
      const syncResult = await storeBiometricData(biometricData, {
        syncedBy: uid,
        syncedAt: admin.firestore.FieldValue.serverTimestamp(),
        empCode: empcode,
        fromDate,
        toDate
      });

      return {
        success: true,
        message: "Biometric data synced successfully",
        recordsProcessed: biometricData.length,
        records: [],  // Sync doesn't return records, just confirms count
        syncId: syncResult.syncId
      };

    } catch (error) {
      functions.logger.error("Error syncing biometric data:", error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError(
        "internal",
        "An error occurred while syncing biometric data."
      );
    }
  }
);

// Function to call the biometric machine API
async function callBiometricAPI(params: {
  empCode: string;
  fromDate: string;
  toDate: string;
  corporateId: string;
  username: string;
  password: string;
}): Promise<any[]> {
  
  const { empCode, fromDate, toDate, corporateId, username, password } = params;
  
  try {
    // Create Basic Auth credentials in the required format
    const authString = `${corporateId}:${username}:${password}:true`;
    const encodedAuth = Buffer.from(authString).toString('base64');
    
    // Construct API URL
    const apiUrl = 'https://api.etimeoffice.com/api/DownloadInOutPunchData';
    const queryParams = new URLSearchParams({
      Empcode: empCode,
      FromDate: fromDate,
      ToDate: toDate
    });
    
    const fullUrl = `${apiUrl}?${queryParams.toString()}`;
    

    
    // Make API request
    const response = await fetch(fullUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Basic ${encodedAuth}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    });

    if (!response.ok) {
      const errorText = await response.text();
      functions.logger.error(`API Error: ${response.status} - ${errorText}`);
      throw new Error(`Biometric API error: ${response.status} ${response.statusText}`);
    }

    const responseData = await response.json();
    
    // Handle the specific etimeoffice.com API response structure
    let records: any[] = [];
    
    if (responseData && typeof responseData === 'object') {
      // Check for etimeoffice API structure: { InOutPunchData: [...], Error: false, Msg: "Success" }
      if (responseData.InOutPunchData && Array.isArray(responseData.InOutPunchData)) {
        records = responseData.InOutPunchData;
      } else if (Array.isArray(responseData)) {
        records = responseData;
      } else if (responseData.data && Array.isArray(responseData.data)) {
        records = responseData.data;
      } else if (responseData.records && Array.isArray(responseData.records)) {
        records = responseData.records;
      } else {
        records = [];
      }
    }
    

    
    return records;
    
  } catch (error) {
    functions.logger.error("Error calling biometric API:", error);
    throw error;
  }
}

// Function to store biometric data in Firestore
async function storeBiometricData(
  biometricData: any[], 
  syncMetadata: {
    syncedBy: string;
    syncedAt: admin.firestore.FieldValue;
    empCode: string;
    fromDate: string;
    toDate: string;
  }
): Promise<{ syncId: string }> {
  
  const db = admin.firestore();
  
  // Check if employee still exists before creating attendance records
  const employeeExists = await db.collection('users')
    .where('empCode', '==', syncMetadata.empCode)
    .where('role', '==', 'employee')
    .limit(1)
    .get();
    
  if (employeeExists.empty) {
    functions.logger.warn(`Attempted to sync biometric data for deleted employee: ${syncMetadata.empCode}`);
    throw new functions.https.HttpsError(
      'not-found',
      `Employee with empCode ${syncMetadata.empCode} no longer exists. Cannot create attendance records.`
    );
  }
  
  const batch = db.batch();
  
  // Create a sync record
  const syncDocRef = db.collection('biometric_syncs').doc();
  const syncId = syncDocRef.id;
  
  batch.set(syncDocRef, {
    ...syncMetadata,
    recordCount: biometricData.length,
    status: 'completed'
  });
  
  // Group attendance data by date and store in optimized structure
  const attendanceByDate = new Map<string, any>();
  
  for (const record of biometricData) {
    if (!record.DateString || !record.Empcode) continue;
    
    // Convert DD/MM/YYYY to dd-MM-yyyy format for document ID
    const dateStr = record.DateString; // Already in DD/MM/YYYY format
    const [day, month, year] = dateStr.split('/');
    const formattedDate = `${day.padStart(2, '0')}-${month.padStart(2, '0')}-${year}`;
    const docId = `${record.Empcode}_${formattedDate}`;
    
    // Initialize attendance document if not exists
    if (!attendanceByDate.has(docId)) {
      attendanceByDate.set(docId, {
        empCode: record.Empcode,
        employeeName: record.Name || '',
        date: formattedDate,
        dateString: dateStr,
        punches: [],
        syncId: syncId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: record.Status || '',
        remark: record.Remark || '',
        rawData: record
      });
    }
    
    const attendanceDoc = attendanceByDate.get(docId);
    
    // Add IN punch if exists
    if (record.INTime && record.INTime !== '--:--') {
      attendanceDoc.punches.push({
        time: record.INTime,
        type: 'IN',
        datetime: `${dateStr} ${record.INTime}`,
        deviceId: 'biometric_machine'
      });
    }
    
    // Add OUT punch if exists  
    if (record.OUTTime && record.OUTTime !== '--:--') {
      attendanceDoc.punches.push({
        time: record.OUTTime,
        type: 'OUT', 
        datetime: `${dateStr} ${record.OUTTime}`,
        deviceId: 'biometric_machine'
      });
    }
  }
  
  // Store attendance documents using nested structure: attendance/{empCode}/{empCode_Month}/{empCode_Date}
  for (const [docId, attendanceData] of attendanceByDate) {
    // Parse date to get month name
    const [day, month, year] = attendanceData.date.split('-');
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                       'July', 'August', 'September', 'October', 'November', 'December'];
    const monthName = monthNames[parseInt(month) - 1];
    
    // Create nested structure: attendance/{empCode}/{empCode_Month}/{empCode_Date}
    const empDocRef = db.collection('attendance').doc(attendanceData.empCode);
    const monthCollectionRef = empDocRef.collection(`${attendanceData.empCode}_${monthName}`);
    const dateDocRef = monthCollectionRef.doc(docId);
    
    // Ensure the parent employee document exists
    batch.set(empDocRef, {
      empCode: attendanceData.empCode,
      employeeName: attendanceData.employeeName,
      lastSyncDate: admin.firestore.FieldValue.serverTimestamp(),
      activeMonths: admin.firestore.FieldValue.arrayUnion(`${attendanceData.empCode}_${monthName}`)
    }, { merge: true });
    
    // Use merge to combine with existing data if document exists
    batch.set(dateDocRef, {
      ...attendanceData,
      month: monthName,
      year: year,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastSyncId: syncId
    }, { merge: true });
  }
  
  // Execute batch write
  await batch.commit();
  
  // Optional: Clean up old sync records (older than 30 days)
  await cleanupOldSyncRecords(syncMetadata.empCode);
  
  return { syncId };
}

// Function to clean up old sync records (keep last 30 days)
async function cleanupOldSyncRecords(empCode: string): Promise<void> {
  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const oldRecords = await admin.firestore()
      .collection('biometric_syncs')
      .where('empCode', '==', empCode)
      .where('syncedAt', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();
    
    if (!oldRecords.empty) {
      const batch = admin.firestore().batch();
      
      oldRecords.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      functions.logger.info(`Cleaned up ${oldRecords.docs.length} old sync records for ${empCode}`);
    }
  } catch (error) {
    functions.logger.warn('Failed to clean up old sync records:', error);
    // Don't throw error - cleanup failure shouldn't break sync
  }
}

// Function to get stored biometric records from Firestore
export const getBiometricRecords = functions.https.onCall(
  async (data, context) => {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated."
      );
    }

    try {
      // Check user permissions
      const uid = context.auth.uid;
      const userDoc = await admin.firestore().collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        throw new functions.https.HttpsError("not-found", "User not found.");
      }

      const userData = userDoc.data();
      const userRole = userData?.role?.toLowerCase();

      // Extract parameters from request
      const { empcode, fromDate, toDate } = data;

      // Permission check: employees can only view their own records
      if (userRole === 'employee') {
        const userEmpCode = userData?.empCode;
        if (!userEmpCode || empcode !== userEmpCode) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "Employees can only view their own biometric records."
          );
        }
      } else if (!['admin', 'hr', 'manager'].includes(userRole)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Insufficient permissions to view biometric records."
        );
      }

      // Validate required parameters
      if (!empcode) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Employee code is required."
        );
      }

      // Build query for nested structure: attendance/{empCode}/{empCode_Month}/{empCode_Date}
      const empDocRef = admin.firestore().collection('attendance').doc(empcode);
      
      // Get the employee document to find active months
      const empDoc = await empDocRef.get();
      let records: any[] = [];
      
      if (empDoc.exists) {
        const empData = empDoc.data();
        const activeMonths = empData?.activeMonths || [];
        
        // Query each month's subcollection
        for (const monthCollection of activeMonths) {
          const monthCollectionRef = empDocRef.collection(monthCollection);
          const monthSnapshot = await monthCollectionRef.get();
          
          monthSnapshot.docs.forEach(doc => {
            const attendanceData = doc.data();
            const punches = attendanceData.punches || [];
            
            // Convert each punch to the expected record format
            punches.forEach((punch: any) => {
              // Parse datetime from "DD/MM/YYYY HH:mm" format
              const [dateStr, timeStr] = punch.datetime.split(' ');
              const [day, month, year] = dateStr.split('/');
              const [hours, minutes] = timeStr.split(':');
              
              const punchDateTime = new Date(
                parseInt(year), 
                parseInt(month) - 1, 
                parseInt(day),
                parseInt(hours),
                parseInt(minutes)
              );
              
              records.push({
                id: `${doc.id}_${punch.time}_${punch.type}`,
                empCode: attendanceData.empCode,
                dateTime: punchDateTime.toISOString(),
                type: punch.type,
                deviceId: punch.deviceId || 'biometric_machine',
                location: 'Office',
                date: attendanceData.date,
                timestamp: punchDateTime
              });
            });
          });
        }
      }

      // Filter by date range if provided
      if (fromDate) {
        const startDate = new Date(fromDate);
        records = records.filter(record => record.timestamp >= startDate);
      }

      if (toDate) {
        const endDate = new Date(toDate + 'T23:59:59.999Z');
        records = records.filter(record => record.timestamp <= endDate);
      }

      // Sort by dateTime descending (most recent first)
      records.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());

      // Remove the temporary timestamp field
      const finalRecords = records.map(record => {
        const { timestamp, ...recordWithoutTimestamp } = record;
        return recordWithoutTimestamp;
      });

      return {
        success: true,
        records: finalRecords,
        recordsProcessed: finalRecords.length,
        message: `Retrieved ${finalRecords.length} biometric records`
      };

    } catch (error) {
      functions.logger.error('Error getting biometric records:', error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to retrieve biometric records."
      );
    }
  }
);

// =============================================================================
// LEAVE MANAGEMENT FUNCTIONS
// =============================================================================

/**
 * Get available optional holidays defined by admin/HR
 */
export const getOptionalHolidays = functions.https.onCall(
  async (data, context) => {
    try {
      // Check if user is authenticated
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated", 
          "User must be authenticated to fetch optional holidays."
        );
      }

      functions.logger.info(`Fetching optional holidays for user: ${context.auth.uid}`);

      // Get optional holidays from Firestore: holidays/optional/data subcollection
      functions.logger.info('Attempting to fetch optional holidays from holidays/optional/data...');
      
      const optionalHolidaysSnapshot = await admin.firestore()
        .collection('holidays')
        .doc('optional')
        .collection('data')
        .get();

      const holidays: any[] = [];
      
      functions.logger.info(`Found ${optionalHolidaysSnapshot.size} documents in holidays/optional/data`);
      
      optionalHolidaysSnapshot.forEach(doc => {
        const holidayData = doc.data();
        functions.logger.info(`Processing holiday doc: ${doc.id}`, holidayData);
        
        // Include all holidays from this collection (they should all be optional type)
        holidays.push({
          id: doc.id,
          data: holidayData
        });
      });

      // Sort holidays by date in JavaScript instead of Firestore
      holidays.sort((a, b) => {
        const dateA = a.data.date?.toDate ? a.data.date.toDate() : new Date(a.data.date);
        const dateB = b.data.date?.toDate ? b.data.date.toDate() : new Date(b.data.date);
        return dateA.getTime() - dateB.getTime();
      });

      functions.logger.info(`Found ${holidays.length} optional holidays`);

      return {
        success: true,
        holidays: holidays,
        message: `Found ${holidays.length} available optional holidays`
      };

    } catch (error) {
      functions.logger.error('Error fetching optional holidays:', error);
      
      // Provide more detailed error information
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      functions.logger.error('Detailed error:', errorMessage);
      
      // Return an empty array instead of throwing to prevent app crashes
      return {
        success: false,
        holidays: [],
        message: `Failed to fetch optional holidays: ${errorMessage}`,
        error: errorMessage
      };
    }
  }
);

// =============================================================================
// LEAVE TYPE HANDLERS - Separate logic for each leave type
// =============================================================================

/**
 * Common leave validation and user data retrieval
 */
async function getLeaveApplicationContext(data: any, context: any) {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated", 
      "User must be authenticated to apply for leave."
    );
  }

  const { leaveType, startDate, endDate, totalDays, daysToDeduct } = data;

  // Validate required fields
  if (!leaveType || !startDate || !endDate) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing required fields: leaveType, startDate, endDate"
    );
  }

  // Get user details
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();

  if (!userDoc.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "User not found"
    );
  }

  const userData = userDoc.data();
  const empCode = userData?.empCode || context.auth.uid;
  const joiningDate = userData?.joiningDate ? userData.joiningDate.toDate() : null;

  return {
    userData,
    empCode,
    joiningDate,
    leaveType,
    startDate: new Date(startDate),
    endDate: new Date(endDate),
    totalDays,
    daysToDeduct
  };
}

/**
 * Calculate working days for deduction based on leave type policy
 */
function calculateWorkingDaysDeduction(startDate: Date, endDate: Date, deductionAmount: number): admin.firestore.Timestamp[] {
  const deductionDates: admin.firestore.Timestamp[] = [];
  const currentDate = new Date(startDate);
  
  // For PL and other full-duration leaves, calculate working days from start date
  while (deductionDates.length < deductionAmount && currentDate <= endDate) {
    // Skip Sundays (weekday 0 = Sunday)
    if (currentDate.getDay() !== 0) {
      deductionDates.push(admin.firestore.Timestamp.fromDate(new Date(currentDate)));
    }
    currentDate.setDate(currentDate.getDate() + 1);
  }
  
  return deductionDates;
}

/**
 * Handle Sick Leave (SL) Application
 */
async function handleSickLeaveApplication(data: any, context: any) {
  const leaveContext = await getLeaveApplicationContext(data, context);
  const { userData, empCode, startDate, endDate, totalDays, daysToDeduct } = leaveContext;
  const { reason, medicalCertificate } = data;

  // SL requires reason
  if (!reason) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Reason is required for Sick Leave"
    );
  }

  // Policy Rule 1: Check for active SL applications (one at a time)
  try {
    const activeSLSnapshot = await admin.firestore()
      .collection('leaveRequests')
      .doc(empCode)
      .collection('SL')
      .where('status', 'in', ['pending', 'approved'])
      .get();

    if (!activeSLSnapshot.empty) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "You have an active SL request. Cancel or wait for approval/rejection to apply again."
      );
    }
  } catch (error) {
    functions.logger.error('Error checking active SL requests:', error);
    // Continue if check fails
  }

  // Policy Rule 2: Check monthly limit (one SL per month)
  try {
    const currentMonth = startDate.getMonth();
    const currentYear = startDate.getFullYear();
    
    // Get all SL requests for the current month
    const monthlySLSnapshot = await admin.firestore()
      .collection('leaveRequests')
      .doc(empCode)
      .collection('SL')
      .get();

    // Check if any SL was applied in the current month (excluding cancelled/rejected/completed)
    let monthlySlUsed = false;
    for (const doc of monthlySLSnapshot.docs) {
      const slData = doc.data();
      if (slData.appliedDate && slData.status !== 'cancelled' && slData.status !== 'rejected' && slData.status !== 'completed') {
        const appliedDate = slData.appliedDate.toDate();
        if (appliedDate.getMonth() === currentMonth && 
            appliedDate.getFullYear() === currentYear) {
          monthlySlUsed = true;
          break;
        }
      }
    }

    if (monthlySlUsed) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "You have already used your monthly SL quota. Only one SL application allowed per month."
      );
    }
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error; // Re-throw our custom error
    }
    functions.logger.error('Error checking monthly SL limit:', error);
    // Continue if check fails
  }

  // Calculate actual deduction (always 1 for SL regardless of duration)
  const finalDeductionAmount = 1;

  // Calculate deduction dates for SL (only first date since only 1 day is deducted)
  const deductionDates = [admin.firestore.Timestamp.fromDate(startDate)];

  // Validate balance - Block application if zero balance
  const currentBalance = userData?.leaveBalance || {};
  const availableBalance = currentBalance['sickLeave'] || 0;
  
  if (availableBalance < finalDeductionAmount) {
    if (availableBalance === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `No Sick Leave balance available. Please use Leave Without Pay (LWP) for future absences. Available: ${availableBalance}`
      );
    } else {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Insufficient Sick Leave balance. Available: ${availableBalance}, Required: ${finalDeductionAmount}`
      );
    }
  }

  functions.logger.info(`SL Deduction: ${finalDeductionAmount} day(s) on dates:`, deductionDates.map(d => d.toDate()));

  // SL is auto-approved
  return {
    status: 'approved',
    finalDeductionAmount,
    deductionDates,
    balanceKey: 'sickLeave',
    approvalInfo: {
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: 'system',
      approvalNote: 'Sick leave auto-approved as per company policy'
    }
  };
}

/**
 * Handle Casual Leave (CL) Application
 */
async function handleCasualLeaveApplication(data: any, context: any) {
  const leaveContext = await getLeaveApplicationContext(data, context);
  const { userData, empCode, joiningDate, startDate, endDate, totalDays } = leaveContext;
  const { reason } = data;

  // CL requires reason
  if (!reason) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Reason is required for Casual Leave"
    );
  }

  // Policy Rule: Check service period eligibility for CL (6 months required)
  if (joiningDate) {
    const now = new Date();
    const monthsWorked = (now.getFullYear() - joiningDate.getFullYear()) * 12 + 
                       (now.getMonth() - joiningDate.getMonth());
    
    if (monthsWorked < 6) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Casual Leave can only be used after 6 months of service"
      );
    }
  }

  // Policy Rule: Check for active CL applications (one at a time)
  try {
    const activeCLSnapshot = await admin.firestore()
      .collection('leaveRequests')
      .doc(empCode)
      .collection('CL')
      .where('status', 'in', ['pending', 'approved'])
      .get();

    if (!activeCLSnapshot.empty) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "You have an active CL request. Cancel or wait for approval/rejection to apply again."
      );
    }
  } catch (error) {
    functions.logger.error('Error checking active CL requests:', error);
    // Continue if check fails
  }

  // Policy Rule: CL Monthly Limit Check (1 per month)
  try {
    const currentMonth = startDate.getMonth();
    const currentYear = startDate.getFullYear();
    
    // Get all CL requests for the current month
    const monthlyClSnapshot = await admin.firestore()
      .collection('leaveRequests')
      .doc(empCode)
      .collection('CL')
      .get();

    // Check if any CL was applied in the current month (excluding cancelled/rejected/completed)
    let monthlyClUsed = false;
    for (const doc of monthlyClSnapshot.docs) {
      const clData = doc.data();
      if (clData.startDate && clData.status !== 'cancelled' && clData.status !== 'rejected' && clData.status !== 'completed') {
        const appliedDate = clData.startDate.toDate();
        if (appliedDate.getMonth() === currentMonth && 
            appliedDate.getFullYear() === currentYear) {
          monthlyClUsed = true;
          break;
        }
      }
    }

    if (monthlyClUsed) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "You have already used your monthly CL quota. Only one CL application allowed per month."
      );
    }
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error; // Re-throw our custom error
    }
    functions.logger.error('Error checking monthly CL limit:', error);
    // Continue if check fails
  }

  // Calculate actual deduction (always 1 for CL regardless of duration)
  const finalDeductionAmount = 1;

  // Calculate deduction dates for CL (only first date since only 1 day is deducted)
  const deductionDates = [admin.firestore.Timestamp.fromDate(startDate)];

  // Validate balance - Block application if zero balance
  const currentBalance = userData?.leaveBalance || {};
  const availableBalance = currentBalance['casualLeave'] || 0;
  
  if (availableBalance < finalDeductionAmount) {
    if (availableBalance === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `No Casual Leave balance available. Please use Leave Without Pay (LWP) for future absences. Available: ${availableBalance}`
      );
    } else {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Insufficient Casual Leave balance. Available: ${availableBalance}, Required: ${finalDeductionAmount}`
      );
    }
  }

  functions.logger.info(`CL Deduction: ${finalDeductionAmount} day(s) on dates:`, deductionDates.map(d => d.toDate()));

  // CL requires approval
  return {
    status: 'pending',
    finalDeductionAmount,
    deductionDates,
    balanceKey: 'casualLeave',
    approvalInfo: {}
  };
}

/**
 * Handle Paid Leave (PL) Application
 */
async function handlePaidLeaveApplication(data: any, context: any) {
  const leaveContext = await getLeaveApplicationContext(data, context);
  const { userData, empCode, joiningDate, startDate, endDate, totalDays } = leaveContext;
  const { reason } = data;

  // PL requires reason
  if (!reason) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Reason is required for Paid Leave"
    );
  }

  // Policy Rule: Check service period eligibility for PL (6 months required)
  if (joiningDate) {
    const now = new Date();
    const monthsWorked = (now.getFullYear() - joiningDate.getFullYear()) * 12 + 
                       (now.getMonth() - joiningDate.getMonth());
    
    if (monthsWorked < 6) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Paid Leave can only be used after 6 months of service"
      );
    }
  }

  // Policy Rule: Check for active PL applications (one at a time)
  try {
    const activePLSnapshot = await admin.firestore()
      .collection('leaveRequests')
      .doc(empCode)
      .collection('PL')
      .where('status', 'in', ['pending', 'approved'])
      .get();

    if (!activePLSnapshot.empty) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "You have an active PL request. Cancel or wait for approval/rejection to apply again."
      );
    }
  } catch (error) {
    functions.logger.error('Error checking active PL requests:', error);
    // Continue if check fails
  }

  // Policy Rule: PL Monthly Limit Check (1 per month)
  try {
    const currentMonth = startDate.getMonth();
    const currentYear = startDate.getFullYear();
    
    // Get all PL requests for the current month
    const monthlyPlSnapshot = await admin.firestore()
      .collection('leaveRequests')
      .doc(empCode)
      .collection('PL')
      .get();

    // Check if any PL was applied in the current month (excluding cancelled/rejected/completed)
    let monthlyPlUsed = false;
    for (const doc of monthlyPlSnapshot.docs) {
      const plData = doc.data();
      if (plData.startDate && plData.status !== 'cancelled' && plData.status !== 'rejected' && plData.status !== 'completed') {
        const appliedDate = plData.startDate.toDate();
        if (appliedDate.getMonth() === currentMonth && 
            appliedDate.getFullYear() === currentYear) {
          monthlyPlUsed = true;
          break;
        }
      }
    }

    if (monthlyPlUsed) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "You have already used your monthly PL quota. Only one PL application allowed per month."
      );
    }
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error; // Re-throw our custom error
    }
    functions.logger.error('Error checking monthly PL limit:', error);
    // Continue if check fails
  }

  // Policy Rule: PL Advance Application Check (cannot apply for current day or next day)
  const today = new Date();
  const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const twoDaysFromNow = new Date(todayStart);
  twoDaysFromNow.setDate(twoDaysFromNow.getDate() + 2);
  
  const startDateOnly = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate());
  
  if (startDateOnly < twoDaysFromNow) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Paid Leave must be applied at least 2 days in advance. You can apply for leave starting from " + 
      twoDaysFromNow.toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' })
    );
  }

  // Policy Rule: PL Minimum Days Check (minimum 2 days)
  if (totalDays < 2) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Paid Leave requires minimum 2 days per application. Please apply for at least 2 days or use Casual Leave for single day requests."
    );
  }

  // Validate balance - Block application if zero balance
  const currentBalance = userData?.leaveBalance || {};
  const availableBalance = currentBalance['paidLeave'] || 0;
  let finalDeductionAmount = totalDays;
  
  if (availableBalance === 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `No Paid Leave balance available. Please use Leave Without Pay (LWP) for future absences. Available: ${availableBalance}`
    );
  } else if (totalDays > availableBalance) {
    // Allow excess days (available balance deducted, rest marked absent)
    const absentDays = totalDays - availableBalance;
    functions.logger.info(`PL approved with partial balance: ${availableBalance} days from balance, ${absentDays} days will be marked absent`);
    finalDeductionAmount = availableBalance;
  }

  // Calculate deduction dates for PL (all working days between start and end date)
  const deductionDates = calculateWorkingDaysDeduction(startDate, endDate, finalDeductionAmount);

  functions.logger.info(`PL Deduction: ${finalDeductionAmount} day(s) on dates:`, deductionDates.map(d => d.toDate()));

  // PL requires approval
  return {
    status: 'pending',
    finalDeductionAmount,
    deductionDates,
    balanceKey: 'paidLeave',
    approvalInfo: {}
  };
}

/**
 * Handle Optional Holiday (OH) Application
 */
async function handleOptionalHolidayApplication(data: any, context: any) {
  const leaveContext = await getLeaveApplicationContext(data, context);
  const { userData, empCode, startDate, endDate, totalDays } = leaveContext;
  const { selectedOptionalHolidayId } = data;

  // OH must be single day
  if (totalDays !== 1) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Optional Holiday can only be applied for single days"
    );
  }

  // Must select a specific holiday
  if (!selectedOptionalHolidayId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Please select a specific optional holiday from the available list"
    );
  }

  // Validate the selected holiday
  functions.logger.info(`🔍 Looking for holiday with ID: ${selectedOptionalHolidayId}`);
  
  const holidayDoc = await admin.firestore()
    .collection('holidays')
    .doc('optional')
    .collection('data')
    .doc(selectedOptionalHolidayId)
    .get();

  functions.logger.info(`🏖️ Holiday document exists: ${holidayDoc.exists}`);

  if (!holidayDoc.exists) {
    // Let's list all available holiday IDs for debugging
    const allHolidays = await admin.firestore()
      .collection('holidays')
      .doc('optional')
      .collection('data')
      .get();
    
    const availableIds = allHolidays.docs.map(doc => doc.id);
    functions.logger.error(`❌ Holiday not found. Available IDs: ${JSON.stringify(availableIds)}`);
    
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Selected optional holiday not found. Available IDs: ${availableIds.join(', ')}`
    );
  }

  const selectedHoliday = holidayDoc.data();
  
  // Validate that the start date matches the holiday date
  const holidayDate = selectedHoliday?.date;
  const requestStartDate = startDate;
  
  // Handle Firestore Timestamp conversion
  let holidayDateObj: Date;
  if (holidayDate?.toDate) {
    holidayDateObj = holidayDate.toDate();
  } else if (holidayDate?._seconds) {
    holidayDateObj = new Date(holidayDate._seconds * 1000);
  } else {
    holidayDateObj = new Date(holidayDate);
  }
  
  // Handle timezone offset - holiday dates are set in IST but stored as UTC
  const ISTOffset = 5.5 * 60 * 60 * 1000; // IST is UTC+5:30
  const holidayDateIST = new Date(holidayDateObj.getTime() + ISTOffset);
  
  // Compare dates using local time components
  const requestYear = requestStartDate.getFullYear();
  const requestMonth = requestStartDate.getMonth() + 1;
  const requestDay = requestStartDate.getDate();
  const requestDateStr = `${requestYear}-${String(requestMonth).padStart(2, '0')}-${String(requestDay).padStart(2, '0')}`;
  
  const holidayYear = holidayDateIST.getFullYear();
  const holidayMonth = holidayDateIST.getMonth() + 1;
  const holidayDay = holidayDateIST.getDate();
  const holidayDateStr = `${holidayYear}-${String(holidayMonth).padStart(2, '0')}-${String(holidayDay).padStart(2, '0')}`;
  
  if (requestDateStr !== holidayDateStr) {
    functions.logger.error(`Date mismatch: Request=${requestDateStr}, Holiday=${holidayDateStr}`);
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Leave date must match the selected optional holiday date`
    );
  }

  // Validate balance - Block application if zero balance
  const currentBalance = userData?.leaveBalance || {};
  const availableBalance = currentBalance['optionalHoliday'] || 0;
  const finalDeductionAmount = 1;
  
  if (availableBalance < finalDeductionAmount) {
    if (availableBalance === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `No Optional Holiday balance available. Please use Leave Without Pay (LWP) for future absences. Available: ${availableBalance}`
      );
    } else {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Insufficient Optional Holiday balance. Available: ${availableBalance}, Required: ${finalDeductionAmount}`
      );
    }
  }

  // Calculate deduction dates for OH (single day)
  const deductionDates = [admin.firestore.Timestamp.fromDate(startDate)];

  functions.logger.info(`OH Deduction: ${finalDeductionAmount} day(s) on dates:`, deductionDates.map(d => d.toDate()));

  // OH is auto-approved
  return {
    status: 'approved',
    finalDeductionAmount,
    deductionDates,
    balanceKey: 'optionalHoliday',
    approvalInfo: {
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: 'system',
      approvalNote: 'Optional holiday auto-approved as per company policy'
    }
  };
}

/**
 * Handle Leave Without Pay (LWP) Application
 */
async function handleLwpLeaveApplication(data: any, context: any) {
  const leaveContext = await getLeaveApplicationContext(data, context);
  const { userData, empCode, startDate, endDate, totalDays } = leaveContext;
  const { reason } = data;

  // LWP requires reason
  if (!reason) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Reason is required for Leave Without Pay"
    );
  }

  // LWP has no balance check - it's unlimited
  // No monthly limits or restrictions - employees can apply multiple times
  // LWP deducts full duration from pay but no balance tracking needed
  const finalDeductionAmount = 0; // No leave balance deduction for LWP

  // Calculate deduction dates (for payroll purposes, but not for balance)
  const deductionDates: admin.firestore.Timestamp[] = [];
  let currentDate = new Date(startDate);
  while (currentDate <= endDate) {
    deductionDates.push(admin.firestore.Timestamp.fromDate(new Date(currentDate)));
    currentDate.setDate(currentDate.getDate() + 1);
  }

  functions.logger.info(`LWP Application: ${totalDays} day(s) on dates:`, deductionDates.map(d => d.toDate()));

  // LWP is auto-approved like SL
  return {
    status: 'approved',
    finalDeductionAmount,
    deductionDates,
    balanceKey: 'lwp', // This key exists but won't be used for balance deduction
    approvalInfo: {
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: 'system',
      approvalNote: 'Leave without pay auto-approved as per company policy'
    }
  };
}

/**
 * Handle Official Leave Application
 */
async function handleOfficialLeaveApplication(data: any, context: any) {
  const leaveContext = await getLeaveApplicationContext(data, context);
  const { userData, empCode, startDate, endDate, totalDays } = leaveContext;
  const { reason } = data;

  // Official Leave requires reason
  if (!reason) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Reason is required for Official Leave"
    );
  }

  // Official Leave has no balance check - it's unlimited like LWP
  // No monthly limits or restrictions - employees can apply multiple times
  // Official Leave doesn't deduct from balance as it's for official work
  const finalDeductionAmount = 0; // No leave balance deduction for Official Leave

  // Calculate deduction dates (for record purposes only)
  const deductionDates: admin.firestore.Timestamp[] = [];
  let currentDate = new Date(startDate);
  while (currentDate <= endDate) {
    deductionDates.push(admin.firestore.Timestamp.fromDate(new Date(currentDate)));
    currentDate.setDate(currentDate.getDate() + 1);
  }

  functions.logger.info(`Official Leave Application: ${totalDays} day(s) on dates:`, deductionDates.map(d => d.toDate()));

  // Official Leave requires manager approval (unlike LWP which is auto-approved)
  return {
    status: 'pending',
    finalDeductionAmount,
    deductionDates,
    balanceKey: 'officialLeave', // Balance key for consistency but won't be used for deduction
    approvalInfo: null // No approval info yet - pending manager approval
  };
}

/**
 * Main Apply for Leave Function - Routes to appropriate handler
 */
export const applyForLeave = functions.https.onCall(
  async (data, context) => {
    try {
      const { leaveType } = data;

      functions.logger.info(`Leave application from user: ${context.auth?.uid}, type: ${leaveType}`);

      // Route to appropriate leave type handler
      let leaveResult;
      switch (leaveType) {
        case 'sick':
          leaveResult = await handleSickLeaveApplication(data, context);
          break;
        case 'casual':
          leaveResult = await handleCasualLeaveApplication(data, context);
          break;
        case 'paid':
          leaveResult = await handlePaidLeaveApplication(data, context);
          break;
        case 'optionalHoliday':
          leaveResult = await handleOptionalHolidayApplication(data, context);
          break;
        case 'lwp':
          leaveResult = await handleLwpLeaveApplication(data, context);
          break;
        case 'officialLeave':
          leaveResult = await handleOfficialLeaveApplication(data, context);
          break;
        default:
          throw new functions.https.HttpsError(
            "invalid-argument",
            `Unsupported leave type: ${leaveType}`
          );
      }

      // Get context from the handlers
      const leaveContext = await getLeaveApplicationContext(data, context);
      const { userData, empCode, startDate, endDate, totalDays } = leaveContext;
      const { reason, medicalCertificate, selectedOptionalHolidayId } = data;
      const { status, finalDeductionAmount, deductionDates, balanceKey, approvalInfo } = leaveResult;

      // Create leave request data
      const leaveRequestData = {
        employeeId: context.auth.uid,
        employeeName: userData?.name || 'Unknown',
        employeeEmail: userData?.email || context.auth.token.email,
        leaveType: leaveType,
        startDate: admin.firestore.Timestamp.fromDate(startDate),
        endDate: admin.firestore.Timestamp.fromDate(endDate),
        totalDays: totalDays,
        daysToDeduct: finalDeductionAmount,
        deductionDates: deductionDates || [], // Array of dates to be deducted from balance (for reporting)
        reason: reason,
        status: status,
        medicalCertificate: medicalCertificate,
        selectedOptionalHolidayId: selectedOptionalHolidayId,
        appliedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...approvalInfo
      };

      // New Collection Structure: leaveRequests > empCode > LeaveType > leavedetails
      const leaveTypeCollection = leaveType === 'sick' ? 'SL' : 
                                leaveType === 'casual' ? 'CL' : 
                                leaveType === 'paid' ? 'PL' : 
                                leaveType === 'lwp' ? 'LWP' : 
                                leaveType === 'officialLeave' ? 'OL' : 'OH';
      
      // Add to new structured leave requests collection
      const leaveRequestRef = await admin.firestore()
        .collection('leaveRequests')
        .doc(empCode)
        .collection(leaveTypeCollection)
        .add(leaveRequestData);

      functions.logger.info(`Leave request created with ID: ${leaveRequestRef.id} for employee: ${empCode}, type: ${leaveTypeCollection}`);

      // Update user's leave balance after approval (for auto-approved leaves)
      if (status === 'approved') {
        await admin.firestore()
          .collection('users')
          .doc(context.auth.uid)
          .update({
            [`leaveBalance.${balanceKey}`]: admin.firestore.FieldValue.increment(-finalDeductionAmount),
            'updatedAt': admin.firestore.FieldValue.serverTimestamp()
          });

        functions.logger.info(`Updated leave balance for user: ${context.auth.uid}, deducted: ${finalDeductionAmount} from ${balanceKey}`);
      }

      // Generate success message based on leave type
      let successMessage = '';
      if (leaveType === 'sick') {
        const absentDays = totalDays - finalDeductionAmount;
        successMessage = `Sick leave approved automatically. ${finalDeductionAmount} day${finalDeductionAmount > 1 ? 's' : ''} deducted from your balance.${absentDays > 0 ? ` ${absentDays} day(s) will be marked as absent if you don't punch in at office.` : ''} HR/Manager has been notified.`;
      } else if (leaveType === 'optionalHoliday') {
        successMessage = `Optional holiday approved automatically. ${finalDeductionAmount} day deducted from your balance.`;
      } else if (leaveType === 'casual') {
        const absentDays = totalDays - finalDeductionAmount;
        successMessage = `Casual leave request submitted successfully and is pending approval.${absentDays > 0 ? ` Note: Only 1 CL will be deducted, ${absentDays} day(s) will be marked as absent if you don't punch in at office.` : ''}`;
      } else if (leaveType === 'paid') {
        const absentDays = totalDays - finalDeductionAmount;
        successMessage = `Paid leave request submitted successfully and is pending approval.${absentDays > 0 ? ` Note: ${finalDeductionAmount} day(s) will be deducted from balance, ${absentDays} day(s) will be marked as absent if you don't punch in at office.` : ''}`;
      } else {
        successMessage = 'Leave request submitted successfully and is pending approval';
      }

      // Send notification to admins/HR/managers for all leaves (both pending and auto-approved)
      if (status === 'pending' || status === 'approved') {
        // Format leave type display name
        const leaveTypeDisplayName = leaveType === 'sick' ? 'Sick Leave' : 
                                   leaveType === 'casual' ? 'Casual Leave' : 
                                   leaveType === 'paid' ? 'Paid Leave' : 
                                   leaveType === 'lwp' ? 'Leave Without Pay' : 
                                   leaveType === 'officialLeave' ? 'Official Leave' : 'Optional Holiday';
        
        // Send notifications asynchronously without blocking the main response
        setImmediate(async () => {
          try {
            const recipients = await getNotificationRecipients();
            
            if (recipients.length > 0) {
              const formatDate = (date: Date) => {
                return date.toLocaleDateString('en-US', {
                  year: 'numeric',
                  month: 'short',
                  day: 'numeric'
                });
              };
              
              const dateRange = endDate && startDate.toDateString() !== endDate.toDateString() 
                ? `${formatDate(startDate)} - ${formatDate(endDate)}`
                : formatDate(startDate);
              
              const title = status === 'pending' ? 'New Leave Application' : 'Leave Auto-Approved';
              const body = status === 'pending' 
                ? `${userData?.name || 'Employee'} (${empCode}) applied for ${leaveTypeDisplayName} from ${dateRange}` 
                : `${userData?.name || 'Employee'} (${empCode}) applied for ${leaveTypeDisplayName} from ${dateRange} - Auto-approved`;
              
              const notificationPromises = recipients.map(recipient => 
                sendFCMNotification(
                  recipient.fcmToken!,
                  title,
                  body,
                  {
                    type: status === 'pending' ? 'leave_application' : 'leave_auto_approved',
                    empCode,
                    employeeName: userData?.name || 'Unknown',
                    leaveType: leaveTypeDisplayName,
                    startDate: startDate.toISOString(),
                    endDate: endDate.toISOString(),
                    reason: reason || '',
                    status: status,
                  }
                ).catch(error => {
                  functions.logger.error(`Failed to send notification to ${recipient.name}:`, error);
                  return null;
                })
              );
              
              const results = await Promise.all(notificationPromises);
              const successCount = results.filter(result => result !== null).length;
              functions.logger.info(`Leave application notifications sent: ${successCount}/${recipients.length} for ${empCode}`);
            }
          } catch (notificationError) {
            functions.logger.error('Failed to send leave application notifications:', notificationError);
          }
        });
      }

      return {
        success: true,
        leaveRequestId: leaveRequestRef.id,
        message: successMessage,
        status: status,
        empCode: empCode,
        leaveTypeCollection: leaveTypeCollection
      };

    } catch (error) {
      functions.logger.error('Error applying for leave:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to submit leave request."
      );
    }
  }
);

/**
 * Get user's leave requests
 */
export const getMyLeaveRequests = functions.https.onCall(
  async (data, context) => {
    try {
      // Check if user is authenticated
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated", 
          "User must be authenticated to fetch leave requests."
        );
      }

      functions.logger.info(`Fetching leave requests for user: ${context.auth.uid}`);

      // Get user details to find empCode
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(context.auth.uid)
        .get();

      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "User not found"
        );
      }

      const userData = userDoc.data();
      const empCode = userData?.empCode || context.auth.uid;

      // Get leave requests from new structure: leaveRequests > empCode > LeaveType > documents
      const requests: any[] = [];
      const leaveTypes = ['SL', 'CL', 'PL', 'OH', 'LWP', 'OL'];

      for (const leaveType of leaveTypes) {
        const leaveTypeSnapshot = await admin.firestore()
          .collection('leaveRequests')
          .doc(empCode)
          .collection(leaveType)
          .orderBy('appliedAt', 'desc')
          .get();

        leaveTypeSnapshot.forEach(doc => {
          const requestData = doc.data();
          
          requests.push({
            id: doc.id,
            leaveType: mapCollectionNameToLeaveType(leaveType),
            data: requestData
          });
        });
      }

      // Sort all requests by appliedAt in descending order
      requests.sort((a, b) => {
        const aTime = a.data.appliedAt?.toDate?.() || new Date(0);
        const bTime = b.data.appliedAt?.toDate?.() || new Date(0);
        return bTime.getTime() - aTime.getTime();
      });

      functions.logger.info(`Found ${requests.length} leave requests for user`);

      return {
        success: true,
        requests: requests,
        message: `Found ${requests.length} leave requests`
      };

    } catch (error) {
      functions.logger.error('Error fetching leave requests:', error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to fetch leave requests."
      );
    }
  }
);

/**
 * Cancel a leave request
 * - Pending requests: Can always be cancelled
 * - Sick Leave (approved): Can be cancelled until end date
 * - Other approved requests: Cannot be cancelled
 */
export const cancelLeaveRequest = functions.https.onCall(
  async (data, context) => {
    try {
      // Check if user is authenticated
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated", 
          "User must be authenticated to cancel leave request."
        );
      }

      const { requestId, leaveType } = data;

      if (!requestId || !leaveType) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Request ID and leave type are required"
        );
      }

      functions.logger.info(`Cancelling leave request: ${requestId} (type: ${leaveType}) by user: ${context.auth.uid}`);

      // Get user details to find empCode
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(context.auth.uid)
        .get();

      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "User not found"
        );
      }

      const userData = userDoc.data();
      const empCode = userData?.empCode || context.auth.uid;

      // Get the leave request from new structure
      const requestDoc = await admin.firestore()
        .collection('leaveRequests')
        .doc(empCode)
        .collection(leaveType)
        .doc(requestId)
        .get();

      if (!requestDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Leave request not found"
        );
      }

      const requestData = requestDoc.data();

      // Verify that this request belongs to the current user
      if (requestData?.employeeId !== context.auth.uid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You can only cancel your own leave requests"
        );
      }

      // Check if request can be cancelled based on status and leave type
      const canCancel = (() => {
        // Always allow cancellation of pending requests
        if (requestData?.status === 'pending') {
          return true;
        }
        
        // For approved requests: check specific rules based on leave type
        if (requestData?.status === 'approved') {
          const today = new Date();
          const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
          
          // Special rule for Sick Leave (both single and multi-day)
          if (leaveType === 'SL') {
            // For SL: allow cancellation until the applied date ends (first day)
            // Since only first day is deducted as SL, allow cancellation on the same day or before
            const startDate = requestData.startDate;
            if (startDate) {
              const leaveStartDate = startDate.toDate ? startDate.toDate() : new Date(startDate);
              const leaveStartDateStart = new Date(leaveStartDate.getFullYear(), leaveStartDate.getMonth(), leaveStartDate.getDate());
              
              functions.logger.info(`Date comparison for SL cancellation:`, {
                todayStart: todayStart.toISOString(),
                leaveStartDateStart: leaveStartDateStart.toISOString(),
                canCancel: todayStart <= leaveStartDateStart,
                totalDays: requestData.totalDays,
                leaveType,
                status: requestData?.status
              });
              
              // Allow cancellation on the same day as start date or before
              return todayStart <= leaveStartDateStart;
            }
          }
          
          // For single-day SL or other leave types, check end date
          const endDate = requestData.endDate;
          if (endDate) {
            // Handle both Firestore Timestamp and Date objects
            const leaveEndDate = endDate.toDate ? endDate.toDate() : new Date(endDate);
            const leaveEndDateStart = new Date(leaveEndDate.getFullYear(), leaveEndDate.getMonth(), leaveEndDate.getDate());
            
            // Debug logging
            functions.logger.info(`Date comparison for ${leaveType} cancellation:`, {
              todayStart: todayStart.toISOString(),
              leaveEndDateStart: leaveEndDateStart.toISOString(),
              canCancel: todayStart <= leaveEndDateStart,
              leaveType,
              status: requestData?.status
            });
            
            // Allow cancellation if today is before or on the leave end date
            return todayStart <= leaveEndDateStart;
          }
        }
        
        return false;
      })();

      if (!canCancel) {
        const statusMessage = requestData?.status === 'approved' 
          ? "Approved leave requests can only be cancelled until the end date"
          : "Only pending leave requests can be cancelled";
        throw new functions.https.HttpsError(
          "invalid-argument",
          statusMessage
        );
      }

      // If this was an approved request, reverse the balance deduction
      let reversalAmount = 0;
      if (requestData?.status === 'approved') {
        // Use the actual deduction amount that was stored during application
        // This ensures we reverse exactly what was deducted
        reversalAmount = requestData.daysToDeduct || 1; // Fallback to 1 for older records
        
        // For older records without daysToDeduct field, calculate based on leave type policy
        if (!requestData.daysToDeduct) {
          if (leaveType === 'SL' || leaveType === 'CL') {
            // SL and CL always deduct only 1 day
            reversalAmount = 1;
          } else {
            // For PL and OH, calculate working days
            const startDate = requestData.startDate.toDate ? requestData.startDate.toDate() : new Date(requestData.startDate);
            const endDate = requestData.endDate.toDate ? requestData.endDate.toDate() : new Date(requestData.endDate);
            
            let workingDays = 0;
            const currentDate = new Date(startDate);
            while (currentDate <= endDate) {
              if (currentDate.getDay() !== 0) { // 0 = Sunday
                workingDays++;
              }
              currentDate.setDate(currentDate.getDate() + 1);
            }
            reversalAmount = workingDays;
          }
        }
        
        // Determine balance key for reversal
        let balanceKey = '';
        switch (leaveType) {
          case 'SL':
            balanceKey = 'sickLeave';
            break;
          case 'CL':
            balanceKey = 'casualLeave';
            break;
          case 'PL':
            balanceKey = 'paidLeave';
            break;
          case 'OH':
            balanceKey = 'optionalHoliday';
            break;
          default:
            functions.logger.error(`Unknown leave type for balance reversal: ${leaveType}`);
        }
        
        // Reverse the balance deduction
        if (balanceKey && reversalAmount > 0) {
          await admin.firestore()
            .collection('users')
            .doc(context.auth.uid)
            .update({
              [`leaveBalance.${balanceKey}`]: admin.firestore.FieldValue.increment(reversalAmount),
              'updatedAt': admin.firestore.FieldValue.serverTimestamp()
            });
          
          functions.logger.info(`Reversed leave balance for user: ${context.auth.uid}, added back: ${reversalAmount} to ${balanceKey}`);
        }
      }

      // Update request status to cancelled
      await admin.firestore()
        .collection('leaveRequests')
        .doc(empCode)
        .collection(leaveType)
        .doc(requestId)
        .update({
          status: 'cancelled',
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

      functions.logger.info(`Leave request ${requestId} cancelled successfully${reversalAmount > 0 ? ` and ${reversalAmount} days restored to balance` : ''}`);

      const message = reversalAmount > 0 
        ? `Leave request cancelled successfully and ${reversalAmount} day${reversalAmount > 1 ? 's' : ''} restored to your balance`
        : 'Leave request cancelled successfully';

      return {
        success: true,
        message: message
      };

    } catch (error) {
      functions.logger.error('Error cancelling leave request:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to cancel leave request."
      );
    }
  }
);

/**
 * Helper function to map collection names to proper leave type values
 */
function mapCollectionNameToLeaveType(collectionName: string): string {
  switch (collectionName) {
    case 'SL':
      return 'sick';
    case 'CL':
      return 'casual';
    case 'PL':
      return 'paid';
    case 'OH':
      return 'optionalHoliday';
    case 'LWP':
      return 'lwp';
    case 'OL':
      return 'officialLeave';
    default:
      return 'sick'; // fallback
  }
}

/**
 * Helper function to map leave type values to collection names
 */
function mapLeaveTypeToCollectionName(leaveType: string): string {
  switch (leaveType) {
    case 'sick':
      return 'SL';
    case 'casual':
      return 'CL';
    case 'paid':
      return 'PL';
    case 'optionalHoliday':
      return 'OH';
    case 'lwp':
      return 'LWP';
    case 'officialLeave':
      return 'OL';
    default:
      return 'SL'; // fallback
  }
}

// Cloud Function: Get All Employee Leave Requests for Admin/HR/Manager
export const getAllEmployeeLeaveRequests = functions.https.onCall(
  async (data, context) => {
    try {
      // Check authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated to access leave requests."
        );
      }

      functions.logger.info(`Admin leave requests called by user: ${context.auth.uid}`);

      // Verify user has admin/HR/manager role
      const callerSnapshot = await admin.firestore()
        .collection('users')
        .doc(context.auth.uid)
        .get();

      if (!callerSnapshot.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "User profile not found."
        );
      }

      const callerData = callerSnapshot.data();
      const allowedRoles = ['admin', 'hr', 'manager'];
      
      if (!callerData || !allowedRoles.includes(callerData.role)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Access denied. Admin, HR, or Manager role required."
        );
      }

      const { 
        status = null, 
        employeeId = null, 
        leaveType = null, 
        startDate = null, 
        endDate = null,
        limit = 100 
      } = data;

      functions.logger.info(`Filters: status=${status}, employeeId=${employeeId}, leaveType=${leaveType}, limit=${limit}`);

      const allLeaveRequests: any[] = [];

      // Get all employee codes first
      const employeesSnapshot = await admin.firestore()
        .collection('users')
        .where('role', '==', 'employee')
        .get();

      const employeeProfiles: { [key: string]: any } = {};
      
      // Build employee profile mapping
      employeesSnapshot.docs.forEach(doc => {
        const userData = doc.data();
        if (userData.empCode) {
          employeeProfiles[userData.empCode] = {
            id: doc.id,
            name: userData.name,
            email: userData.email,
            department: userData.department,
            designation: userData.designation,
            empCode: userData.empCode
          };
        }
      });

      // If specific employee is requested, filter to that employee
      const employeeCodesToCheck = employeeId && employeeProfiles[employeeId] 
        ? [employeeId] 
        : Object.keys(employeeProfiles);

      functions.logger.info(`Checking leave requests for ${employeeCodesToCheck.length} employees`);
      functions.logger.info(`Employee codes to check: ${employeeCodesToCheck.join(', ')}`);

      // Iterate through all employees
      for (const empCode of employeeCodesToCheck) {
        try {
          // Get all subcollections (SL, CL, PL, OH, LWP, OL) for this employee
          const leaveTypesToCheck = leaveType ? [leaveType] : ['SL', 'CL', 'PL', 'OH', 'LWP', 'OL'];
          functions.logger.info(`Checking leave types ${leaveTypesToCheck.join(', ')} for employee ${empCode}`);
          
          for (const ltType of leaveTypesToCheck) {
            try {
              let query = admin.firestore()
                .collection('leaveRequests')
                .doc(empCode)
                .collection(ltType)
                .orderBy('appliedAt', 'desc');

              // Apply status filter
              if (status) {
                query = query.where('status', '==', status);
              }
              // Note: We'll filter out cancelled leaves in the processing loop instead of using !=

              const leaveTypeSnapshot = await query.limit(50).get(); // Limit per employee per leave type
              functions.logger.info(`Found ${leaveTypeSnapshot.docs.length} ${ltType} requests for employee ${empCode}`);

              leaveTypeSnapshot.docs.forEach(doc => {
                const leaveData = doc.data();
                const employeeInfo = employeeProfiles[empCode];

                // Skip cancelled leaves unless specifically requested
                if (!status && leaveData.status === 'cancelled') {
                  return; // Skip this record
                }

                // Convert Firestore timestamps to ISO strings
                const convertTimestamp = (timestamp: any) => {
                  if (timestamp && timestamp.toDate) {
                    return timestamp.toDate().toISOString();
                  }
                  return timestamp;
                };

                // Apply date range filter if provided
                if (startDate || endDate) {
                  const leaveStartDate = new Date(convertTimestamp(leaveData.startDate));
                  
                  if (startDate && leaveStartDate < new Date(startDate)) {
                    return; // Skip this record
                  }
                  
                  if (endDate && leaveStartDate > new Date(endDate)) {
                    return; // Skip this record
                  }
                }

                allLeaveRequests.push({
                  id: doc.id,
                  empCode: empCode,
                  employeeName: employeeInfo?.name || 'Unknown',
                  employeeEmail: employeeInfo?.email || '',
                  department: employeeInfo?.department || 'N/A',
                  designation: employeeInfo?.designation || 'N/A',
                  leaveType: mapCollectionNameToLeaveType(ltType),
                  status: leaveData.status || 'pending',
                  reason: leaveData.reason || '',
                  startDate: convertTimestamp(leaveData.startDate),
                  endDate: convertTimestamp(leaveData.endDate),
                  totalDays: leaveData.totalDays || 0,
                  daysToDeduct: leaveData.daysToDeduct || 0,
                  submittedDate: convertTimestamp(leaveData.appliedAt), // Fix: use appliedAt
                  approvedDate: convertTimestamp(leaveData.approvedAt), // Fix: use approvedAt
                  approvedBy: leaveData.approvedBy || null,
                  rejectedDate: convertTimestamp(leaveData.rejectedAt), // Fix: use rejectedAt
                  rejectedBy: leaveData.rejectedBy || null,
                  rejectionReason: leaveData.rejectionReason || null,
                  medicalCertificate: leaveData.medicalCertificate || null,
                  selectedOptionalHolidayId: leaveData.selectedOptionalHolidayId || null,
                  createdAt: convertTimestamp(leaveData.appliedAt), // Use appliedAt for createdAt
                  updatedAt: convertTimestamp(leaveData.updatedAt)
                });
              });

            } catch (ltError) {
              functions.logger.warn(`Error fetching ${ltType} for employee ${empCode}:`, ltError);
              // Continue with other leave types
            }
          }

        } catch (empError) {
          functions.logger.warn(`Error processing employee ${empCode}:`, empError);
          // Continue with other employees
        }
      }

      // Sort by submission date (newest first) and apply limit
      allLeaveRequests.sort((a, b) => {
        const dateA = new Date(a.submittedDate || 0);
        const dateB = new Date(b.submittedDate || 0);
        return dateB.getTime() - dateA.getTime();
      });

      const limitedResults = allLeaveRequests.slice(0, limit);

      functions.logger.info(`Found ${allLeaveRequests.length} total leave requests, returning ${limitedResults.length}`);

      return {
        success: true,
        requests: limitedResults,
        totalFound: allLeaveRequests.length,
        returned: limitedResults.length,
        hasMore: allLeaveRequests.length > limit
      };

    } catch (error) {
      functions.logger.error('Error fetching employee leave requests:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to fetch employee leave requests."
      );
    }
  }
);

// Cloud Function: Approve Leave Request
export const approveLeaveRequest = functions.https.onCall(
  async (data, context) => {
    try {
      // Check authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated to approve leave requests."
        );
      }

      // Verify user has admin/HR/manager role
      const callerSnapshot = await admin.firestore()
        .collection('users')
        .doc(context.auth.uid)
        .get();

      if (!callerSnapshot.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "User profile not found."
        );
      }

      const callerData = callerSnapshot.data();
      const allowedRoles = ['admin', 'hr', 'manager'];
      
      if (!callerData || !allowedRoles.includes(callerData.role)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Access denied. Admin, HR, or Manager role required."
        );
      }

      const { empCode, leaveType, requestId, comments } = data;

      if (!empCode || !leaveType || !requestId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Employee code, leave type, and request ID are required."
        );
      }

      functions.logger.info(`Approving leave request: ${requestId} for employee: ${empCode}, type: ${leaveType}`);

      // Map leave type value to collection name
      const collectionName = mapLeaveTypeToCollectionName(leaveType);

      // Get the leave request
      const leaveRequestRef = admin.firestore()
        .collection('leaveRequests')
        .doc(empCode)
        .collection(collectionName)
        .doc(requestId);

      const leaveRequestDoc = await leaveRequestRef.get();
      
      if (!leaveRequestDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Leave request not found."
        );
      }

      const requestData = leaveRequestDoc.data();
      
      if (requestData?.status !== 'pending') {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Only pending requests can be approved."
        );
      }

      // Get approver name before updating
      const approverDoc = await admin.firestore()
        .collection('users')
        .doc(context.auth.uid)
        .get();
      
      const approverName = approverDoc.exists ? approverDoc.data()?.name || 'Management' : 'Management';
      
      functions.logger.info(`Approver ID: ${context.auth.uid}, Approver Name: ${approverName}`);

      // Update the leave request status
      await leaveRequestRef.update({
        status: 'approved',
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedBy: approverName,
        approvalComments: comments || '',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Update employee's leave balance
      const employeeRef = admin.firestore()
        .collection('users')
        .doc(requestData?.employeeId);
      
      const daysToDeduct = requestData?.daysToDeduct || 0;
      let balanceKey = '';
      
      switch (leaveType) {
        case 'CL':
          balanceKey = 'casualLeave';
          break;
        case 'PL':
          balanceKey = 'paidLeave';
          break;
        case 'SL':
          balanceKey = 'sickLeave';
          break;
        case 'OH':
          balanceKey = 'optionalHoliday';
          break;
      }

      if (balanceKey) {
        await employeeRef.update({
          [`leaveBalance.${balanceKey}`]: admin.firestore.FieldValue.increment(-daysToDeduct),
          'updatedAt': admin.firestore.FieldValue.serverTimestamp()
        });
      }

      functions.logger.info(`Leave request approved successfully: ${requestId}`);

      // Send approval notification to employee
      setImmediate(async () => {
        try {
          // Get employee data
          const employeeDoc = await admin.firestore()
            .collection('users')
            .doc(requestData?.employeeId)
            .get();
          
          if (employeeDoc.exists) {
            const employeeData = employeeDoc.data();
            if (employeeData?.fcmToken) {
              // Approver name is already available from the database update above
              
              // Format leave type display name (leaveType here is collection name like 'OL', 'CL', etc.)
              const leaveTypeDisplayName = leaveType === 'SL' ? 'Sick Leave' : 
                                         leaveType === 'CL' ? 'Casual Leave' : 
                                         leaveType === 'PL' ? 'Paid Leave' : 
                                         leaveType === 'LWP' ? 'Leave Without Pay' : 
                                         leaveType === 'OL' ? 'Official Leave' : 
                                         leaveType === 'OH' ? 'Optional Holiday' : 'Leave';
              
              const formatDate = (timestamp: any) => {
                const date = timestamp?.toDate ? timestamp.toDate() : new Date(timestamp);
                return date.toLocaleDateString('en-US', {
                  year: 'numeric',
                  month: 'short',
                  day: 'numeric'
                });
              };
              
              const startDateStr = formatDate(requestData?.startDate);
              const endDateStr = formatDate(requestData?.endDate);
              const dateRange = startDateStr === endDateStr ? startDateStr : `${startDateStr} - ${endDateStr}`;
              
              const title = 'Leave Request Approved ✅';
              const body = `Your ${leaveTypeDisplayName} request for ${dateRange} has been approved by ${approverName}`;
              
              await sendFCMNotification(
                employeeData.fcmToken,
                title,
                body,
                {
                  type: 'leave_decision',
                  empCode: employeeData.empCode || '',
                  leaveType: leaveTypeDisplayName,
                  startDate: requestData?.startDate?.toDate().toISOString() || '',
                  endDate: requestData?.endDate?.toDate().toISOString() || '',
                  status: 'approved',
                  approvedBy: approverName,
                }
              );
              
              functions.logger.info(`Approval notification sent to ${employeeData.name} (${employeeData.empCode})`);
            }
          }
        } catch (notificationError) {
          functions.logger.error('Failed to send approval notification:', notificationError);
        }
      });

      return {
        success: true,
        message: 'Leave request approved successfully'
      };

    } catch (error) {
      functions.logger.error('Error approving leave request:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to approve leave request."
      );
    }
  }
);

// Cloud Function: Reject Leave Request
export const rejectLeaveRequest = functions.https.onCall(
  async (data, context) => {
    try {
      // Check authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated to reject leave requests."
        );
      }

      // Verify user has admin/HR/manager role
      const callerSnapshot = await admin.firestore()
        .collection('users')
        .doc(context.auth.uid)
        .get();

      if (!callerSnapshot.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "User profile not found."
        );
      }

      const callerData = callerSnapshot.data();
      const allowedRoles = ['admin', 'hr', 'manager'];
      
      if (!callerData || !allowedRoles.includes(callerData.role)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Access denied. Admin, HR, or Manager role required."
        );
      }

      const { empCode, leaveType, requestId, reason } = data;

      if (!empCode || !leaveType || !requestId || !reason) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Employee code, leave type, request ID, and rejection reason are required."
        );
      }

      functions.logger.info(`Rejecting leave request: ${requestId} for employee: ${empCode}, type: ${leaveType}`);

      // Map leave type value to collection name
      const collectionName = mapLeaveTypeToCollectionName(leaveType);

      // Get the leave request
      const leaveRequestRef = admin.firestore()
        .collection('leaveRequests')
        .doc(empCode)
        .collection(collectionName)
        .doc(requestId);

      const leaveRequestDoc = await leaveRequestRef.get();
      
      if (!leaveRequestDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Leave request not found."
        );
      }

      const requestData = leaveRequestDoc.data();
      
      if (requestData?.status !== 'pending') {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Only pending requests can be rejected."
        );
      }

      // Get rejector name before updating
      const rejectorDoc = await admin.firestore()
        .collection('users')
        .doc(context.auth.uid)
        .get();
      
      const rejectorName = rejectorDoc.exists ? rejectorDoc.data()?.name || 'Management' : 'Management';
      
      functions.logger.info(`Rejector ID: ${context.auth.uid}, Rejector Name: ${rejectorName}`);

      // Update the leave request status
      await leaveRequestRef.update({
        status: 'rejected',
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectedBy: rejectorName,
        rejectionReason: reason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      functions.logger.info(`Leave request rejected successfully: ${requestId}`);

      // Send rejection notification to employee
      setImmediate(async () => {
        try {
          // Get employee data
          const employeeDoc = await admin.firestore()
            .collection('users')
            .doc(requestData?.employeeId)
            .get();
          
          if (employeeDoc.exists) {
            const employeeData = employeeDoc.data();
            if (employeeData?.fcmToken) {
              // Rejector name is already available from the database update above
              
              // Format leave type display name (collectionName is collection name like 'OL', 'CL', etc.)
              const leaveTypeDisplayName = collectionName === 'SL' ? 'Sick Leave' : 
                                         collectionName === 'CL' ? 'Casual Leave' : 
                                         collectionName === 'PL' ? 'Paid Leave' : 
                                         collectionName === 'LWP' ? 'Leave Without Pay' : 
                                         collectionName === 'OL' ? 'Official Leave' : 
                                         collectionName === 'OH' ? 'Optional Holiday' : 'Leave';
              
              const formatDate = (timestamp: any) => {
                const date = timestamp?.toDate ? timestamp.toDate() : new Date(timestamp);
                return date.toLocaleDateString('en-US', {
                  year: 'numeric',
                  month: 'short',
                  day: 'numeric'
                });
              };
              
              const startDateStr = formatDate(requestData?.startDate);
              const endDateStr = formatDate(requestData?.endDate);
              const dateRange = startDateStr === endDateStr ? startDateStr : `${startDateStr} - ${endDateStr}`;
              
              const title = 'Leave Request Rejected ❌';
              let body = `Your ${leaveTypeDisplayName} request for ${dateRange} has been rejected by ${rejectorName}`;
              if (reason) {
                body += `. Reason: ${reason}`;
              }
              
              await sendFCMNotification(
                employeeData.fcmToken,
                title,
                body,
                {
                  type: 'leave_decision',
                  empCode: employeeData.empCode || '',
                  leaveType: leaveTypeDisplayName,
                  startDate: requestData?.startDate?.toDate().toISOString() || '',
                  endDate: requestData?.endDate?.toDate().toISOString() || '',
                  status: 'rejected',
                  rejectionReason: reason,
                }
              );
              
              functions.logger.info(`Rejection notification sent to ${employeeData.name} (${employeeData.empCode})`);
            }
          }
        } catch (notificationError) {
          functions.logger.error('Failed to send rejection notification:', notificationError);
        }
      });

      return {
        success: true,
        message: 'Leave request rejected successfully'
      };

    } catch (error) {
      functions.logger.error('Error rejecting leave request:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to reject leave request."
      );
    }
  }
);

/**
 * Scheduled function to update leave statuses to 'completed' when leave periods end
 * Runs daily at 00:05 UTC to check for leaves that have ended
 */
export const updateLeaveStatuses = functions.pubsub
  .schedule('5 0 * * *') // Run at 00:05 UTC every day
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      functions.logger.info('Starting scheduled leave status update check...');
      
      const today = new Date();
      const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
      
      // Get all employee documents to check their leave requests
      const employeesSnapshot = await admin.firestore()
        .collection('users')
        .where('role', '==', 'employee')
        .get();
      
      let totalUpdated = 0;
      
      for (const employeeDoc of employeesSnapshot.docs) {
        const empCode = employeeDoc.data().empCode;
        if (!empCode) continue;
        
        // Check all leave types for this employee
        const leaveTypes = ['SL', 'CL', 'PL', 'OH'];
        
        for (const leaveType of leaveTypes) {
          const leaveRequestsSnapshot = await admin.firestore()
            .collection('leaveRequests')
            .doc(empCode)
            .collection(leaveType)
            .where('status', '==', 'approved')
            .get();
          
          for (const leaveDoc of leaveRequestsSnapshot.docs) {
            const leaveData = leaveDoc.data();
            const startDate = leaveData.startDate?.toDate();
            const endDate = leaveData.endDate?.toDate();
            
            if (startDate && endDate) {
              let shouldMarkCompleted = false;
              let completionDate: Date;
              
              if (leaveType === 'SL' || leaveType === 'CL') {
                // For SL and CL: Mark completed after the applied date (first day) ends
                // Since only 1 day is deducted regardless of duration
                const appliedDate = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate());
                completionDate = appliedDate;
                shouldMarkCompleted = todayStart > appliedDate;
              } else if (leaveType === 'PL') {
                // For PL: Mark completed when all deducted days have ended
                // Use deductionDates to find the last deducted date
                const deductionDates = leaveData.deductionDates || [];
                if (deductionDates.length > 0) {
                  // Find the last deduction date
                  const lastDeductionTimestamp = deductionDates[deductionDates.length - 1];
                  const lastDeductionDate = lastDeductionTimestamp?.toDate ? 
                    lastDeductionTimestamp.toDate() : new Date(lastDeductionTimestamp);
                  
                  completionDate = new Date(lastDeductionDate.getFullYear(), 
                    lastDeductionDate.getMonth(), lastDeductionDate.getDate());
                  shouldMarkCompleted = todayStart > completionDate;
                } else {
                  // Fallback to end date if deductionDates not available
                  const leaveEndDate = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());
                  completionDate = leaveEndDate;
                  shouldMarkCompleted = todayStart > leaveEndDate;
                }
              } else {
                // For OH: Mark completed after the entire leave period ends
                const leaveEndDate = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());
                completionDate = leaveEndDate;
                shouldMarkCompleted = todayStart > leaveEndDate;
              }
              
              if (shouldMarkCompleted) {
                await leaveDoc.ref.update({
                  status: 'completed',
                  completedAt: admin.firestore.FieldValue.serverTimestamp(),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                
                totalUpdated++;
                let completionBasis = 'end date';
                if (leaveType === 'SL' || leaveType === 'CL') {
                  completionBasis = 'applied date (first day)';
                } else if (leaveType === 'PL') {
                  completionBasis = 'last deduction date';
                }
                
                functions.logger.info(
                  `Updated leave status to completed: ${leaveDoc.id} (${leaveType}) for employee ${empCode} - completion based on ${completionBasis}`
                );
              }
            }
          }
        }
      }
      
      functions.logger.info(`Leave status update completed. Total leaves updated: ${totalUpdated}`);
      
    } catch (error) {
      functions.logger.error('Error in scheduled leave status update:', error);
      throw error;
    }
  });

export const updateLeaveStatus = functions.https.onCall(
  async (data, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated to update leave status."
        );
      }

      const { empCode, leaveType, requestId } = data;

      if (!empCode || !leaveType || !requestId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Employee code, leave type, and request ID are required."
        );
      }

      functions.logger.info(`Manual leave status update: ${requestId} for employee: ${empCode}, type: ${leaveType}`);

      // Map leave type value to collection name
      const collectionName = mapLeaveTypeToCollectionName(leaveType);

      // Get the leave request
      const leaveRequestRef = admin.firestore()
        .collection('leaveRequests')
        .doc(empCode)
        .collection(collectionName)
        .doc(requestId);

      const leaveRequestDoc = await leaveRequestRef.get();

      if (!leaveRequestDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Leave request not found."
        );
      }

      const requestData = leaveRequestDoc.data();

      // Only update approved leaves
      if (requestData?.status !== 'approved') {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Only approved leaves can be marked as completed."
        );
      }

      // Check if leave period has actually ended
      const today = new Date();
      const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
      
      // Different completion logic based on leave type
      let completionDate: Date | null = null;
      let dateType = 'end date';
      
      if (leaveType === 'SL' || leaveType === 'CL') {
        // For SL and CL: Check applied date (first day) completion since only 1 day is deducted
        const startDate = requestData.startDate?.toDate();
        if (startDate) {
          completionDate = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate());
          dateType = 'applied date (first day)';
        }
      } else if (leaveType === 'PL') {
        // For PL: Check last deduction date completion
        const deductionDates = requestData.deductionDates || [];
        if (deductionDates.length > 0) {
          const lastDeductionTimestamp = deductionDates[deductionDates.length - 1];
          const lastDeductionDate = lastDeductionTimestamp?.toDate ? 
            lastDeductionTimestamp.toDate() : new Date(lastDeductionTimestamp);
          completionDate = new Date(lastDeductionDate.getFullYear(), 
            lastDeductionDate.getMonth(), lastDeductionDate.getDate());
          dateType = 'last deduction date';
        } else {
          // Fallback to end date if deductionDates not available
          const endDate = requestData.endDate?.toDate();
          if (endDate) {
            completionDate = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());
            dateType = 'end date';
          }
        }
      } else {
        // For OH: Check end date completion
        const endDate = requestData.endDate?.toDate();
        if (endDate) {
          completionDate = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());
          dateType = 'end date';
        }
      }
      
      if (completionDate && todayStart <= completionDate) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          `Leave period has not ended yet. Status can only be changed to completed after the ${dateType} ends.`
        );
      }

      // Update the leave request status
      await leaveRequestRef.update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      functions.logger.info(`Leave status updated to completed successfully: ${requestId}`);

      return {
        success: true,
        message: 'Leave status updated to completed successfully'
      };

    } catch (error) {
      functions.logger.error('Error updating leave status:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to update leave status."
      );
    }
  }
);

// =====================================================
// PUSH NOTIFICATION FUNCTIONS
// =====================================================

// Helper function to send FCM notification
async function sendFCMNotification(
  fcmToken: string,
  title: string,
  body: string,
  data?: { [key: string]: string }
) {
  try {
    const message = {
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data: data || {},
      android: {
        notification: {
          channelId: 'leave_notifications',
          priority: 'high' as const,
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title,
              body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    functions.logger.info('FCM message sent successfully:', response);
    return response;
  } catch (error) {
    functions.logger.error('Error sending FCM message:', error);
    throw error;
  }
}

// Helper function to get admin/HR/manager users with FCM tokens
async function getNotificationRecipients() {
  try {
    const adminUsersSnapshot = await admin.firestore()
      .collection('users')
      .where('role', 'in', ['admin', 'hr', 'manager'])
      .where('isActive', '==', true)
      .get();

    const recipients: Array<{ uid: string, name: string, role: string, fcmToken?: string }> = [];
    
    adminUsersSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.fcmToken) {
        recipients.push({
          uid: doc.id,
          name: data.name || 'Unknown',
          role: data.role || 'admin',
          fcmToken: data.fcmToken
        });
      }
    });

    return recipients;
  } catch (error) {
    functions.logger.error('Error getting notification recipients:', error);
    return [];
  }
}

// Function to notify admins/HR/managers when employee applies for leave
export const notifyLeaveApplication = functions.https.onCall(
  async (data, context) => {
    try {
      // Verify authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated to send notifications."
        );
      }

      const { empCode, employeeName, leaveType, startDate, endDate, reason } = data;

      if (!empCode || !employeeName || !leaveType || !startDate) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required fields for leave application notification."
        );
      }

      // Get notification recipients (admin, HR, manager)
      const recipients = await getNotificationRecipients();

      if (recipients.length === 0) {
        functions.logger.warn('No admin/HR/manager users found with FCM tokens');
        return {
          success: true,
          message: 'No notification recipients available',
          sentCount: 0
        };
      }

      // Format dates for display
      const formatDate = (dateStr: string) => {
        return new Date(dateStr).toLocaleDateString('en-US', {
          year: 'numeric',
          month: 'short',
          day: 'numeric'
        });
      };

      const dateRange = endDate && startDate !== endDate 
        ? `${formatDate(startDate)} - ${formatDate(endDate)}`
        : formatDate(startDate);

      // Send notifications to all recipients
      const notificationPromises = recipients.map(recipient => {
        const title = 'New Leave Application';
        const body = `${employeeName} (${empCode}) applied for ${leaveType} from ${dateRange}`;
        
        return sendFCMNotification(
          recipient.fcmToken!,
          title,
          body,
          {
            type: 'leave_application',
            empCode,
            employeeName,
            leaveType,
            startDate,
            endDate: endDate || startDate,
            reason: reason || '',
          }
        ).catch(error => {
          functions.logger.error(`Failed to send notification to ${recipient.name} (${recipient.uid}):`, error);
          return null;
        });
      });

      const results = await Promise.all(notificationPromises);
      const successCount = results.filter(result => result !== null).length;

      functions.logger.info(`Leave application notifications sent: ${successCount}/${recipients.length}`);

      return {
        success: true,
        message: 'Leave application notifications sent successfully',
        sentCount: successCount,
        totalRecipients: recipients.length
      };

    } catch (error) {
      functions.logger.error('Error sending leave application notification:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send leave application notification."
      );
    }
  }
);

// Function to notify employee when leave is approved/rejected
export const notifyLeaveDecision = functions.https.onCall(
  async (data, context) => {
    try {
      // Verify authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated to send notifications."
        );
      }

      const { empCode, employeeName, leaveType, startDate, endDate, status, approvedBy, rejectionReason } = data;

      if (!empCode || !employeeName || !leaveType || !startDate || !status) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required fields for leave decision notification."
        );
      }

      // Get the employee's FCM token
      const employeeSnapshot = await admin.firestore()
        .collection('users')
        .where('empCode', '==', empCode)
        .where('isActive', '==', true)
        .limit(1)
        .get();

      if (employeeSnapshot.empty) {
        throw new functions.https.HttpsError(
          "not-found",
          "Employee not found or inactive."
        );
      }

      const employeeDoc = employeeSnapshot.docs[0];
      const employeeData = employeeDoc.data();
      const fcmToken = employeeData.fcmToken;

      if (!fcmToken) {
        functions.logger.warn(`Employee ${empCode} does not have an FCM token`);
        return {
          success: true,
          message: 'Employee does not have FCM token',
          sentCount: 0
        };
      }

      // Format dates for display
      const formatDate = (dateStr: string) => {
        return new Date(dateStr).toLocaleDateString('en-US', {
          year: 'numeric',
          month: 'short',
          day: 'numeric'
        });
      };

      const dateRange = endDate && startDate !== endDate 
        ? `${formatDate(startDate)} - ${formatDate(endDate)}`
        : formatDate(startDate);

      // Prepare notification content based on status
      let title: string;
      let body: string;
      
      if (status === 'approved') {
        title = 'Leave Request Approved ✅';
        body = `Your ${leaveType} request for ${dateRange} has been approved by ${approvedBy || 'management'}`;
      } else if (status === 'rejected') {
        title = 'Leave Request Rejected ❌';
        body = `Your ${leaveType} request for ${dateRange} has been rejected`;
        if (rejectionReason) {
          body += `. Reason: ${rejectionReason}`;
        }
      } else {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Invalid leave status. Must be 'approved' or 'rejected'."
        );
      }

      // Send notification to employee
      await sendFCMNotification(
        fcmToken,
        title,
        body,
        {
          type: 'leave_decision',
          empCode,
          leaveType,
          startDate,
          endDate: endDate || startDate,
          status,
          approvedBy: approvedBy || '',
          rejectionReason: rejectionReason || '',
        }
      );

      functions.logger.info(`Leave decision notification sent to ${employeeName} (${empCode}): ${status}`);

      return {
        success: true,
        message: 'Leave decision notification sent successfully',
        sentCount: 1
      };

    } catch (error) {
      functions.logger.error('Error sending leave decision notification:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send leave decision notification."
      );
    }
  }
);

// ============ WORKING HOURS MANAGEMENT FUNCTIONS ============

// Get working hours settings (Public HTTP function - no authentication required)
export const getSystemSettings = functions.https.onRequest(async (req, res) => {
  try {
    // Set CORS headers to allow browser requests
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    functions.logger.info('📊 Loading system settings (public HTTP access)');

    const db = admin.firestore();
    const settingsDoc = await db.collection('system_settings').doc('config').get();

    if (!settingsDoc.exists) {
      functions.logger.warn('📋 No working hours settings found, returning defaults');
      
      // Return default v3.0 structured settings
      const defaultSettings = {
        version: '3.0',
        fullTimeEmployee: {
          workingHours: 8.0,
          halfDayRange: { start: 0.0, end: 4.0 },
          incompleteRange: { start: 6.0, end: 7.5 },
          lateThresholdTime: '10:00'
        },
        partTimeEmployee: {
          workingHours: 4.0,
          incompleteRange: { start: 0.0, end: 3.5 }
        },
        consultantEmployee: {
          workingHours: 6.0
        }
      };

      res.status(200).json({
        success: true,
        settings: defaultSettings,
        message: 'Default settings loaded'
      });
      return;
    }

    const settingsData = settingsDoc.data();
    functions.logger.info('✅ Successfully retrieved working hours settings from Firestore');

    res.status(200).json({
      success: true,
      settings: settingsData,
      message: 'Settings retrieved successfully'
    });

  } catch (error) {
    functions.logger.error('❌ Error in getWorkingHoursSettings:', error);
    res.status(500).json({
      success: false,
      error: `Failed to get working hours settings: ${error}`
    });
  }
});

// Keep the original callable function as backup (truly public)
export const getWorkingHoursSettings = functions.https.onCall(async (data, context) => {
  try {
    functions.logger.info('📊 Loading working hours settings (callable - public access)');

    const db = admin.firestore();
    const settingsDoc = await db.collection('system_settings').doc('config').get();

    if (!settingsDoc.exists) {
      functions.logger.warn('📋 No working hours settings found, returning defaults');
      
      const defaultSettings = {
        version: '3.0',
        fullTimeEmployee: {
          workingHours: 8.0,
          halfDayRange: { start: 0.0, end: 4.0 },
          incompleteRange: { start: 6.0, end: 7.5 },
          lateThresholdTime: '10:00'
        },
        partTimeEmployee: {
          workingHours: 4.0,
          incompleteRange: { start: 0.0, end: 3.5 }
        },
        consultantEmployee: {
          workingHours: 6.0
        }
      };

      return {
        success: true,
        settings: defaultSettings,
        message: 'Default settings loaded'
      };
    }

    const settingsData = settingsDoc.data();
    functions.logger.info('✅ Successfully retrieved working hours settings from Firestore');

    return {
      success: true,
      settings: settingsData,
      message: 'Settings retrieved successfully'
    };

  } catch (error) {
    functions.logger.error('❌ Error in getWorkingHoursSettings:', error);
    
    // Return default instead of throwing error
    return {
      success: true,
      settings: {
        version: '3.0',
        fullTimeEmployee: {
          workingHours: 8.0,
          halfDayRange: { start: 0.0, end: 4.0 },
          incompleteRange: { start: 6.0, end: 7.5 },
          lateThresholdTime: '10:00'
        },
        partTimeEmployee: {
          workingHours: 4.0,
          incompleteRange: { start: 0.0, end: 3.5 }
        },
        consultantEmployee: {
          workingHours: 6.0
        }
      },
      message: 'Default settings loaded due to error'
    };
  }
});

// Update working hours settings (Admin only)
export const updateWorkingHoursSettings = functions.https.onCall(async (data, context) => {
  try {
    // Log authentication details for debugging
    functions.logger.info('updateWorkingHoursSettings called with context:', {
      authUid: context.auth?.uid,
      authToken: context.auth?.token ? 'present' : 'missing',
      hasAuth: !!context.auth,
      tokenEmail: context.auth?.token?.email,
      tokenRole: context.auth?.token?.role,
      timestamp: new Date().toISOString()
    });

    // Check if user is authenticated - this function requires admin access
    if (!context.auth) {
      functions.logger.error('Authentication failed - no context.auth object');
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to update settings');
    }

    // Additional validation - check if we have a valid UID
    if (!context.auth.uid) {
      functions.logger.error('Authentication failed - no UID in context.auth');
      throw new functions.https.HttpsError('unauthenticated', 'Invalid authentication token');
    }

    // Get user role from Firestore
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(context.auth.uid)
      .get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userData = userDoc.data();
    if (userData!.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can update working hours settings');
    }

    // Log the received data for debugging
    functions.logger.info('Received data structure:', {
      dataKeys: Object.keys(data || {}),
      hasFullTime: !!data.fullTimeEmployee,
      hasPartTime: !!data.partTimeEmployee,
      hasConsultant: !!data.consultantEmployee,
      version: data.version,
      fullData: JSON.stringify(data)
    });

    // Validate input data for v3.0 structure
    const { 
      fullTimeEmployee,
      partTimeEmployee,
      consultantEmployee,
      version
    } = data;

    if (!fullTimeEmployee || !partTimeEmployee || !consultantEmployee) {
      functions.logger.error('Missing employee settings:', {
        fullTimeEmployee: !!fullTimeEmployee,
        partTimeEmployee: !!partTimeEmployee,
        consultantEmployee: !!consultantEmployee
      });
      throw new functions.https.HttpsError('invalid-argument', 'Missing required employee settings parameters');
    }

    // Validate full-time employee settings
    if (!fullTimeEmployee.workingHours) {
      throw new functions.https.HttpsError('invalid-argument', 'Full-time working hours is required');
    }
    if (typeof fullTimeEmployee.workingHours !== 'number' || fullTimeEmployee.workingHours < 4 || fullTimeEmployee.workingHours > 12) {
      throw new functions.https.HttpsError('invalid-argument', `Full-time working hours must be between 4-12 hours, received: ${fullTimeEmployee.workingHours}`);
    }

    if (!fullTimeEmployee.halfDayRange || typeof fullTimeEmployee.halfDayRange !== 'object') {
      throw new functions.https.HttpsError('invalid-argument', 'Full-time halfDayRange is required and must be an object');
    }
    if (typeof fullTimeEmployee.halfDayRange.end !== 'number' || fullTimeEmployee.halfDayRange.end < 0) {
      throw new functions.https.HttpsError('invalid-argument', `Half day threshold must be a positive number, received: ${fullTimeEmployee.halfDayRange.end}`);
    }

    if (!fullTimeEmployee.incompleteRange || typeof fullTimeEmployee.incompleteRange !== 'object') {
      throw new functions.https.HttpsError('invalid-argument', 'Full-time incompleteRange is required and must be an object');
    }
    if (typeof fullTimeEmployee.incompleteRange.end !== 'number' || fullTimeEmployee.incompleteRange.end < 0) {
      throw new functions.https.HttpsError('invalid-argument', `Incomplete hours threshold must be a positive number, received: ${fullTimeEmployee.incompleteRange.end}`);
    }

    // Validate part-time employee settings
    if (!partTimeEmployee.workingHours) {
      throw new functions.https.HttpsError('invalid-argument', 'Part-time working hours is required');
    }
    if (typeof partTimeEmployee.workingHours !== 'number' || partTimeEmployee.workingHours < 2 || partTimeEmployee.workingHours > 8) {
      throw new functions.https.HttpsError('invalid-argument', `Part-time working hours must be between 2-8 hours, received: ${partTimeEmployee.workingHours}`);
    }

    if (!partTimeEmployee.incompleteRange || typeof partTimeEmployee.incompleteRange !== 'object') {
      throw new functions.https.HttpsError('invalid-argument', 'Part-time incompleteRange is required and must be an object');
    }
    if (typeof partTimeEmployee.incompleteRange.end !== 'number' || partTimeEmployee.incompleteRange.end < 0) {
      throw new functions.https.HttpsError('invalid-argument', `Part-time incomplete threshold must be a positive number, received: ${partTimeEmployee.incompleteRange.end}`);
    }

    // Validate consultant employee settings
    if (!consultantEmployee.workingHours) {
      throw new functions.https.HttpsError('invalid-argument', 'Consultant working hours is required');
    }
    if (typeof consultantEmployee.workingHours !== 'number' || consultantEmployee.workingHours < 2 || consultantEmployee.workingHours > 8) {
      throw new functions.https.HttpsError('invalid-argument', `Consultant working hours must be between 2-8 hours, received: ${consultantEmployee.workingHours}`);
    }

    // Validate late threshold time format (HH:MM)
    if (!fullTimeEmployee.lateThresholdTime || typeof fullTimeEmployee.lateThresholdTime !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', `Late threshold time is required and must be a string, received: ${fullTimeEmployee.lateThresholdTime}`);
    }
    if (!/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/.test(fullTimeEmployee.lateThresholdTime)) {
      throw new functions.https.HttpsError('invalid-argument', `Late threshold time must be in HH:MM format, received: ${fullTimeEmployee.lateThresholdTime}`);
    }

    // Logical validation for full-time employee
    if (fullTimeEmployee.halfDayRange.end >= fullTimeEmployee.workingHours) {
      throw new functions.https.HttpsError('invalid-argument', 'Half day threshold must be less than full-time working hours');
    }

    if (fullTimeEmployee.incompleteRange.end >= fullTimeEmployee.workingHours) {
      throw new functions.https.HttpsError('invalid-argument', 'Incomplete hours threshold must be less than full-time working hours');
    }

    if (partTimeEmployee.incompleteRange.end >= partTimeEmployee.workingHours) {
      throw new functions.https.HttpsError('invalid-argument', 'Part-time incomplete threshold must be less than part-time working hours');
    }

    // Update system settings with v3.0 structure
    const settingsData = {
      // v3.0 Employee-specific structure
      fullTimeEmployee: {
        workingHours: parseFloat(fullTimeEmployee.workingHours),
        halfDayRange: {
          start: parseFloat(fullTimeEmployee.halfDayRange.start || 0.0),
          end: parseFloat(fullTimeEmployee.halfDayRange.end)
        },
        incompleteRange: {
          start: parseFloat(fullTimeEmployee.incompleteRange.start || 6.0),
          end: parseFloat(fullTimeEmployee.incompleteRange.end)
        },
        lateThresholdTime: fullTimeEmployee.lateThresholdTime
      },
      
      partTimeEmployee: {
        workingHours: parseFloat(partTimeEmployee.workingHours),
        incompleteRange: {
          start: parseFloat(partTimeEmployee.incompleteRange.start || 0.0),
          end: parseFloat(partTimeEmployee.incompleteRange.end)
        }
      },
      
      consultantEmployee: {
        workingHours: parseFloat(consultantEmployee.workingHours)
      },
      
      // Metadata
      lastUpdatedBy: context.auth.uid,
      lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      version: '3.0', // Version to track data structure
    };

    await admin.firestore()
      .collection('system_settings')
      .doc('config')
      .set(settingsData, { merge: true });

    // Log the change for audit trail
    await admin.firestore()
      .collection('audit_logs')
      .add({
        action: 'working_hours_updated',
        adminId: context.auth.uid,
        adminEmail: userData!.email,
        newSettings: settingsData,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      success: true,
      message: 'Working hours settings updated successfully',
      settings: settingsData
    };

  } catch (error) {
    functions.logger.error('Error updating working hours settings:', error);
    
    // Re-throw HttpsError as is
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to update working hours settings');
  }
});

// Calculate attendance status based on working hours
export const calculateAttendanceStatus = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { workingHours, employeeType, empCode } = data;

    if (typeof workingHours !== 'number' || workingHours < 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid working hours provided');
    }

    // Get employee type if not provided
    let finalEmployeeType = employeeType;
    if (!finalEmployeeType && empCode) {
      const employeeDoc = await admin.firestore()
        .collection('users')
        .where('empCode', '==', empCode)
        .limit(1)
        .get();
      
      if (!employeeDoc.empty) {
        const employeeData = employeeDoc.docs[0].data();
        finalEmployeeType = employeeData.employmentType || 'full_time';
      }
    }
    
    // Default to full_time if still not determined
    finalEmployeeType = finalEmployeeType || 'full_time';

    // Get current working hours settings (v3.0)
    const settingsDoc = await admin.firestore()
      .collection('system_settings')
      .doc('config')
      .get();

    let settings;
    if (settingsDoc.exists && settingsDoc.data()?.version === '3.0') {
      settings = settingsDoc.data();
    } else {
      // Default v3.0 settings
      settings = {
        version: '3.0',
        fullTimeEmployee: {
          workingHours: 8.0,
          halfDayRange: { start: 0.0, end: 4.0 },
          incompleteRange: { start: 6.0, end: 7.5 },
          lateThresholdTime: '10:00'
        },
        partTimeEmployee: {
          workingHours: 4.0,
          incompleteRange: { start: 0.0, end: 3.5 }
        },
        consultantEmployee: {
          workingHours: 6.0
        }
      };
    }

    // Calculate attendance status based on employee type
    let status = 'absent';
    let statusDetails = 'No attendance recorded';
    let requiredHours = 8.0;
    let overtimeHours = 0.0;

    if (finalEmployeeType === 'part_time') {
      // Part-time: Only Complete or Incomplete (NO half-day)
      requiredHours = settings.partTimeEmployee.workingHours;
      const incompleteThreshold = settings.partTimeEmployee.incompleteRange.end;
      
      if (workingHours >= requiredHours) {
        status = 'present_full';
        statusDetails = `Completed part-time day (${workingHours.toFixed(1)}h)`;
      } else if (workingHours > 0) {
        status = 'incomplete';
        statusDetails = `Incomplete part-time hours (${workingHours.toFixed(1)}h of ${requiredHours}h required)`;
      }
      
    } else if (finalEmployeeType === 'consultant') {
      // Consultant: Only Complete or Incomplete (NO half-day)
      requiredHours = settings.consultantEmployee.workingHours;
      
      if (workingHours >= requiredHours) {
        status = 'present_full';
        statusDetails = `Completed consultant day (${workingHours.toFixed(1)}h)`;
      } else if (workingHours > 0) {
        status = 'incomplete';
        statusDetails = `Incomplete consultant hours (${workingHours.toFixed(1)}h of ${requiredHours}h required)`;
      }
      
    } else {
      // Full-time: Complete, Incomplete, or Half-day
      requiredHours = settings.fullTimeEmployee.workingHours;
      const halfDayMax = settings.fullTimeEmployee.halfDayRange.end;
      const incompleteMin = settings.fullTimeEmployee.incompleteRange.start;
      const incompleteMax = settings.fullTimeEmployee.incompleteRange.end;
      
      if (workingHours >= requiredHours) {
        status = 'present_full';
        statusDetails = `Completed full day (${workingHours.toFixed(1)}h)`;
        overtimeHours = Math.max(0, workingHours - requiredHours);
      } else if (workingHours >= incompleteMin && workingHours < requiredHours) {
        status = 'incomplete';
        statusDetails = `Incomplete hours (${workingHours.toFixed(1)}h of ${requiredHours}h required)`;
      } else if (workingHours > 0 && workingHours <= halfDayMax) {
        status = 'present_half';
        statusDetails = `Half day completed (${workingHours.toFixed(1)}h)`;
      }
    }

    return {
      success: true,
      attendanceStatus: {
        status,
        statusDetails,
        workingHours: parseFloat(workingHours.toFixed(2)),
        overtimeHours: parseFloat(overtimeHours.toFixed(2)),
        requiredHours: requiredHours,
        employeeType: finalEmployeeType,
        thresholds: {
          halfDayMax: finalEmployeeType === 'full_time' ? settings.fullTimeEmployee.halfDayRange.end : 0,
          incompleteMin: finalEmployeeType === 'full_time' ? settings.fullTimeEmployee.incompleteRange.start : 0,
          incompleteMax: finalEmployeeType === 'part_time' ? settings.partTimeEmployee.incompleteRange.end : 
                       finalEmployeeType === 'full_time' ? settings.fullTimeEmployee.incompleteRange.end : 0,
          requiredHours: requiredHours
        }
      }
    };

  } catch (error) {
    functions.logger.error('Error calculating attendance status:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to calculate attendance status');
  }
});

// Bulk update attendance statuses (for recalculation when settings change)
export const recalculateAllAttendanceStatuses = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated and is admin
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userDoc = await admin.firestore()
      .collection('users')
      .doc(context.auth.uid)
      .get();

    if (!userDoc.exists || userDoc.data()!.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can recalculate attendance statuses');
    }

    // Get current working hours settings (v3.0)
    const settingsDoc = await admin.firestore()
      .collection('system_settings')
      .doc('config')
      .get();

    let settings;
    if (settingsDoc.exists && settingsDoc.data()?.version === '3.0') {
      settings = settingsDoc.data();
    } else {
      // Default v3.0 settings
      settings = {
        version: '3.0',
        fullTimeEmployee: {
          workingHours: 8.0,
          halfDayRange: { start: 0.0, end: 4.0 },
          incompleteRange: { start: 6.0, end: 7.5 },
          lateThresholdTime: '10:00'
        },
        partTimeEmployee: {
          workingHours: 4.0,
          incompleteRange: { start: 0.0, end: 3.5 }
        },
        consultantEmployee: {
          workingHours: 6.0
        }
      };
    }

    // Get all employees to determine their types
    const employeesSnapshot = await admin.firestore()
      .collection('users')
      .where('role', '==', 'employee')
      .get();
    
    const employeeTypeMap = new Map();
    employeesSnapshot.forEach(doc => {
      const data = doc.data();
      employeeTypeMap.set(data.empCode, data.employmentType || 'full_time');
    });

    // Get date range (last 30 days by default or specified range)
    const { startDate, endDate } = data;
    const start = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const end = endDate ? new Date(endDate) : new Date();

    // Get all attendance records in the date range
    const attendanceSnapshot = await admin.firestore()
      .collection('attendance')
      .where('date', '>=', start)
      .where('date', '<=', end)
      .get();

    const batch = admin.firestore().batch();
    let updatedCount = 0;

    attendanceSnapshot.forEach(doc => {
      const attendanceData = doc.data();
      const workingHours = attendanceData.workingHours || 0;
      const empCode = attendanceData.empCode;
      
      // Get employee type
      const employeeType = employeeTypeMap.get(empCode) || 'full_time';

      // Calculate new status based on employee type
      let status = 'absent';
      let statusDetails = 'No attendance recorded';
      let requiredHours = 8.0;
      let overtimeHours = 0.0;

      if (employeeType === 'part_time') {
        // Part-time: Only Complete or Incomplete (NO half-day)
        requiredHours = settings.partTimeEmployee.workingHours;
        
        if (workingHours >= requiredHours) {
          status = 'present_full';
          statusDetails = `Completed part-time day (${workingHours.toFixed(1)}h)`;
        } else if (workingHours > 0) {
          status = 'incomplete';
          statusDetails = `Incomplete part-time hours (${workingHours.toFixed(1)}h of ${requiredHours}h required)`;
        }
        
      } else if (employeeType === 'consultant') {
        // Consultant: Only Complete or Incomplete (NO half-day)
        requiredHours = settings.consultantEmployee.workingHours;
        
        if (workingHours >= requiredHours) {
          status = 'present_full';
          statusDetails = `Completed consultant day (${workingHours.toFixed(1)}h)`;
        } else if (workingHours > 0) {
          status = 'incomplete';
          statusDetails = `Incomplete consultant hours (${workingHours.toFixed(1)}h of ${requiredHours}h required)`;
        }
        
      } else {
        // Full-time: Complete, Incomplete, or Half-day
        requiredHours = settings.fullTimeEmployee.workingHours;
        const halfDayMax = settings.fullTimeEmployee.halfDayRange.end;
        const incompleteMin = settings.fullTimeEmployee.incompleteRange.start;
        
        if (workingHours >= requiredHours) {
          status = 'present_full';
          statusDetails = `Completed full day (${workingHours.toFixed(1)}h)`;
          overtimeHours = Math.max(0, workingHours - requiredHours);
        } else if (workingHours >= incompleteMin && workingHours < requiredHours) {
          status = 'incomplete';
          statusDetails = `Incomplete hours (${workingHours.toFixed(1)}h of ${requiredHours}h required)`;
        } else if (workingHours > 0 && workingHours <= halfDayMax) {
          status = 'present_half';
          statusDetails = `Half day completed (${workingHours.toFixed(1)}h)`;
        }
      }

      // Update the document
      batch.update(doc.ref, {
        attendanceStatus: status,
        statusDetails,
        overtimeHours: parseFloat(overtimeHours.toFixed(2)),
        lastRecalculated: admin.firestore.FieldValue.serverTimestamp(),
      });

      updatedCount++;
    });

    // Commit the batch update
    if (updatedCount > 0) {
      await batch.commit();
    }

    // Log the bulk update
    await admin.firestore()
      .collection('audit_logs')
      .add({
        action: 'bulk_attendance_recalculation',
        adminId: context.auth.uid,
        adminEmail: userDoc.data()!.email,
        recordsUpdated: updatedCount,
        dateRange: { start, end },
        newSettings: settings,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      success: true,
      message: `Successfully recalculated ${updatedCount} attendance records`,
      recordsUpdated: updatedCount,
      dateRange: { start, end }
    };

  } catch (error) {
    functions.logger.error('Error recalculating attendance statuses:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to recalculate attendance statuses');
  }
});

// ============ ADMIN UTILITY FUNCTIONS ============
// (Temporary functions removed for security)
