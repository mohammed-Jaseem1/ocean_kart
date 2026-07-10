import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class CheckoutScreen extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, dynamic>>? directItems;

  const CheckoutScreen({super.key, required this.totalAmount, this.directItems});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingItems = true;

  List<Map<String, dynamic>> _itemsToOrder = [];
  double _calculatedTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _calculatedTotal = widget.totalAmount;
    _initializeCheckout();
  }

  Future<void> _initializeCheckout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Fetch phone number
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['phone'] != null) {
          _phoneController.text = data['phone'];
        }
      }

      // Fetch items
      List<Map<String, dynamic>> items = [];
      if (widget.directItems != null && widget.directItems!.isNotEmpty) {
        items = List.from(widget.directItems!);
      } else {
        final cartSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('cart').get();
        items = cartSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'productId': doc.id,
            'name': data['name'],
            'pricePerKg': data['pricePerKg'],
            'quantity': data['quantity'] ?? 1.0,
            'shopId': data['shopId'],
            'imageUrl': data['imageUrl'],
          };
        }).toList();
      }

      // Add default preparation option to each item
      for (var item in items) {
        if (!item.containsKey('preparation')) {
          item['preparation'] = 'Whole / Not Cleaned';
        }
      }

      setState(() {
        _itemsToOrder = items;
        _isLoadingItems = false;
      });
      _recalculateTotal();

    } catch (e) {
      print('Error init checkout: $e');
      setState(() => _isLoadingItems = false);
    }
  }

  void _recalculateTotal() {
    double total = 0.0;
    for (var item in _itemsToOrder) {
      final price = (item['pricePerKg'] as num).toDouble();
      final qty = (item['quantity'] as num).toDouble();
      total += (price * qty);
    }
    setState(() {
      _calculatedTotal = total;
    });
  }

  void _updateQuantity(int index, double change) {
    setState(() {
      final currentQty = (_itemsToOrder[index]['quantity'] as num).toDouble();
      final newQty = currentQty + change;
      if (newQty > 0) {
        _itemsToOrder[index]['quantity'] = newQty;
        _recalculateTotal();
      }
    });
  }

  void _updatePreparation(int index, String? value) {
    if (value != null) {
      setState(() {
        _itemsToOrder[index]['preparation'] = value;
      });
    }
  }

  Future<void> _showDummyMap() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Delivery Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dummy Map Image
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        image: const DecorationImage(
                          image: NetworkImage('https://i.stack.imgur.com/HILmr.png'), // A generic dummy map
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const Icon(Icons.location_on, color: Colors.red, size: 48), // Dummy pin
                    Positioned(
                      bottom: 24,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4D8),
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          // Return a dummy selected address
                          Navigator.pop(context, '123 Ocean View Drive, Kochi, Kerala');
                        },
                        child: const Text('Confirm Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _addressController.text = result;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (_addressController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill delivery address and phone')));
      return;
    }

    if (_itemsToOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items to order')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 2. Create Order
      await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'items': _itemsToOrder,
        'totalAmount': _calculatedTotal,
        'deliveryAddress': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'paymentMethod': 'COD',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Clear Cart ONLY if it wasn't a direct buy
      if (widget.directItems == null || widget.directItems!.isEmpty) {
        final cartSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('cart').get();
        for (var doc in cartSnapshot.docs) {
          await doc.reference.delete();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully!')));
        Navigator.of(context).popUntil((route) => route.isFirst); // Go back to Home
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error placing order: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Secure Checkout', style: TextStyle(color: Color(0xFF0A1628), fontWeight: FontWeight.w800, fontSize: 20)),
        iconTheme: const IconThemeData(color: Color(0xFF0A1628)),
        centerTitle: true,
      ),
      body: _isLoadingItems
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A1628), Color(0xFF1E3A5F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF0A1628).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Amount To Pay', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('₹${_calculatedTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('${_itemsToOrder.length} item(s) selected', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text('Items & Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
                  const SizedBox(height: 12),
                  
                  // Items List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _itemsToOrder.length,
                    itemBuilder: (context, index) {
                      final item = _itemsToOrder[index];
                      final qty = (item['quantity'] as num).toDouble();
                      final price = (item['pricePerKg'] as num).toDouble();
                      final imageUrl = item['imageUrl'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    image: imageUrl != null && imageUrl.isNotEmpty
                                        ? DecorationImage(
                                            image: imageUrl.startsWith('http')
                                                ? NetworkImage(imageUrl) as ImageProvider
                                                : MemoryImage(base64Decode(imageUrl)),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: imageUrl == null ? const Icon(Icons.image, color: Colors.grey) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text('₹${price.toStringAsFixed(0)}/kg', style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                // Quantity Selector
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () => _updateQuantity(index, -0.5),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${qty.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 20),
                                      onPressed: () => _updateQuantity(index, 0.5),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Text('Preparation:', style: TextStyle(fontSize: 13, color: Colors.black54)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: item['preparation'],
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        onChanged: (val) => _updatePreparation(index, val),
                                        items: const [
                                          DropdownMenuItem(value: 'Whole / Not Cleaned', child: Text('Whole / Not Cleaned')),
                                          DropdownMenuItem(value: 'Cleaned', child: Text('Cleaned')),
                                          DropdownMenuItem(value: 'Cut for Curry', child: Text('Cut for Curry')),
                                          DropdownMenuItem(value: 'Cut for Fry', child: Text('Cut for Fry')),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),

                  const Row(
                    children: [
                      Icon(Icons.location_on, color: Color(0xFF0A1628), size: 22),
                      SizedBox(width: 8),
                      Text('Delivery Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Map Button & Address Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: _showDummyMap,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.map, color: Color(0xFF00B4D8)),
                                SizedBox(width: 8),
                                Text('Select Location on Map', style: TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        TextField(
                          controller: _addressController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Enter complete address or select on map',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(16),
                            border: const OutlineInputBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Phone Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Phone Number',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                        prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey.shade500),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  const Row(
                    children: [
                      Icon(Icons.payment, color: Color(0xFF0A1628), size: 22),
                      SizedBox(width: 8),
                      Text('Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Payment Option
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00B4D8).withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF00B4D8).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B4D8).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.money, color: Color(0xFF00B4D8)),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cash on Delivery', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0A1628))),
                              SizedBox(height: 4),
                              Text('Pay when you receive your order', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: Color(0xFF00B4D8), size: 28),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Place Order Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B4D8),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isLoading ? null : _placeOrder,
                      child: _isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text('PLACE ORDER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
