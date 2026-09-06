import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectShopsScreen extends StatefulWidget {
  final bool isInitialSetup;

  const SelectShopsScreen({
    super.key,
    this.isInitialSetup = false,
  });

  @override
  State<SelectShopsScreen> createState() => _SelectShopsScreenState();
}

class _SelectShopsScreenState extends State<SelectShopsScreen> {
  static const Color primaryBlue = Color(0xFF00B4D8);
  static const Color darkNavy = Color(0xFF0A1628);
  static const Color cardBg = Color(0xFF132238);

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();

  List<String> _assignedShopIds = [];
  List<String> _selectedShopIds = [];
  List<String> _pendingShopIds = [];

  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentAssignments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAssignments() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final assigned = List<String>.from(data['assignedShopIds'] ?? []);
        final requested = List<String>.from(data['requestedShopIds'] ?? []);

        setState(() {
          _assignedShopIds = assigned;
          _pendingShopIds = requested;
          // Combine for initial checkboxes
          _selectedShopIds = {...assigned, ...requested}.toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading assigned shops: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitShopRequest() async {
    if (currentUser == null) return;
    if (_selectedShopIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one shop to deliver for.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Find shop names for selected IDs
      final shopsSnapshot = await FirebaseFirestore.instance
          .collection('shop_owners')
          .get();

      final List<String> requestedNames = [];
      for (var doc in shopsSnapshot.docs) {
        if (_selectedShopIds.contains(doc.id)) {
          final data = doc.data();
          requestedNames.add(data['shopName'] ?? data['name'] ?? 'Shop');
        }
      }

      // Keep already assigned shops, put newly selected ones in requestedShopIds
      final newRequests = _selectedShopIds
          .where((id) => !_assignedShopIds.contains(id))
          .toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({
        'requestedShopIds': _selectedShopIds,
        'requestedShopNames': requestedNames,
        'shopRequestStatus': 'pending',
        'shopRequestUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newRequests.isNotEmpty
                  ? 'Shop request sent to Admin for approval!'
                  : 'Shop preferences updated!',
            ),
            backgroundColor: const Color(0xFF2ED573),
          ),
        );

        if (widget.isInitialSetup) {
          Navigator.pop(context);
        } else {
          _loadCurrentAssignments();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkNavy,
      appBar: AppBar(
        backgroundColor: darkNavy,
        elevation: 0,
        title: const Text(
          'Select Preferred Shops',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : Column(
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: cardBg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.storefront, color: primaryBlue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Choose Stores to Deliver For',
                            style: TextStyle(
                              color: primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select the shops you want orders to come from. Once submitted, Admin will approve your store assignment.',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                      const SizedBox(height: 12),
                      // Search bar
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: 'Search shop name or location...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white54),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Shops List from Firestore
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('shop_owners')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: primaryBlue));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No shops found in system.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      final shops = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['shopName'] ?? data['name'] ?? '').toString().toLowerCase();
                        final loc = (data['location'] ?? data['address'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery) || loc.contains(_searchQuery);
                      }).toList();

                      if (shops.isEmpty) {
                        return const Center(
                          child: Text(
                            'No matching shops found.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: shops.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = shops[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final shopId = doc.id;
                          final shopName = data['shopName'] ?? data['name'] ?? 'Unnamed Shop';
                          final location = data['location'] ?? data['address'] ?? 'Kerala';
                          final phone = data['mobileNumber'] ?? '';

                          final isAssigned = _assignedShopIds.contains(shopId);
                          final isPending = _pendingShopIds.contains(shopId) && !isAssigned;
                          final isSelected = _selectedShopIds.contains(shopId);

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isAssigned
                                    ? const Color(0xFF2ED573).withValues(alpha: 0.6)
                                    : isSelected
                                        ? primaryBlue
                                        : Colors.white12,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Material(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              clipBehavior: Clip.antiAlias,
                              child: CheckboxListTile(
                              value: isSelected,
                              activeColor: isAssigned ? const Color(0xFF2ED573) : primaryBlue,
                              checkColor: darkNavy,
                              onChanged: (bool? checked) {
                                setState(() {
                                  if (checked == true) {
                                    if (!_selectedShopIds.contains(shopId)) {
                                      _selectedShopIds.add(shopId);
                                    }
                                  } else {
                                    _selectedShopIds.remove(shopId);
                                  }
                                });
                              },
                              secondary: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isAssigned ? const Color(0xFF2ED573) : primaryBlue)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.store,
                                  color: isAssigned ? const Color(0xFF2ED573) : primaryBlue,
                                  size: 24,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      shopName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (isAssigned)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2ED573).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF2ED573), width: 0.8),
                                      ),
                                      child: const Text(
                                        'Assigned',
                                        style: TextStyle(
                                          color: Color(0xFF2ED573),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else if (isPending)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber, width: 0.8),
                                      ),
                                      child: const Text(
                                        'Pending Approval',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.place, size: 13, color: Colors.white54),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            location,
                                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (phone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone, size: 13, color: Colors.white54),
                                          const SizedBox(width: 4),
                                          Text(
                                            phone,
                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                        },
                      );
                    },
                  ),
                ),

                // Submit Button bottom bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submitShopRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: darkNavy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(darkNavy),
                                ),
                              )
                            : Text(
                                'Send Shop Request to Admin (${_selectedShopIds.length} selected)',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
