import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';

class DeliveryPartnerDashboard extends StatefulWidget {
  const DeliveryPartnerDashboard({super.key});

  @override
  State<DeliveryPartnerDashboard> createState() => _DeliveryPartnerDashboardState();
}

class _DeliveryPartnerDashboardState extends State<DeliveryPartnerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color _navyBlue = const Color(0xFF0A1628);
  final Color _lightBlue = const Color(0xFF00B4D8);
  final Color _backgroundWhite = const Color(0xFFF5F7FA);

  Future<void> _acceptDelivery(String orderId) async {
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'out_for_delivery',
        'deliveryBoyId': currentUser!.uid,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery Accepted!'), backgroundColor: Colors.green),
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
          const SnackBar(content: Text('Marked as Delivered!'), backgroundColor: Colors.green),
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
      length: 2,
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
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
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
            )
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF00B4D8),
            labelColor: Color(0xFF00B4D8),
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Available Orders'),
              Tab(text: 'My Deliveries'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAvailableOrders(),
            _buildMyDeliveries(),
          ],
        ),
      ),
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
              if (fallbackSnap.hasError) return Center(child: Text('Error: ${fallbackSnap.error}'));
              if (!fallbackSnap.hasData) return const Center(child: CircularProgressIndicator());
              return _buildOrdersList(fallbackSnap.data!.docs, true);
            },
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
              if (fallbackSnap.hasError) return Center(child: Text('Error: ${fallbackSnap.error}'));
              if (!fallbackSnap.hasData) return const Center(child: CircularProgressIndicator());
              return _buildOrdersList(fallbackSnap.data!.docs, false);
            },
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return _buildOrdersList(snapshot.data!.docs, false);
      },
    );
  }

  Widget _buildOrdersList(List<DocumentSnapshot> docs, bool isAvailable) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isAvailable ? 'No available orders right now.' : 'You have no active deliveries.',
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
        final items = data['items'] as List<dynamic>? ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${orderId.substring(0, 8).toUpperCase()}',
                      style: TextStyle(color: _navyBlue, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    Text('₹$total', style: TextStyle(color: _lightBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const Divider(height: 24),
                
                // Customer Details
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    const Text('Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(phone, style: TextStyle(color: Colors.grey.shade800)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(address, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
                    ),
                  ],
                ),
                const Divider(height: 24),
                
                // Items Preview
                Text('${items.length} Items to Deliver', style: TextStyle(color: _navyBlue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                if (isAvailable) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _acceptDelivery(orderId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _lightBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Accept Delivery', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _markDelivered(orderId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Mark as Delivered', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
