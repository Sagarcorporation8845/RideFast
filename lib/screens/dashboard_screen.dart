import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:ridefast/widgets/main_drawer.dart';

enum ServiceType { ride, parcel }
enum VehicleType { bike, auto, mini, sedan, suv, parcel }

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

  String _pickupLocationLabel = 'Pickup Location';
  String _destinationLabel = 'Destination';

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
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

      _addMarker(currentLatLng);

      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLatLng,
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      print('Could not get location: $e');
    }
  }

  void _addMarker(LatLng position) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: const InfoWindow(title: 'My Location'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text('RideFast', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
        ],
      ),
      drawer: const MainDrawer(),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            initialCameraPosition: const CameraPosition(
              target: LatLng(18.5204, 73.8567), // Default to Pune
              zoom: 12,
            ),
            markers: _markers,
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
                        _buildLocationField(
                          icon: Icons.my_location,
                          label: _pickupLocationLabel,
                          color: Colors.blue,
                          isPickup: true,
                        ),
                        const SizedBox(height: 12),
                        _buildLocationField(
                          icon: Icons.location_on,
                          label: _destinationLabel,
                          color: Colors.red,
                          isPickup: false,
                        ),
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
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _buildServiceButton(label: 'Ride', iconPath: 'assets/images/ride_icon.png', serviceType: ServiceType.ride)),
          Expanded(child: _buildServiceButton(label: 'Parcel', iconPath: 'assets/images/parcel_icon.png', serviceType: ServiceType.parcel)),
        ],
      ),
    );
  }

  Widget _buildServiceButton({
    required String label,
    required String iconPath,
    required ServiceType serviceType,
  }) {
    final bool isSelected = _selectedService == serviceType;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedService = serviceType;
          _selectedVehicle = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF27b4ad) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
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

  Widget _buildLocationField({
    required IconData icon,
    required String label,
    required Color color,
    required bool isPickup,
  }) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).pushNamed('/search');
        if (result != null && result is String) {
          setState(() {
            if (isPickup) {
              _pickupLocationLabel = result;
            } else {
              _destinationLabel = result;
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(color: Colors.grey[800], fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
          _buildVehicleOption(iconPath: 'assets/images/mini_icon.png', label: 'Mini', price: '₹150', vehicleType: VehicleType.mini),
          _buildVehicleOption(iconPath: 'assets/images/sedan_icon.png', label: 'Sedan', price: '₹180', vehicleType: VehicleType.sedan),
          _buildVehicleOption(iconPath: 'assets/images/suv_icon.png', label: 'SUV', price: '₹220', vehicleType: VehicleType.suv),
        ],
      ),
    );
  }

  Widget _buildVehicleOption({
    required String iconPath,
    required String label,
    required String price,
    required VehicleType vehicleType,
  }) {
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