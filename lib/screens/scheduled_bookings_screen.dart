import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Data model for a scheduled booking
class ScheduledBooking {
  final String date;
  final String time;
  final String pickup;
  final String destination;
  final String bookingType; // 'Ride' or 'Parcel'
  final IconData icon;

  const ScheduledBooking({
    required this.date,
    required this.time,
    required this.pickup,
    required this.destination,
    required this.bookingType,
    required this.icon,
  });
}

class ScheduledBookingsScreen extends StatelessWidget {
  const ScheduledBookingsScreen({super.key});

  // Sample data for scheduled bookings
  final List<ScheduledBooking> scheduledBookings = const [
    ScheduledBooking(
      date: 'Aug 20, 2025',
      time: '9:00 AM',
      pickup: 'Home',
      destination: 'Office',
      bookingType: 'Ride',
      icon: Icons.directions_car,
    ),
    ScheduledBooking(
      date: 'Aug 22, 2025',
      time: '1:00 PM',
      pickup: 'Main Warehouse',
      destination: 'Client Office, Koregaon Park',
      bookingType: 'Parcel',
      icon: Icons.inventory_2_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scheduled Bookings',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      // **ADDED**: Floating Action Button to add new bookings
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the main dashboard to create a new booking
          Navigator.of(context).pushNamed('/dashboard');
        },
        backgroundColor: const Color(0xFF27b4ad),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: scheduledBookings.isEmpty
          ? Center(
              child: Text(
                'No upcoming bookings.',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: scheduledBookings.length,
              itemBuilder: (context, index) {
                final booking = scheduledBookings[index];
                return ScheduledBookingCard(booking: booking);
              },
            ),
    );
  }
}

// A reusable card widget for a single scheduled booking
class ScheduledBookingCard extends StatelessWidget {
  final ScheduledBooking booking;
  const ScheduledBookingCard({super.key, required this.booking});

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
              children: [
                Icon(booking.icon, color: const Color(0xFF27b4ad), size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.bookingType,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${booking.date} at ${booking.time}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            _buildLocationRow(
              icon: Icons.my_location,
              location: booking.pickup,
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
              location: booking.destination,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Handle cancel logic
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Handle modify logic
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Modify'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(
      {required IconData icon, required String location, required Color color}) {
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