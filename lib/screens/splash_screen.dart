import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    // Start the process to check login status after a short delay
    Timer(const Duration(seconds: 3), _checkAuthStatus);
  }

  Future<void> _checkAuthStatus() async {
    // Check for a valid authentication token
    final String? token = await _storage.read(key: 'auth_token');

    if (mounted) {
      if (token != null) {
        // If token exists, user is logged in. Go to Dashboard.
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        // If no token, check if user has seen onboarding before.
        final prefs = await SharedPreferences.getInstance();
        final bool hasSeenOnboarding = prefs.getBool('onboarding_complete') ?? false;

        if (hasSeenOnboarding) {
          // If they've seen onboarding, go straight to sign-in.
          Navigator.of(context).pushReplacementNamed('/signin');
        } else {
          // If it's their first time, show onboarding.
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1BC0BA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/riding.gif',
              width: 300,
              height: 300,
            ),
            const SizedBox(height: 16),
            Text(
              'RideFast',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 50,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
