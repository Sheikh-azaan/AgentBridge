import 'package:go_router/go_router.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/registry/registry_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/audit/audit_screen.dart';
import 'screens/rules/rules_screen.dart';
import 'screens/rules/add_rule_screen.dart';
import 'screens/demo/shopping_demo_screen.dart';
import 'screens/demo/delivery_demo_screen.dart';
import 'screens/inspector/inspector_screen.dart';
import 'screens/settings/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
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
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/agents',
      builder: (context, state) => const RegistryScreen(),
    ),
    GoRoute(
      path: '/messages',
      builder: (context, state) => const MessagesScreen(),
    ),
    GoRoute(
      path: '/audit',
      builder: (context, state) => const AuditScreen(),
    ),
    GoRoute(
      path: '/rules',
      builder: (context, state) => const RulesScreen(),
    ),
    GoRoute(
      path: '/rules/add',
      builder: (context, state) => const AddRuleScreen(),
    ),
    GoRoute(
      path: '/demo',
      builder: (context, state) => const ShoppingDemoScreen(),
    ),
    GoRoute(
      path: '/delivery',
      builder: (context, state) => const DeliveryDemoScreen(),
    ),
    GoRoute(
      path: '/inspector',
      builder: (context, state) {
        final message = state.extra as Map<String, dynamic>?;
        final messageId = state.uri.queryParameters['id'];
        return InspectorScreen(initialMessage: message, messageId: messageId);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
