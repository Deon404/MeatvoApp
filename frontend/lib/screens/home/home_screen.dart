import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/home_strings.dart';
import '../../features/connectivity/connectivity_provider.dart';
import '../../features/home/widgets/home_top_bar_delegate.dart';
import '../../models/banner_model.dart';
import '../../models/home_category_item.dart';
import '../../models/product_variant_model.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/product/product_detail_screen.dart';
import '../../ui/shells/meatvo_layout.dart';
import '../../ui/shells/offline_banner.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../utils/app_transitions.dart';
import '../../utils/responsive_helper.dart';
import '../../providers/store_settings_provider.dart';
import '../../viewmodels/home_provider.dart';
import '../../viewmodels/home_state.dart';
import '../../widgets/home/home_body.dart';
import '../../widgets/location/delivery_location_sheet.dart';
import '../../widgets/active_flow/active_flow_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenCartTab,
    required this.onOpenProfileTab,
    required this.onOpenCategoriesTab,
  });

  final VoidCallback onOpenCartTab;
  final VoidCallback onOpenProfileTab;
  final void Function({String? category, int? categoryId}) onOpenCategoriesTab;

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
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(storeSettingsProvider);
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
      backgroundColor: context.meatvo.surfaceWarm,
      body: SafeArea(
        top: false,
        bottom: true,
        child: ActiveFlowBackground(
          child: Stack(
            children: [
              RefreshIndicator(
                color: context.meatvo.brandAccent,
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
                        locationTitle: _locationTitle(state),
                        locationSubtitle: _locationSubtitle(state),
                        unreadCount: state.unreadNotificationCount,
                        onAddressTap: _openAddressBook,
                        onNotificationTap: _openNotifications,
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
                      onRetryAllProducts: () => ref
                          .read(homeViewModelProvider.notifier)
                          .fetchAllProducts(),
                      onBannerTap: _handleBannerTap,
                      onProductTap: _openProduct,
                      onQuantityChange: ref
                          .read(homeViewModelProvider.notifier)
                          .changeCartQuantity,
                      bottomPadding: bottomPad,
                      onChangeLocation: _openAddressBook,
                    ),
                  ],
                ),
              ),
              if (offline) const OfflineBanner(),
            ],
          ),
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
    await DeliveryLocationSheet.show(context);
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
    widget.onOpenCategoriesTab();
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
    widget.onOpenCategoriesTab(
      category: name,
      categoryId: int.tryParse(category.id),
    );
  }

  Future<void> _openProductId(
    String productId, {
    ProductWithVariants? initialProduct,
  }) async {
    await context.pushScale(
      ProductDetailScreen(
        productId: productId,
        initialProduct: initialProduct,
      ),
    );
    if (mounted) {
      await ref.read(homeViewModelProvider.notifier).refreshCart();
    }
  }

  Future<void> _openProduct(ProductWithVariants product) async {
    await _openProductId(
      product.product.id,
      initialProduct: product,
    );
  }

  String _locationTitle(HomeState state) {
    final address = state.defaultAddress;
    if (address == null) return HomeStrings.selectLocation;
    return _shortDeliveryAreaName(state);
  }

  String? _locationSubtitle(HomeState state) {
    final address = state.defaultAddress;
    if (address == null) return null;
    final line = address.fullAddress.trim();
    if (line.isEmpty) return null;
    return line.length <= 48 ? line : '${line.substring(0, 48)}...';
  }

  String _shortDeliveryAreaName(HomeState state) {
    final address = state.defaultAddress;
    if (address == null) return HomeStrings.selectLocation;

    final landmark = address.landmark?.trim() ?? '';
    if (landmark.isNotEmpty) {
      return landmark.length <= 20 ? landmark : '${landmark.substring(0, 20)}...';
    }

    final local = address.shortAddress.trim();
    if (local.isNotEmpty && local != 'Delivery address') {
      return local.length <= 20 ? local : '${local.substring(0, 20)}...';
    }

    return HomeStrings.selectLocation;
  }
}
