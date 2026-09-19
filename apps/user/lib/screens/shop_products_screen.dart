import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

class ShopProductsScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;

  const ShopProductsScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.shopData,
  });

  @override
  State<ShopProductsScreen> createState() => _ShopProductsScreenState();
}

class _ShopProductsScreenState extends State<ShopProductsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final Color _navyBlue = const Color(0xFFF8FAFC);
  final Color _cardColor = Colors.white;
  final Color _lightBlue = const Color(0xFF00B4D8);
  final Color _textColor = const Color(0xFF0F172A);

  late Stream<QuerySnapshot> _productsStream;

  @override
  void initState() {
    super.initState();
    _productsStream = FirebaseFirestore.instance
        .collectionGroup('products')
        .snapshots();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _addToCart(DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to add items to cart')),
        );
      }
      return;
    }

    final data = doc.data() as Map<String, dynamic>;
    final productId = doc.id;
    final bool isOffer = data['isOffer'] == true;
    final double offerPrice = (data['offerPrice'] as num?)?.toDouble() ?? 0.0;
    final price = isOffer ? offerPrice : ((data['pricePerKg'] as num?)?.toDouble() ?? 0.0);
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
          'shopId': data['shopId'] ?? widget.shopId,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Added to Cart',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add to cart: $e')));
      }
    }
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
          child: CircleAvatar(
            backgroundColor: Colors.grey.shade100,
            radius: 19,
            child: Icon(Icons.shopping_cart_outlined, color: _textColor, size: 20),
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
                : const Stream.empty(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              if (count == 0) return const SizedBox();
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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
    final shopProfileImg = (widget.shopData['profileImage'] ??
            widget.shopData['imageUrl'] ??
            widget.shopData['shopImage'] ??
            '')
        .toString()
        .trim();
    final address = (widget.shopData['address'] ??
            widget.shopData['place'] ??
            widget.shopData['location'] ??
            '')
        .toString()
        .trim();
    final phone = (widget.shopData['phone'] ??
            widget.shopData['phoneNumber'] ??
            '')
        .toString()
        .trim();

    return Scaffold(
      backgroundColor: _navyBlue,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.shopName,
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          _buildCartIcon(),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _productsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading products: ${snapshot.error}'));
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Filter products for this shop and stock > 0
          var docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final stock = (data['stockQuantity'] as num?)?.toDouble() ?? 0;
            if (stock <= 0) return false;

            final shopId = (data['shopId'] ?? '').toString();
            // Also check parent doc path if collection is nested under shop
            final pathMatches = doc.reference.path.contains(widget.shopId);

            return shopId == widget.shopId || pathMatches;
          }).toList();

          // Extract unique categories for this shop
          final Set<String> categories = {'All'};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final cat = (data['category'] ?? '').toString().trim();
            if (cat.isNotEmpty) {
              categories.add(cat);
            }
          }

          // Apply category filter
          if (_selectedCategory != 'All') {
            docs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data['category'] ?? '').toString().toLowerCase() ==
                  _selectedCategory.toLowerCase();
            }).toList();
          }

          // Apply search filter
          if (_searchQuery.isNotEmpty) {
            docs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final malayalam = (data['malayalamName'] ?? '')
                  .toString()
                  .toLowerCase();
              return name.contains(_searchQuery.toLowerCase()) ||
                  malayalam.contains(_searchQuery.toLowerCase());
            }).toList();
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Shop Header Info Card
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      // Shop Avatar
                      Container(
                        width: 70,
                        height: 70,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _lightBlue.withValues(alpha: 0.1),
                          border: Border.all(
                            color: _lightBlue.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: shopProfileImg.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: shopProfileImg,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _lightBlue,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: Text(
                                    widget.shopName.isNotEmpty
                                        ? widget.shopName[0].toUpperCase()
                                        : 'S',
                                    style: TextStyle(
                                      color: _lightBlue,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  widget.shopName.isNotEmpty
                                      ? widget.shopName[0].toUpperCase()
                                      : 'S',
                                  style: TextStyle(
                                    color: _lightBlue,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      // Shop Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.shopName,
                                    style: TextStyle(
                                      color: _textColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified,
                                          color: Colors.green, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Verified',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (address.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      color: Colors.grey.shade500, size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      address,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _makePhoneCall(phone),
                                borderRadius: BorderRadius.circular(6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.phone_outlined,
                                        color: _lightBlue, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      phone,
                                      style: TextStyle(
                                        color: _lightBlue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search & Category Filter Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                            });
                          },
                          style: TextStyle(color: _textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search products in ${widget.shopName}...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(Icons.search,
                                color: Colors.grey.shade500, size: 20),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      if (categories.length > 1) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: categories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: isSelected,
                                  selectedColor: _lightBlue,
                                  backgroundColor: Colors.white,
                                  labelStyle: TextStyle(
                                    color:
                                        isSelected ? Colors.white : _textColor,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  showCheckmark: false,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected
                                          ? _lightBlue
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedCategory = cat;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Product Count Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Products (${docs.length})',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Products Grid
              if (docs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products available in this shop',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please check back later or explore other shops',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200.0,
                      mainAxisSpacing: 12.0,
                      crossAxisSpacing: 12.0,
                      childAspectRatio: 0.69,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildProductCard(docs[index]),
                      childCount: docs.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
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
            builder: (_) => ProductDetailScreen(productDoc: doc),
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
                        child: Icon(Icons.set_meal_outlined, color: Colors.black12, size: 36),
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
                          child: Icon(Icons.set_meal_outlined, color: Colors.black12, size: 36),
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
                        child: Icon(Icons.set_meal_outlined, color: Colors.black12, size: 36),
                      );
                    }
                  }(),
                ),
                if (isOutOfStock)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                      onTap: isOutOfStock
                          ? null
                          : () async {
                              await _addToCart(doc);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$name added to cart'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
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
}
