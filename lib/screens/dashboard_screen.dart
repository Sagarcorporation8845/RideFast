import 'dart:async';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:ridefast/models/fare_option.dart';
import 'package:ridefast/widgets/dashboard/location_fields.dart';
import 'package:ridefast/widgets/dashboard/location_search_panel.dart';
import 'package:ridefast/widgets/dashboard/service_selector.dart';
import 'package:ridefast/widgets/dashboard/vehicle_selector.dart';
import 'package:ridefast/widgets/main_drawer.dart';

enum ServiceType { ride, parcel }
enum LocationField { pickup, destination }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // UI State
  ServiceType _selectedService = ServiceType.ride;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _pickupLocationLabel = 'Pickup Location';
  String _destinationLabel = 'Destination';

  // Map & Location State
  final Completer<GoogleMapController> _mapController = Completer();
  final Location _locationService = Location();
  Timer? _pollingTimer;
  final Map<String, Marker> _vehicleMarkers = {};
  Marker? _pickupMarker;
  Marker? _destinationMarker;

  // Mode States
  bool _isSearchingLocation = false;
  bool _isSelectingLocationOnMap = false;
  LocationField? _activeField;

  // Pin Marker Selection State
  LatLng _selectedLocationOnMap = const LatLng(0, 0);
  String _selectedAddressOnMap = "Move the map to select location";
  bool _isMapMoving = false;

  // Fare Estimation State
  List<FareOption> _fareOptions = [];
  FareOption? _selectedFareOption;
  bool _isFetchingFares = false;
  String? _fareErrorMessage;

  // Services & Icons
  final _storage = const FlutterSecureStorage();
  final _dio = Dio();
  BitmapDescriptor _bikeMarkerIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor _autoMarkerIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor _carMarkerIcon = BitmapDescriptor.defaultMarker;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers().then((_) => _initLocation());
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
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    final fi = await codec.getNextFrame();
    final resizedData = (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
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
      final latLng = LatLng(locationData.latitude!, locationData.longitude!);
      final address = await _reverseGeocode(latLng);
      
      _setPickupMarker(latLng, address: address ?? "Current Location");
      
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 15.0)));
      
      _fetchNearbyDrivers();
      _pollingTimer = Timer.periodic(const Duration(seconds: 9), (_) => _fetchNearbyDrivers());
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
      final response = await _dio.get('$apiUrl/ride-service/customer/nearby-drivers',
          queryParameters: {'latitude': _pickupMarker!.position.latitude, 'longitude': _pickupMarker!.position.longitude},
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (response.statusCode == 200 && mounted) {
        _updateVehicleMarkers(response.data);
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
          _vehicleMarkers[driverId] = Marker(markerId: MarkerId(driverId), position: LatLng(lat, lng), icon: icon, anchor: const Offset(0.5, 0.5), rotation: vehicle['bearing']?.toDouble() ?? 0.0, flat: true);
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
  
  Future<String?> _reverseGeocode(LatLng latLng) async {
    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');
    if (apiUrl == null || token == null) return null;
    final url = '$apiUrl/maps-service/maps/geocode/reverse';
    try {
      final response = await _dio.get(url, queryParameters: {'lat': latLng.latitude, 'lng': latLng.longitude}, options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (response.data['status'] == 'OK' && response.data['results'].isNotEmpty) {
        return response.data['results'][0]['formatted_address'];
      }
    } catch (e) {
      debugPrint("Reverse Geocoding Error: $e");
    }
    return null;
  }
  
  Future<LatLng?> _forwardGeocode(String address) async {
    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');
    if (apiUrl == null || token == null) return null;
    final url = '$apiUrl/maps-service/maps/geocode/forward';
    try {
      final response = await _dio.get(url, queryParameters: {'address': address}, options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (response.data['status'] == 'OK' && response.data['results'].isNotEmpty) {
        final location = response.data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      }
    } catch (e) {
      debugPrint("Forward Geocoding Error: $e");
    }
    return null;
  }

  Future<void> _getFareEstimates() async {
    if (_pickupMarker == null || _destinationMarker == null) return;
    setState(() {
      _isFetchingFares = true;
      _fareErrorMessage = null;
      _fareOptions = [];
      _selectedFareOption = null;
    });

    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      setState(() { _isFetchingFares = false; _fareErrorMessage = "Please log in to see fares."; });
      return;
    }

    try {
      final response = await _dio.post(
        '$apiUrl/pricing-service/fares/estimate',
        data: {
          "pickup": {"latitude": _pickupMarker!.position.latitude, "longitude": _pickupMarker!.position.longitude},
          "dropoff": {"latitude": _destinationMarker!.position.latitude, "longitude": _destinationMarker!.position.longitude}
        },
        options: Options(headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> options = response.data['options'];
        setState(() {
          _fareOptions = options.map((data) => FareOption.fromJson(data)).toList();
          _isFetchingFares = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingFares = false;
          _fareErrorMessage = e.response?.data['message'] ?? "An unexpected error occurred.";
        });
      }
    }
  }
  
  // --- UI MODE TRANSITIONS & ACTIONS ---
  void _enterSearchMode(LocationField field) { setState(() { _isSearchingLocation = true; _activeField = field; }); }
  void _exitSearchMode() { setState(() => _isSearchingLocation = false); }

  void _handleLocationSelectedFromSearch(String address) async {
    final coordinates = await _forwardGeocode(address);
    if (coordinates == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not find location for '$address'"), backgroundColor: Colors.red,));
      }
      _exitSearchMode();
      return;
    }
    if (_activeField == LocationField.pickup) {
      _setPickupMarker(coordinates, address: address);
    } else {
      _setDestinationMarker(coordinates, address: address);
    }
    _exitSearchMode();
  }

  void _handleUseCurrentLocation() async {
    try {
      final locationData = await _locationService.getLocation();
      final latLng = LatLng(locationData.latitude!, locationData.longitude!);
      final address = await _reverseGeocode(latLng);
      if (address != null) {
        _handleLocationSelectedFromSearch(address);
      }
    } catch (e) { 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not get current location. Please enable location services."), backgroundColor: Colors.red,));
      }
    }
  }

  void _handleSelectOnMap() { setState(() { _isSearchingLocation = false; _isSelectingLocationOnMap = true; }); }
  
  void _confirmSelectedLocationOnMap() {
    if (_activeField == LocationField.pickup) {
      _setPickupMarker(_selectedLocationOnMap, address: _selectedAddressOnMap);
    } else {
      _setDestinationMarker(_selectedLocationOnMap, address: _selectedAddressOnMap);
    }
    setState(() => _isSelectingLocationOnMap = false);
  }

  // --- MAP & MARKER LOGIC ---
  void _setPickupMarker(LatLng pos, {String? address}) {
    setState(() {
      _pickupMarker = Marker(markerId: const MarkerId('pickupLocation'), position: pos, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen));
      if (address != null) _pickupLocationLabel = address;
    });
    if (_destinationMarker != null) _getFareEstimates();
  }
  void _setDestinationMarker(LatLng pos, {String? address}) {
    setState(() {
      _destinationMarker = Marker(markerId: const MarkerId('destinationLocation'), position: pos, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed));
      if (address != null) _destinationLabel = address;
    });
    if (_pickupMarker != null) {
      _zoomToFitRoute();
      _getFareEstimates();
    }
  }
  
  Set<Marker> _getAllMarkers() {
    final Set<Marker> markers = {};
    if (_pickupMarker != null && !_isSearchingLocation && !_isSelectingLocationOnMap) markers.add(_pickupMarker!);
    if (_destinationMarker != null && !_isSearchingLocation && !_isSelectingLocationOnMap) markers.add(_destinationMarker!);
    markers.addAll(_vehicleMarkers.values);
    return markers;
  }

  Future<void> _zoomToFitRoute() async {
    if (_pickupMarker == null || _destinationMarker == null) return;
    final southwest = LatLng(
        _pickupMarker!.position.latitude < _destinationMarker!.position.latitude ? _pickupMarker!.position.latitude : _destinationMarker!.position.latitude,
        _pickupMarker!.position.longitude < _destinationMarker!.position.longitude ? _pickupMarker!.position.longitude : _destinationMarker!.position.longitude);
    final northeast = LatLng(
        _pickupMarker!.position.latitude > _destinationMarker!.position.latitude ? _pickupMarker!.position.latitude : _destinationMarker!.position.latitude,
        _pickupMarker!.position.longitude > _destinationMarker!.position.longitude ? _pickupMarker!.position.longitude : _destinationMarker!.position.longitude);
    final bounds = LatLngBounds(southwest: southwest, northeast: northeast);
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }
  
  void _onCameraMove(CameraPosition pos) {
    if (_isSelectingLocationOnMap) {
      setState(() { _selectedLocationOnMap = pos.target; _isMapMoving = true; });
    }
  }

  Future<void> _onCameraIdle() async {
    if (_isSelectingLocationOnMap) {
      final address = await _reverseGeocode(_selectedLocationOnMap);
      if (mounted) {
        setState(() { _selectedAddressOnMap = address ?? "Could not fetch address"; _isMapMoving = false; });
      }
    }
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
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            initialCameraPosition: const CameraPosition(target: LatLng(18.5204, 73.8567), zoom: 12),
            markers: _getAllMarkers(),
            onMapCreated: (controller) => _mapController.complete(controller),
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),
          if (_isSelectingLocationOnMap) ..._buildMapSelectionUI(),
          if (_isSearchingLocation) _buildSearchPanel(),
          if (!_isSearchingLocation && !_isSelectingLocationOnMap) _buildBookingPanel(),
        ],
      ),
    );
  }

  Widget _buildBookingPanel() {
    return DraggableScrollableSheet(
      initialChildSize: 0.45, minChildSize: 0.45, maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)), boxShadow: [BoxShadow(blurRadius: 10.0, color: Colors.black12)]),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ServiceSelector(selectedService: _selectedService, onServiceSelected: (s) => setState(() { _selectedService = s; _selectedFareOption = null; })),
                const SizedBox(height: 20),
                LocationFields(pickupLabel: _pickupLocationLabel, destinationLabel: _destinationLabel, onPickupTap: () => _enterSearchMode(LocationField.pickup), onDestinationTap: () => _enterSearchMode(LocationField.destination)),
                const SizedBox(height: 24),
                Text('Select a Ride', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                VehicleSelector(
                  fareOptions: _fareOptions,
                  selectedOption: _selectedFareOption,
                  isLoading: _isFetchingFares,
                  errorMessage: _fareErrorMessage,
                  onVehicleSelected: (option) {
                    setState(() => _selectedFareOption = option);
                    debugPrint("Selected Fare ID: ${option.fareId}");
                  },
                ),
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedFareOption == null ? null : () {
                      // TODO: Implement final booking confirmation call using _selectedFareOption.fareId
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27b4ad), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), disabledBackgroundColor: Colors.grey.shade300),
                    child: Text('Confirm Booking', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchPanel() {
    return LocationSearchPanel(onCancel: _exitSearchMode, onLocationSelected: _handleLocationSelectedFromSearch, onSelectOnMap: _handleSelectOnMap, onUseCurrentLocation: _handleUseCurrentLocation);
  }

  List<Widget> _buildMapSelectionUI() {
    return [
      Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Image.asset('assets/images/marker.png', height: 50),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("SELECT LOCATION", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.location_on, color: Color(0xFF27b4ad)),
                const SizedBox(width: 8),
                Expanded(child: Text(_isMapMoving ? 'Loading...' : _selectedAddressOnMap, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600)))
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isMapMoving ? null : _confirmSelectedLocationOnMap,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27b4ad), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), disabledBackgroundColor: Colors.grey.shade300),
                  child: Text('Confirm Location', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              )
            ],
          ),
        ),
      )
    ];
  }
}

