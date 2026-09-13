import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'checkout_screen.dart';
import '../constants/kerala_places.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  String _selectedCategory = '';
  String _selectedShopId = '';
  String _selectedLocation = 'Kochi';

  final Color _navyBlue = const Color(0xFFF8FAFC);
  final Color _cardColor = Colors.white;
  final Color _lightBlue = const Color(0xFF00B4D8);
  final Color _textColor = const Color(0xFF0F172A);




  late Stream<QuerySnapshot> _productsStream;
  late Stream<List<DocumentSnapshot>> _shopsStream;

  @override
  void initState() {
    super.initState();
    _productsStream = FirebaseFirestore.instance
        .collectionGroup('products')
        .snapshots();
    _shopsStream = FirebaseFirestore.instance
        .collection('shop_owners')
        .snapshots()
        .asyncMap((shopOwnersSnap) async {
      try {
        final legacySnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Shopkeeper')
            .where('status', isEqualTo: 'active')
            .get();
        final shopOwnerIds = shopOwnersSnap.docs.map((d) => d.id).toSet();
        final combinedDocs = List<DocumentSnapshot>.from(
          shopOwnersSnap.docs.where((d) {
            final data = d.data() as Map<String, dynamic>?;
            return data?['status'] != 'inactive' && data?['status'] != 'disabled';
          }),
        );
        for (var doc in legacySnap.docs) {
          if (!shopOwnerIds.contains(doc.id)) {
            combinedDocs.add(doc);
          }
        }
        return combinedDocs;
      } catch (_) {
        return shopOwnersSnap.docs;
      }
    });
  }

  Future<void> _addToCart(DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = doc.data() as Map<String, dynamic>;
    final productId = doc.id;
    final bool isOffer = data['isOffer'] == true;
    final double offerPrice = (data['offerPrice'] as num?)?.toDouble() ?? 0.0;
    final price = isOffer ? offerPrice : ((data['pricePerKg'] as num?)?.toDouble() ?? 0.0);

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
          'imageUrl': data['imageUrl'],
          'shopId': data['shopId'],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navyBlue,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDeliveryPage(),
            _buildOrdersPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryPage() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeroSection()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8, left: 16),
            child: Text(
              'Collections',
              style: TextStyle(
                color: _textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildCategories()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12, left: 16),
            child: Text(
              'Top brands near you',
              style: TextStyle(
                color: _textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildTopBrands()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Text(
              'Fresh Stock Available',
              style: TextStyle(
                color: _textColor.withValues(alpha: 0.9),
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _productsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            var docs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final stock = (data['stockQuantity'] as num?)?.toDouble() ?? 0;
              return stock > 0;
            }).toList();

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

            if (_selectedCategory.isNotEmpty) {
              if (_selectedCategory == 'Offers') {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isOffer'] == true;
                }).toList();
              } else {
                final query = _selectedCategory.toLowerCase();
                final singularQuery = query.endsWith('s')
                    ? query.substring(0, query.length - 1)
                    : query;

                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final cat = (data['category'] ?? '').toString().toLowerCase();
                  final name = (data['name'] ?? '').toString().toLowerCase();

                  if (cat.contains(query) || cat.contains(singularQuery)) {
                    return true;
                  }
                  if (name.contains(query) || name.contains(singularQuery)) {
                    return true;
                  }

                  return false;
                }).toList();
              }
            }

            if (_selectedShopId.isNotEmpty) {
              docs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['shopId'] ?? '') == _selectedShopId;
              }).toList();
            }

            if (docs.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'No products found.',
                      style: TextStyle(color: _textColor.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200.0,
                  mainAxisSpacing: 12.0,
                  crossAxisSpacing: 12.0,
                  childAspectRatio: 0.72, // Adjusted for smaller floating card
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _buildProductCard(docs[index]);
                }, childCount: docs.length),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }


  Widget _buildOrdersPage() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please login to view orders."));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Text(
            'My Orders',
            style: TextStyle(
              color: _textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('userId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // Try without orderBy if index is missing
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .where('userId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshotBackup) {
                    if (snapshotBackup.hasError) {
                      return Center(
                        child: Text(
                          'Error loading orders: ${snapshotBackup.error}',
                        ),
                      );
                    }
                    if (!snapshotBackup.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _buildOrderList(snapshotBackup.data!.docs);
                  },
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildOrderList(snapshot.data!.docs);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderList(List<DocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          'You have no orders yet.',
          style: TextStyle(color: _textColor.withValues(alpha: 0.6)),
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final status = data['status'] ?? 'pending';
        final items = data['items'] as List<dynamic>? ?? [];

        Color statusColor = Colors.orange;
        if (status == 'completed' || status == 'delivered') {
          statusColor = Colors.green;
        } else if (status == 'cancelled') {
          statusColor = Colors.red;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${docs[index].id.substring(0, 8)}',
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '${item['quantity']}x ${item['name']}',
                    style: TextStyle(
                      color: _textColor.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(
                      color: _textColor.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '₹$total',
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (status == 'pending') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cancel Order'),
                          content: const Text(
                            'Are you sure you want to cancel and remove this order?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Yes, Cancel',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(docs[index].id)
                              .delete();
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Order cancelled and removed'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to cancel order: $e'),
                              ),
                            );
                          }
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel Order'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroSection() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 340,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const CachedNetworkImageProvider(
                'https://images.unsplash.com/photo-1615141982883-c7ad0e69fd62?q=80&w=1000&auto=format&fit=crop',
              ),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.6),
                BlendMode.darken,
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Location Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      position: PopupMenuPosition.under,
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      constraints: const BoxConstraints(maxHeight: 300, maxWidth: 200),
                      onSelected: (String newValue) {
                        setState(() {
                          _selectedLocation = newValue;
                        });
                      },
                      itemBuilder: (BuildContext context) {
                        return keralaPlaces.map((String place) {
                          return PopupMenuItem<String>(
                            value: place,
                            height: 38,
                            child: Text(
                              place,
                              style: const TextStyle(color: Colors.black87, fontSize: 13),
                            ),
                          );
                        }).toList();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(
                              keralaPlaces.contains(_selectedLocation)
                                  ? _selectedLocation
                                  : keralaPlaces.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Cart & Profile Icons
              Row(
                children: [
                  _buildCartIcon(),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 20,
                      child: Icon(Icons.person, color: _lightBlue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Order Fresh Seafood Online',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Best shops in your city delivering to your doorstep',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  style: const TextStyle(
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search for fish, prawns, etc.',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
          child: CircleAvatar(
            backgroundColor: Colors.white,
            radius: 20,
            child: Icon(Icons.shopping_cart, color: _lightBlue),
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

  Widget _buildCategories() {
    return SizedBox(
      height: 100,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const SizedBox();
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final cat = docs[index].data() as Map<String, dynamic>;
              final name = cat['name']?.toString() ?? '';
              final imageUrl = cat['imageUrl']?.toString() ?? '';
              final isSelected = _selectedCategory == name;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedCategory == name) {
                        _selectedCategory = ''; // Deselect
                      } else {
                        _selectedCategory = name;
                      }
                    });
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          color: _cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? _lightBlue
                                : _lightBlue.withValues(alpha: 0.3),
                            width: isSelected ? 3 : 1,
                          ),
                          image: imageUrl.isNotEmpty
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(imageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageUrl.isEmpty
                            ? Icon(
                                Icons.category,
                                color: _lightBlue,
                                size: 30,
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTopBrands() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _shopsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox();
        }
        final shops = snapshot.data!;
        return SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final shopDoc = shops[index];
              final shop = shopDoc.data() as Map<String, dynamic>;
              final shopName = shop['name'] ?? 'Shop';
              final shopId = shopDoc.id;
              final isSelected = _selectedShopId == shopId;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedShopId == shopId) {
                        _selectedShopId = '';
                      } else {
                        _selectedShopId = shopId;
                      }
                    });
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          color: isSelected ? _lightBlue : Colors.white,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: _lightBlue.withValues(alpha: 0.3),
                                  width: 4,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            shopName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : _lightBlue,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        shopName,
                        style: TextStyle(
                          color: isSelected ? _lightBlue : _textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String name = data['name'] ?? 'Unknown Product';
    final String? malayalamName = data['malayalamName'];
    final String displayName =
        malayalamName != null && malayalamName.trim().isNotEmpty
        ? '$name\\n($malayalamName)'
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

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFFF1F5F9),
                  width: double.infinity,
                  height: double.infinity,
                  child: () {
                    if (imageUrl == null || imageUrl.isEmpty) {
                      return const Center(child: Icon(Icons.image, color: Colors.black12, size: 32));
                    }
                    if (imageUrl.startsWith('http')) {
                      return CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover);
                    }
                    final cleanBase64 = imageUrl.contains('base64,') ? imageUrl.split('base64,').last : imageUrl;
                    try {
                      return Image.memory(const Base64Decoder().convert(cleanBase64), fit: BoxFit.cover);
                    } catch (_) {
                      return const Center(child: Icon(Icons.image, color: Colors.black12, size: 32));
                    }
                  }(),
                ),
                if (isOffer)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'OFFER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isOffer)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹$price / kg',
                            style: const TextStyle(
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '₹$offerPrice / kg',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '₹$price / kg',
                        style: TextStyle(
                          color: _lightBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    if (isOutOfStock)
                      const Text(
                        'Out of Stock',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      )
                    else
                      Text(
                        '${stockQuantity.toStringAsFixed(1)}kg left',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: isOutOfStock ? null : () => _addToCart(doc),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? Colors.grey.shade300
                                : _lightBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'ADD',
                              style: TextStyle(
                                color: isOutOfStock ? Colors.grey : _lightBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: isOutOfStock
                            ? null
                            : () async {
                                await _addToCart(doc);
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CheckoutScreen(totalAmount: 0),
                                    ),
                                  );
                                }
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isOutOfStock
                                ? null
                                : LinearGradient(
                                    colors: [
                                      _lightBlue,
                                      const Color(0xFF0077B6),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            color: isOutOfStock ? Colors.grey.shade400 : null,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isOutOfStock
                                ? []
                                : [
                                    BoxShadow(
                                      color: _lightBlue.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: const Center(
                            child: Text(
                              'BUY',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: _lightBlue,
        unselectedItemColor: _textColor.withValues(alpha: 0.4),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
        ),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.delivery_dining),
            ),
            label: 'Delivery',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.receipt_long_outlined),
            ),
            label: 'Orders',
          ),
        ],
      ),
    );
  }
}
