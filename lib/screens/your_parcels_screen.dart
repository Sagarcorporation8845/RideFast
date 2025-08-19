import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Data model for a past parcel delivery
class ParcelHistoryItem {
  final String date;
  final String pickup;
  final String destination;
  final String price;
  final String status;
  final String itemName;

  const ParcelHistoryItem({
    required this.date,
    required this.pickup,
    required this.destination,
    required this.price,
    required this.status,
    required this.itemName,
  });
}

class YourParcelsScreen extends StatelessWidget {
  const YourParcelsScreen({super.key});

  // Sample data for the parcel history
  final List<ParcelHistoryItem> parcelHistory = const [
    ParcelHistoryItem(
      date: 'Aug 16, 2025, 11:00 AM',
      pickup: 'Kothrud, Pune',
      destination: 'Hinjewadi, Pune',
      price: '₹150',
      status: 'Delivered',
      itemName: 'Documents',
    ),
    ParcelHistoryItem(
      date: 'Aug 12, 2025, 2:30 PM',
      pickup: 'Andheri, Mumbai',
      destination: 'Thane West',
      price: '₹300',
      status: 'In Transit',
      itemName: 'Laptop Box',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Parcels',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView.builder(
        itemCount: parcelHistory.length,
        itemBuilder: (context, index) {
          final parcel = parcelHistory[index];
          return ParcelHistoryCard(parcel: parcel);
        },
      ),
    );
  }
}

// A reusable card widget to display a single parcel history item
class ParcelHistoryCard extends StatelessWidget {
  final ParcelHistoryItem parcel;

  const ParcelHistoryCard({super.key, required this.parcel});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  parcel.itemName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  parcel.price,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              parcel.date,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const Divider(height: 24),
            _buildLocationRow(
              icon: Icons.my_location,
              location: parcel.pickup,
              color: Colors.blue,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Container(
                height: 20,
                width: 2,
                color: Colors.grey[300],
              ),
            ),
            _buildLocationRow(
              icon: Icons.location_on,
              location: parcel.destination,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                parcel.status,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: parcel.status == 'Delivered' ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String location,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            location,
            style: GoogleFonts.plusJakartaSans(fontSize: 15),
          ),
        ),
      ],
    );
  }
}