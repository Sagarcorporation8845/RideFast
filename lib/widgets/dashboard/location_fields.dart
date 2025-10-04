import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A widget to display pickup and destination location fields.
class LocationFields extends StatelessWidget {
  final String pickupLabel;
  final String destinationLabel;
  final VoidCallback onPickupTap;
  final VoidCallback onDestinationTap;

  const LocationFields({
    super.key,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.onPickupTap,
    required this.onDestinationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildLocationField(
          icon: Icons.my_location,
          label: pickupLabel,
          color: Colors.blue,
          onTap: onPickupTap,
        ),
        const SizedBox(height: 12),
        _buildLocationField(
          icon: Icons.location_on,
          label: destinationLabel,
          color: Colors.red,
          onTap: onDestinationTap,
        ),
      ],
    );
  }

  Widget _buildLocationField({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey[800],
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
