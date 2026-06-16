import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../services/cache_service.dart';
import '../../providers/theme_provider.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

/// Account Settings Screen - User account preferences
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _isLoading = true;
  bool _emailNotifications = true;
  bool _smsNotifications = true;
  bool _orderUpdates = true;
  bool _promotionalOffers = false;
  String _language = 'English';
  String _currency = 'INR';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _smsNotifications = prefs.getBool('sms_notifications') ?? true;
      _orderUpdates = prefs.getBool('order_updates') ?? true;
      _promotionalOffers = prefs.getBool('promotional_offers') ?? false;
      _language = prefs.getString('language') ?? 'English';
      _currency = prefs.getString('currency') ?? 'INR';
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Account Settings'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Notification Settings Section
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.divider, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notification Preferences',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Email Notifications'),
                          subtitle: const Text('Receive updates via email'),
                          value: _emailNotifications,
                          onChanged: (value) {
                            setState(() {
                              _emailNotifications = value;
                            });
                            _saveSetting('email_notifications', value);
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('SMS Notifications'),
                          subtitle: const Text('Receive updates via SMS'),
                          value: _smsNotifications,
                          onChanged: (value) {
                            setState(() {
                              _smsNotifications = value;
                            });
                            _saveSetting('sms_notifications', value);
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('Order Updates'),
                          subtitle: const Text('Get notified about order status'),
                          value: _orderUpdates,
                          onChanged: (value) {
                            setState(() {
                              _orderUpdates = value;
                            });
                            _saveSetting('order_updates', value);
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('Promotional Offers'),
                          subtitle: const Text('Receive offers and discounts'),
                          value: _promotionalOffers,
                          onChanged: (value) {
                            setState(() {
                              _promotionalOffers = value;
                            });
                            _saveSetting('promotional_offers', value);
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Theme Settings Section
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.divider, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Appearance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Consumer(
                          builder: (context, ref, child) {
                            final themeMode = ref.watch(themeProvider);
                            final themeNotifier = ref.read(themeProvider.notifier);
                            
                            return SwitchListTile(
                              title: const Text('Dark Mode'),
                              subtitle: Text(
                                themeMode == ThemeMode.dark
                                    ? 'Dark theme enabled'
                                    : themeMode == ThemeMode.system
                                        ? 'Following system setting'
                                        : 'Light theme enabled',
                              ),
                              value: themeMode == ThemeMode.dark,
                              onChanged: (value) {
                                themeNotifier.setThemeMode(
                                  value ? ThemeMode.dark : ThemeMode.light,
                                );
                              },
                              activeThumbColor: AppColors.primary,
                            );
                          },
                        ),
                        const Divider(),
                        Consumer(
                          builder: (context, ref, child) {
                            final themeMode = ref.watch(themeProvider);
                            final themeNotifier = ref.read(themeProvider.notifier);
                            
                            return ListTile(
                              title: const Text('Theme Mode'),
                              subtitle: Text(
                                themeMode == ThemeMode.dark
                                    ? 'Dark'
                                    : themeMode == ThemeMode.system
                                        ? 'System Default'
                                        : 'Light',
                              ),
                              trailing: DropdownButton<ThemeMode>(
                                value: themeMode,
                                items: const [
                                  DropdownMenuItem(
                                    value: ThemeMode.light,
                                    child: Text('Light'),
                                  ),
                                  DropdownMenuItem(
                                    value: ThemeMode.dark,
                                    child: Text('Dark'),
                                  ),
                                  DropdownMenuItem(
                                    value: ThemeMode.system,
                                    child: Text('System'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    themeNotifier.setThemeMode(value);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // App Settings Section
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.divider, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'App Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Language'),
                          subtitle: Text(_language),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            _showLanguageDialog();
                          },
                        ),
                        const Divider(),
                        ListTile(
                          title: const Text('Currency'),
                          subtitle: Text(_currency),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            _showCurrencyDialog();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Data & Privacy Section
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.divider, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data & Privacy',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: const Text('Clear Cache'),
                          subtitle: const Text('Clear cached data and images'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            _showClearCacheDialog();
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: const Text('Privacy Policy'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const PrivacyPolicyScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: const Text('Terms of Service'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const TermsOfServiceScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showLanguageDialog() {
    String? selectedLanguage = _language;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Language'),
          content: RadioGroup<String>(
            groupValue: selectedLanguage,
            onChanged: (value) {
              setDialogState(() {
                selectedLanguage = value;
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('English'),
                  value: 'English',
                  activeColor: AppColors.primary,
                ),
                RadioListTile<String>(
                  title: const Text('Hindi'),
                  value: 'Hindi',
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedLanguage != null) {
                  setState(() {
                    _language = selectedLanguage!;
                  });
                  _saveSetting('language', selectedLanguage);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyDialog() {
    String? selectedCurrency = _currency;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Currency'),
          content: RadioGroup<String>(
            groupValue: selectedCurrency,
            onChanged: (value) {
              setDialogState(() {
                selectedCurrency = value;
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('INR (₹)'),
                  value: 'INR',
                  activeColor: AppColors.primary,
                ),
                RadioListTile<String>(
                  title: const Text('USD (\$)'),
                  value: 'USD',
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedCurrency != null) {
                  setState(() {
                    _currency = selectedCurrency!;
                  });
                  _saveSetting('currency', selectedCurrency);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data and images. The app may take longer to load next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Clear cache
              await _clearCache();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cache cleared successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    // Clear API cache
    await CacheService.clear();
    
    // Clear image cache (CachedNetworkImage handles this automatically on next load)
    // You might want to add image cache clearing if needed
  }
}

