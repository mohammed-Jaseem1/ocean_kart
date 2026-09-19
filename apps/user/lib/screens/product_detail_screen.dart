import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final DocumentSnapshot productDoc;
  final String? selectedLocation;

  const ProductDetailScreen({
    super.key,
    required this.productDoc,
    this.selectedLocation,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final Color _cardColor = Colors.white;
  final Color _lightBlue = const Color(0xFF00B4D8);
  final Color _textColor = const Color(0xFF0F172A);

  double _quantity = 1.0;
  bool _isAdding = false;

  late DocumentSnapshot _currentDoc;

  @override
  void initState() {
    super.initState();
    _currentDoc = widget.productDoc;
  }

  Future<void> _addToCart(DocumentSnapshot doc, double qty) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add items to cart')),
      );
      return;
    }

    setState(() => _isAdding = true);
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
        await cartRef.update({'quantity': currentQty + qty});
      } else {
        await cartRef.set({
          'name': data['name'],
          'pricePerKg': price,
          'quantity': qty,
          'imageUrl': imageUrl,
          'shopId': data['shopId'],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${data['name'] ?? 'Item'} added to cart'),
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
    } finally {
      if (mounted) setState(() => _isAdding = false);
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
        setState(() {
          _currentDoc = doc;
          _quantity = 1.0;
        });
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
                        onTap: isOutOfStock
                            ? null
                            : () => _addToCart(doc, 1.0),
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

  @override
  Widget build(BuildContext context) {
    final data = _currentDoc.data() as Map<String, dynamic>;
    final String name = data['name'] ?? 'Fresh Fish';
    final String? malayalamName = data['malayalamName'];
    final imagesList =
        (data['images'] as List?)?.map((e) => e.toString()).toList();
    final String? imageUrl = (imagesList != null && imagesList.isNotEmpty)
        ? imagesList.first
        : data['imageUrl']?.toString();

    final double price = (data['pricePerKg'] as num?)?.toDouble() ?? 0.0;
    final bool isOffer = data['isOffer'] == true;
    final double offerPrice = (data['offerPrice'] as num?)?.toDouble() ?? 0.0;
    final double activePrice =
        isOffer && offerPrice > 0 ? offerPrice : price;
    final double stockQuantity =
        (data['stockQuantity'] as num?)?.toDouble() ?? 0.0;
    final bool isOutOfStock = stockQuantity <= 0;
    final String category = (data['category'] ?? '').toString();
    final String shopId = (data['shopId'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Product Details',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          _buildCartIcon(),
          const SizedBox(width: 12),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Quantity stepper
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      color: _textColor,
                      onPressed: _quantity > 0.5 && !isOutOfStock
                          ? () {
                              setState(() {
                                _quantity = (_quantity - 0.5)
                                    .clamp(0.5, stockQuantity > 0 ? stockQuantity : 100.0);
                              });
                            }
                          : null,
                    ),
                    Text(
                      '${_quantity.toStringAsFixed(_quantity.truncateToDouble() == _quantity ? 0 : 1)} kg',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      color: _textColor,
                      onPressed: !isOutOfStock &&
                              (_quantity + 0.5 <= stockQuantity || stockQuantity == 0)
                          ? () {
                              setState(() {
                                _quantity += 0.5;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Add to Cart Button
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isOutOfStock || _isAdding
                        ? null
                        : () => _addToCart(_currentDoc, _quantity),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _lightBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isAdding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_basket_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Add to Cart',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Hero Image
            Container(
              width: double.infinity,
              height: 300,
              color: const Color(0xFFF1F5F9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  () {
                    if (imageUrl == null || imageUrl.isEmpty) {
                      return const Center(
                        child: Icon(Icons.set_meal_outlined,
                            size: 64, color: Colors.black26),
                      );
                    }
                    if (imageUrl.startsWith('http')) {
                      return CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.set_meal_outlined,
                              size: 64, color: Colors.black26),
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
                            size: 64, color: Colors.black26),
                      );
                    }
                  }(),
                  if (isOffer)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'SPECIAL OFFER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product Details Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Malayalam name
                  Text(
                    name,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  if (malayalamName != null &&
                      malayalamName.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      malayalamName,
                      style: TextStyle(
                        color: _textColor.withValues(alpha: 0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Price Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹${activePrice.toStringAsFixed(activePrice.truncateToDouble() == activePrice ? 0 : 2)}',
                        style: const TextStyle(
                          color: Color(0xFF0A2540),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '/ 1kg',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isOffer && offerPrice > 0 && offerPrice < price) ...[
                        const SizedBox(width: 12),
                        Text(
                          '₹${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 16,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Stock & Status Badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOutOfStock
                                  ? Icons.cancel_outlined
                                  : Icons.check_circle_outline,
                              size: 14,
                              color: isOutOfStock ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOutOfStock
                                  ? 'Out of Stock'
                                  : 'In Stock (${stockQuantity.toStringAsFixed(1)} kg available)',
                              style: TextStyle(
                                color: isOutOfStock ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (category.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _lightBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: _lightBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'About this fish',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (data['description'] != null &&
                            data['description'].toString().trim().isNotEmpty)
                        ? data['description'].toString()
                        : 'Freshly harvested, cleaned, and packed in temperature-controlled hygienic environments to preserve maximum ocean freshness and taste.',
                    style: TextStyle(
                      color: _textColor.withValues(alpha: 0.7),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Recommended For You (5 products)
                  Row(
                    children: [
                      Text(
                        'Recommended for you',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Top picks you might like',
                    style: TextStyle(
                      color: _textColor.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildRecommendedSection(category, shopId),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedSection(String category, String shopId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collectionGroup('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final allDocs = snapshot.data!.docs.where((d) => d.id != _currentDoc.id).toList();

        // Prefer same category or same shop, limit to 5
        final recommended = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final stock = (data['stockQuantity'] as num?)?.toDouble() ?? 0;
          return stock > 0;
        }).toList();

        recommended.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aScore = (aData['category'] == category ? 2 : 0) +
              (aData['shopId'] == shopId ? 1 : 0);
          final bScore = (bData['category'] == category ? 2 : 0) +
              (bData['shopId'] == shopId ? 1 : 0);
          return bScore.compareTo(aScore);
        });

        final displayList = recommended.take(5).toList();

        if (displayList.isEmpty) {
          return const SizedBox();
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200.0,
            mainAxisSpacing: 12.0,
            crossAxisSpacing: 12.0,
            childAspectRatio: 0.69,
          ),
          itemCount: displayList.length,
          itemBuilder: (context, index) {
            return _buildProductCard(displayList[index]);
          },
        );
      },
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
}
