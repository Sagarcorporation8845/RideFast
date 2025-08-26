import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _selectedGender;
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF27b4ad), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF27b4ad), // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  // New function to save user data locally
  Future<void> _saveUserDataLocally(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    // We store the user data as a JSON string
    await prefs.setString('user_profile', jsonEncode(userData));
  }

  void _saveProfile() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final dio = Dio();
    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');

    try {
      final response = await dio.put(
        '$apiUrl/profile/update',
        data: {
          'fullName': _fullNameController.text,
          'email': _emailController.text,
          'dob': _dateOfBirth!.toIso8601String().split('T').first, // Format as YYYY-MM-DD
          'gender': _selectedGender,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        // Save the returned user profile data locally
        await _saveUserDataLocally(response.data['user']);
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      }

    } on DioException catch (e) {
      // **THE FIX IS HERE**: This logic now correctly handles different
      // types of error responses from the backend without crashing.
      String errorMessage = 'An unknown error occurred. Please try again.';
      if (e.response != null && e.response?.data is Map) {
        // This handles the JSON error from your backend dev
        // e.g., { "message": "Email already exists" }
        errorMessage = e.response?.data['message'] ?? 'Failed to update profile.';
      } else if (e.response != null) {
        // This handles cases where the error is not a JSON object
        errorMessage = 'Error: ${e.response?.statusCode} - ${e.response?.statusMessage}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
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
    final inputDecorationTheme = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF27b4ad), width: 2),
      ),
      labelStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[700]),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Your Profile', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false, // No back button
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                "Let's get you set up!",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please fill in the details below to continue.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: const Color(0xFF4A5568),
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _fullNameController,
                decoration: inputDecorationTheme.copyWith(labelText: 'Full Name'),
                validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: inputDecorationTheme.copyWith(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your email';
                  if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) return 'Please enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: inputDecorationTheme.copyWith(labelText: 'Gender'),
                items: ['Male', 'Female', 'Other'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (newValue) => setState(() => _selectedGender = newValue),
                validator: (value) => value == null ? 'Please select your gender' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                readOnly: true,
                decoration: inputDecorationTheme.copyWith(
                  labelText: 'Date of Birth',
                  suffixIcon: Icon(Icons.calendar_today, color: Colors.grey[600]),
                ),
                onTap: () => _selectDate(context),
                controller: TextEditingController(
                  text: _dateOfBirth == null ? '' : "${_dateOfBirth!.toLocal()}".split(' ')[0],
                ),
                validator: (value) => _dateOfBirth == null ? 'Please select your date of birth' : null,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27b4ad),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Save and Continue', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
