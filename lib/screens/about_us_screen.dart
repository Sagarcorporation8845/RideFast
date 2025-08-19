import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // You can later get this version number dynamically from your pubspec.yaml
    const appVersion = '1.0.0+1';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'About Us',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // App Info Section
            Column(
              children: [
                const SizedBox(height: 20),
                Image.asset(
                  'assets/images/ride_icon.png', // Using ride_icon as a placeholder logo
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 16),
                Text(
                  'RideFast',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version $appVersion',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                ListTile(
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to Terms of Service page or URL
                  },
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to Privacy Policy page or URL
                  },
                ),
                const Divider(height: 1, indent: 16),
              ],
            ),

            // Copyright Section
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Text(
                '© 2025 Zenevo Innovations Pvt Ltd.\nAll rights reserved.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}