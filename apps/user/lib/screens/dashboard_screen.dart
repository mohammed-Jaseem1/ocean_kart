import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'category_products_screen.dart';
import 'shop_products_screen.dart';
import 'search_screen.dart';
import 'product_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final String _searchQuery = '';
  String _selectedLocation = 'All Locations';
  final Map<String, Map<String, dynamic>> _shopDataMap = {};

  final Color _navyBlue = const Color(0xFFF8FAFC);
  final Color _cardColor = Colors.white;
  final Color _lightBlue = const Color(0xFF00B4D8);
  final Color _textColor = const Color(0xFF0F172A);

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
        final map = <String, Map<String, dynamic>>{};
        for (var doc in combinedDocs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            map[doc.id] = data;
          }
        }
        if (mounted) {
          _shopDataMap.clear();
          _shopDataMap.addAll(map);
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
            ProfileScreen(
              isTab: true,
              onSwitchToOrders: () {
                setState(() {
                  _selectedIndex = 1;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryPage() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildBannerImage()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 12, left: 16),
                  child: Text(
                    'Shop by Category',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildCategories()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12, left: 16),
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
                    if (stock <= 0) return false;

                    // Filter by location
                    if (_selectedLocation != 'All' && _selectedLocation != 'All Locations') {
                      final shopId = data['shopId']?.toString();
                      if (shopId != null && _shopDataMap.containsKey(shopId)) {
                        if (!_shopMatchesLocation(_shopDataMap[shopId], _selectedLocation)) {
                          return false;
                        }
                      } else if (data['location'] != null && data['location'].toString().trim().isNotEmpty) {
                        final prodLoc = data['location'].toString().toLowerCase().trim();
                        if (!prodLoc.contains(_selectedLocation.toLowerCase().trim())) {
                          return false;
                        }
                      }
                    }

                    return true;
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

                  if (docs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            _selectedLocation != 'All' && _selectedLocation != 'All Locations'
                                ? 'No products available in $_selectedLocation.'
                                : 'No products found.',
                            style: TextStyle(color: _textColor.withValues(alpha: 0.6)),
                          ),
                        ),
                      ),
                    );
                  }

                  // Group products by category
                  final Map<String, List<DocumentSnapshot>> categoryMap = {};
                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    String cat = (data['category'] ?? '').toString().trim();
                    if (cat.isEmpty) {
                      cat = 'Fresh Catch';
                    }
                    categoryMap.putIfAbsent(cat, () => []).add(doc);
                  }

                  final categories = categoryMap.keys.toList();
                  categories.sort((a, b) {
                    if (a.toLowerCase().contains('fish')) return -1;
                    if (b.toLowerCase().contains('fish')) return 1;
                    return a.compareTo(b);
                  });

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, catIndex) {
                        final categoryName = categories[catIndex];
                        final catDocs = categoryMap[categoryName]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Section Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        categoryName,
                                        style: TextStyle(
                                          color: _textColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00B4D8)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${catDocs.length}',
                                          style: const TextStyle(
                                            color: Color(0xFF00B4D8),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              CategoryProductsScreen(
                                            categoryName: categoryName,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'See all',
                                          style: TextStyle(
                                            color: Color(0xFF00B4D8),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(width: 3),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 11,
                                          color: Color(0xFF00B4D8),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Grid of products for this category
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 200.0,
                                  mainAxisSpacing: 12.0,
                                  crossAxisSpacing: 12.0,
                                  childAspectRatio: 0.69,
                                ),
                                itemCount: catDocs.length,
                                itemBuilder: (context, index) {
                                  return _buildProductCard(catDocs[index]);
                                },
                              ),
                            ),

                            const SizedBox(height: 8),
                          ],
                        );
                      },
                      childCount: categories.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
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

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Search Icon Button (40x40 to match cart icon)
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: Icon(Icons.search_rounded, color: _textColor, size: 24),
              padding: EdgeInsets.zero,
              tooltip: 'Search',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchScreen(
                      selectedLocation: _selectedLocation,
                      shopDataMap: _shopDataMap,
                    ),
                  ),
                );
              },
            ),
          ),

          // Center: Perfectly centered Location Selector
          Expanded(
            child: Center(
              child: _buildLocationSelector(),
            ),
          ),

          // Right: Cart icon (40x40)
          _buildCartIcon(),
        ],
      ),
    );
  }

  Widget _buildLocationSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('locations').snapshots(),
      builder: (context, locSnap) {
        final List<String> places = ['All Locations'];
        if (locSnap.hasData) {
          final dbPlaces = locSnap.data!.docs
              .map((d) =>
                  ((d.data() as Map<String, dynamic>)['name'] ?? '').toString().trim())
              .where((n) => n.isNotEmpty)
              .toList();
          dbPlaces.sort((a, b) => a.compareTo(b));
          places.addAll(dbPlaces);
        }

        final String currentDisplay = places.contains(_selectedLocation)
            ? _selectedLocation
            : (places.length > 1 ? places[1] : 'All Locations');

        return InkWell(
          onTap: () => _showLocationBottomSheet(places),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    currentDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _textColor,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLocationBottomSheet(List<String> places) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filterQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredPlaces = places.where((p) {
              if (filterQuery.isEmpty) return true;
              return p.toLowerCase().contains(filterQuery.toLowerCase());
            }).toList();

            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on, color: Color(0xFF00B4D8), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Select Location',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Search Filter
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setSheetState(() {
                            filterQuery = val.trim();
                          });
                        },
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search city or area...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // List of locations
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filteredPlaces.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Colors.grey.shade100,
                      ),
                      itemBuilder: (context, index) {
                        final place = filteredPlaces[index];
                        final isSelected = place == _selectedLocation ||
                            (place == 'All Locations' &&
                                (_selectedLocation == 'All' || _selectedLocation == 'All Locations'));

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00B4D8).withValues(alpha: 0.12)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              place == 'All Locations'
                                  ? Icons.public_rounded
                                  : Icons.location_on_rounded,
                              color: isSelected
                                  ? const Color(0xFF00B4D8)
                                  : const Color(0xFF64748B),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            place,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? const Color(0xFF00B4D8) : const Color(0xFF0F172A),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF00B4D8), size: 22)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedLocation = place;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        );
      },
    );
  }

  Widget _buildBannerImage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Container(
        width: double.infinity,
        height: 175,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl:
              'https://firebasestorage.googleapis.com/v0/b/oceankart-83bbd.firebasestorage.app/o/banners%2Ffresh_fish_banner.jpg?alt=media&token=35309bf1-5159-4486-adcf-ed0ac9a77b08',
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Image.asset(
            'assets/fish_banner.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(Icons.set_meal, color: Colors.white, size: 48),
              ),
            ),
          ),
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
      height: 108,
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

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryProductsScreen(
                          categoryName: name,
                          categoryImageUrl: imageUrl,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Container(
                            color: Colors.white,
                            child: Transform.scale(
                              scale: 1.2,
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => Container(
                                        color: Colors.white,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF00B4D8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.white,
                                        child: const Icon(
                                          Icons.set_meal_rounded,
                                          color: Color(0xFF0F172A),
                                          size: 32,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.white,
                                      child: const Icon(
                                        Icons.set_meal_rounded,
                                        color: Color(0xFF0F172A),
                                        size: 32,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 82,
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
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
        final allShops = snapshot.data!;
        final shops = allShops.where((doc) {
          final shop = doc.data() as Map<String, dynamic>?;
          return _shopMatchesLocation(shop, _selectedLocation);
        }).toList();

        if (shops.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              _selectedLocation != 'All' && _selectedLocation != 'All Locations'
                  ? 'No shops available in $_selectedLocation'
                  : 'No shops available',
              style: TextStyle(color: _textColor.withValues(alpha: 0.6), fontSize: 13),
            ),
          );
        }
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
              final shopName = shop['name'] ?? shop['shopName'] ?? 'Shop';
              final shopId = shopDoc.id;
              final shopProfileImg = (shop['profileImage'] ?? shop['imageUrl'] ?? shop['shopImage'] ?? '').toString().trim();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopProductsScreen(
                          shopId: shopId,
                          shopName: shopName,
                          shopData: shop,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 75,
                        height: 75,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: shopProfileImg.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: shopProfileImg,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: _lightBlue),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: Text(
                                    shopName.isNotEmpty ? shopName.substring(0, 1).toUpperCase() : 'S',
                                    style: TextStyle(
                                      color: _lightBlue,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  shopName.isNotEmpty ? shopName.substring(0, 1).toUpperCase() : 'S',
                                  style: TextStyle(
                                    color: _lightBlue,
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
                          color: _textColor,
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
              selectedLocation: _selectedLocation,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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

  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
              ),
              _buildNavItem(
                index: 1,
                label: 'Orders',
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
              ),
              _buildNavItem(
                index: 2,
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? _lightBlue : const Color(0xFF8E8E93);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
