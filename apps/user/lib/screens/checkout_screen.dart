import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'location_picker_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, dynamic>>? directItems;

  const CheckoutScreen({
    super.key,
    required this.totalAmount,
    this.directItems,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _userPhone = '';
  bool _isLoading = false;
  bool _isLoadingItems = true;

  List<Map<String, dynamic>> _itemsToOrder = [];
  double _calculatedTotal = 0.0;
  String _shopName = '';

  // Single Delivery Address management
  Map<String, dynamic>? _selectedAddress; // {address, lat, lon, id}
  bool _isLoadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _calculatedTotal = widget.totalAmount;
    _initializeCheckout();
  }

  String _cleanDisplayAddress(String? address) {
    if (address == null || address.trim().isEmpty) return '';
    return address
        .replaceFirst(RegExp(r'^[A-Z0-9]{2,8}\+[A-Z0-9]{2,4}[\s,]+'), '')
        .trim();
  }

  Future<void> _fetchShopName(String shopId) async {
    if (shopId.isEmpty) return;
    try {
      var shopDoc = await FirebaseFirestore.instance
          .collection('shop_owners')
          .doc(shopId)
          .get();
      if (!shopDoc.exists) {
        shopDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(shopId)
            .get();
      }
      if (shopDoc.exists && mounted) {
        final data = shopDoc.data();
        setState(() {
          _shopName =
              data?['shopName'] ?? data?['name'] ?? 'Local Fish Shop';
        });
      }
    } catch (_) {}
  }

  Future<void> _initializeCheckout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Fetch phone number
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['phone'] != null) {
          _userPhone = data['phone'].toString();
        }
      }

      // Fetch saved address
      await _loadSavedAddresses();

      // Fetch items (selected from cart or direct)
      List<Map<String, dynamic>> items = [];
      if (widget.directItems != null && widget.directItems!.isNotEmpty) {
        items = List.from(widget.directItems!);
      } else {
        final cartSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .get();
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


      setState(() {
        _itemsToOrder = items;
        _isLoadingItems = false;
      });
      _recalculateTotal();

      if (items.isNotEmpty) {
        final firstShopId = items.first['shopId']?.toString() ?? '';
        _fetchShopName(firstShopId);
      }
    } catch (e) {
      debugPrint('Error init checkout: $e');
      setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _loadSavedAddresses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Check primary address subcollection
      final primaryDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc('primary')
          .get();

      if (primaryDoc.exists && primaryDoc.data() != null) {
        final pData = primaryDoc.data()!;
        final addr = {
          'id': 'primary',
          'address': _cleanDisplayAddress(pData['address']?.toString()),
          'lat': (pData['lat'] as num?)?.toDouble(),
          'lon': (pData['lon'] as num?)?.toDouble(),
        };
        setState(() {
          _selectedAddress = addr;
          _isLoadingAddresses = false;
        });
        return;
      }

      // 2. Check user profile for address and coordinates
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final uData = userDoc.data();
      if (uData != null && uData['address'] != null && uData['lat'] != null) {
        final addr = {
          'id': 'primary',
          'address': _cleanDisplayAddress(uData['address']?.toString()),
          'lat': (uData['lat'] as num?)?.toDouble(),
          'lon': (uData['lon'] as num?)?.toDouble(),
        };
        setState(() {
          _selectedAddress = addr;
          _isLoadingAddresses = false;
        });
        return;
      }

      // 3. Fallback: load any existing address
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final docData = doc.data();
        final addr = {
          'id': doc.id,
          'address': _cleanDisplayAddress(docData['address']?.toString()),
          'lat': (docData['lat'] as num?)?.toDouble(),
          'lon': (docData['lon'] as num?)?.toDouble(),
        };
        setState(() {
          _selectedAddress = addr;
          _isLoadingAddresses = false;
        });
        return;
      }

      setState(() {
        _selectedAddress = null;
        _isLoadingAddresses = false;
      });
    } catch (e) {
      debugPrint('Error loading addresses: $e');
      setState(() => _isLoadingAddresses = false);
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


  Future<void> _removeItem(int index) async {
    final item = _itemsToOrder[index];

    setState(() {
      _itemsToOrder.removeAt(index);
      _recalculateTotal();
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && item['productId'] != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .doc(item['productId'])
            .delete();
      } catch (e) {
        debugPrint('Error removing from cart: $e');
      }
    }

    if (_itemsToOrder.isEmpty) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _openMapAndAddAddress() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const LocationPickerBottomSheet();
      },
    );

    if (result != null && mounted) {
      final double? lat = result['lat'] as double?;
      final double? lon = result['lon'] as double?;
      final String rawAddress = result['address'] as String? ?? '';
      final String cleanAddress = _cleanDisplayAddress(rawAddress);

      if (lat == null || lon == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not get GPS coordinates. Please try again on the map.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .doc('primary')
            .set({
          'address': cleanAddress,
          'lat': lat,
          'lon': lon,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Also merge into user profile
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'address': cleanAddress,
          'lat': lat,
          'lon': lon,
        }, SetOptions(merge: true));

        final newAddress = {
          'id': 'primary',
          'address': cleanAddress,
          'lat': lat,
          'lon': lon,
        };

        setState(() {
          _selectedAddress = newAddress;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery location updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save address: $e')),
          );
        }
      }
    }
  }

  Future<bool> _validateDeliveryRadius() async {
    if (_selectedAddress == null) return false;

    final double? deliveryLat = _selectedAddress!['lat'] as double?;
    final double? deliveryLon = _selectedAddress!['lon'] as double?;

    if (deliveryLat == null || deliveryLon == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please select your delivery address from the map for location verification.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }

    final String? shopId = _itemsToOrder.isNotEmpty
        ? _itemsToOrder.first['shopId'] as String?
        : null;

    if (shopId == null || shopId.isEmpty) {
      return true;
    }

    try {
      var shopDoc = await FirebaseFirestore.instance
          .collection('shop_owners')
          .doc(shopId)
          .get();
      if (!shopDoc.exists) {
        shopDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(shopId)
            .get();
      }

      if (!shopDoc.exists) return true;

      final shopData = shopDoc.data()!;
      final double? shopLat = (shopData['latitude'] as num?)?.toDouble();
      final double? shopLon = (shopData['longitude'] as num?)?.toDouble();
      final double deliveryRadiusKm =
          (shopData['deliveryRadiusKm'] as num?)?.toDouble() ?? 10.0;

      if (shopLat == null || shopLon == null) return true;

      final double distanceMeters = Geolocator.distanceBetween(
        shopLat,
        shopLon,
        deliveryLat,
        deliveryLon,
      );
      final double distanceKm = distanceMeters / 1000.0;

      if (distanceKm > deliveryRadiusKm) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              icon: const Icon(Icons.location_off_rounded,
                  color: Colors.redAccent, size: 48),
              title: const Text(
                'Outside Delivery Area',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: Text(
                'Sorry, we don\'t deliver to this location.\n\n'
                'Your address is ${distanceKm.toStringAsFixed(1)} km away, '
                'but our delivery limit is ${deliveryRadiusKm.toStringAsFixed(0)} km from the store.\n\n'
                'Please select a closer address or contact the shop.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF475569), height: 1.5),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B4D8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK, Change Address',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error validating delivery radius: $e');
    }

    return true;
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select or add a delivery address')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to order')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isDeliverable = await _validateDeliveryRadius();
      if (!isDeliverable) {
        setState(() => _isLoading = false);
        return;
      }

      // Check stock for each item
      for (var item in _itemsToOrder) {
        final String? shopId = item['shopId'];
        final String? productId = item['productId'];
        final String name = item['name'] ?? 'Product';
        final double qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;

        if (shopId != null &&
            productId != null &&
            shopId.isNotEmpty &&
            productId.isNotEmpty) {
          var productRef = FirebaseFirestore.instance
              .collection('shop_owners')
              .doc(shopId)
              .collection('products')
              .doc(productId);

          var productDoc = await productRef.get();
          if (!productDoc.exists) {
            productRef = FirebaseFirestore.instance
                .collection('users')
                .doc(shopId)
                .collection('products')
                .doc(productId);
            productDoc = await productRef.get();
          }

          if (!productDoc.exists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$name is no longer available.',
                      style: const TextStyle(color: Colors.white)),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() => _isLoading = false);
            }
            return;
          }

          final currentStock =
              (productDoc.data()?['stockQuantity'] as num?)?.toDouble() ?? 0.0;
          if (currentStock < qty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Sorry, only ${currentStock.toStringAsFixed(1)}kg of $name is available.',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() => _isLoading = false);
            }
            return;
          }
        }
      }

      // Fetch user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final String customerName =
          userData['name'] ?? user.displayName ?? 'Customer';
      final String customerEmail = userData['email'] ?? user.email ?? '';

      final String shopId = _itemsToOrder.isNotEmpty
          ? (_itemsToOrder.first['shopId'] ?? '')
          : '';

      // Create Order document (Cash on Delivery)
      final orderRef =
          await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'shopId': shopId,
        'shopName': _shopName,
        'items': _itemsToOrder,
        'totalAmount': _calculatedTotal,
        'deliveryAddress': _selectedAddress!['address'],
        'deliveryLat': _selectedAddress!['lat'],
        'deliveryLon': _selectedAddress!['lon'],
        'phone': _userPhone,
        'paymentMethod': 'COD',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final String orderId = orderRef.id;
      final String shortOrderId = orderId.length > 8
          ? orderId.substring(0, 8).toUpperCase()
          : orderId.toUpperCase();

      // Update shop stats
      if (shopId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('shop_owners')
              .doc(shopId)
              .set({
            'totalOrders': FieldValue.increment(1),
            'pendingOrders': FieldValue.increment(1),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      // Notification for Shop Owner
      if (shopId.isNotEmpty) {
        try {
          var shopDoc = await FirebaseFirestore.instance
              .collection('shop_owners')
              .doc(shopId)
              .get();
          final String shopCollection =
              shopDoc.exists ? 'shop_owners' : 'users';

          await FirebaseFirestore.instance
              .collection(shopCollection)
              .doc(shopId)
              .collection('notifications')
              .add({
            'title': 'New Order Received! 🛒',
            'body':
                'Order #$shortOrderId placed by $customerName for ₹${_calculatedTotal.toStringAsFixed(0)} (COD).',
            'type': 'order',
            'orderId': orderId,
            'isRead': false,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      // Notification for Customer
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .add({
          'title': 'Order Placed Successfully! 🎉',
          'body':
              'Your order #$shortOrderId for ₹${_calculatedTotal.toStringAsFixed(0)} (Cash on Delivery) has been placed.',
          'type': 'order',
          'orderId': orderId,
          'isRead': false,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      // Update inventory stock
      for (var item in _itemsToOrder) {
        final String? sId = item['shopId'];
        final String? pId = item['productId'];
        final double qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;

        if (sId != null && pId != null && sId.isNotEmpty && pId.isNotEmpty) {
          var productRef = FirebaseFirestore.instance
              .collection('shop_owners')
              .doc(sId)
              .collection('products')
              .doc(pId);

          final productDoc = await productRef.get();
          if (!productDoc.exists) {
            productRef = FirebaseFirestore.instance
                .collection('users')
                .doc(sId)
                .collection('products')
                .doc(pId);
          }

          try {
            await FirebaseFirestore.instance.runTransaction((tx) async {
              final snap = await tx.get(productRef);
              if (snap.exists) {
                final current =
                    (snap.data()?['stockQuantity'] as num?)?.toDouble() ??
                        0.0;
                final newStock = current - qty;
                tx.update(productRef, {
                  'stockQuantity': newStock < 0 ? 0.0 : newStock,
                  'status': newStock <= 0 ? 'out_of_stock' : 'active',
                });
              }
            });
          } catch (_) {}
        }
      }

      // Remove ordered items from Cart
      for (var item in _itemsToOrder) {
        final String? pId = item['productId'];
        if (pId != null && pId.isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('cart')
                .doc(pId)
                .delete();
          } catch (_) {}
        }
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Order Placed Successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Order #$shortOrderId\nTotal: ₹${_calculatedTotal.toStringAsFixed(2)}\n\n'
                  'Payment method: Cash on Delivery\n'
                  'Please keep exact cash ready upon delivery.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF475569), height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B4D8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    },
                    child: const Text('Back to Home',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error placing order: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Order Summary',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: true,
      ),
      body: _isLoadingItems
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Shop Info & COD Header Banner ─────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B4D8)
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              color: Color(0xFF00B4D8), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ordering from',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _shopName.isNotEmpty
                                    ? _shopName
                                    : 'Local Fish Shop',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.payments_outlined,
                                  size: 14, color: Colors.green.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'Pay on Delivery',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Items & Preferences Header ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Items & Preferences',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                        icon: const Icon(Icons.add,
                            size: 18, color: Color(0xFF00B4D8)),
                        label: const Text(
                          'Add More',
                          style: TextStyle(
                            color: Color(0xFF00B4D8),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Items List ────────────────────────────────────────────
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _itemsToOrder.length,
                    itemBuilder: (context, index) {
                      final item = _itemsToOrder[index];
                      final qty = (item['quantity'] as num).toDouble();
                      final price = (item['pricePerKg'] as num).toDouble();
                      final imageUrl = item['imageUrl'];
                      final itemSubtotal = price * qty;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Product Image
                                      Container(
                                        width: 58,
                                        height: 58,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          image: imageUrl != null &&
                                                  imageUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image: imageUrl
                                                          .startsWith('http')
                                                      ? NetworkImage(imageUrl)
                                                          as ImageProvider
                                                      : MemoryImage(
                                                          base64Decode(
                                                              imageUrl),
                                                        ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: imageUrl == null
                                            ? const Icon(Icons.image,
                                                color: Colors.grey)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),

                                      // Product Details & Price Calculation
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'] ?? 'Product',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '₹${price.toStringAsFixed(0)}/kg × ${qty.toStringAsFixed(1)} kg',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Item Total: ₹${itemSubtotal.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Color(0xFF00B4D8),
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Quantity Selector
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _updateQuantity(index, -0.5),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6),
                                            child: Text(
                                              '${qty.toStringAsFixed(1)} kg',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.green,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _updateQuantity(index, 0.5),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                ],
                              ),
                            ),

                            // Delete button
                            Positioned(
                              top: 6,
                              right: 6,
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.grey, size: 20),
                                onPressed: () => _removeItem(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Delivery Address Section ──────────────────────────────
                  const Row(
                    children: [
                      Icon(Icons.location_on,
                          color: Color(0xFF0F172A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Delivery Address',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _isLoadingAddresses
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _selectedAddress != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00B4D8)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.location_on_rounded,
                                            color: Color(0xFF00B4D8),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Text(
                                            'Delivery Location',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14.5,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: _openMapAndAddAddress,
                                          icon: const Icon(
                                              Icons.edit_location_alt_rounded,
                                              size: 16,
                                              color: Color(0xFF00B4D8)),
                                          label: const Text(
                                            'Change',
                                            style: TextStyle(
                                              color: Color(0xFF00B4D8),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _cleanDisplayAddress(
                                          _selectedAddress!['address']
                                              as String?),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: Colors.grey.shade700,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : InkWell(
                                  onTap: _openMapAndAddAddress,
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_location_alt_rounded,
                                            color: Color(0xFF00B4D8)),
                                        SizedBox(width: 8),
                                        Text(
                                          'Set Delivery Location on Map',
                                          style: TextStyle(
                                            color: Color(0xFF00B4D8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),

                  const SizedBox(height: 20),

                  // ── Price Breakdown Section ───────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                color: Color(0xFF00B4D8), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Price Breakdown',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Itemized product lines
                        ..._itemsToOrder.map((item) {
                          final name = item['name'] ?? 'Product';
                          final qty = (item['quantity'] as num).toDouble();
                          final price = (item['pricePerKg'] as num).toDouble();
                          final total = price * qty;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$name (${qty.toStringAsFixed(1)} kg)',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const Divider(height: 16),

                        // Items subtotal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Items Total',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '₹${_calculatedTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Delivery fee
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Delivery Fee',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Text(
                              'FREE',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Packaging & Handling
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Packaging & Handling',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Text(
                              'FREE',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 20),

                        // Grand Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount To Pay',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '₹${_calculatedTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF00B4D8),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // COD Badge
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.money_rounded,
                                  color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cash on Delivery — Pay upon receipt of order',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Place Order Button ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B4D8),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _placeOrder,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              'PLACE ORDER  •  ₹${_calculatedTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
