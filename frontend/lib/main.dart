import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'services/error_tracking_service.dart';
import 'widgets/error_states/error_state_widget.dart';
import 'screens/auth/login_test_screen.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/categories/categories_list_screen.dart';
import 'screens/home/home_screen.dart';
import 'design_system/tokens/meatvo_colors.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'services/cache_service.dart';
import 'services/cart_service.dart';
import 'services/push_notification_service.dart';
import 'providers/theme_provider.dart';
import 'config/backend_resolver.dart';
import 'config/env_config.dart';
import 'config/google_maps_setup.dart';
import 'app_navigator_key.dart';
import 'config/feature_flags.dart';
import 'design_system/theme/meatvo_theme.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'ui/shells/meatvo_floating_nav_bar.dart';
import 'ui/shells/meatvo_layout.dart';
import 'widgets/cart/floating_cart_bar.dart';
import 'utils/app_colors.dart';
import 'utils/responsive_helper.dart';
import 'utils/session_expired.dart';
import 'widgets/location/location_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = _meatvoErrorWidgetBuilder;

  final hiveDirectory = await getApplicationSupportDirectory();
  await Hive.initFlutter(hiveDirectory.path);
  await CacheService.init();

  try {
    await EnvConfig.load();
    GoogleMapsSetup.logDebugStatus();
    await BackendResolver.init();
  } catch (e) {
    debugPrint('⚠️ Env Config Load Failed (Continuing anyway): $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    PushNotificationService.registerBackgroundHandler();
  } catch (e) {
    debugPrint('⚠️ Firebase Init Failed (Missing config?): $e');
  }

  await ErrorTrackingService.runApp(() {
    runApp(const ProviderScope(child: MyApp()));

    // Defer FCM token fetch so cold start is not blocked on Play Services (MIUI).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService().initialize();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      registerSessionExpiredHandler(() {
        final nav = appNavigatorKey.currentState;
        if (nav == null) return;
        nav.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const PhoneScreen()),
          (_) => false,
        );
      });
    });
  });
}

