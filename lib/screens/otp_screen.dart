import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final pinController = TextEditingController();
  final focusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();

  @override
  void dispose() {
    pinController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  // **NEW**: Helper function to save user data locally
  Future<void> _saveUserDataLocally(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    // The key from your backend for the user's name is 'fullName'
    // We will ensure it's mapped to 'full_name' for consistency with the profile update screen
    final Map<String, dynamic> formattedUserData = {
      'full_name': userData['fullName'],
      // Add other fields here if needed
    };
    await prefs.setString('user_profile', jsonEncode(formattedUserData));
  }

  void _verifyOtp(Map<String, String> args) async {
    // Hide keyboard
    focusNode.unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final dio = Dio();
    final apiUrl = dotenv.env['API_URL'];

    try {
      final response = await dio.post(
        '$apiUrl/auth/verify-otp',
        data: {
          'countryCode': args['countryCode'],
          'phoneNumber': args['phoneNumber'],
          'otp': pinController.text,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        final isProfileComplete = response.data['isProfileComplete'] ?? false;
        final user = response.data['user']; // Get the user object from the response

        // Securely store the token
        await _storage.write(key: 'auth_token', value: token);

        if (mounted) {
          if (isProfileComplete) {
            // **THE FIX IS HERE**: If the profile is complete, we save the
            // user data we just received from the login response.
            if (user != null) {
              await _saveUserDataLocally(user);
            }
            Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil('/complete-profile', (route) => false);
          }
        }
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'An unknown error occurred.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, String>;
    final String fullPhoneNumber = arguments['fullPhoneNumber'] ?? 'your number';

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        color: const Color(0xFF1A202C),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Verify your number',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      color: const Color(0xFF718096),
                    ),
                    children: [
                      const TextSpan(text: 'Enter the 4-digit code sent to '),
                      TextSpan(
                        text: fullPhoneNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A202C),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Pinput(
                  controller: pinController,
                  focusNode: focusNode,
                  length: 4,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: const Color(0xFF27b4ad)),
                    ),
                  ),
                  submittedPinTheme: defaultPinTheme,
                  pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                  showCursor: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the OTP';
                    }
                    if (value.length != 4) {
                      return 'OTP must be 4 digits';
                    }
                    return null;
                  },
                  onCompleted: (pin) => _verifyOtp(arguments),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _verifyOtp(arguments),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27b4ad),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            'Verify',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    // TODO: Implement Resend OTP logic
                    print('Resend OTP');
                  },
                  child: Text(
                    "Didn't receive the code? Resend",
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF27b4ad),
                      fontWeight: FontWeight.bold,
                    ),
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
