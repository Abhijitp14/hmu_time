import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password (generic method)
  Future<AuthResult> signInWithEmailAndPassword(String email, String password, {List<UserRole>? allowedRoles}) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.user != null) {
        // Get user data from Firestore
        final userData = await getUserData(result.user!.uid);
        if (userData != null) {
          // Check if user has allowed role
          if (allowedRoles == null || allowedRoles.contains(userData.role)) {
            return AuthResult.success(userData);
          } else {
            // Role not allowed for this login type
            await _auth.signOut();
            final roleNames = allowedRoles.map((role) => role.displayName).join('/');
            return AuthResult.failure('Access denied. $roleNames access only.');
          }
        } else {
          await _auth.signOut();
          return AuthResult.failure('User data not found. Please contact administrator.');
        }
      }
      return AuthResult.failure('Sign in failed');
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e, stackTrace) {
      print('Unexpected error during sign in: $e');
      print('Stack trace: $stackTrace');
      return AuthResult.failure('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Admin login (restricted to admin/hr/manager)
  Future<AuthResult> signInAsAdmin(String email, String password) async {
    return signInWithEmailAndPassword(
      email, 
      password, 
      allowedRoles: [UserRole.admin, UserRole.hr, UserRole.manager]
    );
  }

  // Employee login (restricted to employees only)
  Future<AuthResult> signInAsEmployee(String email, String password) async {
    return signInWithEmailAndPassword(
      email, 
      password, 
      allowedRoles: [UserRole.employee]
    );
  }

  // Get current user data
  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await getUserData(user.uid);
    }
    return null;
  }

  // Get user data from Firestore
  Future<AppUser?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['id'] = uid; // Ensure ID is set
        
        // Debug print to see the data structure
        print('User data from Firestore: $data');
        
        return AppUser.fromJson(data);
      }
      print('User document does not exist or has no data for UID: $uid');
      return null;
    } catch (e, stackTrace) {
      print('Error getting user data: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(null, message: 'Password reset email sent');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  // Get error message for Firebase Auth errors
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}

class AuthResult {
  final bool isSuccess;
  final AppUser? user;
  final String? message;

  AuthResult.success(this.user, {this.message}) : isSuccess = true;
  AuthResult.failure(this.message) : isSuccess = false, user = null;
}
