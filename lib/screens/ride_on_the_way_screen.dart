import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data'; // <-- MISSING IMPORT
import 'dart:ui' as ui; // <-- MISSING IMPORT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- MISSING IMPORT
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ridefast/services/local_notification_service.dart';
import 'package:ridefast/services/ride_state_service.dart';
import 'package:ridefast/services/sound_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:latlong2/latlong.dart' as latlong;


class RideOnTheWayScreen extends StatefulWidget {
  const RideOnTheWayScreen({super.key});

  @override
  State<RideOnTheWayScreen> createState() => _RideOnTheWayScreenState();
}

class _RideOnTheWayScreenState extends State<RideOnTheWayScreen> {
  // Map and Route State
  final Completer<GoogleMapController> _mapController = Completer();
  final Map<MarkerId, Marker> _markers = {};
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  CameraPosition? _initialCameraPosition;
  final Set<Polyline> _polylines = {};

  // Advanced polyline and icon logic
  List<LatLng> _pickupRoutePolylinePoints = [];
  List<LatLng> _rideRoutePolylinePoints = [];
  List<LatLng> _currentPolylinePoints = [];


  // Ride and Driver Data State
  Map<String, dynamic> _rideData = {};
  String _rideStatusText = "Captain is on the way!";
  bool _isDriverArrived = false;
  bool _isRideStarted = false;
  String? _endRideOtp;

