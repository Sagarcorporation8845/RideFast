import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridefast/screens/dashboard_screen.dart'; // For PaymentMethod enum

class PaymentSelector extends StatelessWidget {
  final PaymentMethod selectedPaymentMethod;
  final double walletBalance;
  final bool isWalletAvailable;
  final ValueChanged<PaymentMethod> onPaymentMethodSelected;

  const PaymentSelector({
    super.key,
    required this.selectedPaymentMethod,
    required this.walletBalance,
    required this.isWalletAvailable,
    required this.onPaymentMethodSelected,
  });

  String _getPaymentMethodText() {
    switch (selectedPaymentMethod) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.online:
        return 'Online';
      case PaymentMethod.wallet:
        return 'Wallet';
    }
  }

  IconData _getPaymentMethodIcon() {
    switch (selectedPaymentMethod) {
      case PaymentMethod.cash:
        return Icons.money_rounded;
      case PaymentMethod.online:
        return Icons.credit_card_rounded;
      case PaymentMethod.wallet:
        return Icons.account_balance_wallet_rounded;
    }
  }

  void _showPaymentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Payment Method',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              RadioListTile<PaymentMethod>(
                title: const Text('Cash'),
                value: PaymentMethod.cash,
                groupValue: selectedPaymentMethod,
                onChanged: (value) {
                  onPaymentMethodSelected(value!);
                  Navigator.pop(context);
                },
                activeColor: const Color(0xFF27b4ad),
              ),
              RadioListTile<PaymentMethod>(
                title: const Text('Online'),
                value: PaymentMethod.online,
                groupValue: selectedPaymentMethod,
                onChanged: (value) {
                  onPaymentMethodSelected(value!);
                  Navigator.pop(context);
                },
                activeColor: const Color(0xFF27b4ad),
              ),
              RadioListTile<PaymentMethod>(
                title: const Text('Wallet'),
                subtitle: Text(
                  isWalletAvailable
                      ? 'Balance: ₹${walletBalance.toStringAsFixed(2)}'
                      : 'Not available for this ride',
                  style: TextStyle(
                    color: isWalletAvailable ? Colors.green : Colors.grey,
                  ),
                ),
                value: PaymentMethod.wallet,
                groupValue: selectedPaymentMethod,
                onChanged: isWalletAvailable
                    ? (value) {
                        onPaymentMethodSelected(value!);
                        Navigator.pop(context);
                      }
                    : null, // Disable if not available
                activeColor: const Color(0xFF27b4ad),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showPaymentOptions(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getPaymentMethodIcon(),
                    color: Colors.grey[800],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getPaymentMethodText(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}