import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // **CHANGED**: Navigate to the onboarding screen after 6 seconds
    Timer(const Duration(seconds: 6), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1BC0BA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // **CHANGED**: Replaced SVG with your GIF asset
            Image.asset(
              'assets/images/riding.gif',
              width: 300, // You can adjust the size as needed
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