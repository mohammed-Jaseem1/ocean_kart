import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final user = FirebaseAuth.instance.currentUser;
  late final Stream<QuerySnapshot>? _cartStream;

  // Selected item IDs (all selected items MUST belong to the same shop)
  final Set<String> _selectedItemIds = {};
  String? _selectedShopId;

  // Cache for shop names and in-flight request tracker
  final Map<String, String> _shopNamesCache = {};
  final Set<String> _requestedShopIds = {};

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _cartStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart')
          .snapshots();
    } else {
      _cartStream = null;
    }
  }

  Future<void> _fetchShopNames(List<DocumentSnapshot> docs) async {
    bool hasNewNames = false;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final shopId = data['shopId']?.toString();
      if (shopId != null &&
          shopId.isNotEmpty &&
          !_shopNamesCache.containsKey(shopId) &&
          !_requestedShopIds.contains(shopId)) {
        _requestedShopIds.add(shopId);

        // Check if shopName was directly stored on cart item
        final embeddedName = data['shopName']?.toString();
        if (embeddedName != null && embeddedName.trim().isNotEmpty) {
          _shopNamesCache[shopId] = embeddedName.trim();
          hasNewNames = true;
          continue;
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
          if (shopDoc.exists) {
            final sData = shopDoc.data();
            final name =
                sData?['shopName'] ?? sData?['name'] ?? 'Local Fish Shop';
            _shopNamesCache[shopId] = name.toString();
            hasNewNames = true;
          }
        } catch (_) {}
      }
    }

    if (hasNewNames && mounted) {
      setState(() {});
    }
  }

  Future<void> _updateQuantity(
      String cartItemId, double currentQty, double change) async {
    final newQty = currentQty + change;
    if (newQty <= 0) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart')
          .doc(cartItemId)
          .delete();
      setState(() {
        _selectedItemIds.remove(cartItemId);
        if (_selectedItemIds.isEmpty) {
          _selectedShopId = null;
        }
      });
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart')
          .doc(cartItemId)
          .update({'quantity': newQty});
    }
  }

  Future<void> _handleItemSelection(
      String docId, String itemShopId, bool isSelected) async {
    if (isSelected) {
      // Check if trying to select an item from a different shop
      if (_selectedShopId != null &&
          _selectedShopId != itemShopId &&
          _selectedItemIds.isNotEmpty) {
        final currentShopName =
            _shopNamesCache[_selectedShopId] ?? 'Current Shop';
        final newShopName = _shopNamesCache[itemShopId] ?? 'New Shop';

        final shouldSwitch = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.storefront_rounded,
                    color: Color(0xFF00B4D8), size: 24),
                SizedBox(width: 8),
                Text(
                  'Order from One Shop',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Your cart contains items from multiple shops. You can only checkout items from one shop at a time.\n\n'
              'Do you want to switch your selection from "$currentShopName" to "$newShopName"?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Switch Shop'),
              ),
            ],
          ),
        );

        if (shouldSwitch == true && mounted) {
          setState(() {
            _selectedItemIds.clear();
            _selectedShopId = itemShopId;
            _selectedItemIds.add(docId);
          });
        }
        return;
      }

      setState(() {
        _selectedShopId = itemShopId;
        _selectedItemIds.add(docId);
      });
    } else {
      setState(() {
        _selectedItemIds.remove(docId);
        if (_selectedItemIds.isEmpty) {
          _selectedShopId = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null || _cartStream == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'My Cart',
          style:
              TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _cartStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Your cart is empty!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          // Trigger shop names pre-fetch (guarded by _requestedShopIds)
          _fetchShopNames(docs);

          // Group items by shopId
          final Map<String, List<DocumentSnapshot>> shopGroups = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final sId = data['shopId']?.toString() ?? 'unknown';
            shopGroups.putIfAbsent(sId, () => []).add(doc);
          }

          // Auto-select first shop's items synchronously on first data arrival
          // (No postFrameCallback, no second reload!)
          if ((_selectedShopId == null ||
                  !shopGroups.containsKey(_selectedShopId)) &&
              shopGroups.isNotEmpty) {
            _selectedShopId = shopGroups.keys.first;
            _selectedItemIds.clear();
            _selectedItemIds
                .addAll(shopGroups[_selectedShopId]!.map((d) => d.id));
          }

          // Calculate subtotal for SELECTED items only
          double selectedTotal = 0.0;
          final List<Map<String, dynamic>> selectedItemsList = [];

          for (var doc in docs) {
            if (_selectedItemIds.contains(doc.id)) {
              final data = doc.data() as Map<String, dynamic>;
              final price = (data['pricePerKg'] as num?)?.toDouble() ?? 0.0;
              final qty = (data['quantity'] as num?)?.toDouble() ?? 0.0;
              selectedTotal += price * qty;

              selectedItemsList.add({
                'productId': doc.id,
                'name': data['name'],
                'pricePerKg': price,
                'quantity': qty,
                'shopId': data['shopId'],
                'imageUrl': data['imageUrl'],
              });
            }
          }

          return Column(
            children: [
              // Notice banner if multiple shops in cart
              if (shopGroups.keys.length > 1)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.amber.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Items must be from the same shop to checkout. Select items from one shop below.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Cart Items List (grouped by Shop)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: shopGroups.keys.length,
                  itemBuilder: (context, groupIndex) {
                    final sId = shopGroups.keys.elementAt(groupIndex);
                    final shopDocs = shopGroups[sId]!;
                    final shopName = _shopNamesCache[sId] ?? 'Fish Shop';
                    final isShopActive = (_selectedShopId == sId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isShopActive
                              ? const Color(0xFF00B4D8).withValues(alpha: 0.6)
                              : const Color(0xFFE2E8F0),
                          width: isShopActive ? 1.5 : 1.0,
                        ),
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
                          // Shop Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isShopActive
                                  ? const Color(0xFF00B4D8)
                                      .withValues(alpha: 0.08)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  size: 20,
                                  color: isShopActive
                                      ? const Color(0xFF00B4D8)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    shopName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: isShopActive
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                if (isShopActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00B4D8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'SELECTED SHOP',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const Divider(height: 1),

                          // Items inside this shop group
                          ...shopDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final docId = doc.id;
                            final price = (data['pricePerKg'] as num?)
                                    ?.toDouble() ??
                                0.0;
                            final qty = (data['quantity'] as num?)
                                    ?.toDouble() ??
                                0.0;
                            final imageUrl = data['imageUrl'];
                            final isSelected =
                                _selectedItemIds.contains(docId);
                            final itemTotal = price * qty;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  // Selection Checkbox
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: const Color(0xFF00B4D8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) {
                                      _handleItemSelection(
                                          docId, sId, val == true);
                                    },
                                  ),

                                  // Product Image
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: const Color(0xFFF1F5F9),
                                      image: imageUrl != null
                                          ? DecorationImage(
                                              image: imageUrl.startsWith('http')
                                                  ? NetworkImage(imageUrl)
                                                      as ImageProvider
                                                  : MemoryImage(
                                                      base64Decode(imageUrl)),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: imageUrl == null
                                        ? const Icon(Icons.image,
                                            color: Color(0xFF94A3B8))
                                        : null,
                                  ),

                                  const SizedBox(width: 12),

                                  // Name, Price per kg, Subtotal
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'] ?? 'Product',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '₹${price.toStringAsFixed(0)} / kg',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Total: ₹${itemTotal.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Color(0xFF00B4D8),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quantity Counter
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: Colors.redAccent,
                                            size: 20),
                                        onPressed: () => _updateQuantity(
                                            docId, qty, -0.5),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                        child: Text(
                                          qty == qty.toInt()
                                              ? '${qty.toInt()} kg'
                                              : '${qty.toStringAsFixed(1)} kg',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            color: Colors.green,
                                            size: 20),
                                        onPressed: () => _updateQuantity(
                                            docId, qty, 0.5),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Checkout Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border:
                      const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_selectedItemIds.length} item(s) selected',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Pay on Delivery (COD)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF00B4D8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${selectedTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedItemIds.isNotEmpty
                                ? const Color(0xFF00B4D8)
                                : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: _selectedItemIds.isNotEmpty ? 2 : 0,
                          ),
                          onPressed: _selectedItemIds.isEmpty
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please select at least one item to proceed'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CheckoutScreen(
                                        totalAmount: selectedTotal,
                                        directItems: selectedItemsList,
                                      ),
                                    ),
                                  );
                                },
                          child: Text(
                            _selectedItemIds.isEmpty
                                ? 'Select items to checkout'
                                : 'Proceed to Checkout (${_selectedItemIds.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
