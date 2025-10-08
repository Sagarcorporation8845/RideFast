import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ridefast/screens/dashboard_screen.dart';
import 'package:ridefast/screens/ride_completed_screen.dart';
import 'package:ridefast/screens/ride_on_the_way_screen.dart';
import 'package:ridefast/screens/location_search_screen.dart';
import 'package:ridefast/screens/onboarding_screen.dart';
import 'package:ridefast/screens/otp_screen.dart';
import 'package:ridefast/screens/sign_in_screen.dart';
import 'package:ridefast/screens/splash_screen.dart';
import 'package:ridefast/screens/your_rides_screen.dart';
import 'package:ridefast/screens/your_parcels_screen.dart';
import 'package:ridefast/screens/scheduled_bookings_screen.dart';
import 'package:ridefast/screens/support_screen.dart';
import 'package:ridefast/screens/settings_screen.dart';
import 'package:ridefast/screens/about_us_screen.dart';
import 'package:ridefast/screens/profile_completion_screen.dart';
import 'package:ridefast/screens/edit_profile_screen.dart';
import 'package:ridefast/services/local_notification_service.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize our new local notification service
  await LocalNotificationService().initialize();
  // Load environment variables from the .env file
  await dotenv.load(fileName: ".env");
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideFast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF27b4ad)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/signin': (context) => const SignInScreen(),
        '/otp': (context) => const OTPScreen(),
        '/complete-profile': (context) => const ProfileCompletionScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/search': (context) => const LocationSearchScreen(),
        '/rides': (context) => const YourRidesScreen(),
        '/parcels': (context) => const YourParcelsScreen(),
        '/scheduled': (context) => const ScheduledBookingsScreen(),
        '/support': (context) => const SupportScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/about': (context) => const AboutUsScreen(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/ride-on-the-way': (context) => const RideOnTheWayScreen(),
        '/ride-completed': (context) => const RideCompletedScreen(),
      },
    );
  }
}