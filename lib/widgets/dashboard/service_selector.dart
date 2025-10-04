import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridefast/screens/dashboard_screen.dart'; // For the ServiceType enum

/// A widget that allows users to switch between 'Ride' and 'Parcel' services.
class ServiceSelector extends StatelessWidget {
  final ServiceType selectedService;
  final ValueChanged<ServiceType> onServiceSelected;

  const ServiceSelector({
    super.key,
    required this.selectedService,
    required this.onServiceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildServiceButton(
              label: 'Ride',
              iconPath: 'assets/images/ride_icon.png',
              serviceType: ServiceType.ride,
            ),
          ),
          Expanded(
            child: _buildServiceButton(
              label: 'Parcel',
              iconPath: 'assets/images/parcel_icon.png',
              serviceType: ServiceType.parcel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceButton({
    required String label,
    required String iconPath,
    required ServiceType serviceType,
  }) {
    final bool isSelected = selectedService == serviceType;
    return GestureDetector(
      onTap: () => onServiceSelected(serviceType),
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
            Image.asset(
              iconPath,
              width: 24,
              color: isSelected ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
