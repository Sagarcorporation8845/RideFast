import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotificationsEnabled = true;
  String? _homeAddress;
  String? _workAddress;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _homeAddress = prefs.getString('home_address');
      _workAddress = prefs.getString('work_address');
    });
  }

  Future<LatLng?> _getCoordinatesFromAddress(String address) async {
    final dio = Dio();
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$apiKey';

    try {
      final response = await dio.get(url);
      if (response.data['status'] == 'OK') {
        final location = response.data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      }
    } catch (e) {
      print('Error geocoding address: $e');
    }
    return null;
  }

  Future<void> _saveLocation(String type) async {
    // 1. Open location search screen
    final selectedAddress = await Navigator.of(context).pushNamed('/search');

    if (selectedAddress is String && selectedAddress.isNotEmpty) {
      // 2. Get coordinates for the selected address
      final coordinates = await _getCoordinatesFromAddress(selectedAddress);

      if (coordinates == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find location. Please try another address.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // 3. Call the API to save the location
      final dio = Dio();
      final apiUrl = dotenv.env['API_URL'];
      final token = await _storage.read(key: 'auth_token');

      try {
        final response = await dio.put(
          '$apiUrl/user-service/locations/save',
          data: {
            'type': type.toLowerCase(),
            'address': selectedAddress,
            'latitude': coordinates.latitude,
            'longitude': coordinates.longitude,
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );

        if (response.statusCode == 200) {
          // 4. Save locally and update UI
          final prefs = await SharedPreferences.getInstance();
          if (type == 'Home') {
            await prefs.setString('home_address', selectedAddress);
            setState(() => _homeAddress = selectedAddress);
          } else {
            await prefs.setString('work_address', selectedAddress);
            setState(() => _workAddress = selectedAddress);
          }
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$type location saved!'), backgroundColor: Colors.green),
            );
          }
        }
      } on DioException catch (e) {
         final errorMessage = e.response?.data['message'] ?? 'Failed to save location.';
         if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
            );
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Profile'),
          _buildSettingsTile(
            context,
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Change your name, phone number, email',
            onTap: () => Navigator.of(context).pushNamed('/edit-profile'),
          ),
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            title: Text(
              'Push Notifications',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Receive updates about your rides and promotions',
              style: GoogleFonts.plusJakartaSans(),
            ),
            secondary: const Icon(Icons.notifications_outlined),
            value: _pushNotificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _pushNotificationsEnabled = value;
              });
            },
            activeColor: const Color(0xFF27b4ad),
          ),
          _buildSectionHeader('Saved Places'),
          _buildSettingsTile(
            context,
            icon: Icons.home_outlined,
            title: 'Home',
            subtitle: _homeAddress ?? 'Add or edit your home address',
            onTap: () => _saveLocation('Home'),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.work_outline,
            title: 'Work',
            subtitle: _workAddress ?? 'Add or edit your work address',
            onTap: () => _saveLocation('Work'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: Colors.grey[600],
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 28),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
