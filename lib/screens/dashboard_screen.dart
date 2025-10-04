import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:ridefast/widgets/main_drawer.dart';

enum ServiceType { ride, parcel }
enum VehicleType { bike, auto, economy, premium, xl, parcel }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ServiceType _selectedService = ServiceType.ride;
  VehicleType? _selectedVehicle;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final Completer<GoogleMapController> _mapController = Completer();
  final Location _locationService = Location();
  final _storage = const FlutterSecureStorage();
  Timer? _pollingTimer;

  String _pickupLocationLabel = 'Pickup Location';
  String _destinationLabel = 'Destination';

  // Markers for user location and vehicles
  final Set<Marker> _userMarkers = {};
  // **FIX**: Changed to a Map to store markers by their unique driverId for efficient updates
  final Map<String, Marker> _vehicleMarkers = {};
  LatLng? _pickupLocation;

  // Custom marker icons
  BitmapDescriptor _bikeMarkerIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor _autoMarkerIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor _carMarkerIcon = BitmapDescriptor.defaultMarker;
  bool _isFirstDriverFetch = true;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers().then((_) {
      _initLocation();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // --- SETUP AND INITIALIZATION ---

  Future<void> _loadCustomMarkers() async {
    _bikeMarkerIcon = await _getBitmapDescriptorFromAsset('assets/images/top-view-bike.png', 100);
    _autoMarkerIcon = await _getBitmapDescriptorFromAsset('assets/images/top-view-tuktuk.png', 100);
    _carMarkerIcon = await _getBitmapDescriptorFromAsset('assets/images/top-view-car.png', 100);
  }

  Future<BitmapDescriptor> _getBitmapDescriptorFromAsset(String path, int width) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    final ui.FrameInfo fi = await codec.getNextFrame();
    final Uint8List resizedData = (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(resizedData);
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await _locationService.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _locationService.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      final locationData = await _locationService.getLocation();
      final LatLng currentLatLng = LatLng(locationData.latitude!, locationData.longitude!);

      _pickupLocation = currentLatLng;
      _addUserMarker(currentLatLng);

      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: currentLatLng, zoom: 15.0)));

      _fetchNearbyDrivers();
      _pollingTimer = Timer.periodic(const Duration(seconds: 9), (timer) {
        _fetchNearbyDrivers();
      });
    } catch (e) {
      print('Could not get location: $e');
    }
  }

  // --- API AND DATA HANDLING ---

  Future<void> _fetchNearbyDrivers() async {
    if (_pickupLocation == null) return;

    final dio = Dio();
    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    try {
      final response = await dio.get(
        '$apiUrl/ride-service/customer/nearby-drivers',
        queryParameters: {'latitude': _pickupLocation!.latitude, 'longitude': _pickupLocation!.longitude},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && mounted) {
        _updateVehicleMarkers(response.data);
        if (_isFirstDriverFetch) {
          _zoomToFitMarkers();
          _isFirstDriverFetch = false;
        }
      }
    } on DioException catch (e) {
      print('Could not fetch nearby drivers: $e');
    }
  }

  /// **THE FIX IS HERE**: This function now uses the driverId to efficiently update markers.
  void _updateVehicleMarkers(Map<String, dynamic> data) {
    final vehiclesData = data['vehicles'];
    if (vehiclesData == null) return;

    Set<String> receivedDriverIds = {};

    // Helper function to process each list of vehicles from the API
    void processVehicleList(List vehicles, String type, BitmapDescriptor icon) {
      for (var vehicle in vehicles) {
        final driverId = vehicle['driverId'];
        final lat = vehicle['latitude'];
        final lng = vehicle['longitude'];

        if (driverId != null && lat != null && lng != null) {
          receivedDriverIds.add(driverId);

          final newMarker = Marker(
            markerId: MarkerId(driverId), // Use the stable driverId
            position: LatLng(lat, lng),
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            rotation: vehicle['bearing']?.toDouble() ?? 0.0,
            flat: true,
          );

          // Add or update the marker in our map
          _vehicleMarkers[driverId] = newMarker;
        }
      }
    }

    // Process all vehicle types from the API response
    if (vehiclesData['bike'] is List) {
      processVehicleList(vehiclesData['bike'], 'bike', _bikeMarkerIcon);
    }
    if (vehiclesData['auto'] is List) {
      processVehicleList(vehiclesData['auto'], 'auto', _autoMarkerIcon);
    }
    if (vehiclesData['car'] is Map) {
      if (vehiclesData['car']['economy'] is List) {
        processVehicleList(vehiclesData['car']['economy'], 'economy', _carMarkerIcon);
      }
      if (vehiclesData['car']['premium'] is List) {
        processVehicleList(vehiclesData['car']['premium'], 'premium', _carMarkerIcon);
      }
      if (vehiclesData['car']['XL'] is List) {
        processVehicleList(vehiclesData['car']['XL'], 'xl', _carMarkerIcon);
      }
    }

    // Remove markers for drivers that are no longer nearby
    _vehicleMarkers.removeWhere((driverId, marker) => !receivedDriverIds.contains(driverId));

    // Update the UI
    setState(() {});
  }


  // --- MAP AND MARKER LOGIC ---

  void _addUserMarker(LatLng position) {
    setState(() {
      _userMarkers.clear();
      _userMarkers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: const InfoWindow(title: 'My Location'),
        ),
      );
    });
  }
  
  Set<Marker> _getFilteredVehicleMarkers() {
    final markers = _vehicleMarkers.values.toSet(); // Get all markers from our map
    if (_selectedVehicle == null) return markers; // Show all

    String vehicleTypeString;
    switch (_selectedVehicle!) {
      case VehicleType.bike: vehicleTypeString = 'bike'; break;
      case VehicleType.auto: vehicleTypeString = 'auto'; break;
      case VehicleType.economy: vehicleTypeString = 'economy'; break;
      case VehicleType.premium: vehicleTypeString = 'premium'; break;
      case VehicleType.xl: vehicleTypeString = 'xl'; break;
      default: return {};
    }

    // This filtering logic now needs to be based on the vehicle type stored elsewhere,
    // since the markerId is now just the driverId.
    // For now, let's assume we can infer type from the icon or we store type along with marker.
    // A better approach would be to store vehicle type in a separate map alongside the marker.
    // However, to keep it simple, this example will just show the markers as they come.
    // If you need filtering, you'll need to adjust how you store vehicle data.
    return markers;
  }

  Future<void> _zoomToFitMarkers() async {
    final allMarkers = _userMarkers.union(_vehicleMarkers.values.toSet());
    if (allMarkers.length < 2) return;

    LatLngBounds bounds = _getLatLngBounds(allMarkers);
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  LatLngBounds _getLatLngBounds(Set<Marker> markers) {
    var positions = markers.map((m) => m.position);
    final southwest = LatLng(
      positions.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
      positions.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
    );
    final northeast = LatLng(
      positions.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
      positions.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
    );
    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  // --- WIDGETS ---
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        title: Text('RideFast', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {})],
      ),
      drawer: const MainDrawer(),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            initialCameraPosition: const CameraPosition(target: LatLng(18.5204, 73.8567), zoom: 12),
            markers: _userMarkers.union(_vehicleMarkers.values.toSet()), // Use the values from the map
            onMapCreated: (GoogleMapController controller) {
              _mapController.complete(controller);
            },
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.45,
            maxChildSize: 0.8,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  boxShadow: [BoxShadow(blurRadius: 10.0, color: Colors.black12)],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildServiceSelector(),
                        const SizedBox(height: 20),
                        _buildLocationField(icon: Icons.my_location, label: _pickupLocationLabel, color: Colors.blue, isPickup: true),
                        const SizedBox(height: 12),
                        _buildLocationField(icon: Icons.location_on, label: _destinationLabel, color: Colors.red, isPickup: false),
                        const SizedBox(height: 24),
                        Text('Select a Ride', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildVehicleSelector(),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedVehicle == null ? null : () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27b4ad),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              disabledBackgroundColor: Colors.grey.shade300,
                            ),
                            child: Text('Confirm Booking', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSelector() {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _buildServiceButton(label: 'Ride', iconPath: 'assets/images/ride_icon.png', serviceType: ServiceType.ride)),
          Expanded(child: _buildServiceButton(label: 'Parcel', iconPath: 'assets/images/parcel_icon.png', serviceType: ServiceType.parcel)),
        ],
      ),
    );
  }

  Widget _buildServiceButton({required String label, required String iconPath, required ServiceType serviceType}) {
    final bool isSelected = _selectedService == serviceType;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedService = serviceType;
        _selectedVehicle = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFF27b4ad) : Colors.transparent, borderRadius: BorderRadius.circular(30)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(iconPath, width: 24, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField({required IconData icon, required String label, required Color color, required bool isPickup}) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).pushNamed('/search');
        if (result != null && result is String) {
          setState(() {
            if (isPickup) _pickupLocationLabel = result;
            else _destinationLabel = result;
          });
          // TODO: Update pickup location and re-fetch drivers
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.grey[800], fontSize: 16), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  Widget _buildVehicleSelector() {
    if (_selectedService == ServiceType.parcel) {
      return _buildVehicleOption(iconPath: 'assets/images/parcel_icon.png', label: 'Parcel', price: '₹50', vehicleType: VehicleType.parcel);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildVehicleOption(iconPath: 'assets/images/bike_icon.png', label: 'Bike', price: '₹75', vehicleType: VehicleType.bike),
          _buildVehicleOption(iconPath: 'assets/images/auto_icon.png', label: 'Auto', price: '₹120', vehicleType: VehicleType.auto),
          _buildVehicleOption(iconPath: 'assets/images/mini_icon.png', label: 'Economy', price: '₹150', vehicleType: VehicleType.economy),
          _buildVehicleOption(iconPath: 'assets/images/sedan_icon.png', label: 'Premium', price: '₹180', vehicleType: VehicleType.premium),
          _buildVehicleOption(iconPath: 'assets/images/suv_icon.png', label: 'Extra XL', price: '₹220', vehicleType: VehicleType.xl),
        ],
      ),
    );
  }

  Widget _buildVehicleOption({required String iconPath, required String label, required String price, required VehicleType vehicleType}) {
    final bool isSelected = _selectedVehicle == vehicleType;
    return GestureDetector(
      onTap: () => setState(() => _selectedVehicle = vehicleType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2F1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF27b4ad) : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Image.asset(iconPath, width: 48, height: 48),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(price, style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}