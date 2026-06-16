import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/shimmer_loader.dart';

/// Profile Edit Screen - Edit user profile information
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  UserModel? _user;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _user = user;
          if (user != null) {
            _nameController.text = user.name ?? '';
            _emailController.text = user.email ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().isEmpty 
          ? null 
          : _emailController.text.trim();

      // Validate email format if provided
      if (email != null && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid email address'),
              backgroundColor: AppThemeColors.error,
            ),
          );
        }
        setState(() {
          _isSaving = false;
        });
        return;
      }

      await _authService.updateProfile(
        name: name.isEmpty ? null : name,
        email: email,
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context, true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppThemeColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppThemeColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppThemeColors.background,
      appBar: AppBar(
        backgroundColor: AppThemeColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Edit Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppThemeColors.textPrimary,
              ),
        ),
      ),
      body: _isLoading
          ? const ShimmerLoader.listTile(count: 3)
          : _errorMessage != null
              ? _buildErrorState()
              : _buildForm(),
    );
  }

  Widget _buildErrorState() {
    return ErrorStateWidget(
      title: 'Failed to load profile',
      message: _errorMessage ?? 'Unknown error',
      onRetry: _loadUserProfile,
    );
  }

  Widget _buildForm() {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      borderSide: const BorderSide(color: AppThemeColors.border),
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeColors.white,
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone Number',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppThemeColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _user?.phoneNumber ?? 'Not available',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppThemeColors.textPrimary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Phone number cannot be changed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppThemeColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter your full name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              filled: true,
              fillColor: AppThemeColors.white,
              enabledBorder: inputBorder,
              border: inputBorder,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                borderSide: const BorderSide(
                  color: AppThemeColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter your email (optional)',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
              filled: true,
              fillColor: AppThemeColors.white,
              enabledBorder: inputBorder,
              border: inputBorder,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                borderSide: const BorderSide(
                  color: AppThemeColors.primary,
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton.primary(
            'Save Changes',
            _saveProfile,
            isLoading: _isSaving,
            isFullWidth: true,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

