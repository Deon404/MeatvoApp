import 'backend_resolver.dart';
import 'env_config.dart';

String get kBaseUrl => ApiConfig.baseUrl;

abstract final class ApiAuthPaths {
  static String get sendOtp => EnvConfig.apiAuthSendOtpPath;

  static String get verifyOtp => EnvConfig.apiAuthVerifyOtpPath;

  static String get refresh => EnvConfig.apiAuthRefreshPath;

  static String get refreshToken => EnvConfig.apiAuthRefreshTokenPath;

  static const logout = '/auth/logout';
  static const me = '/auth/me';
  static const mfaVerify = '/auth/mfa/verify';
}

abstract final class ApiProductPaths {
  static const products = '/products';
  static const featured = '/products/featured';
  static const productById = '/products/';
  static const categories = '/categories';
  static const banners = '/banners';
  static const search = '/products/search';
}

abstract final class ApiCartPaths {
  static const cart = '/cart';
  static const count = '/cart/count';
  static const cartItem = '/cart/';
}

abstract final class ApiOrderPaths {
  static const orders = '/orders';
  static const myOrders = '/orders/my';
  static const applyCoupon = '/orders/apply-coupon';
  static const orderById = '/orders/';
  static const cancelOrder = '/orders/';
  static String deliveryOtp(String id) => '/orders/enhanced/$id/delivery-otp';
}

abstract final class ApiCouponPaths {
  static const validate = '/coupons/validate';
  static const coupons = '/coupons';
}

abstract final class ApiPaymentPaths {
  static const initiate = '/payments/initiate';
  static const verify = '/payments/verify';
  static const status = '/payments/status';
}

abstract final class ApiDeliveryPaths {
  static const slots = '/delivery/slots';
  static const orders = '/delivery/orders';
  static const profile = '/delivery/me';
  static const earnings = '/delivery/earnings';
  static const updateProfile = '/delivery/profile';
  static const toggleOnline = '/delivery/online';
  static const location = '/delivery/location';
  static const uploadProof = '/delivery/upload/proof';
  /// Live rider accept — legacy delivery route (PACKED → OUT_FOR_DELIVERY).
  static String orderAccept(String id) => '/delivery/orders/$id/accept';
  static String orderReject(String id) => '/delivery/orders/$id/reject';
  static String orderFailedDelivery(String id) => '/delivery/orders/$id/failed-delivery';
  static String orderReturnToStore(String id) => '/delivery/orders/$id/return-to-store';
  static String orderOperationalException(String id) =>
      '/delivery/orders/$id/operational-exception';
  static String orderStatus(String id) => '/delivery/orders/$id/status';
  static const bulkAssign = '/delivery/orders/bulk-assign';
}

abstract final class ApiUserPaths {
  static const addresses = '/addresses';
  static const profile = '/users/profile';
  static const notifications = '/users/notifications';
  static const wishlist = '/users/wishlist';
  static const reviews = '/users/reviews';
  static String reviewForOrder(String orderId) => '/users/reviews/order/$orderId';
  static String productRating(String id) => '/products/$id/rating';
}

abstract final class ApiAdminPaths {
  static const dashboard = '/admin/dashboard';
  static const orders = '/admin/orders';
  static const products = '/admin/products';
  static const categories = '/admin/categories';
  static const banners = '/admin/banners';
  static const settings = '/admin/settings';
  static const users = '/admin/users';
  static const deliveryPartners = '/admin/delivery-partners';
  static const uploadImage = '/admin/upload/image';
  static const deliveryRouteOptimize = '/admin/delivery/route/optimize';
  static const deliveryAssignRoutes = '/admin/delivery/assign-routes';
  static const coupons = '/admin/coupons';
  static const analytics = '/admin/analytics';
  static const opsMetrics = '/admin/ops-metrics';

  static String couponById(int id) => '/admin/coupons/$id';

  static String userById(String id) => '/admin/users/$id';
  static String userStatus(String id) => '/admin/users/$id/status';
  static String userRole(String id) => '/admin/users/$id/role';
  static String deliveryPartnerById(String id) =>
      '/admin/delivery-partners/$id';
  static String resolveFailedDelivery(String orderId) =>
      '/admin/orders/$orderId/resolve-failed-delivery';
  static String resolveAssignmentFailure(String orderId) =>
      '/admin/orders/$orderId/resolve-assignment-failure';
  static const adminTasks = '/admin/tasks';
  static const operationalEvents = '/admin/operational-events';
  static const capacitySuggestion = '/admin/store/capacity-suggestion';
  static const capacitySuggestionDismiss = '/admin/store/capacity-suggestion/dismiss';

