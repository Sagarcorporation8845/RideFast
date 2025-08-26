import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// **CHANGED**: Converted to a StatefulWidget to manage user data
class MainDrawer extends StatefulWidget {
  const MainDrawer({super.key});

  @override
  State<MainDrawer> createState() => _MainDrawerState();
}

class _MainDrawerState extends State<MainDrawer> {
  String _userName = "Guest"; // Default name

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // **NEW**: Function to load user data from SharedPreferences
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userDataString = prefs.getString('user_profile');

    if (userDataString != null) {
      final Map<String, dynamic> userData = jsonDecode(userDataString);
      // The key from your backend is 'full_name'
      setState(() {
        _userName = userData['full_name'] ?? "Guest";
      });
    }
  }

  void _logout(BuildContext context) async {
    final storage = const FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();

    // Clear all saved authentication and user data
    await storage.delete(key: 'auth_token');
    await prefs.remove('user_profile');

    // Navigate to the sign-in screen and remove all previous screens from the stack
    if (Navigator.of(context).mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF27b4ad);
    const textColor = Color(0xFF4A5568);
    const iconColor = Color(0xFF718096);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // --- DRAWER HEADER ---
          _buildDrawerHeader(primaryColor),

          // --- BOOKINGS SECTION ---
          _buildDrawerItem(
            icon: Icons.history,
            text: 'Your Rides',
            onTap: () => _navigateTo(context, '/rides'),
            iconColor: iconColor,
            textColor: textColor,
          ),
          _buildDrawerItem(
            icon: Icons.local_shipping_outlined,
            text: 'Your Parcels',
            onTap: () => _navigateTo(context, '/parcels'),
            iconColor: iconColor,
            textColor: textColor,
          ),
          _buildDrawerItem(
            icon: Icons.schedule,
            text: 'Scheduled Bookings',
            onTap: () => _navigateTo(context, '/scheduled'),
            iconColor: iconColor,
            textColor: textColor,
          ),

          const Divider(thickness: 1, indent: 16, endIndent: 16),

          // --- PAYMENTS & WALLET SECTION ---
          _buildDrawerItem(
            icon: Icons.payment,
            text: 'Payments',
            onTap: () {}, // TODO: Add payments route
            iconColor: iconColor,
            textColor: textColor,
          ),
          _buildDrawerItem(
            icon: Icons.account_balance_wallet_outlined,
            text: 'RideFast Wallet',
            onTap: () {}, // TODO: Add wallet route
            iconColor: iconColor,
            textColor: textColor,
          ),
          _buildDrawerItem(
            icon: Icons.local_offer_outlined,
            text: 'Promotions',
            onTap: () {}, // TODO: Add promotions route
            iconColor: iconColor,
            textColor: textColor,
          ),

          const Divider(thickness: 1, indent: 16, endIndent: 16),

          // --- SUPPORT & SETTINGS SECTION ---
          _buildDrawerItem(
            icon: Icons.support_agent,
            text: 'Support',
            onTap: () => _navigateTo(context, '/support'),
            iconColor: iconColor,
            textColor: textColor,
          ),
          _buildDrawerItem(
            icon: Icons.settings_outlined,
            text: 'Settings',
            onTap: () => _navigateTo(context, '/settings'),
            iconColor: iconColor,
            textColor: textColor,
          ),
          _buildDrawerItem(
            icon: Icons.info_outline,
            text: 'About Us',
            onTap: () => _navigateTo(context, '/about'),
            iconColor: iconColor,
            textColor: textColor,
          ),
           const Divider(thickness: 1, indent: 16, endIndent: 16),

          // --- LOGOUT ---
          _buildDrawerItem(
            icon: Icons.logout,
            text: 'Logout',
            onTap: () => _logout(context),
            iconColor: iconColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  // Helper widget for the drawer header
  Widget _buildDrawerHeader(Color primaryColor) {
    return UserAccountsDrawerHeader(
      accountName: Text(
        // **CHANGED**: Using the dynamic user name
        "Hi $_userName!",
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      accountEmail: Text(
        "View and edit profile",
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
      currentAccountPicture: const CircleAvatar(
        backgroundImage: AssetImage('assets/images/profile_pic.png'),
        radius: 40,
      ),
      decoration: BoxDecoration(
        color: primaryColor,
      ),
      margin: EdgeInsets.zero,
    );
  }

  // Helper widget for each menu item
  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
    required Color iconColor,
    required Color textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 26),
      title: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  // Helper method for navigation
  void _navigateTo(BuildContext context, String routeName) {
    // Closes the drawer first
    Navigator.pop(context);
    Navigator.pushNamed(context, routeName);
  }
}
