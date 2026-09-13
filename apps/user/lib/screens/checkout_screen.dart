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
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingItems = true;

  List<Map<String, dynamic>> _itemsToOrder = [];
  double _calculatedTotal = 0.0;

  // Address management
  List<Map<String, dynamic>> _savedAddresses = [];
  Map<String, dynamic>? _selectedAddress; // {label, address, lat, lon, id}
  bool _isLoadingAddresses = true;

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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['phone'] != null) {
          _phoneController.text = data['phone'];
        }
      }

      // Fetch saved addresses from subcollection
      await _loadSavedAddresses();

      // Fetch items
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

      // Add default preparation option to each item
      for (var item in items) {
        if (!item.containsKey('preparation')) {
          item['preparation'] = <String>[];
        } else if (item['preparation'] is String) {
          item['preparation'] = <String>[item['preparation']];
        }
      }

      setState(() {
        _itemsToOrder = items;
        _isLoadingItems = false;
      });
      _recalculateTotal();
    } catch (e) {
      debugPrint('Error init checkout: $e');
      setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _loadSavedAddresses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .orderBy('createdAt', descending: false)
          .get();

      final addresses = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();

      setState(() {
        _savedAddresses = addresses;
        _isLoadingAddresses = false;
        // Auto-select first address if available
        if (addresses.isNotEmpty && _selectedAddress == null) {
          _selectedAddress = addresses.first;
        }
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

  void _updatePreparation(int index, String option, bool isSelected) {
    setState(() {
      final List<String> current = List<String>.from(
        _itemsToOrder[index]['preparation'] ?? [],
      );
      if (isSelected) {
        if (!current.contains(option)) current.add(option);
      } else {
        current.remove(option);
      }
      _itemsToOrder[index]['preparation'] = current;
    });
  }

  Future<void> _removeItem(int index) async {
    final item = _itemsToOrder[index];

    setState(() {
      _itemsToOrder.removeAt(index);
      _recalculateTotal();
    });

    if (widget.directItems == null || widget.directItems!.isEmpty) {
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
      final String address = result['address'] as String? ?? '';

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

      // Show label picker dialog
      final label = await _showLabelPickerDialog();
      if (label == null || !mounted) return;

      // Save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .add({
          'label': label,
          'address': address,
          'lat': lat,
          'lon': lon,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final newAddress = {
          'id': docRef.id,
          'label': label,
          'address': address,
          'lat': lat,
          'lon': lon,
        };

        setState(() {
          _savedAddresses.add(newAddress);
          _selectedAddress = newAddress;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label address saved!'),
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

  Future<String?> _showLabelPickerDialog() async {
    String selectedLabel = 'Home';
    final customController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Save Address As',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Home', 'Work', 'Other'].map((label) {
                      final isSelected = selectedLabel == label;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedLabel = label),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF00B4D8)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                label == 'Home'
                                    ? Icons.home_outlined
                                    : label == 'Work'
                                        ? Icons.work_outline
                                        : Icons.location_on_outlined,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedLabel == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customController,
                      decoration: InputDecoration(
                        hintText: 'Enter a custom label...',
                        hintStyle:
                            TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B4D8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final finalLabel = selectedLabel == 'Other' &&
                            customController.text.trim().isNotEmpty
                        ? customController.text.trim()
                        : selectedLabel;
                    Navigator.pop(ctx, finalLabel);
                  },
                  child: const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAddress(String addressId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Address',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Remove this saved address?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc(addressId)
          .delete();

      setState(() {
        _savedAddresses.removeWhere((a) => a['id'] == addressId);
        if (_selectedAddress?['id'] == addressId) {
          _selectedAddress =
              _savedAddresses.isNotEmpty ? _savedAddresses.first : null;
        }
      });
    }
  }

  /// Returns true if delivery is allowed, false if blocked.
  Future<bool> _validateDeliveryRadius() async {
    if (_selectedAddress == null) return false;

    final double? deliveryLat = _selectedAddress!['lat'] as double?;
    final double? deliveryLon = _selectedAddress!['lon'] as double?;

    // Require GPS coordinates on the address
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

    // Get the shopId from items
    final String? shopId = _itemsToOrder.isNotEmpty
        ? _itemsToOrder.first['shopId'] as String?
        : null;

    if (shopId == null || shopId.isEmpty) {
      // No shopId to validate against — allow order
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

      // If shop has no GPS pin, skip radius check
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
                    fontSize: 14,
                    color: Color(0xFF475569),
                    height: 1.5),
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
      // On error, allow order to proceed
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

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    if (_itemsToOrder.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No items to order')));
      return;
    }

    setState(() => _isLoading = true);

    // Validate delivery radius before anything else
    final bool canDeliver = await _validateDeliveryRadius();
    if (!canDeliver) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Save phone for future
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phone': _phoneController.text.trim(),
      }, SetOptions(merge: true));

      // 1. Validate stock for all items
      for (var item in _itemsToOrder) {
        final String? shopId = item['shopId'];
        final String? productId = item['productId'];
        final double qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        final String name = item['name'] ?? 'Product';

        if (shopId != null && productId != null) {
          var productDoc = await FirebaseFirestore.instance
              .collection('shop_owners')
              .doc(shopId)
              .collection('products')
              .doc(productId)
              .get();

          if (!productDoc.exists) {
            productDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(shopId)
                .collection('products')
                .doc(productId)
                .get();
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

      // 2. Fetch user profile data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final String customerName =
          userData['name'] ?? user.displayName ?? 'Unknown Customer';
      final String customerEmail = userData['email'] ?? user.email ?? '';

      // 3. Create Order
      final orderRef = await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'shopId': _itemsToOrder.isNotEmpty ? _itemsToOrder.first['shopId'] : '',
        'items': _itemsToOrder,
        'totalAmount': _calculatedTotal,
        'deliveryAddress': _selectedAddress!['address'],
        'deliveryLat': _selectedAddress!['lat'],
        'deliveryLon': _selectedAddress!['lon'],
        'deliveryAddressLabel': _selectedAddress!['label'] ?? '',
        'phone': _phoneController.text.trim(),
        'paymentMethod': 'COD',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final String orderId = orderRef.id;
      final String shopId = _itemsToOrder.isNotEmpty ? (_itemsToOrder.first['shopId'] ?? '') : '';
      final String shortOrderId = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();

      // Update shop owner aggregated stats to reduce reads
      if (shopId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('shop_owners').doc(shopId).set({
            'totalOrders': FieldValue.increment(1),
            'pendingOrders': FieldValue.increment(1),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error incrementing shop owner order stats: $e');
        }
      }

      // Trigger Notification for Shop Owner
      if (shopId.isNotEmpty) {
        try {
          var shopDoc = await FirebaseFirestore.instance
              .collection('shop_owners')
              .doc(shopId)
              .get();
          final String shopCollection = shopDoc.exists ? 'shop_owners' : 'users';

          await FirebaseFirestore.instance
              .collection(shopCollection)
              .doc(shopId)
              .collection('notifications')
              .add({
            'title': 'New Order Received! 🛒',
            'body': 'Order #$shortOrderId placed by $customerName for ₹${_calculatedTotal.toStringAsFixed(0)}.',
            'type': 'order',
            'orderId': orderId,
            'isRead': false,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error triggering shop owner notification: $e');
        }
      }

      // Trigger Notification for Customer
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .add({
          'title': 'Order Placed Successfully! 🎉',
          'body': 'Your order #$shortOrderId for ₹${_calculatedTotal.toStringAsFixed(0)} has been placed.',
          'type': 'order',
          'orderId': orderId,
          'isRead': false,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error triggering customer notification: $e');
      }

      // 4. Reduce inventory stock
      for (var item in _itemsToOrder) {
        final String? shopId = item['shopId'];
        final String? productId = item['productId'];
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

          final productDoc = await productRef.get();
          if (!productDoc.exists) {
            productRef = FirebaseFirestore.instance
                .collection('users')
                .doc(shopId)
                .collection('products')
                .doc(productId);
          }

          try {
            await FirebaseFirestore.instance
                .runTransaction((transaction) async {
              final snapshot = await transaction.get(productRef);
              if (snapshot.exists) {
                final currentStock =
                    (snapshot.data()?['stockQuantity'] as num?)?.toDouble() ??
                        0.0;
                final newStock = currentStock - qty;
                transaction.update(productRef, {
                  'stockQuantity': newStock < 0 ? 0.0 : newStock,
                  'status': newStock <= 0 ? 'out_of_stock' : 'active',
                });
              }
            });
          } catch (e) {
            debugPrint('Failed to update stock for $productId: $e');
          }
        }
      }

      // 5. Clear Cart if not direct buy
      if (widget.directItems == null || widget.directItems!.isEmpty) {
        final cartSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .get();
        for (var doc in cartSnapshot.docs) {
          await doc.reference.delete();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
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
    _phoneController.dispose();
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
          'Secure Checkout',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: true,
      ),
      body: _isLoadingItems
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Order Summary Card ──────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF00B4D8).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount To Pay',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${_calculatedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${_itemsToOrder.length} item(s) selected',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Items & Preferences ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Items & Preferences',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                        icon: const Icon(Icons.add,
                            color: Color(0xFF00B4D8)),
                        label: const Text(
                          'Add More',
                          style: TextStyle(
                            color: Color(0xFF00B4D8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Items List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _itemsToOrder.length,
                    itemBuilder: (context, index) {
                      final item = _itemsToOrder[index];
                      final qty =
                          (item['quantity'] as num).toDouble();
                      final price =
                          (item['pricePerKg'] as num).toDouble();
                      final imageUrl = item['imageUrl'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          image: imageUrl != null &&
                                                  imageUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image: imageUrl
                                                          .startsWith('http')
                                                      ? NetworkImage(
                                                              imageUrl)
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'],
                                              style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              '₹${price.toStringAsFixed(0)}/kg',
                                              style: const TextStyle(
                                                color: Colors.blueAccent,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
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
                                                _updateQuantity(
                                                    index, -0.5),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${qty.toStringAsFixed(1)} kg',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.green,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _updateQuantity(
                                                    index, 0.5),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Preparation Options (Select multiple):',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                'Cleaning',
                                                'Cut for Curry',
                                                'Cut for Fry',
                                              ].map((option) {
                                                final isSelected = ((item[
                                                                'preparation'] ??
                                                            []) as List)
                                                    .contains(option);
                                                return FilterChip(
                                                  label: Text(option,
                                                      style:
                                                          const TextStyle(
                                                              fontSize:
                                                                  12)),
                                                  selected: isSelected,
                                                  onSelected: (selected) =>
                                                      _updatePreparation(
                                                          index,
                                                          option,
                                                          selected),
                                                  selectedColor: const Color(
                                                          0xFF00B4D8)
                                                      .withValues(
                                                          alpha: 0.2),
                                                  checkmarkColor:
                                                      const Color(
                                                          0xFF00B4D8),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.cancel,
                                    color: Colors.grey, size: 24),
                                onPressed: () => _removeItem(index),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Delivery Address Section ───────────────────────
                  const Row(
                    children: [
                      Icon(Icons.location_on,
                          color: Color(0xFF0F172A), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Delivery Address',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _isLoadingAddresses
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Column(
                          children: [
                            // Saved address cards
                            if (_savedAddresses.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.location_off_outlined,
                                          size: 40,
                                          color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No saved addresses yet',
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap below to add your delivery location',
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount: _savedAddresses.length,
                                itemBuilder: (context, index) {
                                  final addr = _savedAddresses[index];
                                  final isSelected = _selectedAddress !=
                                          null &&
                                      _selectedAddress!['id'] == addr['id'];
                                  final label =
                                      addr['label'] as String? ?? 'Address';

                                  IconData labelIcon = Icons.location_on;
                                  if (label == 'Home') {
                                    labelIcon = Icons.home_rounded;
                                  } else if (label == 'Work') {
                                    labelIcon = Icons.work_rounded;
                                  }

                                  return GestureDetector(
                                    onTap: () => setState(
                                        () => _selectedAddress = addr),
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF00B4D8)
                                                .withValues(alpha: 0.07)
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF00B4D8)
                                              : const Color(0xFFE2E8F0),
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.03),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFF00B4D8)
                                                      .withValues(alpha: 0.15)
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              labelIcon,
                                              color: isSelected
                                                  ? const Color(0xFF00B4D8)
                                                  : const Color(0xFF64748B),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  label,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF00B4D8)
                                                        : const Color(
                                                            0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  addr['address'] as String? ??
                                                      '',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              color: Color(0xFF00B4D8),
                                              size: 22,
                                            )
                                          else
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Color(0xFFCBD5E1),
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  _deleteAddress(
                                                      addr['id'] as String),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 10),

                            // Add new address button
                            InkWell(
                              onTap: _openMapAndAddAddress,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFF00B4D8)
                                          .withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_location_alt_rounded,
                                        color: Color(0xFF00B4D8), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Add New Address from Map',
                                      style: TextStyle(
                                        color: Color(0xFF00B4D8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                  const SizedBox(height: 16),

                  // ── Phone Input ────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                          fontSize: 15, color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Phone Number',
                        hintStyle:
                            TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: Colors.grey.shade500,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Payment Method ────────────────────────────────
                  const Row(
                    children: [
                      Icon(Icons.payment,
                          color: Color(0xFF0F172A), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00B4D8).withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00B4D8).withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.money,
                              color: Color(0xFF00B4D8)),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cash on Delivery',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Pay when you receive your order',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle,
                            color: Color(0xFF00B4D8), size: 28),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ── Place Order Button ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B4D8),
                        foregroundColor: Colors.white,
                        elevation: 0,
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
                          : const Text(
                              'PLACE ORDER',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
