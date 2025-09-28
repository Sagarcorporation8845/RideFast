import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _selectedGender;
  bool _isLoading = false;
  bool _isFetching = true; // New state to track initial data fetch
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchAndLoadUserProfile();
  }

  // **THE FIX IS HERE**: This function now calls the GET /profile API
  Future<void> _fetchAndLoadUserProfile() async {
    setState(() {
      _isFetching = true;
    });

    final dio = Dio();
    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');

    try {
      final response = await dio.get(
        '$apiUrl/user-service/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final userData = response.data['user'];
        // Save the latest profile data locally
        await _saveUserDataLocally(userData);

        // Populate the form fields with the fetched data
        _fullNameController.text = userData['full_name'] ?? '';
        _emailController.text = userData['email'] ?? '';
        _selectedGender = userData['gender'];
        if (userData['date_of_birth'] != null) {
          _dateOfBirth = DateTime.parse(userData['date_of_birth']);
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.response?.data['message'] ?? 'Failed to load profile.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

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
              primary: Color(0xFF27b4ad),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF27b4ad),
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

  Future<void> _saveUserDataLocally(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(userData));
  }

  void _updateProfile() async {
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
        '$apiUrl/user-service/profile/update',
        data: {
          'fullName': _fullNameController.text,
          'email': _emailController.text,
          'dob': _dateOfBirth!.toIso8601String().split('T').first,
          'gender': _selectedGender,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        await _saveUserDataLocally(response.data['user']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(); // Go back to settings screen
        }
      }
    } on DioException catch (e) {
      String errorMessage = 'An unknown error occurred.';
      if (e.response != null && e.response?.data is Map) {
        errorMessage = e.response?.data['message'] ?? 'Failed to update profile.';
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
        title: Text('Edit Profile', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27b4ad),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text('Save Changes', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
