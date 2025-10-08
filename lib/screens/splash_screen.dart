import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridefast/services/ride_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = const FlutterSecureStorage();
  final _rideStateService = RideStateService();

  @override
  void initState() {
    super.initState();
    // Check status after a short delay to show the splash screen
    Timer(const Duration(seconds: 2), _checkAuthAndRideStatus);
  }

  Future<void> _checkAuthAndRideStatus() async {
    if (!mounted) return;

    final String? token = await _storage.read(key: 'auth_token');

    if (token != null) {
      // User is logged in, check for an active ride
      final activeRide = await _rideStateService.loadRideState();

      if (activeRide != null) {
        final state = activeRide['state'];
        final data = activeRide['data'];

        // If a driver is assigned or has arrived, resume the ride screen
        if (state == RideState.driverAssigned.toString() || state == RideState.driverArrived.toString() || state == RideState.rideStarted.toString()) {
          Navigator.of(context).pushReplacementNamed('/ride-on-the-way', arguments: data);
          return;
        }
      }
      
      // No active ride, proceed to the dashboard
      Navigator.of(context).pushReplacementNamed('/dashboard');

    } else {
      // User is not logged in, proceed with the normal onboarding/sign-in flow
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenOnboarding = prefs.getBool('onboarding_complete') ?? false;

      if (hasSeenOnboarding) {
        Navigator.of(context).pushReplacementNamed('/signin');
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
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