import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class FaqItem {
  final String id;
  final String question;
  final String answer;
  final String category;
  final int sortOrder;
  final bool isActive;

  FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    this.category = 'General',
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory FaqItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FaqItem(
      id: doc.id,
      question: data['question'] ?? '',
      answer: data['answer'] ?? '',
      category: data['category'] ?? 'General',
      sortOrder: data['sortOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }
}

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const Color _primary = Color(0xFF00B4D8);
  static const Color _primaryDark = Color(0xFF0077B6);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _errorRed = Color(0xFFEF4444);

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final Set<String> _expandedFaqIds = {};
  bool _isDeleteAccountExpanded = false;
  String _supportPhone = '+919876543210';

  List<FaqItem> _faqs = _getDefaultFaqs();

  static List<FaqItem> _getDefaultFaqs() {
    return [
      FaqItem(
        id: 'faq_1',
        question: 'How do you guarantee freshness of fish and seafood?',
        answer:
            'We procure fresh daily morning catches directly from local coastal harbors and verified fishermen. Our seafood is preserved with food-grade flake ice at temperatures between 0°C to 4°C, completely chemical-free and formalin-free, and delivered to your doorstep within hours.',
        category: 'Quality',
        sortOrder: 1,
      ),
      FaqItem(
        id: 'faq_2',
        question: 'Can I choose cleaning, cutting, and filleting styles?',
        answer:
            'Yes! On each product detail page, you can choose custom cuts: Whole Cleaned, Steaks / Curry Cut, Boneless Fillets, Headless, or Tail-off. Our expert fishmongers prepare your order hygienically just before dispatch.',
        category: 'Preparation',
        sortOrder: 2,
      ),
      FaqItem(
        id: 'faq_3',
        question: 'What is the difference between Gross Weight and Net Weight?',
        answer:
            'Gross weight refers to the weight of the fresh whole fish before cleaning or descaling. Net weight is the final usable weight after removing scales, fins, and viscera. We clearly mention the estimated net cut yield on each product card so there are no surprises.',
        category: 'Pricing',
        sortOrder: 3,
      ),
      FaqItem(
        id: 'faq_4',
        question: 'What payment options are available?',
        answer:
            'We support Cash on Delivery (COD) as well as UPI (Google Pay, PhonePe, Paytm) upon doorstep delivery. You can inspect the seafood package before completing your payment.',
        category: 'Payments',
        sortOrder: 4,
      ),
      FaqItem(
        id: 'faq_5',
        question: 'What is your cancellation and refund policy?',
        answer:
            'Because seafood is perishable, you can cancel an order free of charge before the shop begins cutting. If upon arrival the catch does not meet freshness standards, notify the delivery partner immediately or report within 2 hours for a no-questions-asked replacement or refund.',
        category: 'Returns',
        sortOrder: 5,
      ),
      FaqItem(
        id: 'faq_6',
        question: 'How fast is the delivery?',
        answer:
            'Most orders from your local neighborhood seafood partner are prepared and delivered within 45 to 90 minutes. You can track your order status in real time from the Orders tab.',
        category: 'Delivery',
        sortOrder: 6,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadFaqsFromFirestore();
    _loadPlatformSettings();
  }

  Future<void> _loadFaqsFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('faqs')
          .get(const GetOptions(source: Source.serverAndCache));
      if (snapshot.docs.isNotEmpty && mounted) {
        final items = snapshot.docs
            .map((doc) => FaqItem.fromFirestore(doc))
            .where((f) => f.isActive)
            .toList();
        items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        if (items.isNotEmpty) {
          final seen = <String>{};
          final unique = <FaqItem>[];
          for (final faq in items) {
            final key = faq.question.trim().toLowerCase();
            if (!seen.contains(key)) {
              seen.add(key);
              unique.add(faq);
            }
          }
          if (mounted && unique.isNotEmpty) {
            setState(() => _faqs = unique);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPlatformSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('platform').get();
      if (doc.exists && doc.data() != null && mounted) {
        final phone = (doc.data()!['supportPhone'] ?? doc.data()!['support_phone'] ?? '').toString().trim();
        if (phone.isNotEmpty) {
          setState(() {
            _supportPhone = phone;
          });
        }
      }
    } catch (_) {}
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFaq(String id) {
    setState(() {
      if (_expandedFaqIds.contains(id)) {
        _expandedFaqIds.remove(id);
      } else {
        _expandedFaqIds.add(id);
      }
    });
  }

  Future<void> _launchUrlHelper(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open contact option'),
            backgroundColor: _errorRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching: $e'), backgroundColor: _errorRed),
      );
    }
  }



  List<FaqItem> _filterFaqs(List<FaqItem> allFaqs) {
    if (_searchQuery.isEmpty) return allFaqs;
    return allFaqs.where((faq) {
      return faq.question.toLowerCase().contains(_searchQuery) ||
          faq.answer.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _showDeleteAccountDialog() {
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isConfirmed = confirmController.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Delete Account?',
              style: TextStyle(fontWeight: FontWeight.w700, color: _errorRed, fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete your account, saved addresses, cart items, order history, and personal profile data.',
                  style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Type DELETE to confirm:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textPrimary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  onChanged: (_) => setDialogState(() {}),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type DELETE',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _errorRed, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
              ),
              TextButton(
                onPressed: isConfirmed
                    ? () async {
                        Navigator.of(ctx).pop();
                        await _deleteAccount();
                      }
                    : null,
                style: TextButton.styleFrom(
                  disabledForegroundColor: const Color(0xFF9CA3AF),
                ),
                child: Text(
                  'Delete',
                  style: TextStyle(
                    color: isConfirmed ? _errorRed : const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _errorRed),
      ),
    );

    try {
      // 1. Delete cart
      try {
        final cartDocs = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('cart')
            .get();
        for (var doc in cartDocs.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Cart deletion error: $e');
      }

      // 2. Delete addresses
      try {
        final addrDocs = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('addresses')
            .get();
        for (var doc in addrDocs.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Address deletion error: $e');
      }

      // 3. Delete user root document
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      } catch (e) {
        debugPrint('User doc deletion error: $e');
      }

      // 4. Delete user auth
      try {
        await user.delete();
      } on FirebaseAuthException catch (authErr) {
        debugPrint('Auth delete note: $authErr');
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        await FirebaseAuth.instance.signOut();
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account permanently deleted.'),
            backgroundColor: _errorRed,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: _errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Help Center',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _primary,
          onRefresh: _loadFaqsFromFirestore,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input (Poyoka style)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A1A1A)),
                    decoration: InputDecoration(
                      hintText: 'Search help topics, catch freshness, refunds...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA0AEC0)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF718096)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF718096)),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // FAQ Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Frequently Asked Questions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (_expandedFaqIds.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _expandedFaqIds.clear()),
                        child: const Text(
                          'Collapse All',
                          style: TextStyle(
                            fontSize: 12,
                            color: _primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Live FAQs Accordion List
                ..._buildFaqList(),
                const SizedBox(height: 24),

                // ── Direct Support Channels (Poyoka 2-column style) ─────
                const Text(
                  'Need Instant Assistance?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Connect directly with our seafood support desk for quick resolutions.',
                  style: TextStyle(fontSize: 12.5, color: _textSecondary),
                ),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () {
                    final uri = Uri.parse('tel:$_supportPhone');
                    _launchUrlHelper(uri);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.phone_in_talk_rounded,
                            size: 20,
                            color: _primaryDark,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Call Support Care Desk',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _supportPhone,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Danger Zone: Delete Account (Collapsible Accordion Card) ──
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDeleteAccountExpanded
                          ? _errorRed.withValues(alpha: 0.3)
                          : const Color(0xFFE5E7EB),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header (tappable to expand/collapse)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _isDeleteAccountExpanded = !_isDeleteAccountExpanded),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _errorRed.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person_remove_rounded,
                                  color: _errorRed,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Delete Account',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isDeleteAccountExpanded
                                          ? 'Permanently delete your account and data'
                                          : 'Tap to view account deletion options',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _isDeleteAccountExpanded
                                      ? _errorRed.withValues(alpha: 0.1)
                                      : const Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isDeleteAccountExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: _isDeleteAccountExpanded ? _errorRed : _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Collapsed Body
                      if (_isDeleteAccountExpanded) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 18, color: _errorRed),
                                  SizedBox(width: 8),
                                  Text(
                                    'Warning: This action is permanent',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _errorRed,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Deleting your account is permanent. All your profile information, order history, saved delivery addresses, and cart items will be permanently erased and cannot be recovered.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _showDeleteAccountDialog,
                                  icon: const Icon(Icons.delete_forever_rounded, size: 18, color: _errorRed),
                                  label: const Text(
                                    'Proceed to Delete Account',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _errorRed,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: _errorRed, width: 1.3),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }



  List<Widget> _buildFaqList() {
    final filtered = _filterFaqs(_faqs);

    if (filtered.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Column(
            children: [
              Icon(Icons.help_outline_rounded, size: 36, color: Color(0xFF9CA3AF)),
              SizedBox(height: 10),
              Text(
                'No matching questions found',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
              ),
              SizedBox(height: 4),
              Text(
                'Try a different search word or submit a support ticket below.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ];
    }

    return filtered.map((faq) {
      final isExpanded = _expandedFaqIds.contains(faq.id);

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded ? _primary.withValues(alpha: 0.4) : const Color(0xFFEBEBEB),
            width: 1.0,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleFaq(faq.id),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        faq.question,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isExpanded ? _primaryDark : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: isExpanded ? _primaryDark : _textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Divider(height: 1, color: Color(0xFFF3F4F6)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Text(
                  faq.answer,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF555555),
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }
}
