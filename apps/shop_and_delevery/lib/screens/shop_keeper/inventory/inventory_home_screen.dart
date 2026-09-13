import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_product_screen.dart';
import '../../../widgets/cached_product_image.dart';

class InventoryHomeScreen extends StatefulWidget {
  const InventoryHomeScreen({super.key});

  @override
  State<InventoryHomeScreen> createState() => _InventoryHomeScreenState();
}

class _InventoryHomeScreenState extends State<InventoryHomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  User? get user => FirebaseAuth.instance.currentUser;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleProductStatus(String productId, bool currentlyActive) async {
    final currentUser = user;
    if (currentUser == null) return;
    final newStatus = currentlyActive ? 'inactive' : 'active';
    try {
      await FirebaseFirestore.instance
          .collection('shop_owners')
          .doc(currentUser.uid)
          .collection('products')
          .doc(productId)
          .update({
            'status': newStatus,
            'isAvailable': !currentlyActive,
          });

      // Updated in shop_owners collection

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyActive ? 'Product set to Inactive' : 'Product set to Active'),
            backgroundColor: currentlyActive ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating product status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteProduct(String productId, String productName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        content: Text('Are you sure you want to delete "$productName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('shop_owners')
            .doc(user!.uid)
            .collection('products')
            .doc(productId)
            .delete();

        // Deleted from shop_owners collection

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting product: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }



  String _formatPrice(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const navyBlue = Color(0xFF0A1628);
    const lightBlue = Color(0xFF00B4D8);
    const backgroundWhite = Color(0xFFF5F7FA);

    final currentUser = user;

    return Scaffold(
      backgroundColor: backgroundWhite,
      body: currentUser == null
          ? const Center(
              child: Text(
                'Please log in to manage inventory',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shop_owners')
                  .doc(currentUser.uid)
                  .collection('products')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: lightBlue));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Error loading inventory: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                }
                final allDocs = snapshot.data?.docs ?? [];

                if (allDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: lightBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inventory_2_outlined, size: 64, color: lightBlue),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No Products in Inventory',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add items to your catalog so customers can view and place orders.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Extract Categories with count
                final Map<String, int> categoryCounts = {'All': allDocs.length};
                for (var doc in allDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final cat = (data['category'] ?? 'Others').toString().trim();
                  if (cat.isNotEmpty) {
                    categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
                  }
                }
                final categoryList = categoryCounts.keys.toList();

                // Filter by category and search
                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final category = data['category'] ?? '';
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final malayalamName = (data['malayalamName'] ?? '').toString().toLowerCase();

                  final matchesCategory = _selectedCategory == 'All' || category == _selectedCategory;
                  final query = _searchQuery.toLowerCase();
                  final matchesSearch = query.isEmpty || name.contains(query) || malayalamName.contains(query);

                  return matchesCategory && matchesSearch;
                }).toList();

