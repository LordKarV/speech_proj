import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:speech_app/theme/app_button_styles.dart';
import 'dart:developer' as developer;
import '../theme/ app_colors.dart';

/// Authentication screen for user login and registration
/// Supports email/password authentication and Google Sign-In
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Toggle between login and registration modes
  bool isLogin = true;
  
  // Form controllers for user input
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  /// Handle form submission for login or registration
  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    developer.log('🔐 AuthScreen: Starting ${isLogin ? 'login' : 'registration'} process');
    developer.log('📧 AuthScreen: Email: $email');

    try {
      if (isLogin) {
        // Perform user login
        developer.log('🔑 AuthScreen: Attempting login with email/password');
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        developer.log('✅ AuthScreen: Login successful');
      } else {
        // Perform user registration
        developer.log('📝 AuthScreen: Attempting registration with email/password');
        developer.log('👤 AuthScreen: Name: $name');
        
        final userCred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        developer.log('💾 AuthScreen: Creating user document in Firestore');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .set({
          'name': name,
          'email': email,
          'createdAt': Timestamp.now(),
        });
        
        developer.log('✅ AuthScreen: Registration and user document creation successful');
      }
    } catch (e) {
      developer.log('❌ AuthScreen: Authentication error: $e');
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle Google Sign-In authentication
  Future<void> _signInWithGoogle() async {
    try {
      developer.log('🔐 AuthScreen: Starting Google Sign-In process');
      
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        developer.log('⚠️ AuthScreen: Google Sign-In cancelled by user');
        return;
      }

      developer.log('🔑 AuthScreen: Getting Google authentication credentials');
      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      developer.log('🔐 AuthScreen: Signing in with Google credentials');
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);

      // Create user document for new Google users
      if (userCred.additionalUserInfo!.isNewUser) {
        developer.log('👤 AuthScreen: New Google user detected, creating user document');
        developer.log('📧 AuthScreen: Google user email: ${userCred.user!.email}');
        developer.log('👤 AuthScreen: Google user name: ${userCred.user!.displayName}');
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .set({
          'name': userCred.user!.displayName ?? '',
          'email': userCred.user!.email,
          'createdAt': Timestamp.now(),
          'provider': 'google',
        });
        
        developer.log('✅ AuthScreen: Google user document created successfully');
      } else {
        developer.log('✅ AuthScreen: Existing Google user signed in successfully');
      }
    } catch (e) {
      developer.log('❌ AuthScreen: Google sign-in error: $e');
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Toggle between login and registration modes
  void _toggleAuthMode() {
    developer.log('🔄 AuthScreen: Toggling auth mode from ${isLogin ? 'login' : 'registration'} to ${!isLogin ? 'login' : 'registration'}');
    setState(() {
      isLogin = !isLogin;
    });
  }

  @override
  void dispose() {
    developer.log('🗑️ AuthScreen: Disposing controllers');
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    developer.log('🎨 AuthScreen: Building UI in ${isLogin ? 'login' : 'registration'} mode');
    
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(isLogin ? 'Login' : 'Sign Up'),
        backgroundColor: AppColors.backgroundPrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name field (only shown during registration)
              if (!isLogin)
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
              
              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              
              // Password field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              
              const SizedBox(height: 20),
              
              // Primary submit button (Login/Sign Up)
              ElevatedButton(
                onPressed: _submit,
                style: AppButtonStyles.primaryButton,
                child: Text(isLogin ? 'Login' : 'Sign Up'),
              ),
              
              const SizedBox(height: 10),
              
              // Google Sign-In button
              ElevatedButton.icon(
                onPressed: _signInWithGoogle,
                style: AppButtonStyles.secondaryButton,
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
              ),
              
              // Toggle between login and registration
              TextButton(
                onPressed: _toggleAuthMode,
                style: AppButtonStyles.textButton,
                child: Text(
                  isLogin
                      ? "Don't have an account? Sign up"
                      : "Already have an account? Log in",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
