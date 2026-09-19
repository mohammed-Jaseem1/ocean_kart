import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String selectedLocation;
  final Map<String, Map<String, dynamic>> shopDataMap;

  const SearchScreen({
    super.key,
    required this.selectedLocation,
    this.shopDataMap = const {},
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late String _activeLocation;

  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _activeLocation = widget.selectedLocation;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _shopMatchesLocation(Map<String, dynamic>? shop, String location) {
    if (shop == null) return false;
    if (location == 'All' || location == 'All Locations' || location.isEmpty) {
      return true;
    }
    final loc = (shop['location'] ?? '').toString().toLowerCase().trim();
    final addr = (shop['address'] ?? shop['shopAddress'] ?? shop['pinnedAddress'] ?? '').toString().toLowerCase().trim();
    final target = location.toLowerCase().trim();

    return loc == target || loc.contains(target) || addr.contains(target);
  }

  Future<void> _addToCart(DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add items to cart')),
      );
      return;
    }

    final data = doc.data() as Map<String, dynamic>;
    final productId = doc.id;
    final bool isOffer = data['isOffer'] == true;
    final double offerPrice = (data['offerPrice'] as num?)?.toDouble() ?? 0.0;
    final price = isOffer && offerPrice > 0
        ? offerPrice
        : ((data['pricePerKg'] as num?)?.toDouble() ?? 0.0);

    final imagesList = (data['images'] as List?)?.map((e) => e.toString()).toList();
    final String? imageUrl = (imagesList != null && imagesList.isNotEmpty)
        ? imagesList.first
        : data['imageUrl']?.toString();

    try {
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(productId);
      final cartDoc = await cartRef.get();

      if (cartDoc.exists) {
        final currentQty =
            (cartDoc.data()?['quantity'] as num?)?.toDouble() ?? 0.0;
        await cartRef.update({'quantity': currentQty + 1.0});
      } else {
        await cartRef.set({
          'name': data['name'],
          'pricePerKg': price,
          'quantity': 1.0,
          'imageUrl': imageUrl,
          'shopId': data['shopId'],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${data['name'] ?? 'Fish'} added to cart'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to cart: $e')),
        );
      }
    }
  }

  Widget _buildProductCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String name = data['name'] ?? 'Unknown Product';
    final String? malayalamName = data['malayalamName'];
    final String displayName =
        malayalamName != null && malayalamName.trim().isNotEmpty
            ? '$name ($malayalamName)'
            : name;
    final imagesList = (data['images'] as List?)?.map((e) => e.toString()).toList();
    final String? imageUrl = (imagesList != null && imagesList.isNotEmpty)
        ? imagesList.first
        : data['imageUrl']?.toString();
    final double price = (data['pricePerKg'] as num?)?.toDouble() ?? 0.0;
    final bool isOffer = data['isOffer'] == true;
    final double offerPrice = (data['offerPrice'] as num?)?.toDouble() ?? 0.0;
    final double stockQuantity =
        (data['stockQuantity'] as num?)?.toDouble() ?? 0.0;
    final bool isOutOfStock = stockQuantity <= 0;
    final double activePrice = isOffer && offerPrice > 0 ? offerPrice : price;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              productDoc: doc,
              selectedLocation: _activeLocation,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFF8FAFC),
                    child: () {
                      if (imageUrl == null || imageUrl.isEmpty) {
                        return const Center(
                          child: Icon(Icons.set_meal_outlined,
                              color: Colors.black12, size: 36),
                        );
                      }
                      if (imageUrl.startsWith('http')) {
                        return CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.set_meal_outlined,
                                color: Colors.black12, size: 36),
                          ),
                        );
                      }
                      final cleanBase64 = imageUrl.contains('base64,')
                          ? imageUrl.split('base64,').last
                          : imageUrl;
                      try {
                        return Image.memory(
                          const Base64Decoder().convert(cleanBase64),
                          fit: BoxFit.cover,
                        );
                      } catch (_) {
                        return const Center(
                          child: Icon(Icons.set_meal_outlined,
                              color: Colors.black12, size: 36),
                        );
                      }
                    }(),
                  ),
                  if (isOutOfStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Out of Stock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isOutOfStock ? null : () => _addToCart(doc),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_basket_outlined,
                                  size: 19,
                                  color: isOutOfStock
                                      ? Colors.grey.shade400
                                      : const Color(0xFF0F2942),
                                ),
                                Positioned(
                                  right: -3,
                                  bottom: -1,
                                  child: Container(
                                    padding: const EdgeInsets.all(0.5),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      size: 10,
                                      color: isOutOfStock
                                          ? Colors.grey.shade400
                                          : const Color(0xFF0F2942),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isOffer && offerPrice > 0 && offerPrice < price)
                    Text(
                      '₹${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        decoration: TextDecoration.lineThrough,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    const SizedBox(height: 16),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹${activePrice.toStringAsFixed(activePrice.truncateToDouble() == activePrice ? 0 : 2)}',
                        style: const TextStyle(
                          color: Color(0xFF0A2540),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        '/1kg',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              color: Color(0xFF0F172A),
              size: 20,
            ),
          ),
        ),
        Positioned(
          right: -2,
          top: -2,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseAuth.instance.currentUser != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('cart')
                    .snapshots()
                : null,
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const SizedBox();
              }
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    '${snap.data!.docs.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            style: TextStyle(color: _textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search fresh fish, prawns, crab...',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13.5,
              ),
              border: InputBorder.none,
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Color(0xFF00B4D8),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        actions: [
          _buildCartIcon(),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter / Location Indicator bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.redAccent.shade400),
                const SizedBox(width: 4),
                Text(
                  _activeLocation,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          // Search Results or Suggestions
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collectionGroup('products').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final stock = (data['stockQuantity'] as num?)?.toDouble() ?? 0;
                  if (stock <= 0) return false;

                  // Location filter
                  if (_activeLocation != 'All' && _activeLocation != 'All Locations') {
                    final shopId = data['shopId']?.toString();
                    if (shopId != null && widget.shopDataMap.containsKey(shopId)) {
                      if (!_shopMatchesLocation(widget.shopDataMap[shopId], _activeLocation)) {
                        return false;
                      }
                    } else if (data['location'] != null &&
                        data['location'].toString().trim().isNotEmpty) {
                      final prodLoc = data['location'].toString().toLowerCase().trim();
                      if (!prodLoc.contains(_activeLocation.toLowerCase().trim())) {
                        return false;
                      }
                    }
                  }

                  // Search query filter
                  if (_searchQuery.isNotEmpty) {
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final malayalam = (data['malayalamName'] ?? '').toString().toLowerCase();
                    final cat = (data['category'] ?? '').toString().toLowerCase();
                    final q = _searchQuery.toLowerCase();
                    return name.contains(q) || malayalam.contains(q) || cat.contains(q);
                  }

                  return true;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No fish found for "$_searchQuery"'
                                : 'No products available in $_activeLocation',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textColor.withValues(alpha: 0.7),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try searching for salmon, pomfret, prawns, or change location.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textColor.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200.0,
                    mainAxisSpacing: 12.0,
                    crossAxisSpacing: 12.0,
                    childAspectRatio: 0.69,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(docs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
