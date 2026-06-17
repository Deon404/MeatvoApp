import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/support_config.dart';
import '../../core/constants/app_constants.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../models/user_model.dart';
import '../../screens/address/address_list_screen.dart';
import '../../screens/auth/phone_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/profile/profile_edit_screen.dart';
import '../../screens/settings/privacy_policy_screen.dart';
import '../../screens/settings/terms_of_service_screen.dart';
import '../../screens/wishlist/wishlist_screen.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../features/home/widgets/home_brand_footer.dart';

const _brandRed = Color(0xFFC8102E);
const _textDark = Color(0xFF1A1A1A);
const _textGrey = Color(0xFF6B6B6B);
const _iconBg = AppColors.greyLight;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.onOpenOrderHistory,
  });

  final VoidCallback? onOpenOrderHistory;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserModel?> _userFuture;

  @override
  void initState() {
    super.initState();
    _reloadUser();
  }

  void _reloadUser() {
    _userFuture = StorageService().getUser();
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    setState(_reloadUser);
    await _userFuture;
  }

  Future<void> _openProfileEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );
    if (updated == true && mounted) {
      setState(_reloadUser);
    }
  }

  Future<void> _confirmLogout() async {
    final mv = context.meatvo;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: mv.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mv.radii.lg),
        ),
        title: Text(
          'Log out?',
          style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                color: mv.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        content: Text(
          'You will need to sign in again to place orders and view your history.',
          style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                color: mv.textSecondary,
                height: 1.45,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: mv.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const PhoneScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not log out. Please try again.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _launchUrl(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    if (!await launchUrl(uri, mode: mode)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link. Please try again.')),
      );
    }
  }

  void _showSupportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Help & Support',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.call_outlined, color: _brandRed),
                title: const Text('Call us'),
                subtitle: Text(SupportConfig.phone),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _launchUrl(Uri.parse('tel:${SupportConfig.phone}'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline, color: _brandRed),
                title: const Text('Email'),
                subtitle: Text(SupportConfig.email),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _launchUrl(Uri.parse('mailto:${SupportConfig.email}'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline, color: _brandRed),
                title: const Text('FAQ'),
                subtitle: const Text('Common questions about orders & delivery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _launchUrl(
                    Uri.parse(SupportConfig.faqUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showTermsPrivacySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: _brandRed),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right, size: 16, color: _textGrey),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const TermsOfServiceScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: _brandRed),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right, size: 16, color: _textGrey),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _brandRed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _textGrey,
          ),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.divider,
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: _textGrey),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 16,
              color: _textGrey,
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, indent: 72, endIndent: 20),
      ],
    );
  }

  Widget _buildAvatar(UserModel? user) {
    final name = user?.name?.trim() ?? '';
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : 'M';
    final imageUrl = user?.profileImageUrl?.trim();

    return CircleAvatar(
      radius: 30,
      backgroundColor: _brandRed,
      child: ClipOval(
        child: (imageUrl != null && imageUrl.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (_, __) => _avatarFallback(initial),
                errorWidget: (_, __, ___) => _avatarFallback(initial),
              )
            : _avatarFallback(initial),
      ),
    );
  }

  Widget _avatarFallback(String initial) {
    return Container(
      width: 60,
      height: 60,
      color: _brandRed,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.warmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: _brandRed,
          backgroundColor: Colors.white,
          child: FutureBuilder<UserModel?>(
            future: _userFuture,
            builder: (context, snapshot) {
              final user = snapshot.data;
              final userName = user?.name?.trim().isNotEmpty == true
                  ? user!.name!.trim()
                  : 'Guest';
              final phone = _formatPhone(user?.phoneNumber);

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Row(
                        children: [
                          _buildAvatar(user),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _openProfileEdit();
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              side: const BorderSide(color: _brandRed),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              foregroundColor: _brandRed,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem('45', 'Orders'),
                          _statDivider(),
                          _statItem('12', 'Saved'),
                          _statDivider(),
                          _statItem('3', 'Addresses'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          _menuTile(
                            icon: Icons.receipt_long,
                            title: 'My Orders',
                            onTap: () {
                              final openOrders = widget.onOpenOrderHistory;
                              if (openOrders != null) {
                                openOrders();
                              }
                            },
                          ),
                          _menuTile(
                            icon: Icons.favorite_border,
                            title: 'Saved Items',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const WishlistScreen(),
                                ),
                              );
                            },
                          ),
                          _menuTile(
                            icon: Icons.location_on_outlined,
                            title: 'Addresses',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const AddressListScreen(),
                                ),
                              );
                            },
                          ),
                          _menuTile(
                            icon: Icons.notifications_none,
                            title: 'Notifications',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              );
                            },
                          ),
                          _menuTile(
                            icon: Icons.help_outline,
                            title: 'Help & Support',
                            onTap: _showSupportSheet,
                          ),
                          _menuTile(
                            icon: Icons.policy_outlined,
                            title: 'Terms & Privacy',
                            onTap: _showTermsPrivacySheet,
                            showDivider: false,
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton.icon(
                        onPressed: _confirmLogout,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.logout, size: 18, color: _brandRed),
                        label: const Text(
                          'Log out',
                          style: TextStyle(
                            color: _brandRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const HomeBrandFooter(
                      align: CrossAxisAlignment.center,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatPhone(String? raw) {
    final digits = raw?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return 'Add your mobile number';
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    if (digits.length > 10 && digits.startsWith('91')) {
      final local = digits.substring(digits.length - 10);
      return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
    }
    return raw!.trim();
  }
}
