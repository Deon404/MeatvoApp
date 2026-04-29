import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/phone_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/checkout/address_screen.dart';
import '../screens/checkout/order_success_screen.dart';
import '../screens/checkout/payment_screen.dart';
import '../screens/checkout/review_screen.dart';
import '../screens/home/category_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/product_detail_screen.dart';
import '../screens/home/product_list_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/orders/order_history_screen.dart';
import '../screens/orders/order_tracking_screen.dart';
import '../screens/profile/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = auth.isAuthenticated;
      final path = state.uri.path;
      final isAuthRoute = path == '/login' || path == '/otp' || path == '/splash';

      if (auth.isLoading) return null;
      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const PhoneScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = (state.extra ?? '').toString();
          return OtpScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductListScreen(),
      ),
      GoRoute(
        path: '/products/:categoryId',
        builder: (context, state) {
          final categoryId = int.tryParse(state.pathParameters['categoryId'] ?? '') ?? 0;
          final categoryName = (state.extra ?? 'Category').toString();
          return CategoryScreen(categoryId: categoryId, title: categoryName);
        },
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final productId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ProductDetailScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/checkout/address',
        builder: (context, state) => const AddressScreen(),
      ),
      GoRoute(
        path: '/checkout/review',
        builder: (context, state) => const ReviewScreen(),
      ),
      GoRoute(
        path: '/checkout/payment',
        builder: (context, state) => const PaymentScreen(),
      ),
      GoRoute(
        path: '/checkout/success',
        builder: (context, state) {
          final orderId = (state.extra ?? '').toString();
          return OrderSuccessScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrderHistoryScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) {
          final orderId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return OrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/orders/:id/tracking',
        builder: (context, state) {
          final orderId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});
