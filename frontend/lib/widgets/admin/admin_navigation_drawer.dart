import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../screens/auth/phone_screen.dart';
import '../../services/auth_service.dart';
import '../../screens/admin/admin_banners_screen.dart';
import '../../screens/admin/admin_categories_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/admin_orders_map_screen.dart';
import '../../screens/admin/admin_orders_screen.dart';
import '../../screens/admin/admin_products_screen.dart';
import '../../screens/admin/admin_riders_screen.dart';
import '../../screens/admin/admin_settings_screen.dart';
import '../../screens/admin/admin_users_screen.dart';
import '../../screens/admin/admin_coupons_screen.dart';
import '../../screens/admin/admin_analytics_screen.dart';

enum AdminNavSection {
  dashboard,
  orders,
  routeMap,
  riders,
  products,
  categories,
  banners,
  users,
  coupons,
  analytics,
  settings,
}

class AdminNavigationDrawer extends StatelessWidget {
  const AdminNavigationDrawer({
    super.key,
    required this.currentSection,
    this.todayOrders,
    this.todayRevenue,
    this.onLogout,
  });

  final AdminNavSection currentSection;
  final int? todayOrders;
  final double? todayRevenue;
  final VoidCallback? onLogout;

  static Future<void> confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access the admin dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await AuthService().signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const PhoneScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not log out. Please try again.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  static void navigate(
    BuildContext context, {
    required AdminNavSection section,
    required AdminNavSection currentSection,
  }) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    if (section == currentSection) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => _screenFor(section)),
    );
  }

  static Widget _screenFor(AdminNavSection section) {
    switch (section) {
      case AdminNavSection.dashboard:
        return const AdminDashboardScreen();
      case AdminNavSection.orders:
        return const AdminOrdersScreen();
      case AdminNavSection.routeMap:
        return const AdminOrdersMapScreen();
      case AdminNavSection.riders:
        return const AdminRidersScreen();
      case AdminNavSection.products:
        return const AdminProductsScreen();
      case AdminNavSection.categories:
        return const AdminCategoriesScreen();
      case AdminNavSection.banners:
        return const AdminBannersScreen();
      case AdminNavSection.users:
        return const AdminUsersScreen();
      case AdminNavSection.coupons:
        return const AdminCouponsScreen();
      case AdminNavSection.analytics:
        return const AdminAnalyticsScreen();
      case AdminNavSection.settings:
        return const AdminSettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cardBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionLabel('Overview'),
                  _navTile(
                    context,
                    section: AdminNavSection.dashboard,
                    title: 'Dashboard',
                    icon: Icons.dashboard_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _sectionLabel('Operations'),
                  _navTile(
                    context,
                    section: AdminNavSection.orders,
                    title: 'Orders',
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.bluePrimary,
                  ),
                  _navTile(
                    context,
                    section: AdminNavSection.routeMap,
                    title: 'Route Map',
                    icon: Icons.map_outlined,
                    color: AppColors.primary,
                  ),
                  _navTile(
                    context,
                    section: AdminNavSection.riders,
                    title: 'Riders',
                    icon: Icons.delivery_dining_outlined,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 8),
                  _sectionLabel('Catalog'),
                  _navTile(
                    context,
                    section: AdminNavSection.products,
                    title: 'Products',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.success,
                  ),
                  _navTile(
                    context,
                    section: AdminNavSection.categories,
                    title: 'Categories',
                    icon: Icons.category_outlined,
                    color: AppColors.bluePrimary,
                  ),
                  _navTile(
                    context,
                    section: AdminNavSection.banners,
                    title: 'Banners',
                    icon: Icons.view_carousel_outlined,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 8),
                  _sectionLabel('Management'),
                  _navTile(
                    context,
                    section: AdminNavSection.users,
                    title: 'Users',
                    icon: Icons.people_outline,
                    color: AppColors.primary,
                  ),
                  _navTile(
                    context,
                    section: AdminNavSection.coupons,
                    title: 'Coupons',
                    icon: Icons.local_offer_outlined,
                    color: AppColors.warning,
                  ),
                  _navTile(
                    context,
                    section: AdminNavSection.analytics,
                    title: 'Analytics',
                    icon: Icons.insights_outlined,
                    color: AppColors.success,
                  ),
                  _navTile(
                    context,
                    section: AdminNavSection.settings,
                    title: 'Store Settings',
                    icon: Icons.settings_outlined,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            _buildLogoutTile(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final orders = todayOrders;
    final revenue = todayRevenue;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryHover],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Meatvo Admin',
            style: AppTextStyles.h2.copyWith(
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          if (orders != null || revenue != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (orders != null)
                  Expanded(
                    child: _headerStat(
                      label: 'Today',
                      value: '$orders orders',
                    ),
                  ),
                if (orders != null && revenue != null)
                  const SizedBox(width: 10),
                if (revenue != null)
                  Expanded(
                    child: _headerStat(
                      label: 'Revenue',
                      value: '₹${_formatRevenue(revenue)}',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerStat({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required AdminNavSection section,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = section == currentSection;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? AppColors.accentLight : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => navigate(
            context,
            section: section,
            currentSection: currentSection,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.18)
                        : AppColors.greyLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected ? color : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, size: 18, color: color)
                else
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.logout, color: AppColors.primary, size: 20),
      ),
      title: const Text(
        'Log out',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onLogout?.call();
      },
    );
  }

  String _formatRevenue(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