/// Flip to `true` in debug builds to open the backend integration test screen.
/// Set back to `false` before any production / release build.
const bool _kShowIntegrationTest = false;

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    
    return MaterialApp(
      title: 'Meatvo',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        R.init(context);
        return child ?? const SizedBox.shrink();
      },
      navigatorKey: appNavigatorKey,
      themeMode: themeMode,
      theme: FeatureFlags.useMeatvoDesignSystem
          ? MeatvoTheme.light
          : AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Dev toggle: set _kShowIntegrationTest = true to open backend test screen.
      // Flip back to false (or remove) before release.
      home: kDebugMode && _kShowIntegrationTest
          ? const LoginTestScreen()
          : const SplashScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  DateTime? _lastBackPressTime;
  String? _categoriesInitialCategory;
  int? _categoriesInitialCategoryId;

  List<Widget> get _screens => [
        HomeTab(
          onOpenCartTab: _openCartTab,
          onOpenProfileTab: _openProfileTab,
          onOpenCategoriesTab: _openCategoriesTab,
        ),
        CategoriesListScreen(
          key: ValueKey(
            'categories-${_categoriesInitialCategory ?? ''}-'
            '${_categoriesInitialCategoryId ?? ''}',
          ),
          initialCategory: _categoriesInitialCategory,
          initialCategoryId: _categoriesInitialCategoryId,
        ),
        CartTab(onOpenHomeTab: () => _onItemTapped(0)),
        const OrdersTab(),
        ProfileScreen(
          onOpenOrderHistory: () => _onItemTapped(3),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _primeCartBadge();
  }

  Future<void> _primeCartBadge() async {
    try {
      await CartService().getCart();
    } catch (_) {}
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _categoriesInitialCategory = null;
        _categoriesInitialCategoryId = null;
      }
    });
  }

  void _openCartTab() {
    _onItemTapped(2);
  }

  void _openProfileTab() {
    _onItemTapped(4);
  }

  void _openCategoriesTab({String? category, int? categoryId}) {
    setState(() {
      _selectedIndex = 1;
      _categoriesInitialCategory = category?.trim();
      _categoriesInitialCategoryId = categoryId;
    });
  }

  Future<bool> _onWillPop() async {
    if (!context.mounted) return false;

    final now = DateTime.now();
    
    // Check if there's a navigation stack to pop
    if (Navigator.of(context).canPop()) {
      // If there's a previous screen, just pop
      Navigator.of(context).pop();
      return false; // Don't exit app
    }
    
    // If on main tab screen, check for double back press
    if (_lastBackPressTime == null || 
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      // First back press or more than 2 seconds passed
      _lastBackPressTime = now;
      
      if (!context.mounted) return false;

      // Show snackbar message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.redPrimary,
        ),
      );
      return false; // Don't exit app yet
    }
    
    // Double back press within 2 seconds - show exit confirmation
    return await _showExitDialog() ?? false;
  }

  Future<bool?> _showExitDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Do you want to exit the app?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.redPrimary,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LocationGate(
      child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldExit = await _onWillPop();
          if (shouldExit) {
            // Exit the app
            if (Platform.isAndroid) {
              SystemNavigator.pop();
            } else if (Platform.isIOS) {
              exit(0);
            }
          }
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MeatvoLayout.tabShellBottomInset(context),
                ),
                child: _screens[_selectedIndex],
              ),
            ),
            MeatvoFloatingNavBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: [
                const MeatvoNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                const MeatvoNavItem(
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                  label: 'Categories',
                ),
                MeatvoNavItem(
                  icon: Icons.shopping_cart_outlined,
                  activeIcon: Icons.shopping_cart_rounded,
                  label: 'Cart',
                  badge: _CartNavBadge(),
                ),
                const MeatvoNavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Orders',
                ),
                const MeatvoNavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                ),
              ],
            ),
            if (_selectedIndex == 0 || _selectedIndex == 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: MeatvoLayout.tabShellFloatingCartBottom(context),
                child: FloatingCartBar(
                  onViewCartTapped: _openCartTab,
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}

class _CartNavBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CartService.cartItemCountNotifier,
      builder: (context, cartCount, _) {
        if (cartCount <= 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          decoration: BoxDecoration(
            color: AppThemeColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.radiusPill),
            border: Border.all(color: AppThemeColors.surface, width: 1.2),
          ),
          child: Text(
            cartCount > 99 ? '99+' : '$cartCount',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

// Home Tab - Uses the new HomeScreen
class HomeTab extends StatelessWidget {
  final VoidCallback onOpenCartTab;
  final VoidCallback onOpenProfileTab;
  final void Function({String? category, int? categoryId}) onOpenCategoriesTab;

  const HomeTab({
    super.key,
    required this.onOpenCartTab,
    required this.onOpenProfileTab,
    required this.onOpenCategoriesTab,
  });

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      onOpenCartTab: onOpenCartTab,
      onOpenProfileTab: onOpenProfileTab,
      onOpenCategoriesTab: onOpenCategoriesTab,
    );
  }
}

// Categories Tab - Uses the CategoriesListScreen
class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoriesListScreen();
  }
}

class CartTab extends StatelessWidget {
  final VoidCallback onOpenHomeTab;

  const CartTab({super.key, required this.onOpenHomeTab});

  @override
  Widget build(BuildContext context) {
    return CartScreen(inTabShell: true, onNavigateToHome: onOpenHomeTab);
  }
}

class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const OrdersScreen();
  }
}

Widget _meatvoErrorWidgetBuilder(FlutterErrorDetails details) {
  if (kDebugMode) {
    return _DebugErrorScreen(details: details);
  }
  return const _ReleaseErrorScreen();
}

/// Debug-only red panel that replaces a failed widget subtree.
///
/// `ErrorWidget.builder` returns a widget that does NOT have a `Scaffold` /
/// `MaterialApp` ancestor in the failed subtree's position, so we wrap in
/// [Material] + [SafeArea] manually to get a sane render context.
class _DebugErrorScreen extends StatelessWidget {
  const _DebugErrorScreen({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    const monoStyle = TextStyle(
      fontFamily: 'monospace',
      color: Colors.white,
      fontSize: 12,
      height: 1.35,
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.red.shade900,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WIDGET BUILD ERROR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  details.exceptionAsString(),
                  style: monoStyle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'STACK TRACE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  details.stack?.toString() ?? '<no stack trace>',
                  style: monoStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Release-mode user-friendly fallback. Wraps the existing
/// [GenericErrorWidget] and triggers a soft restart by pushing the
/// [SplashScreen] via [appNavigatorKey] (no `flutter_phoenix` dep needed).
class _ReleaseErrorScreen extends StatelessWidget {
  const _ReleaseErrorScreen();

  void _retryToSplash() {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: MeatvoColors.surfaceWarm,
        child: SafeArea(
          child: GenericErrorWidget(
            message: 'Something went wrong. Tap retry to continue.',
            onRetry: _retryToSplash,
          ),
        ),
      ),
    );
  }
}
