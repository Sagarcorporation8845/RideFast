import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridefast/models/fare_option.dart';
import 'package:shimmer/shimmer.dart';

class VehicleSelector extends StatelessWidget {
  final List<FareOption> fareOptions;
  final FareOption? selectedOption;
  final Function(FareOption) onVehicleSelected;
  final bool isLoading;
  final String? errorMessage;

  const VehicleSelector({
    super.key,
    required this.fareOptions,
    this.selectedOption,
    required this.onVehicleSelected,
    this.isLoading = false,
    this.errorMessage,
  });

  // Predefined order for sorting the vehicle list
  static const _sortOrder = {
    'bike': 0,
    'auto': 1,
    'car_economy': 2,
    'car_premium': 3,
    'car_xl': 4,
  };

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildSkeletonLoader();
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    
    if (fareOptions.isEmpty) {
       return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Text("Select a pickup and drop-off to see available rides."),
        ),
      );
    }

    // Sort the list before building it
    final sortedOptions = List<FareOption>.from(fareOptions);
    sortedOptions.sort((a, b) {
      final aOrder = _sortOrder[a.sortKey] ?? 99;
      final bOrder = _sortOrder[b.sortKey] ?? 99;
      return aOrder.compareTo(bOrder);
    });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedOptions.length,
      itemBuilder: (context, index) {
        final option = sortedOptions[index];
        final bool isSelected = selectedOption?.fareId == option.fareId;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? const Color(0xFF27b4ad) : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => onVehicleSelected(option),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? const Color(0xFFE0F2F1) : Colors.white,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Image.asset(option.imagePath, width: 60, height: 60),
                title: Text(
                  option.displayName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'Hassle-free rides',
                  style: GoogleFonts.plusJakartaSans(color: Colors.black54),
                ),
                trailing: Text(
                  '₹${option.amount.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(3, (index) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(width: 60, height: 60, color: Colors.white),
            title: Container(width: 120, height: 16, color: Colors.white),
            subtitle: Container(width: 100, height: 12, margin: const EdgeInsets.only(top: 4), color: Colors.white),
            trailing: Container(width: 50, height: 20, color: Colors.white),
          ),
        )),
      ),
    );
  }
}

