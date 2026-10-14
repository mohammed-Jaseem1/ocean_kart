import 'package:flutter/material.dart';

class TermsPolicyScreen extends StatelessWidget {
  const TermsPolicyScreen({super.key});

  static const Color _primary = Color(0xFF00B4D8);
  static const Color _primaryDark = Color(0xFF0077B6);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  Widget _buildPolicySection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primaryDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Terms & Privacy Policy',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header summary banner (Poyoka style)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.security_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Your Privacy & Trust Matter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'At OceanKart, we are committed to delivering 100% chemical-free fresh seafood while safeguarding your personal data, delivery coordinates, and payment privacy with uncompromising standards.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Last Updated: October 2026 • Version 2.0',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Policy Sections (Poyoka style cards)
            _buildPolicySection(
              icon: Icons.water_drop_rounded,
              title: '1. Fresh Catch & Formalin-Free Guarantee',
              content:
                  'All fish, crustaceans, and marine catches featured on OceanKart are procured fresh on the morning of delivery from verified coastal harbors. We strictly prohibit the use of formalin, ammonia, or harmful chemical preservatives. Our seafood is preserved only using food-grade ice maintained between 0°C to 4°C during cutting, cleaning, and delivery.',
            ),

            _buildPolicySection(
              icon: Icons.scale_rounded,
              title: '2. Gross vs Net Cut Weight Transparency',
              content:
                  'Prices quoted represent whole fish gross catch weights unless explicitly indicated otherwise. When you choose cleaning options (such as descaling, gutting, headless, or filleting), naturally occurring weight reduction occurs (typically 15%–35% depending on fish anatomy). The approximate final net cut yield is clearly displayed before checkout.',
            ),

            _buildPolicySection(
              icon: Icons.payments_rounded,
              title: '3. Pricing & Cash on Delivery (COD)',
              content:
                  'We offer flexible payment options including doorstep Cash on Delivery (COD) and doorstep UPI QR payments. You will only pay the final order total confirmed on your digital bill. There are no surprise surcharge fees or unstated processing commissions.',
            ),

            _buildPolicySection(
              icon: Icons.verified_user_rounded,
              title: '4. 2-Hour Freshness Check & Replacement Policy',
              content:
                  'Because fresh seafood is perishable, we request customers to inspect the seal and aroma of the package upon delivery. In the rare event of quality inconsistency, report the issue through Help & Support within 2 hours of delivery with a quick photograph for an immediate replacement or full refund.',
            ),

            _buildPolicySection(
              icon: Icons.location_on_rounded,
              title: '5. Delivery Location & GPS Data Privacy',
              content:
                  'Your delivery coordinates and address are captured exclusively to calculate delivery routes, connect you with the nearest coastal partner hub, and guide delivery riders to your doorstep. We never sell, rent, or trade your address or contact information to marketing networks or third parties.',
            ),

            _buildPolicySection(
              icon: Icons.manage_accounts_rounded,
              title: '6. Account Erasure & Data Rights',
              content:
                  'You hold full ownership of your personal data. At any time, you can edit your profile information or request permanent account erasure directly from the "Delete Account" option inside the Help Center. Once confirmed, all your addresses, carts, and identity records are permanently purged.',
            ),

            _buildPolicySection(
              icon: Icons.headset_mic_rounded,
              title: '7. Customer Grievance & Support Desk',
              content:
                  'Have questions, feedback, or concerns regarding your order or our privacy practices? Contact our dedicated support team via WhatsApp, phone at +91 98765 43210, or email support@oceankart.com. Our care desk operates daily from 6:00 AM to 9:00 PM.',
            ),

            const SizedBox(height: 12),
            const Center(
              child: Text(
                '© 2026 OceanKart Fresh Marine Technologies Pvt Ltd. All rights reserved.',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
