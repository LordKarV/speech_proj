import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/app_label.dart';
import '../components/section_header.dart';
import '../theme/ app_colors.dart';
import '../theme/app_dimensions.dart';
import 'spectrogram_screen.dart';

/// Main home screen displaying user welcome message, new recording option, and recent recordings
class HomeScreen extends StatelessWidget {
  // Sample data for recent recordings - will be replaced with actual data from database
  static const List<Map<String, String>> recentRecordings = [
    {"date": "Jun 12", "title": "Reading A", "duration": "00:25"},
    {"date": "Jun 11", "title": "Intro Poem", "duration": "00:18"},
    {"date": "Jun 10", "title": "Custom Text", "duration": "00:30"},
    {"date": "Jun 09", "title": "Practice Session", "duration": "00:42"},
    {"date": "Jun 08", "title": "Morning Reading", "duration": "00:35"},
    {"date": "Jun 07", "title": "Evening Practice", "duration": "00:28"},
  ];

  const HomeScreen({super.key});

  /// Handle navigation to spectrogram screen with microphone permission check
  Future<void> _navigateToRecording(BuildContext context) async {
    developer.log('🎤 HomeScreen: Checking microphone permission for new recording');
    
    // Check current microphone permission status
    final permission = await Permission.microphone.status;
    developer.log('🔐 HomeScreen: Current microphone permission status: $permission');
    
    if (!permission.isGranted) {
      developer.log('🔐 HomeScreen: Requesting microphone permission');
      final result = await Permission.microphone.request();
      developer.log('🔐 HomeScreen: Permission request result: $result');
      
      if (!result.isGranted) {
        developer.log('❌ HomeScreen: Microphone permission denied');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Microphone permission is required for recording'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }
    
    developer.log('✅ HomeScreen: Microphone permission granted, navigating to recording screen');
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SpectrogramScreen(),
        ),
      );
    }
  }

  /// Handle user sign out with confirmation dialog
  Future<void> _handleSignOut(BuildContext context) async {
    developer.log('🚪 HomeScreen: User requested sign out');
    
    // Show confirmation dialog
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: const AppLabel.primary(
            'Sign Out',
            size: LabelSize.large,
            fontWeight: FontWeight.bold,
          ),
          content: const AppLabel.secondary('Are you sure you want to sign out?'),
          actions: [
            AppButton.secondary(
              onPressed: () {
                developer.log('🚪 HomeScreen: Sign out cancelled');
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            AppButton.primary(
              onPressed: () {
                developer.log('🚪 HomeScreen: Sign out confirmed');
                Navigator.of(context).pop(true);
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
    
    if (shouldSignOut == true) {
      try {
        developer.log('🚪 HomeScreen: Signing out user');
        await FirebaseAuth.instance.signOut();
        developer.log('✅ HomeScreen: User signed out successfully');
      } catch (e) {
        developer.log('❌ HomeScreen: Error signing out: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  /// Handle recording item tap (placeholder for future implementation)
  void _handleRecordingTap(BuildContext context, Map<String, String> recording) {
    developer.log('🎵 HomeScreen: Recording tapped - ${recording['title']}');
    
    // TODO: Navigate to recording details or playback screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing ${recording['title']}...'),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  /// Handle view all recordings tap (placeholder for future implementation)
  void _handleViewAllRecordings(BuildContext context) {
    developer.log('📋 HomeScreen: View all recordings requested');
    
    // TODO: Navigate to full history screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Full history coming soon!'),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current user information for display
    final User? user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
    
    developer.log('🏠 HomeScreen: Building home screen for user: $displayName');
    developer.log('📊 HomeScreen: Displaying ${recentRecordings.length} recent recordings');

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with welcome message and user profile
              _buildHeader(context, displayName),
              
              const SizedBox(height: AppDimensions.marginLarge),
              
              // New Recording Section
              _buildNewRecordingCard(context),
              
              const SizedBox(height: AppDimensions.marginXLarge),
              
              // Recent Recordings Section Header
              _buildRecentRecordingsHeader(context),
              
              const SizedBox(height: AppDimensions.marginMedium),
              
              // Recent Recordings List
              _buildRecentRecordingsList(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Build header with welcome message and user profile menu
  Widget _buildHeader(BuildContext context, String displayName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Welcome message
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppLabel.primary(
                'Welcome, ${displayName.capitalize()}',
                size: LabelSize.xlarge,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: AppDimensions.marginXSmall),
              const AppLabel.secondary('Ready to analyze your speech?'),
            ],
          ),
        ),
        // User profile menu
        _buildUserProfileMenu(context, displayName),
      ],
    );
  }

  /// Build user profile menu with avatar and sign out option
  Widget _buildUserProfileMenu(BuildContext context, String displayName) {
    return PopupMenuButton<String>(
      icon: CircleAvatar(
        radius: 23,
        backgroundColor: AppColors.accent,
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      onSelected: (value) async {
        developer.log('👤 HomeScreen: Profile menu item selected: $value');
        if (value == 'signout') {
          await _handleSignOut(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const AppLabel.secondary('Sign out'),
            ],
          ),
        ),
      ],
    );
  }

  /// Build new recording card with microphone icon and call-to-action
  Widget _buildNewRecordingCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToRecording(context),
      child: SizedBox(
        width: double.infinity,
        child: AppCard.elevated(
          padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Microphone icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic,
                  size: 40,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: AppDimensions.marginLarge),
              const AppLabel.primary(
                "New Recording",
                size: LabelSize.large,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: AppDimensions.marginSmall),
              const AppLabel.secondary(
                "Tap to start analyzing your speech",
                size: LabelSize.medium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build recent recordings section header with view all button
  Widget _buildRecentRecordingsHeader(BuildContext context) {
    return SectionHeader(
      title: 'Recent Recordings',
      action: AppButton.tertiary(
        onPressed: () => _handleViewAllRecordings(context),
        child: const Text('View all'),
      ),
    );
  }

  /// Build scrollable list of recent recordings
  Widget _buildRecentRecordingsList(BuildContext context) {
    return Expanded(
      child: recentRecordings.isEmpty
          ? const Center(
              child: AppLabel.secondary('No recordings yet'),
            )
          : ListView.separated(
              itemCount: recentRecordings.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.marginSmall),
              itemBuilder: (context, index) {
                final recording = recentRecordings[index];
                return _buildRecordingListItem(context, recording);
              },
            ),
    );
  }

  /// Build individual recording list item
  Widget _buildRecordingListItem(BuildContext context, Map<String, String> recording) {
    return AppCard.basic(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppDimensions.paddingSmall,
          horizontal: AppDimensions.paddingMedium,
        ),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.accent.withOpacity(0.1),
          child: Icon(
            Icons.audiotrack,
            color: AppColors.accent,
            size: 20,
          ),
        ),
        title: AppLabel.primary(
          recording['title']!,
          fontWeight: FontWeight.bold,
          size: LabelSize.medium,
        ),
        subtitle: AppLabel.secondary(
          recording['date']!,
          size: LabelSize.small,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingSmall,
            vertical: AppDimensions.paddingXSmall,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundTertiary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          child: AppLabel.primary(
            recording['duration']!,
            fontWeight: FontWeight.w500,
            size: LabelSize.small,
          ),
        ),
        onTap: () => _handleRecordingTap(context, recording),
      ),
    );
  }
}

/// Extension to capitalize the first letter of a string
extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
