import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_screen.dart';
import 'shop_details_screen.dart';
import 'assigned_stores_screen.dart';

class DeliveryPartnerDashboard extends StatefulWidget {
  const DeliveryPartnerDashboard({super.key});

  @override
  State<DeliveryPartnerDashboard> createState() =>
      _DeliveryPartnerDashboardState();
}

class _DeliveryPartnerDashboardState extends State<DeliveryPartnerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  // Deliveries Tab Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDayFilter = 'All Time'; // 'All Time', 'Today', 'Yesterday', 'This Week', 'This Month'
  String _selectedStatusFilter = 'All'; // 'All', 'out_for_delivery', 'completed', 'cancelled'

  static const Color _primaryCyan = Color(0xFF00B4D8);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _acceptDelivery(String orderId) async {
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {'status': 'out_for_delivery', 'deliveryBoyId': currentUser!.uid},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery Accepted!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markDelivered(String orderId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {'status': 'completed'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as Delivered!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: _textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Active',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: _textDark,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'You are ready to receive delivery orders.',
                              style: TextStyle(fontSize: 12, color: _textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month} $hour:$minute';
    }
    return timestamp.toString();
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Available Orders';
      case 1:
        return 'My Deliveries';
      case 2:
        return 'Partner Profile';
      default:
        return 'Delivery Dashboard';
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildAvailableOrdersTab();
      case 1:
        return _buildDeliveriesScreen();
      case 2:
        return const ProfileScreen(isTab: true);
      default:
        return _buildAvailableOrdersTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text("Please login")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: _textDark, size: 24),
            onPressed: _showNotifications,
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: _cardBorder, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: _primaryCyan,
          unselectedItemColor: _textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: 'Available',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.two_wheeler_outlined),
              activeIcon: Icon(Icons.two_wheeler_rounded),
              label: 'Deliveries',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryBoyId', isEqualTo: currentUser!.uid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        int totalOrders = 0;
        double totalAmountCollected = 0.0;
        int todayOrders = 0;
        double todayAmountCollected = 0.0;

        if (snapshot.hasData) {
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final double amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

            totalOrders++;
            totalAmountCollected += amount;

            if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
              final date = (data['createdAt'] as Timestamp).toDate();
              if (date.isAfter(startOfDay) || date.isAtSameMomentAs(startOfDay)) {
                todayOrders++;
                todayAmountCollected += amount;
              }
            }
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primaryCyan.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Earnings & Orders Overview",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Today\'s Orders',
                    todayOrders.toString(),
                    Icons.today_rounded,
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  _buildStatItem(
                    'Today\'s Collected',
                    '₹${todayAmountCollected.toStringAsFixed(0)}',
                    Icons.payments_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Total Orders',
                    totalOrders.toString(),
                    Icons.receipt_long_rounded,
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  _buildStatItem(
                    'Total Collected',
                    '₹${totalAmountCollected.toStringAsFixed(0)}',
                    Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==================== AVAILABLE ORDERS TAB ====================
  Widget _buildAvailableOrdersTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('delivery_partners')
          .doc(currentUser!.uid)
          .snapshots(),
      builder: (context, userSnap) {
        final userData = (userSnap.data?.data() as Map<String, dynamic>?) ?? {};
        final List<String> assignedShopIds = List<String>.from(userData['assignedShopIds'] ?? []);
        final List<String> assignedShopNames = List<String>.from(userData['assignedShopNames'] ?? []);

        return Column(
          children: [
            _buildStatsHeader(),

            // Store Assignment Banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AssignedStoresScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: assignedShopIds.isNotEmpty
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.storefront,
                              color: assignedShopIds.isNotEmpty
                                  ? const Color(0xFF10B981)
                                  : Colors.amber.shade800,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      assignedShopIds.isNotEmpty
                                          ? 'Assigned Stores (${assignedShopNames.length})'
                                          : 'No Stores Assigned Yet',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: _textDark,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_ios, size: 11, color: _textMuted),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  assignedShopIds.isNotEmpty
                                      ? 'Tap to view all stores, details & orders'
                                      : 'OceanKart Admin assigns your delivery stores.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (assignedShopIds.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${assignedShopIds.length} Active',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (assignedShopIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: List.generate(
                        assignedShopNames.isNotEmpty ? assignedShopNames.length : assignedShopIds.length,
                        (index) {
                          final name = assignedShopNames.isNotEmpty
                              ? assignedShopNames[index]
                              : assignedShopIds[index];
                          final id = index < assignedShopIds.length ? assignedShopIds[index] : '';

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ShopDetailsScreen(
                                    shopId: id,
                                    shopName: name,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _primaryCyan.withValues(alpha: 0.35)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                                  const SizedBox(width: 6),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _textDark,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 15, color: _primaryCyan),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Recent 5 Orders Section (Shown in Available Tab as requested)
            _buildRecentFiveOrdersCard(),

            // Section Header: Available Orders for Delivery
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: _primaryCyan, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Available Orders for Delivery',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
            ),

            // Orders Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('status', isEqualTo: 'ready_for_delivery')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_primaryCyan),
                      ),
                    );
                  }

                  final allOrders = snapshot.data!.docs;

                  // Filter orders strictly based on admin-assigned shop IDs
                  final filteredOrders = assignedShopIds.isNotEmpty
                      ? allOrders.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final orderShopId = data['shopId'] ?? '';
                          return assignedShopIds.contains(orderShopId);
                        }).toList()
                      : <DocumentSnapshot>[];

                  if (assignedShopIds.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.store_outlined, size: 36, color: _primaryCyan),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Awaiting Store Assignment',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Your account has not been assigned to any stores yet.\nOceanKart Admin will assign your delivery stores.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _textMuted, fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final docs = List<DocumentSnapshot>.from(filteredOrders);
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>?;
                    final bData = b.data() as Map<String, dynamic>?;
                    final aTime = aData?['createdAt'] as Timestamp?;
                    final bTime = bData?['createdAt'] as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  return _buildOrdersList(docs, isAvailable: true);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Recent 5 Orders Preview in Available Tab
  Widget _buildRecentFiveOrdersCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryBoyId', isEqualTo: currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = List<DocumentSnapshot>.from(snapshot.data!.docs);
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTime = aData?['createdAt'] as Timestamp?;
          final bTime = bData?['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        final recentDocs = docs.take(5).toList();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history_rounded, size: 16, color: _primaryCyan),
                      SizedBox(width: 6),
                      Text(
                        'Recent Orders (Last 5)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => setState(() => _currentIndex = 1),
                    child: const Text(
                      'View All in Deliveries →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _primaryCyan,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: recentDocs.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final data = recentDocs[index].data() as Map<String, dynamic>;
                    final orderId = recentDocs[index].id;
                    final status = (data['status'] ?? '').toString();
                    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                    final timeStr = _formatTimestamp(data['createdAt']);
                    final isDelivered = status == 'completed' || status == 'delivered';

                    return Container(
                      width: 140,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '#${orderId.substring(0, orderId.length >= 6 ? 6 : orderId.length).toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _textDark),
                              ),
                              Text(
                                '₹${total.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: _textDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeStr,
                            style: const TextStyle(fontSize: 10, color: _textMuted),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDelivered
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isDelivered ? 'Delivered' : status.replaceAll('_', ' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isDelivered ? const Color(0xFF10B981) : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== DELIVERIES SCREEN (Full with Search + Day + Status filters) ====================
  Widget _buildDeliveriesScreen() {
    return Column(
      children: [
        // 1. Search Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            style: const TextStyle(fontSize: 13.5, color: _textDark),
            decoration: InputDecoration(
              hintText: 'Search by order #, customer, address, item...',
              hintStyle: const TextStyle(fontSize: 13, color: _textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: _textMuted, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: _textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            ),
          ),
        ),

        // 2. Horizontal Day Filter
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _buildDayChip('All Time'),
              _buildDayChip('Today'),
              _buildDayChip('Yesterday'),
              _buildDayChip('This Week'),
              _buildDayChip('This Month'),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // 3. Status Filter Below
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _buildStatusChip('All', 'All'),
              _buildStatusChip('out_for_delivery', 'Out for Delivery'),
              _buildStatusChip('completed', 'Delivered'),
              _buildStatusChip('cancelled', 'Cancelled'),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // 4. Deliveries Stream List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('deliveryBoyId', isEqualTo: currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error loading deliveries: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryCyan),
                  ),
                );
              }

              final allDocs = List<DocumentSnapshot>.from(snapshot.data!.docs);

              // Sort in memory by createdAt descending
              allDocs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>?;
                final bData = b.data() as Map<String, dynamic>?;
                final aTime = aData?['createdAt'] as Timestamp?;
                final bTime = bData?['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              // Apply Filters
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final yesterdayStart = todayStart.subtract(const Duration(days: 1));
              final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
              final monthStart = DateTime(now.year, now.month, 1);

              final filtered = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = (data['status'] ?? '').toString();
                final orderId = doc.id.toLowerCase();
                final phone = (data['phone'] ?? '').toString().toLowerCase();
                final address = (data['deliveryAddress'] ?? '').toString().toLowerCase();
                final customerName = (data['customerName'] ?? data['name'] ?? '').toString().toLowerCase();
                final shopName = (data['shopName'] ?? '').toString().toLowerCase();
                final items = (data['items'] as List<dynamic>?) ?? [];

                // 1. Status Filter
                if (_selectedStatusFilter != 'All') {
                  if (_selectedStatusFilter == 'completed') {
                    if (status != 'completed' && status != 'delivered') return false;
                  } else if (status != _selectedStatusFilter) {
                    return false;
                  }
                }

                // 2. Day Filter
                if (_selectedDayFilter != 'All Time') {
                  final ts = data['createdAt'] as Timestamp?;
                  if (ts == null) return false;
                  final date = ts.toDate();

                  if (_selectedDayFilter == 'Today') {
                    if (date.isBefore(todayStart)) return false;
                  } else if (_selectedDayFilter == 'Yesterday') {
                    if (date.isBefore(yesterdayStart) || date.isAfter(todayStart)) return false;
                  } else if (_selectedDayFilter == 'This Week') {
                    if (date.isBefore(weekStart)) return false;
                  } else if (_selectedDayFilter == 'This Month') {
                    if (date.isBefore(monthStart)) return false;
                  }
                }

                // 3. Search Query
                if (_searchQuery.isNotEmpty) {
                  bool matchesItem = items.any((item) {
                    final itemMap = item as Map<String, dynamic>?;
                    final itemName = (itemMap?['name'] ?? '').toString().toLowerCase();
                    return itemName.contains(_searchQuery);
                  });

                  bool matchesSearch = orderId.contains(_searchQuery) ||
                      phone.contains(_searchQuery) ||
                      address.contains(_searchQuery) ||
                      customerName.contains(_searchQuery) ||
                      shopName.contains(_searchQuery) ||
                      matchesItem;

                  if (!matchesSearch) return false;
                }

                return true;
              }).toList();

              return _buildOrdersList(filtered, isAvailable: false);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayChip(String label) {
    final bool isSelected = _selectedDayFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          if (val) setState(() => _selectedDayFilter = label);
        },
        selectedColor: _primaryCyan,
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : _textDark,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? _primaryCyan : _cardBorder,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  Widget _buildStatusChip(String value, String label) {
    final bool isSelected = _selectedStatusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedStatusFilter = value),
        selectedColor: _primaryCyan.withValues(alpha: 0.15),
        backgroundColor: Colors.white,
        checkmarkColor: _primaryCyan,
        labelStyle: TextStyle(
          color: isSelected ? _primaryCyan : _textMuted,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 11.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? _primaryCyan : _cardBorder,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

  Widget _buildOrdersList(
    List<DocumentSnapshot> docs, {
    required bool isAvailable,
  }) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 56,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isAvailable
                  ? 'No available orders right now.'
                  : 'No matching deliveries found.',
              style: const TextStyle(color: _textMuted, fontSize: 14.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final String orderId = docs[index].id;
        final String status = data['status'] ?? 'pending';
        final double total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final String phone = data['phone'] ?? 'N/A';
        final String address = data['deliveryAddress'] ?? 'N/A';
        final double? deliveryLat = (data['deliveryLat'] as num?)?.toDouble();
        final double? deliveryLon = (data['deliveryLon'] as num?)?.toDouble();
        final items = data['items'] as List<dynamic>? ?? [];

        final bool isDelivered = status == 'completed' || status == 'delivered';
        final bool isOutForDelivery = status == 'out_for_delivery';

        String timeStr = 'N/A';
        if (data['createdAt'] is Timestamp) {
          final dt = (data['createdAt'] as Timestamp).toDate();
          final hr = dt.hour.toString().padLeft(2, '0');
          final mn = dt.minute.toString().padLeft(2, '0');
          timeStr = '${dt.day}/${dt.month}/${dt.year} $hr:$mn';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order ID + Amount + Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDelivered
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : (isAvailable
                                    ? _primaryCyan.withValues(alpha: 0.1)
                                    : (isOutForDelivery
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : Colors.grey.withValues(alpha: 0.1))),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Order #${orderId.substring(0, orderId.length >= 8 ? 8 : orderId.length).toUpperCase()}',
                            style: TextStyle(
                              color: isDelivered
                                  ? const Color(0xFF10B981)
                                  : (isAvailable
                                      ? _primaryCyan
                                      : (isOutForDelivery
                                          ? Colors.orange.shade800
                                          : _textMuted)),
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDelivered
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : (isOutForDelivery
                                      ? Colors.amber.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.12)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isDelivered ? 'Delivered' : status.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDelivered
                                    ? const Color(0xFF10B981)
                                    : (isOutForDelivery ? Colors.amber.shade900 : _textMuted),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '₹$total',
                      style: const TextStyle(
                        color: _textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  timeStr,
                  style: const TextStyle(fontSize: 11, color: _textMuted),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: _cardBorder),
                const SizedBox(height: 12),

                // Customer Details
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline, size: 15, color: _textDark),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Customer Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: _textMuted,
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        if (phone != 'N/A' && phone.isNotEmpty) {
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        }
                      },
                      child: Text(
                        phone,
                        style: const TextStyle(
                          color: _primaryCyan,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: _textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            address,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final query = (deliveryLat != null && deliveryLon != null)
                                  ? '$deliveryLat,$deliveryLon'
                                  : Uri.encodeComponent(address);
                              final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not open map.')),
                                  );
                                }
                              }
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.navigation_outlined, size: 14, color: _primaryCyan),
                                SizedBox(width: 4),
                                Text(
                                  'Navigate on Google Maps',
                                  style: TextStyle(
                                    color: _primaryCyan,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: _cardBorder),
                const SizedBox(height: 12),

                // Items Preview
                const Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 15,
                      color: _primaryCyan,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Items in Order',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final itemMap = item as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${itemMap['name']} x ${itemMap['quantity']}',
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '₹${(itemMap['price'] as num?)?.toDouble() ?? 0.0}',
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Action Buttons
                if (isAvailable)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptDelivery(orderId),
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 17),
                      label: const Text(
                        'Accept Delivery',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryCyan,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else if (isOutForDelivery)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _markDelivered(orderId),
                      icon: const Icon(Icons.done_all, color: Colors.white, size: 17),
                      label: const Text(
                        'Mark as Delivered',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else if (isDelivered)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Delivered Successfully',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
