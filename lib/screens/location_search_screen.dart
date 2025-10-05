import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:location/location.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final Dio _dio = Dio();
  List<dynamic> _predictions = [];
  final Location _locationService = Location();
  final _storage = const FlutterSecureStorage();
  String _sessionToken = "";
  LocationData? _currentLocation; // **NEW**: To store user's location

  @override
  void initState() {
    super.initState();
    _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
    _getCurrentLocation(); // **NEW**: Get location when the screen loads
  }

  // **NEW**: Helper function to get the user's current location
  Future<void> _getCurrentLocation() async {
    try {
      _currentLocation = await _locationService.getLocation();
    } catch (e) {
      debugPrint("Could not get current location for search bias: $e");
      // Silently fail, search will still work but without location bias
    }
  }

  Future<void> _onSearchChanged(String input) async {
    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');
    if (input.isEmpty || apiUrl == null || token == null) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    final url = '$apiUrl/maps-service/maps/places/autocomplete';

    // **FIX**: Prepare the query parameters, including lat/lng if available
    final queryParameters = <String, dynamic>{
      'input': input,
      'sessiontoken': _sessionToken,
    };

    if (_currentLocation != null) {
      queryParameters['lat'] = _currentLocation!.latitude;
      queryParameters['lng'] = _currentLocation!.longitude;
    }

    try {
      Response response = await _dio.get(
        url,
        queryParameters: queryParameters, // Pass the parameters map
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() {
          _predictions = response.data['predictions'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching places: $e');
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final locationData = await _locationService.getLocation();
      final lat = locationData.latitude;
      final lng = locationData.longitude;

      final apiUrl = dotenv.env['API_URL'];
      final token = await _storage.read(key: 'auth_token');

      if (lat == null || lng == null || apiUrl == null || token == null) return;
      
      final url = '$apiUrl/maps-service/maps/geocode/reverse';

      Response response = await _dio.get(
        url,
        queryParameters: {'lat': lat, 'lng': lng},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.data['results'] != null && response.data['results'].isNotEmpty) {
        final String formattedAddress = response.data['results'][0]['formatted_address'];
        if (mounted) {
          Navigator.of(context).pop(formattedAddress);
        }
      }
    } catch (e) {
      debugPrint('Error getting current location address: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Choose Location',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search for a location...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.my_location, color: Color(0xFF27b4ad)),
            title: Text(
              'Use current location',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF27b4ad),
              ),
            ),
            onTap: _useCurrentLocation,
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(_predictions[index]['structured_formatting']['main_text']),
                  subtitle: Text(_predictions[index]['structured_formatting']['secondary_text']),
                  onTap: () {
                    _sessionToken = DateTime.now().millisecondsSinceEpoch.toString(); 
                    Navigator.of(context).pop(_predictions[index]['description']);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}