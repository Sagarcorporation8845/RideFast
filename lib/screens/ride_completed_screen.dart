import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridefast/services/sound_service.dart';

class RideCompletedScreen extends StatefulWidget {
  const RideCompletedScreen({super.key});

  @override
  State<RideCompletedScreen> createState() => _RideCompletedScreenState();
}

class _RideCompletedScreenState extends State<RideCompletedScreen> with TickerProviderStateMixin {
  late AnimationController _checkAnimationController;
  late Animation<double> _checkAnimation;
  late AnimationController _confettiController;
  late List<ConfettiParticle> _confettiParticles;
  final SoundService _soundService = SoundService();

  @override
  void initState() {
    super.initState();
    _soundService.playRideCompletedSound();

    // Controller for the checkmark's "flip" and scale animation
    _checkAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Use an elastic curve for a bouncy, satisfying effect
    _checkAnimation = CurvedAnimation(
      parent: _checkAnimationController,
      curve: Curves.elasticOut,
    );

    // Controller for the confetti animation duration
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Generate a list of random particles for the confetti
    _confettiParticles = List.generate(100, (index) => ConfettiParticle());

    // Start the animations after the screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAnimationController.forward();
      _confettiController.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _checkAnimationController.dispose();
    _confettiController.dispose();
    _soundService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rideData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
    final pickupAddress = rideData['pickup_address'] ?? 'Start Point';
    final dropoffAddress = rideData['dropoff_address'] ?? 'Destination';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // The confetti animation layer
          CustomPaint(
            painter: ConfettiPainter(
              animation: _confettiController,
              particles: _confettiParticles,
            ),
            child: const SizedBox.expand(),
          ),
          // The main UI content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // Animated checkmark
                  ScaleTransition(
                    scale: _checkAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Color(0xFF27b4ad),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Ride Completed!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You have arrived at your destination.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      color: const Color(0xFF4A5568),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Ride details card
                  _buildRideDetailsCard(pickupAddress, dropoffAddress),
                  const Spacer(flex: 3),
                  // Done button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27b4ad),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideDetailsCard(String pickup, String destination) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.my_location,
            color: Colors.blue,
            label: 'Pickup',
            address: pickup,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 4, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 30,
                width: 2,
                color: Colors.grey[300],
              ),
            ),
          ),
          _buildLocationRow(
            icon: Icons.location_on,
            color: Colors.red,
            label: 'Destination',
            address: destination,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Custom Painter for Confetti ---

class ConfettiPainter extends CustomPainter {
  final Animation<double> animation;
  final List<ConfettiParticle> particles;

  ConfettiPainter({required this.animation, required this.particles}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    if (progress == 0 || progress == 1) return;

    for (var particle in particles) {
      // Calculate particle's current position
      final y = particle.startY + (size.height + 50) * progress * particle.speed; // Move from top to bottom
      final x = particle.startX + sin(progress * pi * particle.frequency) * particle.amplitude;

      final paint = Paint()..color = particle.color.withOpacity(1.0 - progress);

      // Save the canvas state, translate, rotate, draw, and restore
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * pi * 2 * particle.rotationSpeed);
      canvas.drawRect(Rect.fromLTWH(-5, -5, 10, 10), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- Data Model for a Single Confetti Particle ---

class ConfettiParticle {
  final Color color;
  final double startY;
  final double startX;
  final double speed;
  final double frequency;
  final double amplitude;
  final double rotationSpeed;

  ConfettiParticle()
      : color = _getRandomColor(),
        startY = -20 - (Random().nextDouble() * 200), // Start above the screen
        startX = Random().nextDouble() * 500, // Spread across the width
        speed = 0.5 + Random().nextDouble() * 0.8, // Varying speeds
        frequency = 2 + Random().nextDouble() * 4, // Varying sine wave frequency
        amplitude = 20 + Random().nextDouble() * 30, // Varying sine wave amplitude
        rotationSpeed = 0.5 + Random().nextDouble() * 2; // Varying rotation speed

  static Color _getRandomColor() {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
    ];
    return colors[Random().nextInt(colors.length)];
  }
}