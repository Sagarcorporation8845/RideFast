import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Data model for an FAQ item
class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  // Sample data for FAQs
  final List<FaqItem> faqs = const [
    FaqItem(
      question: 'How do I cancel a ride?',
      answer:
          'You can cancel a ride directly from the booking screen before a driver is assigned. If a driver is assigned, a cancellation fee may apply.',
    ),
    FaqItem(
      question: 'What are the payment options?',
      answer:
          'We support payments via UPI, credit/debit cards, net banking, and the RideFast Wallet. You can also pay with cash directly to the driver.',
    ),
    FaqItem(
      question: 'How is the fare calculated?',
      answer:
          'Fares are calculated based on the base price, distance, and duration of the ride. Surge pricing may apply during peak hours.',
    ),
    FaqItem(
      question: 'Can I send a parcel to another city?',
      answer:
          'Currently, our parcel services are limited to within city limits. We are working on expanding our services to inter-city deliveries soon.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF27b4ad);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Contact Us Section ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Contact Us',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.call_outlined, color: primaryColor),
                    title: const Text('Call Support'),
                    subtitle: const Text('Talk to our support agent'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Implement call functionality
                    },
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: primaryColor),
                    title: const Text('Email Us'),
                    subtitle: const Text('Get a response within 24 hours'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Implement email functionality
                    },
                  ),
                ],
              ),
            ),

            // --- FAQs Section ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Frequently Asked Questions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: faqs.length,
              itemBuilder: (context, index) {
                final faq = faqs[index];
                return ExpansionTile(
                  title: Text(
                    faq.question,
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600),
                  ),
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        faq.answer,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.grey[700]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}