                return Column(
                  children: [
                    // Search and Filter Bar Header
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        children: [
                          // Search Box
                          Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim();
                                });
                              },
                              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText: 'Search product name, category...',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
                                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                        },
                                        child: Icon(Icons.cancel_rounded, color: Colors.grey.shade400, size: 18),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Horizontal Category Chips
                          SizedBox(
                            height: 38,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: categoryList.length,
                              itemBuilder: (context, index) {
                                final category = categoryList[index];
                                final count = categoryCounts[category] ?? 0;
                                final isSelected = category == _selectedCategory;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      '$category ($count)',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : navyBlue,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: navyBlue,
                                    backgroundColor: Colors.grey.shade50,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected ? navyBlue : Colors.grey.shade300,
                                      ),
                                    ),
                                    showCheckmark: false,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedCategory = category;
                                        });
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Product List
                    Expanded(
                      child: docs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.filter_alt_off_outlined, size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No matching products found',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Try adjusting your search or category filter.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 90),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data() as Map<String, dynamic>;
                                final productId = docs[index].id;
                                final double price = (data['pricePerKg'] as num?)?.toDouble() ?? 0.0;
                                final bool isOffer = data['isOffer'] == true;
                                final double offerPrice = (data['offerPrice'] as num?)?.toDouble() ?? 0.0;
                                final String status = (data['status'] ?? 'active').toString().toLowerCase();
                                final bool isActive = status == 'active' && (data['isAvailable'] != false);
                                final String name = data['name'] ?? 'Unknown Product';
                                final String? malayalamName = data['malayalamName'];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Image Preview Container
                                            Stack(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(14),
                                                    border: Border.all(color: Colors.grey.shade200),
                                                  ),
                                                  child: CachedProductImage(
                                                    imageSource: () {
                                                      final imagesList = (data['images'] as List?)?.map((e) => e.toString()).toList();
                                                      return (imagesList != null && imagesList.isNotEmpty)
                                                          ? imagesList.first
                                                          : (data['imageUrl']?.toString());
                                                    }(),
                                                    width: 76,
                                                    height: 76,
                                                    fit: BoxFit.cover,
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                ),
                                                if (isOffer)
                                                  Positioned(
                                                    top: 4,
                                                    left: 4,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.redAccent,
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Text(
                                                        'OFFER',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 8.5,
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(width: 14),

                                            // Details Section
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Title & Malayalam Name
                                                  Text(
                                                    malayalamName != null && malayalamName.trim().isNotEmpty
                                                        ? '$name ($malayalamName)'
                                                        : name,
                                                    style: const TextStyle(
                                                      color: Color(0xFF0F172A),
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 15,
                                                      height: 1.2,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),

                                                  // Category Chip & Stock Status Row
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          data['category'] ?? 'General',
                                                          style: const TextStyle(
                                                            color: Color(0xFF475569),
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),

                                                  // Price Row
                                                  Row(
                                                    children: [
                                                      if (isOffer) ...[
                                                        Text(
                                                          '₹${_formatPrice(offerPrice)}',
                                                          style: const TextStyle(
                                                            color: Colors.redAccent,
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '₹${_formatPrice(price)}',
                                                          style: TextStyle(
                                                            color: Colors.grey.shade400,
                                                            decoration: TextDecoration.lineThrough,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        Text(
                                                          ' / kg',
                                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                        ),
                                                      ] else ...[
                                                        Text(
                                                          '₹${_formatPrice(price)}',
                                                          style: const TextStyle(
                                                            color: lightBlue,
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        Text(
                                                          ' / kg',
                                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Active / Inactive Switch
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: isActive ? Colors.green.shade200 : Colors.red.shade200),
                                                  ),
                                                  child: Text(
                                                    isActive ? 'ACTIVE' : 'INACTIVE',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Transform.scale(
                                                  scale: 0.8,
                                                  child: Switch(
                                                    value: isActive,
                                                    activeThumbColor: lightBlue,
                                                    activeTrackColor: lightBlue.withValues(alpha: 0.3),
                                                    inactiveThumbColor: Colors.grey.shade400,
                                                    inactiveTrackColor: Colors.grey.shade200,
                                                    onChanged: (val) => _toggleProductStatus(productId, isActive),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        const Divider(height: 20, color: Color(0xFFF1F5F9)),

                                        // Action Buttons Row (Edit Details & Delete)
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => AddProductScreen(
                                                      productId: productId,
                                                      productData: data,
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF00B4D8)),
                                              label: const Text(
                                                'Edit Details',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00B4D8)),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Color(0xFF00B4D8)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              onPressed: () => _deleteProduct(productId, name),
                                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                              label: const Text(
                                                'Delete',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: Colors.red.shade200),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_product',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProductScreen()),
          );
        },
        backgroundColor: navyBlue,
        icon: const Icon(Icons.add_box_outlined, color: Colors.white),
        label: const Text('+ Add Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
      ),
    );
  }
}
