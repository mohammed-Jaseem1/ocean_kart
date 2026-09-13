import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inventory/add_product_screen.dart';
import 'inventory/inventory_home_screen.dart';
import 'profile_screen.dart';
import 'orders_screen.dart';
import '../common/notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  int todayOrders = 0;
  int pendingOrders = 0;
  int completedOrders = 0;
  double totalRevenue = 0.0;
  bool isLoading = true;

  String _shopName = 'My Store';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (currentUser == null) return;
    
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: currentUser!.uid)
          .get();
          
      int today = 0;
      int pending = 0;
      int completed = 0;
      double revenue = 0.0;
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        
        if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
           final Timestamp ts = data['createdAt'];
           final date = ts.toDate();
           if (date.isAfter(startOfDay)) {
             today++;
           }
        } else {
           today++; 
        }

        if (status == 'pending') {
          pending++;
        } else if (status == 'completed' || status == 'delivered') {
          completed++;
          revenue += (data['totalAmount'] ?? data['amount'] ?? 0.0).toDouble();
        }
      }

      // Also fetch shop details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      
      String shopName = 'My Store';

      if (userDoc.exists) {
        final uData = userDoc.data() as Map<String, dynamic>;
        shopName = uData['shopName'] ?? uData['name'] ?? 'My Store';
      }

      if (mounted) {
        setState(() {
          todayOrders = today;
          pendingOrders = pending;
          completedOrders = completed;
          totalRevenue = revenue;
          _shopName = shopName;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyBlue = Color(0xFF0A1628);
    const lightBlue = Color(0xFF00B4D8);
    const backgroundWhite = Color(0xFFF5F7FA); // A light greyish white for modern contrast

    final List<Widget> pages = [
      _buildDashboardContent(context, navyBlue, lightBlue),
      const InventoryHomeScreen(),
      const OrdersScreen(isHistory: false),
      const OrdersScreen(isHistory: true),
    ];

    return Scaffold(
      backgroundColor: backgroundWhite,
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // Notification Icon with dynamic unread badge
          StreamBuilder<QuerySnapshot>(
            stream: currentUser != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .collection('notifications')
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                    );
                  },
                  tooltip: 'Notifications',
                );
              }
              final docs = snapshot.data?.docs ?? [];
              final unreadCount = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['isRead'] != true && data['read'] != true;
              }).length;

              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                    if (unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B4D8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                },
                tooltip: 'Notifications',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            tooltip: 'Store Profile',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              selectedItemColor: lightBlue,
              unselectedItemColor: const Color(0xFF94A3B8),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconSize: 20,
              selectedFontSize: 11.5,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 3.0),
                    child: Icon(Icons.dashboard_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 3.0),
                    child: Icon(Icons.dashboard_rounded),
                  ),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 3.0),
                    child: Icon(Icons.inventory_2_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 3.0),
                    child: Icon(Icons.inventory_2_rounded),
                  ),
                  label: 'Inventory',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 3.0),
                    child: Icon(Icons.receipt_long_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 3.0),
                    child: Icon(Icons.receipt_long_rounded),
                  ),
                  label: 'New Orders',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 3.0),
                    child: Icon(Icons.history_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 3.0),
                    child: Icon(Icons.history_rounded),
                  ),
                  label: 'History',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, Color navyBlue, Color lightBlue) {
    return RefreshIndicator(
      color: lightBlue,
      onRefresh: _fetchDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modern Clean Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF0A2540)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x200F172A),
                    offset: Offset(0, 8),
                    blurRadius: 16,
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.75),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _shopName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Store Open',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Statistics Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  // 4 Compact Stats in One Line
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactStatCard(
                          title: 'Orders',
                          value: isLoading ? '...' : todayOrders.toString(),
                          icon: Icons.shopping_bag_rounded,
                          color: lightBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactStatCard(
                          title: 'Pending',
                          value: isLoading ? '...' : pendingOrders.toString(),
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFFFF9F43),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactStatCard(
                          title: 'Completed',
                          value: isLoading ? '...' : completedOrders.toString(),
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactStatCard(
                          title: 'Revenue',
                          value: isLoading ? '...' : '₹${totalRevenue.toStringAsFixed(0)}',
                          icon: Icons.account_balance_wallet_rounded,
                          color: const Color(0xFF00B4D8),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions Section
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildQuickActionButton(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Add Fish / Product',
                    subtitle: 'Add fresh items & pricing to catalog',
                    color: lightBlue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddProductScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Recent Orders Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedIndex = 2; // Switch to New Orders tab
                          });
                        },
                        child: const Row(
                          children: [
                            Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00B4D8),
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF00B4D8)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Recent Orders Stream
                  _buildRecentOrdersStream(lightBlue),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrdersStream(Color lightBlue) {
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Error loading orders: ${snapshot.error}',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          );
        }

        final docs = List<DocumentSnapshot>.from(snapshot.data?.docs ?? []);
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    'No orders placed yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'New customer orders will appear here in real time.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Sort by createdAt descending
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

        final recentDocs = docs.take(4).toList();

        return Column(
          children: recentDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String orderId = doc.id;
            final String status = (data['status'] ?? 'pending').toString().toLowerCase();
            final double total = (data['totalAmount'] ?? data['amount'] ?? 0.0).toDouble();
            final items = data['items'] as List<dynamic>? ?? [];

            Color statusColor = const Color(0xFFFF9F43);
            if (status == 'completed' || status == 'delivered') {
              statusColor = const Color(0xFF10B981);
            } else if (status == 'ready_for_delivery' || status == 'out_for_delivery') {
              statusColor = const Color(0xFF00B4D8);
            } else if (status == 'cancelled') {
              statusColor = Colors.redAccent;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_outlined, size: 16, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Order #${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Items snippet
                  Text(
                    items.isNotEmpty
                        ? items.map((e) => '${e['quantity'] ?? 1}x ${e['name'] ?? 'Item'}').join(', ')
                        : 'No item details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: ₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedIndex = 2; // Go to orders tab
                          });
                        },
                        child: const Text(
                          'Manage Order →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00B4D8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCompactStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A1628),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade500, size: 16),
            ),
          ],
        ),
      ),
    );
  }

}
