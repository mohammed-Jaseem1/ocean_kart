import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrdersScreen extends StatefulWidget {
  final bool isHistory;
  const OrdersScreen({super.key, this.isHistory = false});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color _navyBlue = const Color(0xFF0A1628);
  final Color _lightBlue = const Color(0xFF00B4D8);

  void _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': newStatus,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order marked as $newStatus'), backgroundColor: Colors.green),
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

  String _formatDate(DateTime date) {
    String hour = date.hour.toString().padLeft(2, '0');
    String min = date.minute.toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} $hour:$min';
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: _navyBlue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(child: Text("Please login to view orders."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: currentUser!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Fallback if index is missing
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('shopId', isEqualTo: currentUser!.uid)
                .snapshots(),
            builder: (context, snapshotBackup) {
              if (snapshotBackup.hasError) return Center(child: Text('Error loading orders: ${snapshotBackup.error}'));
              if (!snapshotBackup.hasData) return const Center(child: CircularProgressIndicator());
              return _buildFilteredList(snapshotBackup.data!.docs);
            }
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return _buildFilteredList(snapshot.data!.docs);
      },
    );
  }

  Widget _buildFilteredList(List<DocumentSnapshot> docs) {
    final filteredDocs = docs.where((doc) {
      final status = (doc.data() as Map<String, dynamic>)['status'] ?? 'pending';
      if (widget.isHistory) {
        return status == 'completed' || status == 'delivered' || status == 'cancelled';
      } else {
        return status == 'pending' || status == 'ready_for_delivery' || status == 'out_for_delivery';
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(widget.isHistory ? 'Order History (${filteredDocs.length})' : 'New Orders (${filteredDocs.length})'),
        Expanded(child: _buildOrdersList(filteredDocs)),
      ],
    );
  }

  Widget _buildOrdersList(List<DocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No orders yet.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 18),
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
        final items = data['items'] as List<dynamic>? ?? [];
        
        DateTime? date;
        if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
          date = (data['createdAt'] as Timestamp).toDate();
        }

        Color statusColor = Colors.orange;
        if (status == 'completed' || status == 'delivered') statusColor = Colors.green;
        else if (status == 'ready_for_delivery') statusColor = Colors.blue;
        else if (status == 'out_for_delivery') statusColor = Colors.teal;
        else if (status == 'cancelled') statusColor = Colors.red;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          shadowColor: Colors.black12,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(date),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
                const Divider(height: 24),
                
                // Customer Details
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(phone, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                
                // Items List
                Text('Order Items', style: TextStyle(color: _navyBlue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final qty = item['quantity']?.toString() ?? '1';
                  final name = item['name'] ?? 'Item';
                  final prepList = item['preparation'] as List<dynamic>? ?? [];
                  final prepText = prepList.isNotEmpty ? ' (${prepList.join(', ')})' : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${qty}x ', style: TextStyle(fontWeight: FontWeight.bold, color: _lightBlue)),
                        Expanded(
                          child: Text('$name$prepText', style: const TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    Text('₹$total', style: TextStyle(color: _navyBlue, fontWeight: FontWeight.w900, fontSize: 18)),
                  ],
                ),
                
                if (status == 'pending') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'cancelled'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'ready_for_delivery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Accept Order', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
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
