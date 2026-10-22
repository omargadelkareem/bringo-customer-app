import 'package:bringo/features/categories/restaurant_details_screen.dart';
import 'package:bringo/features/categories/resturants_screen.dart';
import 'package:bringo/features/home/home_screen.dart';
import 'package:bringo/features/orders/order_tracking_screen.dart';
import 'package:bringo/features/supermarket/supermarket_screen.dart';
import 'package:go_router/go_router.dart';

import '../../features/Main/main_layout_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/products/category_products_screen.dart';
import '../../features/products/product_details_screen.dart';
import '../../features/splash/splash_screen.dart';
import 'app_routes.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.restaurants,
        builder: (context, state) => const RestaurantsScreen(),
      ),
      GoRoute(
        path: AppRoutes.restaurantDetails,
        builder: (context, state) {
          final restaurant = state.extra as Map<String, dynamic>;
          return RestaurantDetailsScreen(restaurant: restaurant);
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.productDetails,
        builder: (context, state) {
          final product = state.extra as Map<String, dynamic>;

          return ProductDetailsScreen(product: product);
        },
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) {
          final items = state.extra as List<Map<String, dynamic>>? ?? [];

          return CartScreen(cartItems: items);
        },
      ),
      GoRoute(
        path: AppRoutes.orderTracking,
        builder: (context, state) {
          final orderId = state.extra as String;

          return OrderTrackingScreen(
            orderId: orderId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.supermarket,
        builder: (context, state) {
          return const SupermarketScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.mainLayout,
        builder: (context, state) => const MainLayoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.categoryProducts,
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;

          return CategoryProductsScreen(
            categoryId: data['categoryId'],
            categoryName: data['categoryName'],
          );
        },
      ),
    ],
  );
}
