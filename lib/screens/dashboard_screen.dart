import 'dart:async';
import 'dart:convert';
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
import 'package:ridefast/services/local_notification_service.dart';
import 'package:ridefast/services/ride_state_service.dart';
import 'package:ridefast/widgets/dashboard/location_fields.dart';
import 'package:ridefast/widgets/dashboard/location_search_panel.dart';
import 'package:ridefast/widgets/dashboard/payment_selector.dart';
import 'package:ridefast/widgets/dashboard/searching_panel.dart';
import 'package:ridefast/widgets/dashboard/service_selector.dart';
import 'package:ridefast/widgets/dashboard/vehicle_selector.dart';
import 'package:ridefast/widgets/main_drawer.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Enums defined outside the class for better accessibility
enum ServiceType { ride, parcel }
enum LocationField { pickup, destination }
enum PaymentMethod { cash, online, wallet }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // UI State
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  ServiceType _selectedService = ServiceType.ride;
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
  bool _isSearchingForDriver = false;

  // Pin Marker Selection State
  LatLng _selectedLocationOnMap = const LatLng(0, 0);
  String _selectedAddressOnMap = "Move the map to select location";
  bool _isMapMoving = false;

  // Fare Estimation State
  List<FareOption> _fareOptions = [];
  FareOption? _selectedFareOption;
  bool _isFetchingFares = false;
  String? _fareErrorMessage;

  // Payment State
  double _walletBalance = 0.0;
  bool _isWalletAvailable = false;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  bool _isRequestingRide = false;

  // Services & Communication
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Dio _dio = Dio();
  final RideStateService _rideStateService = RideStateService();
  final LocalNotificationService _notificationService = LocalNotificationService();
  WebSocketChannel? _channel;

  // Icons
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
    _channel?.sink.close();
    super.dispose();
  }

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
      if (!serviceEnabled) serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) return;

      PermissionStatus permissionGranted = await _locationService.hasPermission();
      if (permissionGranted == PermissionStatus.denied) permissionGranted = await _locationService.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;

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

  Future<void> _fetchNearbyDrivers() async {
    if (_pickupMarker == null) return;
    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');
    if (token == null || apiUrl == null) return;

    try {
      final response = await _dio.get('$apiUrl/ride-service/customer/nearby-drivers',
          queryParameters: {'latitude': _pickupMarker!.position.latitude, 'longitude': _pickupMarker!.position.longitude},
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (response.statusCode == 200 && mounted) {
        _updateVehicleMarkers(response.data);
      }
    } on DioException {
      // Fail silently on polling
    }
  }

  void _updateVehicleMarkers(Map<String, dynamic> data) {
    if (!mounted) return;
    final vehiclesData = data['vehicles'];
    if (vehiclesData == null) return;
    Set<String> receivedDriverIds = {};
    void processVehicleList(List? vehicles, BitmapDescriptor icon) {
      if (vehicles == null) return;
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
              flat: true);
        }
      }
    }

    processVehicleList(vehiclesData['bike'], _bikeMarkerIcon);
    processVehicleList(vehiclesData['auto'], _autoMarkerIcon);
    if (vehiclesData['car'] is Map) {
      processVehicleList(vehiclesData['car']['economy'], _carMarkerIcon);
      processVehicleList(vehiclesData['car']['premium'], _carMarkerIcon);
      processVehicleList(vehiclesData['car']['XL'], _carMarkerIcon);
    }
    _vehicleMarkers.removeWhere((driverId, _) => !receivedDriverIds.contains(driverId));
    setState(() {});
  }

  Future<String?> _reverseGeocode(LatLng latLng) async {
    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');
    if (apiUrl == null || token == null) return null;
    try {
      final response = await _dio.get('$apiUrl/maps-service/maps/geocode/reverse',
          queryParameters: {'lat': latLng.latitude, 'lng': latLng.longitude},
          options: Options(headers: {'Authorization': 'Bearer $token'}));
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
    try {
      final response = await _dio.get('$apiUrl/maps-service/maps/geocode/forward',
          queryParameters: {'address': address},
          options: Options(headers: {'Authorization': 'Bearer $token'}));
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
    if (token == null || apiUrl == null) {
      setState(() {
        _isFetchingFares = false;
        _fareErrorMessage = "Authentication error. Please log in again.";
      });
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
      if (mounted && response.statusCode == 200) {
        final List<dynamic> options = response.data['options'] ?? [];
        final paymentOptions = response.data['payment_options'];
        setState(() {
          _fareOptions = options.map((data) => FareOption.fromJson(data)).toList();
          if (paymentOptions != null && paymentOptions['wallet'] != null) {
            _isWalletAvailable = paymentOptions['wallet']['is_available'] ?? false;
            _walletBalance = (paymentOptions['wallet']['balance'] as num?)?.toDouble() ?? 0.0;
          }
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

  Future<void> _requestRide() async {
    if (_selectedFareOption == null) return;
    setState(() => _isRequestingRide = true);

    final apiUrl = dotenv.env['API_URL'];
    final token = await _storage.read(key: 'auth_token');
    if (apiUrl == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot request ride. Please restart the app.'), backgroundColor: Colors.red));
      setState(() => _isRequestingRide = false);
      return;
    }

    final paymentMethodMap = {PaymentMethod.cash: 'cash', PaymentMethod.online: 'online', PaymentMethod.wallet: 'wallet'};
    try {
      final response = await _dio.post(
        '$apiUrl/ride-service/customer/rides/request',
        data: {
          "fareId": _selectedFareOption!.fareId,
          "payment_method": paymentMethodMap[_selectedPaymentMethod],
          "use_wallet": _selectedPaymentMethod == PaymentMethod.wallet,
        },
        options: Options(headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}),
      );

      if (mounted && response.statusCode == 201) {
        final rideId = response.data['rideId'];
        await _rideStateService.saveRideState(RideState.searching, {'rideId': rideId});
        _startDriverSearch(rideId);
      }
    } on DioException catch (e) {
      final message = e.response?.statusCode == 400
          ? 'Your ride request has expired. Please select your location again.'
          : e.response?.data['message'] ?? 'An unknown error occurred.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isRequestingRide = false);
    }
  }

  Future<void> _startDriverSearch(String rideId) async {
    setState(() => _isSearchingForDriver = true);
    final token = await _storage.read(key: 'auth_token');
    final websocketUrl = dotenv.env['WEBSOCKET_URL'];
    if (token == null || websocketUrl == null) {
      _cancelDriverSearch(showError: true, message: 'Configuration error. Please restart.');
      return;
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(websocketUrl), protocols: ["customer-protocol", token]);
      _channel!.stream.listen((message) {
        if (!mounted) return;
        final decoded = jsonDecode(message);
        if (decoded['type'] == 'DRIVER_ASSIGNED') {
          _channel?.sink.close();
          final payload = Map<String, dynamic>.from(decoded['payload']);
          final driverName = payload['driver']?['name'] ?? 'Your driver';

          _notificationService.showNotification(
            id: rideId.hashCode,
            title: 'Driver Assigned!',
            body: '$driverName is on the way to pick you up.',
          );

          final rideDataForPersistence = {
            ...payload,
            'pickup_address': _pickupLocationLabel,
            'dropoff_address': _destinationLabel,
            'pickup_lat': _pickupMarker?.position.latitude,
            'pickup_lng': _pickupMarker?.position.longitude,
            'dropoff_lat': _destinationMarker?.position.latitude,
            'dropoff_lng': _destinationMarker?.position.longitude,
            'initial_state': RideState.driverAssigned.toString(),
          };
          _rideStateService.saveRideState(RideState.driverAssigned, rideDataForPersistence).then((_) {
            Navigator.of(context).pushNamed('/ride-on-the-way', arguments: rideDataForPersistence);
            setState(() { _isSearchingForDriver = false; });
          });
        } else if (decoded['type'] == 'NO_DRIVERS_AVAILABLE') {
          _cancelDriverSearch(showError: true, message: 'All drivers are busy. Please try again.');
        }
      }, onError: (error) {
        _cancelDriverSearch(showError: true, message: 'Connection error. Please try again.');
      });
    } catch (e) {
      _cancelDriverSearch(showError: true, message: 'Failed to connect to server.');
    }
  }

  void _cancelDriverSearch({bool showError = false, String? message}) async {
    await _rideStateService.clearRideState();
    _channel?.sink.close();
    if (mounted) {
      setState(() { _isSearchingForDriver = false; });
      if (showError && message != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.orange[800]));
      }
    }
  }

  void _enterSearchMode(LocationField field) => setState(() { _isSearchingLocation = true; _activeField = field; });
  void _exitSearchMode() => setState(() => _isSearchingLocation = false);

  void _handleLocationSelectedFromSearch(String address) async {
    final coordinates = await _forwardGeocode(address);
    if (coordinates == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not find location for '$address'"), backgroundColor: Colors.red));
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
      if (address != null) _handleLocationSelectedFromSearch(address);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not get current location. Please enable location services."), backgroundColor: Colors.red));
    }
  }

  void _handleSelectOnMap() => setState(() { _isSearchingLocation = false; _isSelectingLocationOnMap = true; });

  void _confirmSelectedLocationOnMap() {
    if (_activeField == LocationField.pickup) {
      _setPickupMarker(_selectedLocationOnMap, address: _selectedAddressOnMap);
    } else {
      _setDestinationMarker(_selectedLocationOnMap, address: _selectedAddressOnMap);
    }
    setState(() => _isSelectingLocationOnMap = false);
  }

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

  void _onCameraMove(CameraPosition pos) { if (_isSelectingLocationOnMap) setState(() { _selectedLocationOnMap = pos.target; _isMapMoving = true; }); }

  Future<void> _onCameraIdle() async {
    if (_isSelectingLocationOnMap) {
      final address = await _reverseGeocode(_selectedLocationOnMap);
      if (mounted) setState(() { _selectedAddressOnMap = address ?? "Could not fetch address"; _isMapMoving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()), title: Text('RideFast', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)), centerTitle: true, actions: [IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {})]),
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
              onCameraIdle: _onCameraIdle),
          if (_isSelectingLocationOnMap) ..._buildMapSelectionUI(),
          if (_isSearchingLocation) _buildSearchPanel(),
          if (!_isSearchingLocation && !_isSelectingLocationOnMap) AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _isSearchingForDriver ? _buildSearchingPanel() : _buildBookingPanel())
        ],
      ),
    );
  }

  Widget _buildBookingPanel() {
    String buttonText = 'Confirm Booking';
    if (_selectedFareOption != null) { buttonText = 'Book ${_selectedFareOption!.displayName}'; }

    return DraggableScrollableSheet(
      key: const ValueKey('bookingPanel'),
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)), boxShadow: [BoxShadow(blurRadius: 10.0, color: Colors.black12)]),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            children: [
              ServiceSelector(selectedService: _selectedService, onServiceSelected: (s) => setState(() { _selectedService = s; _selectedFareOption = null; })),
              const SizedBox(height: 20),
              LocationFields(pickupLabel: _pickupLocationLabel, destinationLabel: _destinationLabel, onPickupTap: () => _enterSearchMode(LocationField.pickup), onDestinationTap: () => _enterSearchMode(LocationField.destination)),
              const SizedBox(height: 24),
              Text('Select a Ride', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              VehicleSelector(fareOptions: _fareOptions, selectedOption: _selectedFareOption, isLoading: _isFetchingFares, errorMessage: _fareErrorMessage, onVehicleSelected: (option) { setState(() => _selectedFareOption = option); }),
              if (_fareOptions.isNotEmpty) ...[
                const SizedBox(height: 24),
                PaymentSelector(selectedPaymentMethod: _selectedPaymentMethod, walletBalance: _walletBalance, isWalletAvailable: _isWalletAvailable, onPaymentMethodSelected: (method) { setState(() { _selectedPaymentMethod = method; }); })
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedFareOption == null || _isRequestingRide) ? null : _requestRide,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27b4ad),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      disabledBackgroundColor: Colors.grey.shade300),
                  child: _isRequestingRide
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Text(buttonText, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchingPanel() {
    return Align(
      key: const ValueKey('searchingPanel'),
      alignment: Alignment.bottomCenter,
      child: SearchingPanel(
        vehicleTypeName: _selectedFareOption?.displayName ?? 'ride',
        onCancelSearch: () => _cancelDriverSearch(showError: false),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return LocationSearchPanel(
        onCancel: _exitSearchMode,
        onLocationSelected: _handleLocationSelectedFromSearch,
        onSelectOnMap: _handleSelectOnMap,
        onUseCurrentLocation: _handleUseCurrentLocation);
  }

  List<Widget> _buildMapSelectionUI() {
    return [
      Center(child: Padding(padding: const EdgeInsets.only(bottom: 40.0), child: Image.asset('assets/images/marker.png', height: 50))),
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
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27b4ad),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      disabledBackgroundColor: Colors.grey.shade300),
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