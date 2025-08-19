import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

// Changed to a StatefulWidget to manage the input controller
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+91';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onContinue() {
    final fullPhoneNumber = '$_selectedCountryCode ${_phoneController.text}';
    // TODO: Add logic to send OTP to the phone number
    print('Sending OTP to: $fullPhoneNumber');

    // Navigate to the OTP screen, passing the phone number as an argument
    Navigator.of(context).pushNamed('/otp', arguments: fullPhoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Title
                Text(
                  'RideFast',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 40),

                // Card with input fields and buttons
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 5,
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter your mobile number',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF718096),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Phone number input
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFFE2E8F0)),
                                left: BorderSide(color: Color(0xFFE2E8F0)),
                                bottom: BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCountryCode,
                                items: ['+91', '+1', '+44'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedCountryCode = newValue;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController, // Added controller
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: 'Mobile Number',
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF27b4ad)),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Continue Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _onContinue, // Updated onPressed
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27b4ad),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            'Continue',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Terms of Service Text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text.rich(
                          TextSpan(
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF718096),
                            ),
                            children: const [
                              TextSpan(text: 'By continuing, you agree to our '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  color: Color(0xFF27b4ad),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: Color(0xFF27b4ad),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Divider
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('Or continue with', style: TextStyle(color: Colors.grey)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Social Logins
                      SocialLoginButton(
                        label: 'Continue with Google',
                        svgAsset: 'assets/images/google_logo.svg',
                        onPressed: () {},
                      ),
                      const SizedBox(height: 16),
                      SocialLoginButton(
                        label: 'Continue with Apple',
                        svgAsset: 'assets/images/apple_logo.svg',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A reusable button for social logins
class SocialLoginButton extends StatelessWidget {
  final String label;
  final String svgAsset;
  final VoidCallback onPressed;

  // Placeholder SVG data for Google logo
  static const String googleLogoSvg = '''
  <svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M22.56,12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26,1.37-1.04,2.53-2.21,3.31v2.77h3.57c2.08-1.92,3.28-4.74,3.28-8.09Z" fill="#4285F4"></path><path d="M12,23c2.97,0,5.46-.98,7.28-2.66l-3.57-2.77c-.98.66-2.23,1.06-3.71,1.06-2.86,0-5.29-1.93-6.16-4.53H2.18v2.84C3.99,20.53,7.7,23,12,23Z" fill="#34A853"></path><path d="M5.84,14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43,8.55,1,10.22,1,12s.43,3.45,1.18,4.93l3.66-2.84Z" fill="#FBBC05"></path><path d="M12,5.16c1.55,0,2.95.53,4.04,1.58l3.15-3.15C17.45,1.99,14.97,1,12,1,7.7,1,3.99,3.47,2.18,7.07l3.66,2.84c.87-2.6,3.3-4.53,6.16-4.53Z" fill="#EA4335"></path></svg>
  ''';

  // Placeholder SVG data for Apple logo
  static const String appleLogoSvg = '''
  <svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M17.2,12.01c0-1.25-0.34-2.2-1.03-2.88c-0.69-0.68-1.7-1.03-3.05-1.03c-1.63,0-2.95,0.52-3.95,1.55c-1.01,1.04-1.51,2.44-1.51,4.2c0,1.3,0.24,2.39,0.72,3.25c0.48,0.86,1.15,1.5,2.01,1.93c0.86,0.43,1.75,0.64,2.68,0.64c1.17,0,2.3-0.37,3.39-1.12l-1.35-1.44c-0.71,0.58-1.5,0.87-2.38,0.87c-0.6,0-1.11-0.16-1.55-0.47c-0.44-0.31-0.78-0.77-1.02-1.36c-0.24-0.59-0.36-1.28-0.36-2.07c0-0.89,0.2-1.63,0.59-2.22c0.39-0.59,0.94-0.89,1.64-0.89c0.55,0,1.02,0.16,1.4,0.49c0.38,0.32,0.66,0.77,0.83,1.34h-2.22v1.89h3.76C17.18,13.16,17.2,12.59,17.2,12.01z M20.94,6.45c-0.24-0.71-0.52-1.37-0.85-1.99c-0.33-0.61-0.7-1.16-1.13-1.64c-0.43-0.48-0.9-0.88-1.42-1.21c-0.52-0.33-1.06-0.58-1.63-0.74c-0.57-0.16-1.15-0.24-1.72-0.24c-0.61,0-1.2,0.09-1.78,0.26c-1.13,0.34-2.11,0.9-2.94,1.68c-0.83,0.78-1.47,1.72-1.93,2.83c-0.46,1.1-0.69,2.3-0.69,3.58c0,1.1,0.18,2.15,0.54,3.15c0.36,1,0.88,1.87,1.57,2.63c0.69,0.76,1.51,1.36,2.46,1.79c0.95,0.43,2.03,0.65,3.22,0.65c0.75,0,1.49-0.13,2.23-0.38c0.74-0.25,1.44-0.61,2.09-1.08c0.65-0.47,1.22-1.03,1.7-1.67c0.48-0.64,0.86-1.36,1.14-2.14c0.28-0.78,0.42-1.6,0.42-2.45C21.6,8.44,21.36,7.45,20.94,6.45z"></path></svg>
  ''';

  const SocialLoginButton({
    super.key,
    required this.label,
    required this.svgAsset,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Determine which SVG data to use based on the label
    final String svgData = label.contains('Google') ? googleLogoSvg : appleLogoSvg;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: SvgPicture.string(svgData, width: 20, height: 20),
        onPressed: onPressed,
        label: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A202C),
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFFF8FAFC),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}