import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'shop_details_screen.dart';
import 'select_shops_screen.dart';

class AssignedStoresScreen extends StatefulWidget {
  const AssignedStoresScreen({super.key});

  @override
  State<AssignedStoresScreen> createState() => _AssignedStoresScreenState();
}

class _AssignedStoresScreenState extends State<AssignedStoresScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();

  static const Color _primaryCyan = Color(0xFF00B4D8);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _successGreen = Color(0xFF10B981);

  String _searchQuery = '';
  final Map<String, Map<String, dynamic>> _shopDataCache = {};
  bool _isLoadingShops = true;

  @override
  void initState() {
    super.initState();
    _fetchAllShopsDetails();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllShopsDetails() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('shop_owners').get();
      for (var doc in snapshot.docs) {
        _shopDataCache[doc.id] = doc.data();
      }

      // Also check users collection as fallback
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Shop Owner')
          .get();
      for (var doc in usersSnapshot.docs) {
        if (!_shopDataCache.containsKey(doc.id)) {
          _shopDataCache[doc.id] = doc.data();
        }
      }
    } catch (e) {
      debugPrint('Error loading shops cache: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingShops = false);
      }
    }
  }


  Future<void> _openDirections(String address) async {
    if (address.isEmpty || address == 'N/A') return;
    final encoded = Uri.encodeComponent(address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map directions')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assigned Stores')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'My Assigned Stores',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: _textDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_outlined, color: _primaryCyan),
            tooltip: 'Request / Select Stores',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SelectShopsScreen()),
              ).then((_) => _fetchAllShopsDetails());
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting && _isLoadingShops) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryCyan),
              ),
            );
          }

          final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final List<String> assignedShopIds = List<String>.from(userData['assignedShopIds'] ?? []);
          final List<String> assignedShopNames = List<String>.from(userData['assignedShopNames'] ?? []);

          if (assignedShopIds.isEmpty && assignedShopNames.isEmpty) {
            return _buildEmptyState();
          }

          // Build item list
          final List<Map<String, dynamic>> shopItems = [];
          final count = assignedShopIds.length > assignedShopNames.length
              ? assignedShopIds.length
              : assignedShopNames.length;

          for (int i = 0; i < count; i++) {
            final id = i < assignedShopIds.length ? assignedShopIds[i] : '';
            final name = i < assignedShopNames.length ? assignedShopNames[i] : (id.isNotEmpty ? id : 'Store');
            final cachedData = _shopDataCache[id] ?? {};

            shopItems.add({
              'id': id,
              'name': cachedData['shopName'] ?? cachedData['name'] ?? name,
              'data': cachedData,
            });
          }

          // Filter by search
          final filteredShops = shopItems.where((shop) {
            final name = shop['name'].toString().toLowerCase();
            final q = _searchQuery.toLowerCase().trim();
            return q.isEmpty || name.contains(q);
          }).toList();

          return Column(
            children: [
              // Search & Header Stats
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search assigned stores...',
                        hintStyle: const TextStyle(fontSize: 13.5, color: _textMuted),
                        prefixIcon: const Icon(Icons.search, color: _primaryCyan, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: _textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${shopItems.length} Stores Assigned',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SelectShopsScreen()),
                            ).then((_) => _fetchAllShopsDetails());
                          },
                          child: const Row(
                            children: [
                              Text(
                                'Manage Stores',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryCyan,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right, size: 16, color: _primaryCyan),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stores List
              Expanded(
                child: filteredShops.isEmpty
                    ? Center(
                        child: Text(
                          'No stores match "$_searchQuery"',
                          style: const TextStyle(color: _textMuted, fontSize: 13.5),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredShops.length,
                        itemBuilder: (context, index) {
                          final item = filteredShops[index];
                          final shopId = item['id'] as String;
                          final shopName = item['name'] as String;
                          final shopData = item['data'] as Map<String, dynamic>;

                          return _buildStoreCard(shopId, shopName, shopData);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStoreCard(String shopId, String shopName, Map<String, dynamic> shopData) {
    final phone = shopData['phone'] ?? shopData['mobileNumber'] ?? 'N/A';
    final address = shopData['shopAddress'] ?? shopData['address'] ?? shopData['location'] ?? 'N/A';
    final isShopActive = shopData['isAvailable'] ?? shopData['isOpen'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopDetailsScreen(
                  shopId: shopId,
                  shopName: shopName,
                  initialShopData: shopData.isNotEmpty ? shopData : null,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Store Icon, Name, Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: _primaryCyan, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isShopActive ? _successGreen : Colors.amber.shade700,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isShopActive ? 'Active / Open' : 'Closed',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isShopActive ? _successGreen : Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _textMuted, size: 22),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: _cardBorder),
                const SizedBox(height: 12),

                // Address & Phone
                if (address != 'N/A') ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: _textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _textDark, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                if (phone != 'N/A') ...[
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 15, color: _textMuted),
                      const SizedBox(width: 6),
                      Text(
                        phone,
                        style: const TextStyle(fontSize: 12, color: _textDark, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons Row: Ready Orders Badge + Call & Directions + View Orders Button
                Row(
                  children: [
                    // Pending Orders Stream Badge
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .where('shopId', isEqualTo: shopId)
                          .snapshots(),
                      builder: (context, orderSnap) {
                        int readyCount = 0;
                        if (orderSnap.hasData) {
                          readyCount = orderSnap.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final st = (data['status'] ?? '').toString().toLowerCase();
                            final boy = data['deliveryBoyId'];
                            return (st == 'pending' || st == 'ready_for_pickup' || st == 'placed') &&
                                (boy == null || boy == '');
                          }).length;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: readyCount > 0
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 13,
                                color: readyCount > 0 ? const Color(0xFFF59E0B) : _textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                readyCount > 0 ? '$readyCount Ready' : '0 Orders',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: readyCount > 0 ? const Color(0xFFF59E0B) : _textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const Spacer(),

                    // Directions Quick Action
                    if (address != 'N/A')
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.directions_outlined, color: _primaryCyan, size: 18),
                        tooltip: 'Directions',
                        onPressed: () => _openDirections(address),
                      ),

                    const SizedBox(width: 4),

                    // View Store Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ShopDetailsScreen(
                              shopId: shopId,
                              shopName: shopName,
                              initialShopData: shopData.isNotEmpty ? shopData : null,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryCyan,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right, size: 15, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primaryCyan.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded, size: 48, color: _primaryCyan),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Assigned Stores Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have not been assigned to any stores yet by the admin. You can also select stores to request assignment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textMuted, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectShopsScreen()),
                ).then((_) => _fetchAllShopsDetails());
              },
              icon: const Icon(Icons.add_business_rounded, size: 18, color: Colors.white),
              label: const Text(
                'Request Store Assignment',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryCyan,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