  // WebSocket, Timer, and Notification State
  WebSocketChannel? _channel;
  Timer? _waitingTimer;
  int _waitingSeconds = 300; // 5 minutes
  final _storage = const FlutterSecureStorage();
  final _rideStateService = RideStateService();
  final LocalNotificationService _notificationService = LocalNotificationService();
  final SoundService _soundService = SoundService();
  bool _isConnecting = false;
  int _reconnectAttempts = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rideData.isEmpty) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
      setState(() { _rideData = args; });
      if (args['initial_camera_position'] != null) {
        _initialCameraPosition = CameraPosition(
          target: LatLng(args['initial_camera_position']['latitude'], args['initial_camera_position']['longitude']),
          zoom: args['initial_camera_position']['zoom'],
        );
      } else {
        _initialCameraPosition = const CameraPosition(target: LatLng(18.4636, 73.8665), zoom: 12);
      }
      _initializeScreen();
    }
  }

  Future<void> _initializeScreen() async {
    await _loadVehicleIcon();
    _pickupIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    _dropoffIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

    _connectToWebSocket();

    final pickupLatLng = LatLng(_rideData['pickup_lat'] ?? 18.4522, _rideData['pickup_lng'] ?? 73.8655);
    final dropoffLatLng = LatLng(_rideData['dropoff_lat'] ?? 18.5204, _rideData['dropoff_lng'] ?? 73.8567);

    _addMarker(id: 'pickup', position: pickupLatLng, icon: _pickupIcon!);
    _addMarker(id: 'dropoff', position: dropoffLatLng, icon: _dropoffIcon!);
    
    _pickupRoutePolylinePoints = _decodePolyline(_rideData['pickupRoutePolyline']);
    _rideRoutePolylinePoints = _decodePolyline(_rideData['rideRoutePolyline']);

    // Initially, show the pickup route
    _currentPolylinePoints = List.from(_pickupRoutePolylinePoints);
    _drawPolyline(_currentPolylinePoints, 'active_route', Colors.amber.shade700);


    final initialState = RideState.values.firstWhere((e) => e.toString() == _rideData['initial_state'], orElse: () => RideState.driverAssigned);
    if (initialState == RideState.driverArrived) {
      _handleDriverArrived(fromInit: true);
    } else if (initialState == RideState.rideStarted) {
      _handleRideStarted(fromInit: true);
    }
  }

  Future<void> _loadVehicleIcon() async {
    String vehicleCategory = _rideData['vehicle_category'] ?? 'car';
    String iconPath;
    switch (vehicleCategory) {
      case 'bike':
        iconPath = 'assets/images/top-view-bike.png';
        break;
      case 'auto':
        iconPath = 'assets/images/top-view-tuktuk.png';
        break;
      default:
        iconPath = 'assets/images/top-view-car.png';
    }
     final ByteData data = await rootBundle.load(iconPath);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 100);
    final ui.FrameInfo fi = await codec.getNextFrame();
    _driverIcon = BitmapDescriptor.fromBytes((await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  }

  List<LatLng> _decodePolyline(String? encodedPolyline) {
    if (encodedPolyline == null || encodedPolyline.isEmpty) return [];
    final polylinePoints = PolylinePoints();
    List<PointLatLng> decodedResult = polylinePoints.decodePolyline(encodedPolyline);
    return decodedResult.map((point) => LatLng(point.latitude, point.longitude)).toList();
  }

  void _drawPolyline(List<LatLng> points, String polylineId, Color color) {
    if (points.isEmpty) return;

    final polyline = Polyline(
      polylineId: PolylineId(polylineId),
      color: color.withOpacity(0.8),
      points: points,
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );
    setState(() {
      _polylines.add(polyline);
    });
  }

  Future<void> _connectToWebSocket() async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    final token = await _storage.read(key: 'auth_token');
    final websocketUrl = dotenv.env['WEBSOCKET_URL'];
    if (token == null || websocketUrl == null) {
      setState(() => _isConnecting = false);
      return;
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(websocketUrl), protocols: ["customer-protocol", token]);
      setState(() { _isConnecting = false; _reconnectAttempts = 0; });
      _channel!.stream.listen(_onWebSocketMessage,
        onDone: _handleWebSocketDisconnect,
        onError: (error) {
          debugPrint("WebSocket Error: $error");
          _handleWebSocketDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint("WebSocket Connection Error: $e");
      _handleWebSocketDisconnect();
    }
  }

  void _onWebSocketMessage(message) {
      final decoded = jsonDecode(message);
      switch (decoded['type']) {
        case 'DRIVER_LOCATION_UPDATE':
          final payload = decoded['payload'];
          _updateDriverMarker(
            LatLng(payload['latitude'], payload['longitude']),
            (payload['bearing'] as num? ?? 0.0).toDouble()
          );
          break;
        case 'DRIVER_ARRIVED':
          _soundService.playNewStateSound();
          _handleDriverArrived();
          break;
        case 'RIDE_STARTED':
          _soundService.playNewStateSound();
          _handleRideStarted();
          break;
        case 'END_RIDE_OTP_GENERATED':
          _soundService.playNewStateSound();
          final payload = decoded['payload'];
          _handleEndRideOtp(payload['otp']);
          break;
        case 'RIDE_COMPLETED':
          _handleRideCompleted();
          break;
      }
  }

  void _handleWebSocketDisconnect() {
    if (!mounted) return;
    _channel = null; 
    setState(() => _isConnecting = false);
    if (_reconnectAttempts < 5) {
      final waitSeconds = 2 * (_reconnectAttempts + 1);
      Future.delayed(Duration(seconds: waitSeconds), () {
        if (mounted) {
          _reconnectAttempts++;
          _connectToWebSocket();
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection lost. Please check your internet.'), backgroundColor: Colors.red),
      );
    }
  }

  void _updateDriverMarker(LatLng position, double bearing) {
    if (!mounted || _driverIcon == null) return;
    
    final marker = Marker(
      markerId: const MarkerId('driver'), 
      position: position, 
      icon: _driverIcon!, 
      anchor: const Offset(0.5, 0.5), 
      rotation: bearing,
      flat: true
    );

    setState(() { 
      _markers[const MarkerId('driver')] = marker; 
    });

    _updatePolylineForDriverLocation(position);

    _mapController.future.then((controller) => controller.animateCamera(CameraUpdate.newLatLng(position)));
  }

  void _updatePolylineForDriverLocation(LatLng driverLocation) {
    if (_currentPolylinePoints.isEmpty) return;
    
    final distance = latlong.Distance();
    int closestPointIndex = -1;
    double minDistance = double.infinity;

    for (int i = 0; i < _currentPolylinePoints.length; i++) {
      final point = _currentPolylinePoints[i];
      final d = distance.as(
        latlong.LengthUnit.Meter,
        latlong.LatLng(driverLocation.latitude, driverLocation.longitude),
        latlong.LatLng(point.latitude, point.longitude),
      );
      if (d < minDistance) {
        minDistance = d;
        closestPointIndex = i;
      }
    }
    
    if (closestPointIndex != -1) {
      setState(() {
        _currentPolylinePoints = _currentPolylinePoints.sublist(closestPointIndex);
        _drawPolyline(_currentPolylinePoints, 'active_route', _isDriverArrived ? const Color(0xFF27b4ad) : Colors.amber.shade700);
      });
    }
  }

  void _handleDriverArrived({bool fromInit = false}) {
    if (_isDriverArrived) return;
    
    setState(() {
      _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
      _currentPolylinePoints = List.from(_rideRoutePolylinePoints);
    });
    _drawPolyline(_currentPolylinePoints, 'active_route', const Color(0xFF27b4ad));


    if (!fromInit) {
      _rideData['initial_state'] = RideState.driverArrived.toString();
      _rideStateService.saveRideState(RideState.driverArrived, _rideData);
      
      _notificationService.showNotification(
        id: _rideData['rideId'].hashCode,
        title: 'Driver Arrived!',
        body: 'Your driver is at the pickup location. Please be ready.',
      );
    }

    if (mounted) {
       setState(() {
        _isDriverArrived = true;
        _rideStatusText = "Captain is waiting for pickup";
      });
    }
    
    _startWaitingTimer();
  }

  void _handleRideStarted({bool fromInit = false}) {
    if (!fromInit) {
      _rideData['initial_state'] = RideState.rideStarted.toString();
      _rideStateService.saveRideState(RideState.rideStarted, _rideData);
       _notificationService.showNotification(
        id: _rideData['rideId'].hashCode,
        title: 'Ride Started!',
        body: 'Your ride is now in progress. Enjoy your trip!',
      );
    }
    if (mounted) {
      setState(() {
        _isRideStarted = true;
        _isDriverArrived = false;
        _waitingTimer?.cancel();
        _rideStatusText = "You are on your way!";
      });
    }
  }

  void _handleEndRideOtp(String otp) {
    _rideStateService.saveRideState(RideState.rideStarted, {..._rideData, 'end_ride_otp': otp});
     _notificationService.showNotification(
        id: _rideData['rideId'].hashCode + 1,
        title: 'Almost there!',
        body: 'Share the OTP with your driver to end the ride.',
      );
    if (mounted) {
      setState(() {
        _endRideOtp = otp;
        _rideStatusText = "Share OTP to end ride";
      });
    }
  }

  void _handleRideCompleted() {
    _rideStateService.clearRideState();
     _notificationService.showNotification(
        id: _rideData['rideId'].hashCode + 2,
        title: 'Ride Completed!',
        body: 'Thank you for choosing RideFast.',
      );
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/ride-completed', arguments: _rideData);
    }
  }

  void _startWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_waitingSeconds > 0) {
        if (mounted) setState(() { _waitingSeconds--; });
      } else {
        timer.cancel();
      }
    });
  }

  void _addMarker({required String id, required LatLng position, required BitmapDescriptor icon}) {
    final markerId = MarkerId(id);
    final marker = Marker(markerId: markerId, position: position, icon: icon);
    if (mounted) setState(() { _markers[markerId] = marker; });
  }

  Color _getTimerColor() {
    if (_waitingSeconds <= 60) return Colors.red;
    if (_waitingSeconds <= 180) return Colors.orange;
    return const Color(0xFF27b4ad);
  }
  
  void _onCancelRide() async {
    _soundService.playRideCancelledSound();
    await _rideStateService.clearRideState();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _waitingTimer?.cancel();
    _soundService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driver = _rideData['driver'] as Map<String, dynamic>? ?? {};
    final vehicle = _rideData['vehicle'] as Map<String, dynamic>? ?? {};
    final startOtp = _rideData['otp'] as String? ?? '----';
    final driverName = driver['name'] as String? ?? 'Driver';
    final driverRating = (driver['rating'] as num?)?.toDouble() ?? 5.0;
    final driverPhotoUrl = driver['photo_url'] as String?;
    final vehicleModel = vehicle['model'] as String? ?? 'Vehicle';
    final licensePlate = vehicle['license_plate'] as String? ?? '-------';
    final pickupAddress = _rideData['pickup_address'] as String? ?? 'Not specified';
    final dropoffAddress = _rideData['dropoff_address'] as String? ?? 'Not specified';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
             if (_initialCameraPosition == null)
              const Center(child: CircularProgressIndicator())
            else
              GoogleMap(
                initialCameraPosition: _initialCameraPosition!,
                onMapCreated: (controller) => _mapController.complete(controller),
                markers: Set<Marker>.of(_markers.values),
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
            DraggableScrollableSheet(
              initialChildSize: 0.5, minChildSize: 0.5, maxChildSize: 0.75,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)],
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_rideStatusText, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold)),
                                  if (_isDriverArrived) Text('Waiting charges may apply', style: TextStyle(color: Colors.grey[600]))
                                ],
                              ),
                            ),
                            if (_isDriverArrived)
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(width: 50, height: 50, child: CircularProgressIndicator(value: _waitingSeconds / 300.0, strokeWidth: 5, backgroundColor: _getTimerColor().withOpacity(0.2), valueColor: AlwaysStoppedAnimation<Color>(_getTimerColor()))),
                                  Text('${(_waitingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_waitingSeconds % 60).toString().padLeft(2, '0')}', style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 14))
                                ],
                              )
                          ],
                        ),
                      ),
                       if (!_isRideStarted)
                        _buildOtpContainer(
                          label: 'Start your order with PIN', 
                          otp: startOtp
                        ),
                      if (_isRideStarted && _endRideOtp != null)
                         _buildOtpContainer(
                          label: 'Share PIN to end ride', 
                          otp: _endRideOtp!
                        ),
                      const SizedBox(height: 20),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(radius: 28, backgroundImage: driverPhotoUrl != null ? NetworkImage(driverPhotoUrl) : const AssetImage('assets/images/profile_pic.png') as ImageProvider),
                        title: Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Row(children: [Icon(Icons.star_rounded, color: Colors.amber[700], size: 20), Text(' ${driverRating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 16))]),
                        trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(licensePlate, style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 18)), 
                          Text(vehicleModel, style: TextStyle(color: Colors.grey[600]))
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.call_outlined), label: const Text('Call Driver'), onPressed: () {}, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.message_outlined), label: const Text('Message'), onPressed: () {}, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)))))]),
                      const Divider(height: 30),
                      ExpansionTile(
                        title: Text('Trip Details', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          ListTile(leading: const Icon(Icons.my_location, color: Colors.green), title: const Text('Pickup from'), subtitle: Text(pickupAddress)),
                          ListTile(leading: const Icon(Icons.location_on, color: Colors.red), title: const Text('Dropping at'), subtitle: Text(dropoffAddress)),
                          const SizedBox(height: 10),
                          if (!_isRideStarted)
                            TextButton.icon(
                              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                              label: Text('Cancel Ride', style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.bold)),
                              onPressed: _onCancelRide,
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
             if (_channel == null && !_isConnecting)
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: double.infinity,
                  color: Colors.amber[700],
                  padding: const EdgeInsets.all(8.0),
                  child: const Text(
                    'Reconnecting...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpContainer({required String label, required String otp}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF0FDFA), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: otp.split('').map((digit) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
              child: Text(digit, style: GoogleFonts.robotoMono(fontSize: 20, fontWeight: FontWeight.bold)),
            )).toList(),
          )
        ],
      ),
    );
  }
}