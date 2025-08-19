import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        children: [
          // --- Profile Section ---
          _buildSectionHeader('Profile'),
          _buildSettingsTile(
            context,
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Change your name, phone number, email',
            onTap: () {},
          ),

          // --- Notifications Section ---
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            title: Text(
              'Push Notifications',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Receive updates about your rides and promotions',
              style: GoogleFonts.plusJakartaSans(),
            ),
            secondary: const Icon(Icons.notifications_outlined),
            value: _pushNotificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _pushNotificationsEnabled = value;
              });
            },
            activeColor: const Color(0xFF27b4ad),
          ),

          // --- Saved Places Section ---
          _buildSectionHeader('Saved Places'),
          _buildSettingsTile(
            context,
            icon: Icons.home_outlined,
            title: 'Home',
            subtitle: 'Add or edit your home address',
            onTap: () {},
          ),
          _buildSettingsTile(
            context,
            icon: Icons.work_outline,
            title: 'Work',
            subtitle: 'Add or edit your work address',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // Helper widget for section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: Colors.grey[600],
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // Helper widget for a standard settings list tile
  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 28),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}