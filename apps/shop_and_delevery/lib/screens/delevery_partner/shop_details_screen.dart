import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

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

  static const Color _primaryCyan = Color(0xFF00B4D8);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _successGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialShopData != null && widget.initialShopData!.isNotEmpty) {
      _shopData = widget.initialShopData!;
      _isLoading = false;
    }
    _fetchShopDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchShopDetails() async {
    if (widget.shopId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Try shop_owners collection
      final shopDoc = await FirebaseFirestore.instance
          .collection('shop_owners')
          .doc(widget.shopId)
          .get();

      if (shopDoc.exists && mounted) {
        setState(() {
          _shopData = shopDoc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
        return;
      }

      // 2. Fallback to users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.shopId)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _shopData = userDoc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
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
    final encoded = Uri.encodeComponent(address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
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
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'out_for_delivery',
        'deliveryBoyId': currentUser!.uid,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery Accepted!'),
            backgroundColor: _successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markDelivered(String orderId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'completed',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as Delivered!'),
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
                const SizedBox(height: 4),
                Row(
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
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _successGreen.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'Assigned to You',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
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
          return (status == 'pending' || status == 'ready_for_pickup' || status == 'placed') &&
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
            return (status == 'pending' || status == 'ready_for_pickup' || status == 'placed') &&
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
                  onPressed: () => _acceptDelivery(orderId),
                  icon: const Icon(Icons.check, size: 16, color: Colors.white),
                  label: const Text(
                    'Accept Delivery',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryCyan,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else if (isActive)
              Row(
                children: [
                  if (customerPhone.toString().isNotEmpty)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: () => _makePhoneCall(customerPhone.toString()),
                        icon: const Icon(Icons.phone, size: 15, color: _primaryCyan),
                        label: const Text('Call', style: TextStyle(color: _primaryCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _primaryCyan),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  if (customerPhone.toString().isNotEmpty) const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _markDelivered(orderId),
                      icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                      label: const Text(
                        'Mark Delivered',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _successGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
