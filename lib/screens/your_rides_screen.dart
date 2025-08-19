import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// A simple data model for a past ride
class RideHistoryItem {
  final String date;
  final String pickup;
  final String destination;
  final String price;
  final String status; // e.g., 'Completed', 'Cancelled'

  const RideHistoryItem({
    required this.date,
    required this.pickup,
    required this.destination,
    required this.price,
    required this.status,
  });
}

class YourRidesScreen extends StatelessWidget {
  const YourRidesScreen({super.key});

  // Sample data for the ride history
  final List<RideHistoryItem> rideHistory = const [
    RideHistoryItem(
      date: 'Aug 17, 2025, 10:30 AM',
      pickup: 'Wadki, Maharashtra',
      destination: 'Pune Airport, Pune',
      price: '₹250',
      status: 'Completed',
    ),
    RideHistoryItem(
      date: 'Aug 15, 2025, 5:45 PM',
      pickup: 'Swargate, Pune',
      destination: 'Koregaon Park, Pune',
      price: '₹120',
      status: 'Completed',
    ),
    RideHistoryItem(
      date: 'Aug 14, 2025, 9:00 AM',
      pickup: 'Mumbai Central',
      destination: 'Bandra West',
      price: '₹350',
      status: 'Cancelled',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Rides',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView.builder(
        itemCount: rideHistory.length,
        itemBuilder: (context, index) {
          final ride = rideHistory[index];
          return RideHistoryCard(ride: ride);
        },
      ),
    );
  }
}

// A reusable card widget to display a single ride history item
class RideHistoryCard extends StatelessWidget {
  final RideHistoryItem ride;

  const RideHistoryCard({super.key, required this.ride});

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
                  ride.date,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  ride.price,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildLocationRow(
              icon: Icons.my_location,
              location: ride.pickup,
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
              location: ride.destination,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                ride.status,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: ride.status == 'Completed' ? Colors.green : Colors.red,
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