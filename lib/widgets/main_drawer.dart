import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

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
            onTap: () => _navigateTo(context, '/payments'),
            iconColor: iconColor,
            textColor: textColor,
          ),
          _buildDrawerItem(
            icon: Icons.account_balance_wallet_outlined,
            text: 'RideFast Wallet',
            onTap: () => _navigateTo(context, '/wallet'),
            iconColor: iconColor,
            textColor: textColor,
          ),
          _buildDrawerItem(
            icon: Icons.local_offer_outlined,
            text: 'Promotions',
            onTap: () => _navigateTo(context, '/promotions'),
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
            onTap: () {
              // Handle logout logic
              Navigator.of(context).pushReplacementNamed('/signin');
            },
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
        "Hi Sagar!",
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      accountEmail: Text(
        "View and edit profile", // Subtitle to encourage interaction
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

  // **FIX IS HERE**
  // Helper method for navigation
  void _navigateTo(BuildContext context, String routeName) {
    // Closes the drawer first
    Navigator.pop(context);
    // **CHANGED**: Added the actual navigation command
    Navigator.pushNamed(context, routeName);
  }
}