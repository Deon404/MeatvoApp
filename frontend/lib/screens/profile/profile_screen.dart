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
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../features/home/widgets/home_brand_footer.dart';

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
  Map<String, int>? _stats;

  @override
  void initState() {
    super.initState();
    _reloadUser();
    _loadStats();
  }

  void _reloadUser() {
    _userFuture = StorageService().getUser();
  }

  Future<void> _loadStats() async {
    try {
      final res = await ApiService().get('/users/me');
      final root = res.data;
      if (root is! Map<String, dynamic> || root['success'] != true) return;

      final payload = root['data'];
      if (payload is! Map<String, dynamic>) return;

      final stats = payload['stats'];
      if (stats is! Map<String, dynamic>) return;

      if (!mounted) return;
      setState(() {
        _stats = {
          'ordersCount': (stats['ordersCount'] as num?)?.toInt() ?? 0,
          'wishlistCount': (stats['wishlistCount'] as num?)?.toInt() ?? 0,
          'addressesCount': (stats['addressesCount'] as num?)?.toInt() ?? 0,
        };
      });
    } catch (_) {
      // Keep _stats null — UI shows '-' until/unless load succeeds.
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    setState(() {
      _stats = null;
      _reloadUser();
    });
    _loadStats();
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
    final mv = context.meatvo;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: mv.surfaceCard,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Help & Support',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: mv.textPrimary,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.call_outlined, color: mv.brandAccent),
                title: const Text('Call us'),
                subtitle: Text(SupportConfig.phone),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _launchUrl(Uri.parse('tel:${SupportConfig.phone}'));
                },
              ),
              ListTile(
                leading: Icon(Icons.mail_outline, color: mv.brandAccent),
                title: const Text('Email'),
                subtitle: Text(SupportConfig.email),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _launchUrl(Uri.parse('mailto:${SupportConfig.email}'));
                },
              ),
              ListTile(
                leading: Icon(Icons.help_outline, color: mv.brandAccent),
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
    final mv = context.meatvo;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: mv.surfaceCard,
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
                leading: Icon(Icons.description_outlined, color: mv.brandAccent),
                title: const Text('Terms of Service'),
                trailing: Icon(Icons.chevron_right, size: 16, color: mv.textSecondary),
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
                leading: Icon(Icons.privacy_tip_outlined, color: mv.brandAccent),
                title: const Text('Privacy Policy'),
                trailing: Icon(Icons.chevron_right, size: 16, color: mv.textSecondary),
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
    final mv = context.meatvo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: mv.brandAccent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: mv.textSecondary,
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
    final mv = context.meatvo;
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
              child: Icon(icon, size: 18, color: mv.textSecondary),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: mv.textPrimary,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              size: 16,
              color: mv.textSecondary,
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
    final mv = context.meatvo;
    final name = user?.name?.trim() ?? '';
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : 'M';
    final imageUrl = user?.profileImageUrl?.trim();

    return CircleAvatar(
      radius: 30,
      backgroundColor: mv.brandAccent,
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
    final mv = context.meatvo;
    return Container(
      width: 60,
      height: 60,
      color: mv.brandAccent,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: mv.surfaceCard,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.warmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: mv.brandAccent,
          backgroundColor: mv.surfaceCard,
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
                      color: mv.surfaceCard,
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
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: mv.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  phone,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: mv.textSecondary,
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
                              side: BorderSide(color: mv.brandAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              foregroundColor: mv.brandAccent,
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
                        color: mv.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem(
                            _stats?['ordersCount']?.toString() ?? '-',
                            'Orders',
                          ),
                          _statDivider(),
                          _statItem(
                            _stats?['wishlistCount']?.toString() ?? '-',
                            'Saved',
                          ),
                          _statDivider(),
                          _statItem(
                            _stats?['addressesCount']?.toString() ?? '-',
                            'Addresses',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: mv.surfaceCard,
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
                        icon: Icon(Icons.logout, size: 18, color: mv.brandAccent),
                        label: Text(
                          'Log out',
                          style: TextStyle(
                            color: mv.brandAccent,
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
