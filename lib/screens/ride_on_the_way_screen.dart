import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ridefast/services/local_notification_service.dart';
import 'package:ridefast/services/ride_state_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

  // Ride and Driver Data State
  Map<String, dynamic> _rideData = {};
  String _rideStatusText = "Captain is on the way!";
  bool _isDriverArrived = false;

  // WebSocket, Timer, and Notification State
  WebSocketChannel? _channel;
  Timer? _waitingTimer;
  int _waitingSeconds = 300; // 5 minutes
  final _storage = const FlutterSecureStorage();
  final _rideStateService = RideStateService();
  final LocalNotificationService _notificationService = LocalNotificationService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rideData.isEmpty) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
      setState(() { _rideData = args; });
      _initializeScreen();
    }
  }

  Future<void> _initializeScreen() async {
    // Load custom marker icons
    _driverIcon = await BitmapDescriptor.fromAssetImage(const ImageConfiguration(size: Size(48, 48)), 'assets/images/top-view-car.png');
    _pickupIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    _dropoffIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

    _connectToWebSocket();

    final pickupLatLng = LatLng(_rideData['pickup_lat'] ?? 18.4522, _rideData['pickup_lng'] ?? 73.8655);
    final dropoffLatLng = LatLng(_rideData['dropoff_lat'] ?? 18.5204, _rideData['dropoff_lng'] ?? 73.8567);

    _addMarker(id: 'pickup', position: pickupLatLng, icon: _pickupIcon!);
    _addMarker(id: 'dropoff', position: dropoffLatLng, icon: _dropoffIcon!);

    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(pickupLatLng.latitude < dropoffLatLng.latitude ? pickupLatLng.latitude : dropoffLatLng.latitude, pickupLatLng.longitude < dropoffLatLng.longitude ? pickupLatLng.longitude : dropoffLatLng.longitude),
        northeast: LatLng(pickupLatLng.latitude > dropoffLatLng.latitude ? pickupLatLng.latitude : dropoffLatLng.latitude, pickupLatLng.longitude > dropoffLatLng.longitude ? pickupLatLng.longitude : dropoffLatLng.longitude),
      ), 100.0,
    ));

    if (_rideData['initial_state'] == RideState.driverArrived.toString()) {
      _handleDriverArrived(fromInit: true);
    }
  }

  Future<void> _connectToWebSocket() async {
    final token = await _storage.read(key: 'auth_token');
    final websocketUrl = dotenv.env['WEBSOCKET_URL'];
    if (token == null || websocketUrl == null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(websocketUrl), protocols: ["customer-protocol", token]);
      _channel!.stream.listen((message) {
        final decoded = jsonDecode(message);
        switch (decoded['type']) {
          case 'DRIVER_LOCATION_UPDATE':
            final payload = decoded['payload'];
            _updateDriverMarker(LatLng(payload['latitude'], payload['longitude']));
            break;
          case 'DRIVER_ARRIVED':
            _handleDriverArrived();
            break;
        }
      });
    } catch (e) {
      debugPrint("WebSocket Connection Error: $e");
    }
  }

  void _updateDriverMarker(LatLng position) {
    final marker = Marker(markerId: const MarkerId('driver'), position: position, icon: _driverIcon!, anchor: const Offset(0.5, 0.5), flat: true);
    setState(() { _markers[const MarkerId('driver')] = marker; });
  }

  void _handleDriverArrived({bool fromInit = false}) {
    if (_isDriverArrived) return;
    
    if (!fromInit) {
      _rideData['initial_state'] = RideState.driverArrived.toString();
      _rideStateService.saveRideState(RideState.driverArrived, _rideData);
      
      _notificationService.showNotification(
        id: _rideData['rideId'].hashCode,
        title: 'Driver Arrived!',
        body: 'Your driver is at the pickup location. Please be ready.',
      );
    }

    setState(() {
      _isDriverArrived = true;
      _rideStatusText = "Captain is waiting for pickup";
    });
    
    _startWaitingTimer();
  }

  void _startWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_waitingSeconds > 0) {
        setState(() { _waitingSeconds--; });
      } else {
        timer.cancel();
      }
    });
  }

  void _addMarker({required String id, required LatLng position, required BitmapDescriptor icon}) {
    final markerId = MarkerId(id);
    final marker = Marker(markerId: markerId, position: position, icon: icon);
    setState(() { _markers[markerId] = marker; });
  }

  Color _getTimerColor() {
    if (_waitingSeconds <= 60) return Colors.red;
    if (_waitingSeconds <= 180) return Colors.orange;
    return const Color(0xFF27b4ad);
  }
  
  void _onCancelRide() async {
    await _rideStateService.clearRideState();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _waitingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driver = _rideData['driver'] as Map<String, dynamic>? ?? {};
    final vehicle = _rideData['vehicle'] as Map<String, dynamic>? ?? {};
    final otp = _rideData['otp'] as String? ?? '----';
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
            GoogleMap(
              initialCameraPosition: const CameraPosition(target: LatLng(18.5204, 73.8567), zoom: 14),
              onMapCreated: (controller) => _mapController.complete(controller),
              markers: Set<Marker>.of(_markers.values),
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFFF0FDFA), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('Start your order with PIN', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 16)),
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
          ],
        ),
      ),
    );
  }
}

