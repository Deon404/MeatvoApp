abstract final class HomeStrings {
  static const deliveryLabel = 'Delivering to';
  static const selectLocation = 'Select location';
  static const heroTagline = 'Fresh meat and eggs, delivered fast';
  static const searchHint = 'Search chicken, eggs...';

  static const quickCategoriesTitle = 'Quick categories';
  static const categoriesTitle = 'Categories';
  static const recommendedTitle = 'Recommended for You';
  static const popularTitle = 'Popular';
  static const featuredTitle = 'Featured Products';
  static const freshEggsTitle = 'Fresh Eggs';
  static const whyMeatvoTitle = 'Why Meatvo';
  static const viewAllLabel = 'View All';
  static const retryLabel = 'Retry';
  static const browseCategoriesLabel = 'Browse categories';
  static const browseCatalogLabel = 'Browse catalog';

  static const homeLoadErrorTitle = 'Unable to load home';
  static const genericHomeLoadError =
      'Please pull to refresh or try again.';
  static const connectionLostTitle = "You're offline right now";
  static const connectionLostMessage =
      "We'll reconnect automatically";
  static const offlineTitle = "You're offline right now";
  static const offlineSubtitle = "We'll reconnect automatically";
  static const offlineBanner = 'Offline mode · We\'ll reconnect automatically';
  static const categoriesLoadError = 'Categories could not be loaded.';
  static const recommendationsLoadError =
      'Recommendations could not be loaded.';
  static const featuredLoadError = 'Featured products could not be loaded.';
  static const allProductsLoadError = 'Products could not be loaded.';
  static const popularLoadError = 'Popular products could not be loaded.';

  static const noCategoriesTitle = 'No categories available';
  static const noCategoriesMessage =
      'Try refreshing or browse the full catalog.';
  static const noRecommendationsTitle = 'No recommendations yet';
  static const noRecommendationsMessage =
      'Browse categories to discover fresh picks for today.';
  static const noFeaturedTitle = 'No featured products yet';
  static const noFeaturedMessage =
      'Fresh featured cuts will show up here as soon as they are available.';
  static const noPopularTitle = 'No popular products yet';
  static const noPopularMessage =
      'Explore the catalog and check back for popular picks.';

  static const bannerLinkUnavailable =
      'This banner link is not available in the app yet.';
  static const locationLoadingMessage = 'Getting your location...';
  static const locationSavedMessage = 'Delivery address set successfully!';

  static String cartUpdateFailed(Object error) =>
      'Could not update your cart. Please try again.';

  static String locationFetchFailed(Object error) =>
      'Could not find your location. Please try again.';
}
