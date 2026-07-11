import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_screen.dart';

class DeliveryPartnerDashboard extends StatefulWidget {
  const DeliveryPartnerDashboard({super.key});

  @override
  State<DeliveryPartnerDashboard> createState() =>
      _DeliveryPartnerDashboardState();
}

class _DeliveryPartnerDashboardState extends State<DeliveryPartnerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color _navyBlue = const Color(0xFF0A1628);
  final Color _lightBlue = const Color(0xFF00B4D8);
  final Color _backgroundWhite = const Color(0xFFF5F7FA);

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
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Please login")));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _backgroundWhite,
        appBar: AppBar(
          backgroundColor: _navyBlue,
          elevation: 0,
          title: const Text(
            'Delivery Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              tooltip: 'Profile',
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              tooltip: 'Log Out',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildStatsHeader(),
            const TabBar(
              indicatorColor: Color(0xFF00B4D8),
              labelColor: Color(0xFF00B4D8),
              unselectedLabelColor: Colors.black54,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Available Orders'),
                Tab(text: 'My Deliveries'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAvailableOrders(),
                  _buildMyDeliveries(),
                  _buildDeliveryHistory(),
                ],
              ),
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
        int totalDeliveries = 0;
        double totalEarnings = 0.0;

        if (snapshot.hasData) {
          totalDeliveries = snapshot.data!.docs.length;
          totalEarnings = totalDeliveries * 40.0; // Assume ₹40 per delivery
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_navyBlue, _lightBlue.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _lightBlue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Deliveries',
                totalDeliveries.toString(),
                Icons.check_circle_outline,
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildStatItem(
                'Total Earnings',
                '₹${totalEarnings.toStringAsFixed(0)}',
                Icons.account_balance_wallet_outlined,
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
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'ready_for_delivery')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Fallback if index missing
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('status', isEqualTo: 'ready_for_delivery')
                .snapshots(),
            builder: (context, fallbackSnap) {
              if (fallbackSnap.hasError)
                return Center(child: Text('Error: ${fallbackSnap.error}'));
              if (!fallbackSnap.hasData)
                return const Center(child: CircularProgressIndicator());
              return _buildOrdersList(fallbackSnap.data!.docs, true);
            },
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return _buildOrdersList(snapshot.data!.docs, true);
      },
    );
  }

  Widget _buildMyDeliveries() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryBoyId', isEqualTo: currentUser!.uid)
          .where('status', isEqualTo: 'out_for_delivery')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('deliveryBoyId', isEqualTo: currentUser!.uid)
                .where('status', isEqualTo: 'out_for_delivery')
                .snapshots(),
            builder: (context, fallbackSnap) {
              if (fallbackSnap.hasError)
                return Center(child: Text('Error: ${fallbackSnap.error}'));
              if (!fallbackSnap.hasData)
                return const Center(child: CircularProgressIndicator());
              return _buildOrdersList(fallbackSnap.data!.docs, false);
            },
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return _buildOrdersList(snapshot.data!.docs, false);
      },
    );
  }

  Widget _buildDeliveryHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryBoyId', isEqualTo: currentUser!.uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('deliveryBoyId', isEqualTo: currentUser!.uid)
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, fallbackSnap) {
              if (fallbackSnap.hasError)
                return Center(child: Text('Error: ${fallbackSnap.error}'));
              if (!fallbackSnap.hasData)
                return const Center(child: CircularProgressIndicator());
              return _buildOrdersList(
                fallbackSnap.data!.docs,
                false,
                isHistory: true,
              );
            },
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return _buildOrdersList(snapshot.data!.docs, false, isHistory: true);
      },
    );
  }

  Widget _buildOrdersList(
    List<DocumentSnapshot> docs,
    bool isAvailable, {
    bool isHistory = false,
  }) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isHistory
                  ? 'No delivery history found.'
                  : (isAvailable
                        ? 'No available orders right now.'
                        : 'You have no active deliveries.'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
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
        final double total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final String phone = data['phone'] ?? 'N/A';
        final String address = data['deliveryAddress'] ?? 'N/A';
        final double? deliveryLat = data['deliveryLat'] as double?;
        final double? deliveryLon = data['deliveryLon'] as double?;
        final items = data['items'] as List<dynamic>? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isHistory
                            ? Colors.green.withOpacity(0.1)
                            : (isAvailable
                                  ? _lightBlue.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Order #${orderId.substring(0, 8).toUpperCase()}',
                        style: TextStyle(
                          color: isHistory
                              ? Colors.green.shade700
                              : (isAvailable
                                    ? _lightBlue
                                    : Colors.orange.shade700),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '₹$total',
                      style: TextStyle(
                        color: _navyBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 16),

                // Customer Details
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, size: 16, color: _navyBlue),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Customer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      phone,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 8),
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            address,
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
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
                            child: Row(
                              children: [
                                Icon(Icons.map, size: 16, color: _lightBlue),
                                const SizedBox(width: 4),
                                Text(
                                  'View on Map',
                                  style: TextStyle(
                                    color: _lightBlue,
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
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 16),

                // Items Preview
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 16,
                      color: _lightBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${items.length} Items to Deliver',
                      style: TextStyle(
                        color: _navyBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                if (isHistory) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Delivery Completed',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else if (isAvailable) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _acceptDelivery(orderId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _lightBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Accept Delivery',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _markDelivered(orderId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Mark as Delivered',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
