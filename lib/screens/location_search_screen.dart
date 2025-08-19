import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  final String? _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
  final Location _locationService = Location();

  void _onSearchChanged(String input) async {
    if (input.isEmpty || _apiKey == null) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    // Coordinates for Pune, Maharashtra to bias the search results
    const puneLocation = '18.5204,73.8567';
    const radius = '50000'; // 50km radius

    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_apiKey&sessiontoken=1234567890&components=country:in&location=$puneLocation&radius=$radius&strictbounds=true';

    try {
      Response response = await _dio.get(url);
      setState(() {
        _predictions = response.data['predictions'];
      });
    } catch (e) {
      print('Error fetching places: $e');
    }
  }
  
  // New function to get current location and reverse geocode it
  Future<void> _useCurrentLocation() async {
    try {
      final locationData = await _locationService.getLocation();
      final lat = locationData.latitude;
      final lng = locationData.longitude;

      if (lat == null || lng == null || _apiKey == null) return;
      
      String url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey';

      Response response = await _dio.get(url);
      if (response.data['results'] != null && response.data['results'].isNotEmpty) {
        final String formattedAddress = response.data['results'][0]['formatted_address'];
        if (mounted) {
          Navigator.of(context).pop(formattedAddress);
        }
      }
    } catch (e) {
      print('Error getting current location address: $e');
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
          // New "Use current location" button
          ListTile(
            leading: const Icon(Icons.my_location, color: Color(0xFF27b4ad)),
            title: Text(
              'Use current location',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF27b4ad)
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