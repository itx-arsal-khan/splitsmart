import 'dart:io';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import '../services/backend_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_util.dart';
import '../widgets/custom_card.dart';
import '../widgets/avatar_widget.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isUploadingImage = false;
  
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final user = BackendService.currentUser;
    if (user == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 70,
        maxWidth: 500,
        maxHeight: 500,
      );
      
      if (image != null) {
        setState(() => _isUploadingImage = true);
        final rawBytes = await image.readAsBytes();
        
        // Force manual compression so it's instantly uploaded even on Desktop
        final decodedImage = img.decodeImage(rawBytes);
        if (decodedImage == null) throw Exception('Failed to decode image');
        
        final resizedImage = img.copyResize(decodedImage, width: 300);
        final compressedBytes = img.encodeJpg(resizedImage, quality: 70);
        
        await BackendService.uploadProfilePicture(user.uid, compressedBytes, '${DateTime.now().millisecondsSinceEpoch}.jpg');
        
        if (mounted) {
          SnackbarUtil.showSuccess(context, 'Profile picture updated!');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Failed to upload image: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = BackendService.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Info',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            // Avatar
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: BackendService.userProfileStream(user?.uid ?? ''),
              builder: (context, snapshot) {
                final userData = snapshot.data?.data();
                final photoUrl = userData?['photoUrl'] as String?;
                
                return GestureDetector(
                  onTap: _isUploadingImage ? null : _pickAndUploadImage,
                  child: AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.2 * _glowController.value),
                              blurRadius: 30 + (10 * _glowController.value),
                              spreadRadius: 5 + (5 * _glowController.value),
                            )
                          ]
                        ),
                        child: child,
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AvatarWidget(
                          initials: BackendService.initialsFromName(
                            BackendService.displayNameForUser(user),
                          ),
                          imageUrl: photoUrl,
                          size: 100,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          textColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        if (_isUploadingImage)
                          const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        if (!_isUploadingImage)
                          Positioned(
                            bottom: 0,
                            right: -4,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                                border: Border.all(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.edit,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              BackendService.displayNameForUser(user),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              user?.email ?? 'Connected with Firebase',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            // Settings list
            CustomCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildAnimatedTile(
                    index: 0,
                    child: _settingsItem(
                      icon: Icons.person_outline,
                      title: 'Change My Name',
                      showDivider: true,
                      onTap: _showChangeNameDialog,
                    ),
                  ),
                  _buildAnimatedTile(
                    index: 1,
                    child: _settingsToggleItem(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark Mode',
                      value: AppTheme.themeNotifier.value == ThemeMode.dark,
                      onChanged: (val) {
                        setState(() {
                          AppTheme.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                        });
                      },
                      showDivider: true,
                    ),
                  ),
                  _buildAnimatedTile(
                    index: 2,
                    child: _settingsItem(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      showDivider: true,
                      onTap: _showChangePasswordDialog,
                    ),
                  ),
                  _buildAnimatedTile(
                    index: 3,
                    child: _settingsItem(
                      icon: Icons.language,
                      title: 'App Language',
                      subtitle: 'English (Pakistan)',
                      showDivider: true,
                      onTap: _showLanguageDialog,
                    ),
                  ),
                  _buildAnimatedTile(
                    index: 4,
                    child: _settingsItem(
                      icon: Icons.info_outline,
                      title: 'About This App',
                      showDivider: false,
                      onTap: _showAboutDialog,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (BackendService.isFirebaseReady) {
                        await FirebaseAuth.instance.signOut();
                      }
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
              child: Text(
                'Log Out',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              BackendService.isFirebaseReady
                  ? 'CONNECTED TO FIREBASE BACKEND'
                  : 'LOCAL DEMO MODE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ---------- Helper Widget ----------
  Widget _buildAnimatedTile({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(index),
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _settingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: _isLoading ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.radiusSm,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 76,
            endIndent: AppSpacing.lg,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Widget _settingsToggleItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.radiusSm,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Switch(
                value: value,
                onChanged: _isLoading ? null : onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 76,
            endIndent: AppSpacing.lg,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  // ---------- Dialog: Change Name ----------
  void _showChangeNameDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Your Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final success = await BackendService.updateUserDisplayName(newName);
              setState(() => _isLoading = false);
              if (!mounted) return;
              if (success) {
                SnackbarUtil.showSuccess(context, 'Name updated successfully');
              } else {
                SnackbarUtil.showError(context, 'Failed to update name');
              }
              if (success) setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------- Dialog: Change Password ----------
  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final current = currentController.text.trim();
              final newPw = newController.text.trim();
              final confirm = confirmController.text.trim();
              if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
                SnackbarUtil.showError(ctx, 'All fields are required');
                return;
              }
              if (newPw != confirm) {
                SnackbarUtil.showError(ctx, 'Passwords do not match');
                return;
              }
              if (newPw.length < 6) {
                SnackbarUtil.showError(ctx, 'Password must be at least 6 characters');
                return;
              }
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final success = await BackendService.changePassword(current, newPw);
              setState(() => _isLoading = false);
              if (!mounted) return;
              if (success) {
                SnackbarUtil.showSuccess(context, 'Password changed successfully');
              } else {
                SnackbarUtil.showError(context, 'Failed to change password');
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // ---------- Dialog: Language ----------
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Language'),
        content: const Text('Language selection will be available in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------- Dialog: About ----------
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About This App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SplitWise Clone',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'A simple expense splitting app built with Flutter & Firebase.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}