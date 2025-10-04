import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridefast/screens/dashboard_screen.dart'; // For Enums

/// A widget for selecting a vehicle type from a horizontal list.
class VehicleSelector extends StatelessWidget {
  final ServiceType selectedService;
  final VehicleType? selectedVehicle;
  final ValueChanged<VehicleType> onVehicleSelected;

  const VehicleSelector({
    super.key,
    required this.selectedService,
    required this.selectedVehicle,
    required this.onVehicleSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedService == ServiceType.parcel) {
      return _buildVehicleOption(
        iconPath: 'assets/images/parcel_icon.png',
        label: 'Parcel',
        price: '₹50', // Example price
        vehicleType: VehicleType.parcel,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildVehicleOption(
              iconPath: 'assets/images/bike_icon.png',
              label: 'Bike',
              price: '₹75',
              vehicleType: VehicleType.bike),
          _buildVehicleOption(
              iconPath: 'assets/images/auto_icon.png',
              label: 'Auto',
              price: '₹120',
              vehicleType: VehicleType.auto),
          _buildVehicleOption(
              iconPath: 'assets/images/mini_icon.png',
              label: 'Economy',
              price: '₹150',
              vehicleType: VehicleType.economy),
          _buildVehicleOption(
              iconPath: 'assets/images/sedan_icon.png',
              label: 'Premium',
              price: '₹180',
              vehicleType: VehicleType.premium),
          _buildVehicleOption(
              iconPath: 'assets/images/suv_icon.png',
              label: 'Extra XL',
              price: '₹220',
              vehicleType: VehicleType.xl),
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
    final bool isSelected = selectedVehicle == vehicleType;
    return GestureDetector(
      onTap: () => onVehicleSelected(vehicleType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2F1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF27b4ad) : Colors.transparent,
            width: 2,
          ),
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
