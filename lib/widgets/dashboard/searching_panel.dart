import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchingPanel extends StatelessWidget {
  final VoidCallback onCancelSearch;
  final String vehicleTypeName;
 
  const SearchingPanel({
    super.key,
    required this.onCancelSearch,
    required this.vehicleTypeName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(blurRadius: 10.0, color: Colors.black12),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/searching.gif',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 16),
            Text(
              'Looking for your',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '$vehicleTypeName ride',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              backgroundColor: Colors.grey[200],
              color: const Color(0xFF27b4ad),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCancelSearch,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
