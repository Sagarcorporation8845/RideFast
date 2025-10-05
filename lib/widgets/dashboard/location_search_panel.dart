import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:location/location.dart';
import 'package:uuid/uuid.dart';

// A simple data model for a recent location
class RecentLocation {
  final IconData icon;
  final String address;
  final String description;

  RecentLocation({required this.icon, required this.address, required this.description});
}

class LocationSearchPanel extends StatefulWidget {
  final Function(String address) onLocationSelected;
  final VoidCallback onSelectOnMap;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onCancel;

  const LocationSearchPanel({
    super.key,
    required this.onLocationSelected,
    required this.onSelectOnMap,
    required this.onUseCurrentLocation,
    required this.onCancel,
  });

  @override
  State<LocationSearchPanel> createState() => _LocationSearchPanelState();
}

class _LocationSearchPanelState extends State<LocationSearchPanel> {
  final TextEditingController _controller = TextEditingController();
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();
  final _locationService = Location();
  final _uuid = const Uuid();
  
  List<dynamic> _predictions = [];
  String _sessionToken = "";
  LocationData? _currentLocation;

  // Placeholder for recent locations
  final List<RecentLocation> _recentLocations = [
    RecentLocation(icon: Icons.home_outlined, address: "Home", description: "Wadki, Maharashtra, India"),
    RecentLocation(icon: Icons.work_outline, address: "Work", description: "Pune Airport, Pune"),
  ];

  @override
  void initState() {
    super.initState();
    _sessionToken = _uuid.v4();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentLocation = await _locationService.getLocation();
    } catch (e) {
      debugPrint("Could not get current location for search bias: $e");
    }
  }

  Future<void> _onSearchChanged(String input) async {
    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');
    if (input.isEmpty || apiUrl == null || token == null) {
      setState(() => _predictions = []);
      return;
    }

    final url = '$apiUrl/maps-service/maps/places/autocomplete';
    final queryParameters = <String, dynamic>{
      'input': input, 'sessiontoken': _sessionToken
    };
    if (_currentLocation != null) {
      queryParameters['lat'] = _currentLocation!.latitude;
      queryParameters['lng'] = _currentLocation!.longitude;
    }

    try {
      final response = await _dio.get(url, queryParameters: queryParameters, options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (mounted) setState(() => _predictions = response.data['predictions']);
    } catch (e) {
      debugPrint('Error fetching places: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header with Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: widget.onCancel,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search for a location...',
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Content List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // --- Static Options ---
                    _buildOptionTile(
                      icon: Icons.my_location,
                      title: 'Use current location',
                      onTap: widget.onUseCurrentLocation,
                    ),
                    _buildOptionTile(
                      icon: Icons.map_outlined,
                      title: 'Select on map',
                      onTap: widget.onSelectOnMap,
                    ),
                    const Divider(height: 1),

                    // --- Search Results or Recent Locations ---
                    if (_controller.text.isNotEmpty)
                      ..._buildPredictionsList()
                    else
                      ..._buildRecentLocationsList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPredictionsList() {
    return _predictions.map((prediction) {
      return ListTile(
        leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
        title: Text(prediction['structured_formatting']['main_text']),
        subtitle: Text(prediction['structured_formatting']['secondary_text']),
        onTap: () {
          widget.onLocationSelected(prediction['description']);
        },
      );
    }).toList();
  }

  List<Widget> _buildRecentLocationsList() {
    return [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text('Recent Locations', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      ),
      ..._recentLocations.map((location) {
        return ListTile(
          leading: Icon(location.icon, color: Colors.grey),
          title: Text(location.address),
          subtitle: Text(location.description),
          onTap: () {
            widget.onLocationSelected(location.description);
          },
        );
      }).toList(),
    ];
  }

  Widget _buildOptionTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF27b4ad)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}