  static String orderTimeline(String orderId) => '/admin/orders/$orderId/timeline';
}

abstract final class ApiRiderPaths {
  static const orders = ApiDeliveryPaths.orders;
  static const profile = ApiDeliveryPaths.profile;
  static String orderStatus(String id) => ApiDeliveryPaths.orderStatus(id);
}

class ApiConfig {
  static const Duration connectTimeout = Duration(seconds: 12);
  static const Duration sendTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  /// Checkout POST /orders — allow extra time on slow mobile networks.
  static const Duration orderReceiveTimeout = Duration(seconds: 45);
  static const Duration orderSendTimeout = Duration(seconds: 20);
  static const Duration authTimeout = Duration(seconds: 15);
  static const int retryAttempts = 2;
  static const Duration cacheTtl = Duration(minutes: 2);
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration transitionDuration = Duration(milliseconds: 300);

  static String get _root => BackendResolver.root.replaceFirst(RegExp(r'/$'), '');
  static String get baseUrl => '$_root/api';
  static String get socketUrl => _root;
  static String get health => '$_root/health';

  static String get sendOtp => '$baseUrl${ApiAuthPaths.sendOtp}';
  static String get verifyOtp => '$baseUrl${ApiAuthPaths.verifyOtp}';
  static String get refresh => '$baseUrl${ApiAuthPaths.refresh}';
  static String get logout => '$baseUrl${ApiAuthPaths.logout}';
  static String get me => '$baseUrl${ApiAuthPaths.me}';

  static String get products => '$baseUrl${ApiProductPaths.products}';
  static String productById(String id) =>
      '$baseUrl${ApiProductPaths.productById}$id';
  static String get featuredProducts => '$baseUrl${ApiProductPaths.featured}';
  static String get categories => '$baseUrl${ApiProductPaths.categories}';
  static String get banners => '$baseUrl${ApiProductPaths.banners}';
  static String searchProducts(String query) =>
      '$baseUrl${ApiProductPaths.search}?q=${Uri.encodeQueryComponent(query)}';

  static String get cart => '$baseUrl${ApiCartPaths.cart}';
  static String cartItem(String itemId) =>
      '$baseUrl${ApiCartPaths.cartItem}$itemId';

  static String get orders => '$baseUrl${ApiOrderPaths.orders}';
  static String orderById(String id) => '$baseUrl${ApiOrderPaths.orderById}$id';
  static String cancelOrder(String id) =>
      '$baseUrl${ApiOrderPaths.cancelOrder}$id/cancel';

  static String get initiatePayment => '$baseUrl${ApiPaymentPaths.initiate}';
  static String get verifyPayment => '$baseUrl${ApiPaymentPaths.verify}';
  static String get paymentStatus => '$baseUrl${ApiPaymentPaths.status}';

  static String get deliverySlots => '$baseUrl${ApiDeliveryPaths.slots}';
  static String get deliveryOrders => '$baseUrl${ApiDeliveryPaths.orders}';
  static String get deliveryProfile => '$baseUrl${ApiDeliveryPaths.profile}';

  static String get addresses => '$baseUrl${ApiUserPaths.addresses}';
  static String addressById(String id) => '$baseUrl${ApiUserPaths.addresses}/$id';
  static String get profile => '$baseUrl${ApiUserPaths.profile}';
  static String get updateProfile => '$baseUrl${ApiUserPaths.profile}';

  static String get adminDashboard => '$baseUrl${ApiAdminPaths.dashboard}';
  static String get adminOrders => '$baseUrl${ApiAdminPaths.orders}';
  static String get adminProducts => '$baseUrl${ApiAdminPaths.products}';
  static String get adminUsers => '$baseUrl${ApiAdminPaths.users}';

  static String get keyAccessToken => EnvConfig.secureStorageAccessTokenKey;
  static String get keyRefreshToken => EnvConfig.secureStorageRefreshTokenKey;
  static String get keyUser => EnvConfig.secureStorageUserDataKey;
  static String get keyUserRole => EnvConfig.secureStorageUserRoleKey;
  static String get keyUserId => EnvConfig.secureStorageUserIdKey;
}
