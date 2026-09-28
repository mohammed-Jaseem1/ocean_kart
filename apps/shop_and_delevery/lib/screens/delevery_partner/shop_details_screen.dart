import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class ShopDetailsScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic>? initialShopData;

  const ShopDetailsScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    this.initialShopData,
  });

  @override
  State<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> with SingleTickerProviderStateMixin {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic> _shopData = {};
  List<String> _partnerAssignedShopIds = [];
  double? _partnerLat;
  double? _partnerLon;
  String _partnerName = '';
  String _partnerPhone = '';

  static const Color _primaryCyan = Color(0xFF00B4D8);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _successGreen = Color(0xFF10B981);

  bool get _isShopAssigned => _partnerAssignedShopIds.contains(widget.shopId);

  String? get _distanceText {
    final double? shopLat = (_shopData['latitude'] ?? _shopData['lat']) is num
        ? ((_shopData['latitude'] ?? _shopData['lat']) as num).toDouble()
        : null;
    final double? shopLon = (_shopData['longitude'] ?? _shopData['lon'] ?? _shopData['lng']) is num
        ? ((_shopData['longitude'] ?? _shopData['lon'] ?? _shopData['lng']) as num).toDouble()
        : null;

    if (_partnerLat != null && _partnerLon != null && shopLat != null && shopLon != null) {
      final meters = Geolocator.distanceBetween(_partnerLat!, _partnerLon!, shopLat, shopLon);
      return meters >= 1000
          ? '${(meters / 1000).toStringAsFixed(1)} km away'
          : '${meters.toStringAsFixed(0)} m away';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialShopData != null && widget.initialShopData!.isNotEmpty) {
      _shopData = widget.initialShopData!;
      _isLoading = false;
    }
    _fetchDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    try {
      // 1. Fetch current delivery partner profile for store assignments & location
      if (currentUser != null) {
        final pDoc = await FirebaseFirestore.instance
            .collection('delivery_partners')
            .doc(currentUser!.uid)
            .get();
        if (pDoc.exists) {
          final pData = pDoc.data() ?? {};
          _partnerAssignedShopIds = List<String>.from(pData['assignedShopIds'] ?? []);
          _partnerLat = (pData['latitude'] as num?)?.toDouble();
          _partnerLon = (pData['longitude'] as num?)?.toDouble();
          _partnerName = (pData['name'] ?? currentUser?.displayName ?? 'Delivery Partner').toString();
          _partnerPhone = (pData['mobileNumber'] ?? pData['phone'] ?? '').toString();
        }
      }

      // 2. Fetch Shop details
      if (widget.shopId.isNotEmpty) {
        final shopDoc = await FirebaseFirestore.instance
            .collection('shop_owners')
            .doc(widget.shopId)
            .get();

        if (shopDoc.exists) {
          _shopData = shopDoc.data() as Map<String, dynamic>;
        } else {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.shopId)
              .get();
          if (userDoc.exists) {
            _shopData = userDoc.data() as Map<String, dynamic>;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching details in ShopDetailsScreen: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dial $phoneNumber')),
      );
    }
  }

  Future<void> _openDirections(String address) async {
    if (address.isEmpty || address == 'N/A') return;
    final double? shopLat = (_shopData['latitude'] ?? _shopData['lat']) is num
        ? ((_shopData['latitude'] ?? _shopData['lat']) as num).toDouble()
        : null;
    final double? shopLon = (_shopData['longitude'] ?? _shopData['lon'] ?? _shopData['lng']) is num
        ? ((_shopData['longitude'] ?? _shopData['lon'] ?? _shopData['lng']) as num).toDouble()
        : null;

    final query = (shopLat != null && shopLon != null)
        ? '$shopLat,$shopLon'
        : Uri.encodeComponent(address);

    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map directions')),
      );
    }
  }

  Future<void> _acceptDelivery(String orderId) async {
    if (currentUser == null) return;

    if (!_isShopAssigned) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied: This store is not assigned to you by OceanKart Admin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
    String? customerId;
    String? shopId;
    final String shortOrderId = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
    final String partnerName = _partnerName.isNotEmpty ? _partnerName : 'Delivery Partner';

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(orderRef);
        if (!snap.exists) {
          throw Exception('Order does not exist.');
        }

        final orderData = snap.data() as Map<String, dynamic>;
        final currentStatus = (orderData['status'] ?? '').toString().toLowerCase();

        // Concurrency lock: check status
        if (currentStatus != 'ready_for_delivery' && currentStatus != 'ready_for_pickup') {
          throw Exception('ALREADY_ACCEPTED');
        }

        customerId = orderData['userId']?.toString();
        shopId = orderData['shopId']?.toString();

        transaction.update(orderRef, {
          'status': 'out_for_delivery',
          'deliveryBoyId': currentUser!.uid,
          if (_partnerName.isNotEmpty) 'deliveryBoyName': _partnerName,
          if (_partnerPhone.isNotEmpty) 'deliveryBoyPhone': _partnerPhone,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      // 1. Notify Customer
      if (customerId != null && customerId!.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(customerId!)
              .collection('notifications')
              .add({
            'title': 'Order Out for Delivery',
            'body': 'Your order #$shortOrderId is out for delivery with $partnerName${_partnerPhone.isNotEmpty ? ' ($_partnerPhone)' : ''}.',
            'type': 'order',
            'orderId': orderId,
            'isRead': false,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error notifying customer: $e');
        }
      }

      // 2. Notify Shop Owner
      if (shopId != null && shopId!.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('shop_owners')
              .doc(shopId!)
              .collection('notifications')
              .add({
            'title': 'Order Picked Up',
            'body': 'Order #$shortOrderId was picked up for delivery by $partnerName.',
            'type': 'order',
            'orderId': orderId,
            'isRead': false,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error notifying shopkeeper: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery Accepted! Status set to Out for Delivery.'),
            backgroundColor: _successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isAlreadyAccepted = e.toString().contains('ALREADY_ACCEPTED');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAlreadyAccepted
                  ? 'This order has already been accepted by another delivery partner.'
                  : 'Failed to accept: $e',
            ),
            backgroundColor: isAlreadyAccepted ? Colors.orange : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markDelivered(String orderId, double total, {String? customerId, String? shopId}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Cash Collection',
          style: TextStyle(fontWeight: FontWeight.w800, color: _textDark, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Have you collected the full cash payment for this COD delivery?',
              style: TextStyle(fontSize: 13.5, color: _textMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cash to Collect (COD):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _textDark)),
                  Text(
                    '₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _successGreen),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _successGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm & Deliver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      final partnerName = _partnerName.isNotEmpty ? _partnerName : 'Delivery Partner';
      final String shortOrderId = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
      final targetShopId = shopId != null && shopId.isNotEmpty ? shopId : widget.shopId;

      await orderRef.update({
        'status': 'completed',
        'deliveredAt': FieldValue.serverTimestamp(),
        'paymentStatus': 'paid',
      });

      // 1. Increment Shopkeeper aggregated stats (completedOrders & totalRevenue)
      if (targetShopId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('shop_owners').doc(targetShopId).set({
            'completedOrders': FieldValue.increment(1),
            'totalRevenue': FieldValue.increment(total),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error updating shop stats: $e');
        }
      }

      // 2. Notify Customer (no keyboard emojis)
      if (customerId != null && customerId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(customerId)
              .collection('notifications')
              .add({
            'title': 'Order Delivered',
            'body': 'Your order #$shortOrderId has been successfully delivered. Thank you for shopping with OceanKart.',
            'type': 'order',
            'orderId': orderId,
            'isRead': false,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error notifying customer: $e');
        }
      }

      // 3. Notify Shopkeeper (no keyboard emojis)
      if (targetShopId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('shop_owners')
              .doc(targetShopId)
              .collection('notifications')
              .add({
            'title': 'Order Delivered by Partner',
            'body': 'Order #$shortOrderId has been marked as delivered by $partnerName. Total amount: ₹${total.toStringAsFixed(0)}.',
            'type': 'order',
            'orderId': orderId,
            'isRead': false,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error notifying shopkeeper: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order Marked as Delivered! Payment collected.'),
            backgroundColor: _successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reportDeliveryIssue(String orderId, {String? customerId, String? shopId}) async {
    String selectedReason = 'Customer unreachable / phone switched off';
    final notesController = TextEditingController();

    final reasons = [
      'Customer unreachable / phone switched off',
      'Customer refused delivery / COD payment',
      'Incorrect / incomplete delivery address',
      'Customer cancelled at doorstep',
      'Delivery location inaccessible / bad weather',
    ];

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.report_problem_outlined, color: Colors.redAccent, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Unable to Deliver Order',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textDark),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _textMuted, size: 20),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select the reason this order could not be completed:',
                    style: TextStyle(fontSize: 13, color: _textMuted),
                  ),
                  const SizedBox(height: 12),
                  ...reasons.map((r) {
                    final isSelected = selectedReason == r;
                    return InkWell(
                      onTap: () => setSheetState(() => selectedReason = r),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.redAccent.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? Colors.redAccent : _cardBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? Colors.redAccent : _textMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.redAccent.shade700 : _textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Additional notes / explanation (optional)',
                      hintStyle: const TextStyle(fontSize: 12.5, color: _textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _cardBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Back', style: TextStyle(color: _textMuted, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Confirm Undelivered', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (confirmed != true) return;

    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      final partnerName = _partnerName.isNotEmpty ? _partnerName : 'Delivery Partner';
      final String shortOrderId = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
      final targetShopId = shopId != null && shopId.isNotEmpty ? shopId : widget.shopId;
      final additionalNotes = notesController.text.trim();

      await orderRef.update({
        'status': 'undelivered',
        'undeliveredReason': selectedReason,
        if (additionalNotes.isNotEmpty) 'undeliveredNotes': additionalNotes,
        'undeliveredAt': FieldValue.serverTimestamp(),
      });

      // 1. Notify Customer (no keyboard emojis)
      if (customerId != null && customerId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(customerId)
              .collection('notifications')
              .add({
            'title': 'Delivery Attempt Unsuccessful',
            'body': 'Your order #$shortOrderId could not be delivered: $selectedReason.',
            'type': 'order',
            'orderId': orderId,
            'isRead': false,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error notifying customer: $e');
        }
      }

      // 2. Notify Shopkeeper (no keyboard emojis)
      if (targetShopId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('shop_owners')
              .doc(targetShopId)
              .collection('notifications')
              .add({
            'title': 'Order Delivery Failed',
            'body': 'Order #$shortOrderId could not be delivered by $partnerName. Reason: $selectedReason.',
            'type': 'order',
            'orderId': orderId,
            'isRead': false,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error notifying shopkeeper: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as undelivered. Customer and shopkeeper notified.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _shopData['shopName'] ??
        _shopData['name'] ??
        (widget.shopName.isNotEmpty ? widget.shopName : 'Store Details');
    final phone = _shopData['phone'] ?? _shopData['mobileNumber'] ?? 'N/A';
    final address = _shopData['shopAddress'] ??
        _shopData['address'] ??
        _shopData['location'] ??
        'N/A';
    final isShopActive = _shopData['isStoreOpen'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          displayName,
          style: const TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: _textDark),
        actions: [
          if (address != 'N/A')
            IconButton(
              icon: const Icon(Icons.directions, color: _primaryCyan),
              tooltip: 'Directions',
              onPressed: () => _openDirections(address),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryCyan),
              ),
            )
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Hero Card
                          _buildStoreHeroCard(displayName, isShopActive),
                          if (!_isShopAssigned) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'This store is not assigned to you. OceanKart Admin manages store assignments.',
                                      style: TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Contact & Location Card
                          _buildInfoCard(phone, address),
                          const SizedBox(height: 14),

                          // Orders Summary & Tabs Header
                          _buildOrdersSummaryCard(),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarHeaderDelegate(
                      tabBar: TabBar(
                        controller: _tabController,
                        labelColor: _primaryCyan,
                        unselectedLabelColor: _textMuted,
                        indicatorColor: _primaryCyan,
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        tabs: const [
                          Tab(text: 'Available'),
                          Tab(text: 'My Deliveries'),
                          Tab(text: 'Completed'),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrdersStream(filter: 'available'),
                  _buildOrdersStream(filter: 'active'),
                  _buildOrdersStream(filter: 'completed'),
                ],
              ),
            ),
    );
  }

  Widget _buildStoreHeroCard(String displayName, bool isShopActive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0096C7), Color(0xFF00B4D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primaryCyan.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isShopActive ? Icons.check_circle : Icons.pause_circle_outline,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isShopActive ? 'Active Store' : 'Closed Now',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isShopAssigned
                            ? _successGreen.withValues(alpha: 0.35)
                            : Colors.red.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _isShopAssigned ? 'Assigned to You' : 'Not Assigned',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_distanceText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              _distanceText!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String phone, String address) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Store Contact & Details',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: phone,
          ),
          const Divider(height: 18, color: _cardBorder),
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Store Address',
            value: address,
            actionIcon: Icons.directions,
            actionLabel: 'Map',
            onAction: address != 'N/A' ? () => _openDirections(address) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    IconData? actionIcon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _primaryCyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: _primaryCyan),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, color: _textMuted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _textDark),
              ),
            ],
          ),
        ),
        if (actionIcon != null && onAction != null) ...[
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon, size: 14, color: Colors.white),
            label: Text(actionLabel ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryCyan,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              elevation: 0,
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOrdersSummaryCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final oShopId = data['shopId'] ?? '';
          final oShopName = data['shopName'] ?? '';
          return (widget.shopId.isNotEmpty && oShopId == widget.shopId) ||
              (widget.shopName.isNotEmpty && oShopName == widget.shopName);
        }).toList();

        final availableCount = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          final boyId = data['deliveryBoyId'];
          return (status == 'ready_for_delivery' || status == 'ready_for_pickup') &&
              (boyId == null || boyId == '');
        }).length;

        final myActiveCount = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          final boyId = data['deliveryBoyId'];
          return (status == 'out_for_delivery' || status == 'accepted' || status == 'in_transit') &&
              boyId == currentUser?.uid;
        }).length;

        final completedCount = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          return status == 'completed' || status == 'delivered';
        }).length;

        return Row(
          children: [
            _buildStatBox('Ready', '$availableCount', const Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            _buildStatBox('My Active', '$myActiveCount', _primaryCyan),
            const SizedBox(width: 8),
            _buildStatBox('Delivered', '$completedCount', _successGreen),
          ],
        );
      },
    );
  }

  Widget _buildStatBox(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11.5, color: _textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersStream({required String filter}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_primaryCyan),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyOrdersState('No orders found for this store.');
        }

        final allOrders = snapshot.data!.docs;

        // Filter orders for this shop
        final shopOrders = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final oShopId = data['shopId'] ?? '';
          final oShopName = data['shopName'] ?? '';
          return (widget.shopId.isNotEmpty && oShopId == widget.shopId) ||
              (widget.shopName.isNotEmpty && oShopName == widget.shopName);
        }).toList();

        // Apply tab filter
        final filtered = shopOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          final boyId = data['deliveryBoyId'];

          if (filter == 'available') {
            return (status == 'ready_for_delivery' || status == 'ready_for_pickup') &&
                (boyId == null || boyId == '');
          } else if (filter == 'active') {
            return (status == 'out_for_delivery' || status == 'accepted' || status == 'in_transit') &&
                boyId == currentUser?.uid;
          } else if (filter == 'completed') {
            return (status == 'completed' || status == 'delivered');
          }
          return true;
        }).toList();

        // Sort descending by date
        filtered.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTime = aData?['createdAt'] as Timestamp?;
          final bTime = bData?['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (filtered.isEmpty) {
          final msg = filter == 'available'
              ? 'No new available orders waiting for pickup.'
              : filter == 'active'
                  ? 'No active in-progress deliveries right now.'
                  : 'No completed deliveries recorded yet.';
          return _buildEmptyOrdersState(msg);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final orderDoc = filtered[index];
            final orderData = orderDoc.data() as Map<String, dynamic>;
            final orderId = orderDoc.id;
            return _buildOrderCard(orderId, orderData, filter);
          },
        );
      },
    );
  }

  Widget _buildEmptyOrdersState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 36, color: _primaryCyan),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(String orderId, Map<String, dynamic> data, String filter) {
    final items = List<dynamic>.from(data['items'] ?? []);
    final address = data['deliveryAddress'] ?? data['address'] ?? 'Customer Address';
    final customerPhone = data['customerPhone'] ?? data['userPhone'] ?? data['phone'] ?? '';
    final totalAmount = data['totalAmount'] ?? data['total'] ?? 0;
    final isAvailable = filter == 'available';
    final isActive = filter == 'active';
    final isCompleted = filter == 'completed';
    final isUndelivered = data['status'] == 'undelivered';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID & Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _primaryCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: _primaryCyan, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Order #${orderId.length > 6 ? orderId.substring(orderId.length - 6).toUpperCase() : orderId.toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹$totalAmount',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _primaryCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Items List
            if (items.isNotEmpty) ...[
              Text(
                items.map((i) => '${i['name'] ?? 'Item'} x${i['quantity'] ?? 1}').join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: _textDark, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
            ],

            // Customer Delivery Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_pin, size: 14, color: _textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: _textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons
            if (isAvailable)
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: _isShopAssigned ? () => _acceptDelivery(orderId) : null,
                  icon: Icon(_isShopAssigned ? Icons.check : Icons.lock_outline, size: 16, color: Colors.white),
                  label: Text(
                    _isShopAssigned ? 'Accept Delivery' : 'Store Not Assigned',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isShopAssigned ? _primaryCyan : Colors.grey.shade400,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else if (isActive)
              Row(
                children: [
                  if (customerPhone.toString().isNotEmpty) ...[
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: () => _makePhoneCall(customerPhone.toString()),
                        icon: const Icon(Icons.phone, size: 14, color: _primaryCyan),
                        label: const Text('Call', style: TextStyle(color: _primaryCyan, fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _primaryCyan),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: () => _reportDeliveryIssue(
                        orderId,
                        customerId: data['userId']?.toString(),
                        shopId: (data['shopId'] ?? widget.shopId)?.toString(),
                      ),
                      icon: const Icon(Icons.report_problem_outlined, size: 14, color: Colors.redAccent),
                      label: const Text('Issue', style: TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _markDelivered(
                        orderId,
                        (totalAmount is num) ? totalAmount.toDouble() : double.tryParse(totalAmount.toString()) ?? 0.0,
                        customerId: data['userId']?.toString(),
                        shopId: (data['shopId'] ?? widget.shopId)?.toString(),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 15, color: Colors.white),
                      label: const Text(
                        'Mark Delivered',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _successGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                ],
              )
            else if (isCompleted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: _successGreen, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Delivered Successfully',
                      style: TextStyle(color: _successGreen, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              )
            else if (isUndelivered)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        data['undeliveredReason'] != null
                            ? 'Undelivered: ${data['undeliveredReason']}'
                            : 'Delivery Unsuccessful',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarHeaderDelegate({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarHeaderDelegate oldDelegate) {
    return false;
  }
}
