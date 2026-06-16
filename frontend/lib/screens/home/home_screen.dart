import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/home_strings.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../features/connectivity/connectivity_provider.dart';
import '../../features/home/widgets/home_top_bar_delegate.dart';
import '../../models/banner_model.dart';
import '../../models/home_category_item.dart';
import '../../models/product_variant_model.dart';
import '../../screens/address/address_list_screen.dart';
import '../../screens/categories/categories_list_screen.dart';
import '../../screens/categories/category_products_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/product/product_detail_screen.dart';
import '../../ui/shells/meatvo_layout.dart';
import '../../ui/shells/offline_banner.dart';
import '../../utils/app_transitions.dart';
import '../../utils/responsive_helper.dart';
import '../../viewmodels/home_provider.dart';
import '../../viewmodels/home_state.dart';
import '../../widgets/home/home_body.dart';
import '../../widgets/location/location_onboarding_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenCartTab,
    required this.onOpenProfileTab,
  });

  final VoidCallback onOpenCartTab;
  final VoidCallback onOpenProfileTab;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(homeViewModelProvider.notifier).initialize(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(homeViewModelProvider.notifier).handleResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    ref.listen<HomeState>(homeViewModelProvider, (previous, next) {
      final message = next.cartErrorMessage;
      if (message == null || previous?.cartErrorMessage == message || !mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      ref.read(homeViewModelProvider.notifier).clearCartError();
    });

    ref.listen<AsyncValue<bool>>(isOfflineProvider, (previous, next) {
      final offline = next.value ?? false;
      if (_wasOffline && !offline) {
        ref.read(homeViewModelProvider.notifier).refresh();
      }
      _wasOffline = offline;
    });

    final state = ref.watch(homeViewModelProvider);
    final offline = ref.watch(isOfflineProvider).value ?? false;

    final bottomPad = MeatvoLayout.homeScrollBottomInset(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFFAF9F7),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Stack(
          children: [
            RefreshIndicator(
              color: Colors.red.shade600,
              onRefresh: () =>
                  ref.read(homeViewModelProvider.notifier).refresh(),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: HomeTopBarDelegate(
                      topPadding: MediaQuery.paddingOf(context).top,
                      locationLabel: _shortDeliveryAreaName(state),
                      unreadCount: state.unreadNotificationCount,
                      profileInitial: _profileInitial(state),
                      onAddressTap: _openAddressBook,
                      onNotificationTap: _openNotifications,
                      onProfileTap: widget.onOpenProfileTab,
                    ),
                  ),
                  HomeBody(
                    state: state,
                    onOpenCategories: _openCategories,
                    onOpenCategory: _openCategory,
                    onRetryHome: () =>
                        ref.read(homeViewModelProvider.notifier).refresh(),
                    onRetryCategories: () => ref
                        .read(homeViewModelProvider.notifier)
                        .fetchCategories(),
                    onRetryFeatured: () => ref
                        .read(homeViewModelProvider.notifier)
                        .fetchFeaturedProducts(),
                    onRetryPopular: () => ref
                        .read(homeViewModelProvider.notifier)
                        .fetchBestSellers(),
                    onBannerTap: _handleBannerTap,
                    onProductTap: _openProduct,
                    onQuantityChange: ref
                        .read(homeViewModelProvider.notifier)
                        .changeCartQuantity,
                    bottomPadding: bottomPad,
                  ),
                ],
              ),
            ),
            if (offline) const OfflineBanner(),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBannerTap(BannerModel banner) async {
    if (banner.linkType == 'category') {
      final raw = (banner.linkId ?? banner.title).trim();
      if (raw.isEmpty) return;
      _openCategory(
        HomeCategoryItem(
          // Admin can store either the numeric category id ("1") or a slug
          // ("chicken") here; the catalog viewmodel uses both gracefully.
          id: raw,
          name: _resolveCategoryNameById(raw) ?? banner.title.trim(),
        ),
      );
      return;
    }
    if (banner.linkType == 'product' && banner.linkId != null) {
      await _openProductId(banner.linkId!);
      return;
    }
    if (mounted && banner.link?.isNotEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(HomeStrings.bannerLinkUnavailable)),
      );
    }
  }

  /// Look up the canonical category name from the home state when the banner
  /// only provides a numeric id like "2" — avoids ending up with an empty
  /// `categoryName` reaching the catalog filter.
  String? _resolveCategoryNameById(String idOrSlug) {
    final categories = ref.read(homeViewModelProvider).categories;
    for (final category in categories) {
      if (category.id == idOrSlug ||
          category.name.toLowerCase() == idOrSlug.toLowerCase()) {
        return category.name;
      }
    }
    return null;
  }

  Future<void> _openAddressBook() async {
    final state = ref.read(homeViewModelProvider);
    if (state.defaultAddress == null) {
      final name = state.user?.name?.trim();
      final firstName = name != null && name.isNotEmpty
          ? name.split(RegExp(r'\s+')).first
          : null;
      await LocationOnboardingSheet.show(context, userName: firstName);
      if (mounted) {
        await ref.read(homeViewModelProvider.notifier).refresh();
      }
      return;
    }
    await context.pushSlideRight(const AddressListScreen());
    if (mounted) {
      await ref.read(homeViewModelProvider.notifier).refresh();
    }
  }

  Future<void> _openNotifications() async {
    await context.pushSlideRight(const NotificationsScreen());
    if (mounted) {
      await ref.read(homeViewModelProvider.notifier).loadHome();
    }
  }

  void _openCategories() {
    context.pushSlideRight(const CategoriesListScreen());
  }

  void _openCategory(HomeCategoryItem category) {
    // Guard against an empty name reaching the catalog — that previously
    // produced a blank white screen because the filter matched nothing
    // AND the empty state widget collapsed inside the sliver.
    final name = category.name.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This category is not available right now.')),
      );
      return;
    }
    // Use `pushSlideRight` so it matches the rest of the customer flow
    // (categories tab, product detail) — no platform default slide-up
    // flash that can look like a white screen mid-transition on Android.
    context.pushSlideRight(
      CategoryProductsScreen(
        categoryName: name,
        // Admin saves category id as a string ("1", "2", ...); parse to int
        // for the backend filter, but fall through (null) if it's a slug.
        categoryId: int.tryParse(category.id),
      ),
    );
  }

  Future<void> _openProduct(ProductWithVariants product) async {
    await _openProductId(product.product.id);
  }

  Future<void> _openProductId(String productId) async {
    await context.pushScale(ProductDetailScreen(productId: productId));
    if (mounted) {
      // Only refresh cart, not entire home - product data is already cached
      await ref.read(homeViewModelProvider.notifier).refreshCart();
    }
  }

  String _shortDeliveryAreaName(HomeState state) {
    // Capture everything to locals so the `address!.landmark!` bangs
    // disappear. Instance fields cannot be smart-cast in Dart, so the
    // old code was vulnerable to the websocket address-update event
    // nulling the field between the guard and the read → classic
    // "Null check operator used on a null value" crash on the header.
    final address = state.defaultAddress;
    if (address == null) return HomeStrings.selectLocation;

    final landmark = address.landmark?.trim() ?? '';
    if (landmark.isNotEmpty) {
      return landmark.length <= 20 ? landmark : '${landmark.substring(0, 20)}...';
    }

    final addr1 = address.addressLine1.trim();
    if (addr1.isNotEmpty) {
      final firstSeg = addr1.split(',').first.trim();
      return firstSeg.length <= 20
          ? firstSeg
          : '${firstSeg.substring(0, 20)}...';
    }

    final city = address.city.trim();
    final fallback = city.isNotEmpty ? city : HomeStrings.selectLocation;
    return fallback.length <= 20 ? fallback : '${fallback.substring(0, 20)}...';
  }

  String _profileInitial(HomeState state) {
    final name = state.user?.name?.trim() ?? '';
    return name.isEmpty ? 'M' : name.substring(0, 1).toUpperCase();
  }
}
