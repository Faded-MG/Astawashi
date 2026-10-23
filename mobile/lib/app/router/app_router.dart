import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/customers/presentation/add_customer_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/dashboard/presentation/home_dashboard_screen.dart';
import '../../features/ledger/presentation/ledger_screen.dart';
import '../../features/ledger/presentation/new_credit_sale_sheet.dart';
import '../../features/ledger/presentation/record_repayment_sheet.dart';
import '../../features/settings/presentation/more_screen.dart';
import '../widgets/app_scaffold.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({String initialLocation = '/splash'}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const HomeDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customers',
                builder: (context, state) => const CustomersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ledger',
                builder: (context, state) => const LedgerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customers/new',
        builder: (context, state) => const AddCustomerScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customers/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CustomerDetailScreen(customerId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/credit/new',
        builder: (context, state) {
          final customerId = state.uri.queryParameters['customerId'];
          return NewCreditSaleScreen(initialCustomerId: customerId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/repayment/new',
        builder: (context, state) {
          final customerId = state.uri.queryParameters['customerId'];
          return RecordRepaymentScreen(initialCustomerId: customerId);
        },
      ),
    ],
  );
}
