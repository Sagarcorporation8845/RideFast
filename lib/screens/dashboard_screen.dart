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
import 'package:ridefast/widgets/dashboard/location_fields.dart';
import 'package:ridefast/widgets/dashboard/service_selector.dart';
import 'package:ridefast/widgets/dashboard/vehicle_selector.dart';
import 'package:ridefast/widgets/main_drawer.dart';

// Enums moved here to be accessible by child widgets
enum ServiceType { ride, parcel }
enum VehicleType { bike, auto, economy, premium, xl, parcel }
enum LocationField { pickup, destination }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // UI State
  ServiceType _selectedService = ServiceType.ride;
  VehicleType? _selectedVehicle;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _pickupLocationLabel = 'Pickup Location';
  String _destinationLabel = 'Destination';

  // Map & Location State
  final Completer<GoogleMapController> _mapController = Completer();
  final Location _locationService = Location();
  Timer? _pollingTimer;
  final Map<String, Marker> _vehicleMarkers = {};
  bool _isFirstDriverFetch = true;

  // **FIX 1**: Dedicated state for pickup and destination markers
  Marker? _pickupMarker;
  Marker? _destinationMarker;

  // Pin Marker Selection State
  bool _isSelectingLocation = false;
  LocationField? _activeLocationField;
  LatLng _selectedLocationOnMap = const LatLng(0, 0); // Center of map
  String _selectedAddressOnMap = "Move the map to select location";
  bool _isMapMoving = false;

  // Custom marker icons
  BitmapDescriptor _bikeMarkerIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor _autoMarkerIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor _carMarkerIcon = BitmapDescriptor.defaultMarker;
  
  // Services
  final _storage = const FlutterSecureStorage();
  final _dio = Dio();

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

      // **FIX 2**: Set the initial pickup marker instead of a generic user marker
      _setPickupMarker(currentLatLng);

      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: currentLatLng, zoom: 15.0)));

      _fetchNearbyDrivers();
      _pollingTimer = Timer.periodic(const Duration(seconds: 9), (timer) {
        _fetchNearbyDrivers();
      });
    } catch (e) {
      debugPrint('Could not get location: $e');
    }
  }

  // --- API AND DATA HANDLING ---

  Future<void> _fetchNearbyDrivers() async {
    if (_pickupMarker == null) return;

    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    try {
      final response = await _dio.get(
        '$apiUrl/ride-service/customer/nearby-drivers',
        queryParameters: {'latitude': _pickupMarker!.position.latitude, 'longitude': _pickupMarker!.position.longitude},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && mounted) {
        _updateVehicleMarkers(response.data);
        if (_isFirstDriverFetch) {
          _isFirstDriverFetch = false;
        }
      }
    } on DioException catch (e) {
      debugPrint('Could not fetch nearby drivers: $e');
    }
  }

  void _updateVehicleMarkers(Map<String, dynamic> data) {
    final vehiclesData = data['vehicles'];
    if (vehiclesData == null) return;
    Set<String> receivedDriverIds = {};
    void processVehicleList(List vehicles, BitmapDescriptor icon) {
      for (var vehicle in vehicles) {
        final driverId = vehicle['driverId'];
        final lat = vehicle['latitude'];
        final lng = vehicle['longitude'];
        if (driverId != null && lat != null && lng != null) {
          receivedDriverIds.add(driverId);
          _vehicleMarkers[driverId] = Marker(
            markerId: MarkerId(driverId),
            position: LatLng(lat, lng),
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            rotation: vehicle['bearing']?.toDouble() ?? 0.0,
            flat: true,
          );
        }
      }
    }
    if (vehiclesData['bike'] is List) processVehicleList(vehiclesData['bike'], _bikeMarkerIcon);
    if (vehiclesData['auto'] is List) processVehicleList(vehiclesData['auto'], _autoMarkerIcon);
    if (vehiclesData['car'] is Map) {
      if (vehiclesData['car']['economy'] is List) processVehicleList(vehiclesData['car']['economy'], _carMarkerIcon);
      if (vehiclesData['car']['premium'] is List) processVehicleList(vehiclesData['car']['premium'], _carMarkerIcon);
      if (vehiclesData['car']['XL'] is List) processVehicleList(vehiclesData['car']['XL'], _carMarkerIcon);
    }
    _vehicleMarkers.removeWhere((driverId, _) => !receivedDriverIds.contains(driverId));
    if (mounted) setState(() {});
  }

  // --- PIN MARKER LOCATION SELECTION LOGIC ---

  void _onCameraMove(CameraPosition position) {
    if (_isSelectingLocation) {
      setState(() {
        _selectedLocationOnMap = position.target;
        _isMapMoving = true;
      });
    }
  }

  Future<void> _onCameraIdle() async {
    if (_isSelectingLocation) {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${_selectedLocationOnMap.latitude},${_selectedLocationOnMap.longitude}&key=$apiKey';
      try {
        final response = await _dio.get(url);
        if (response.data['status'] == 'OK' && mounted) {
          final results = response.data['results'];
          setState(() {
            _selectedAddressOnMap = results.isNotEmpty ? results[0]['formatted_address'] : 'Unnamed Road';
            _isMapMoving = false;
          });
        }
      } catch (e) {
        debugPrint("Geocoding Error: $e");
        setState(() {
           _selectedAddressOnMap = "Could not fetch address";
          _isMapMoving = false;
        });
      }
    }
  }

  void _enterLocationSelectionMode(LocationField field) {
    setState(() {
      _isSelectingLocation = true;
      _activeLocationField = field;
    });
  }

  void _confirmSelectedLocation() {
    if (_activeLocationField == LocationField.pickup) {
       _setPickupMarker(_selectedLocationOnMap, address: _selectedAddressOnMap);
       _fetchNearbyDrivers(); // Re-fetch drivers for new location
    } else {
       _setDestinationMarker(_selectedLocationOnMap, address: _selectedAddressOnMap);
    }
    
    setState(() {
      _isSelectingLocation = false;
      _activeLocationField = null;
    });

    // **FIX 3**: Auto-zoom if both markers are now set
    if (_pickupMarker != null && _destinationMarker != null) {
      _zoomToFitRoute();
    }
  }

  // --- MAP AND MARKER LOGIC ---
  
  void _setPickupMarker(LatLng position, {String? address}) {
    setState(() {
      _pickupMarker = Marker(
        markerId: const MarkerId('pickupLocation'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Green for pickup
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      );
      if (address != null) {
        _pickupLocationLabel = address;
      }
    });
  }

  void _setDestinationMarker(LatLng position, {String? address}) {
    setState(() {
      _destinationMarker = Marker(
        markerId: const MarkerId('destinationLocation'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Red for destination
        infoWindow: const InfoWindow(title: 'Destination'),
      );
      if (address != null) {
        _destinationLabel = address;
      }
    });
  }
  
  // **FIX 4**: New helper to combine all visible markers
  Set<Marker> _getAllMarkers() {
    final Set<Marker> markers = {};
    if (_pickupMarker != null && !_isSelectingLocation) markers.add(_pickupMarker!);
    if (_destinationMarker != null && !_isSelectingLocation) markers.add(_destinationMarker!);
    markers.addAll(_vehicleMarkers.values);
    return markers;
  }

  Future<void> _zoomToFitRoute() async {
    if (_pickupMarker == null || _destinationMarker == null) return;

    final LatLng southwest = LatLng(
      _pickupMarker!.position.latitude < _destinationMarker!.position.latitude
          ? _pickupMarker!.position.latitude
          : _destinationMarker!.position.latitude,
      _pickupMarker!.position.longitude < _destinationMarker!.position.longitude
          ? _pickupMarker!.position.longitude
          : _destinationMarker!.position.longitude,
    );
    final LatLng northeast = LatLng(
      _pickupMarker!.position.latitude > _destinationMarker!.position.latitude
          ? _pickupMarker!.position.latitude
          : _destinationMarker!.position.latitude,
      _pickupMarker!.position.longitude > _destinationMarker!.position.longitude
          ? _pickupMarker!.position.longitude
          : _destinationMarker!.position.longitude,
    );

    final bounds = LatLngBounds(southwest: southwest, northeast: northeast);
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0)); // 100 is padding
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
            myLocationEnabled: false, // We use our own markers now
            myLocationButtonEnabled: false,
            initialCameraPosition: const CameraPosition(target: LatLng(18.5204, 73.8567), zoom: 12),
            markers: _getAllMarkers(),
            onMapCreated: (GoogleMapController controller) => _mapController.complete(controller),
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),

          if (_isSelectingLocation) ...[
            // Central Pin Marker
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Image.asset('assets/images/marker.png', height: 50),
              ),
            ),
            // Location Confirmation Card
            _buildLocationConfirmationCard(),
          ],

          // Main Booking Sheet
          if (!_isSelectingLocation)
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
                          ServiceSelector(
                            selectedService: _selectedService,
                            onServiceSelected: (service) => setState(() {
                              _selectedService = service;
                              _selectedVehicle = null;
                            }),
                          ),
                          const SizedBox(height: 20),
                          LocationFields(
                            pickupLabel: _pickupLocationLabel,
                            destinationLabel: _destinationLabel,
                            onPickupTap: () => _enterLocationSelectionMode(LocationField.pickup),
                            onDestinationTap: () => _enterLocationSelectionMode(LocationField.destination),
                          ),
                          const SizedBox(height: 24),
                          Text('Select a Ride', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          VehicleSelector(
                            selectedService: _selectedService,
                            selectedVehicle: _selectedVehicle,
                            onVehicleSelected: (vehicle) => setState(() => _selectedVehicle = vehicle),
                          ),
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

  /// Widget for the location confirmation card.
  Widget _buildLocationConfirmationCard() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SELECT LOCATION",
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF27b4ad)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isMapMoving ? 'Loading...' : _selectedAddressOnMap,
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isMapMoving ? null : _confirmSelectedLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27b4ad),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                   disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: Text(
                  'Confirm Location',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}