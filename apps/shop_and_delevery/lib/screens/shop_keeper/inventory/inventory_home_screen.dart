import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_product_screen.dart';
import 'dart:convert';

class InventoryHomeScreen extends StatefulWidget {
  const InventoryHomeScreen({super.key});

  @override
  State<InventoryHomeScreen> createState() => _InventoryHomeScreenState();
}

class _InventoryHomeScreenState extends State<InventoryHomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _selectedCategory = 'All';

  Future<void> _toggleProductStatus(String productId, bool currentlyActive) async {
    final newStatus = currentlyActive ? 'inactive' : 'active';
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('products')
          .doc(productId)
          .update({
            'status': newStatus,
            'isAvailable': !currentlyActive,
            'stockQuantity': currentlyActive ? 0.0 : 100.0,
          });

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

  Future<void> _editPrice(String productId, double currentPrice) async {
    final priceController = TextEditingController(text: currentPrice.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Sale Price (₹)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.black, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Enter new price',
              hintStyle: TextStyle(color: Colors.grey),
              prefixText: '₹ ',
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final newPrice = double.tryParse(priceController.text);
                Navigator.pop(context, newPrice);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B4D8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (result != null && result >= 0) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('products')
            .doc(productId)
            .update({'pricePerKg': result});
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating price: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyBlue = Color(0xFF0A1628);
    const lightBlue = Color(0xFF00B4D8);
    const backgroundWhite = Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: backgroundWhite,
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('products')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: lightBlue));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final allDocs = snapshot.data?.docs ?? [];
                
                if (allDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No products in inventory', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AddProductScreen()),
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Add Your First Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: navyBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final Set<String> categories = {'All'};
                for (var doc in allDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['category'] != null && data['category'].toString().trim().isNotEmpty) {
                    categories.add(data['category']);
                  }
                }
                final categoryList = categories.toList();

                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final category = data['category'] ?? '';
                  return _selectedCategory == 'All' || category == _selectedCategory;
                }).toList();

                return Column(
                  children: [
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: categoryList.length,
                        itemBuilder: (context, index) {
                          final category = categoryList[index];
                          final isSelected = category == _selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category, style: TextStyle(color: isSelected ? Colors.white : navyBlue, fontWeight: FontWeight.bold)),
                              selected: isSelected,
                              selectedColor: navyBlue,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300)),
                              showCheckmark: false,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = category;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: docs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.filter_alt_off_outlined, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text('No products found in category', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data() as Map<String, dynamic>;
                                final productId = docs[index].id;
                                final currentPrice = (data['pricePerKg'] as num?)?.toDouble() ?? 0.0;
                                final String status = (data['status'] ?? 'active').toString().toLowerCase();
                                final bool isActive = status == 'active' && (data['isAvailable'] != false);

                                return Card(
                                  color: Colors.white,
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        (() {
                                          final imagesList = (data['images'] as List?)?.map((e) => e.toString()).toList();
                                          final imgStr = (imagesList != null && imagesList.isNotEmpty)
                                              ? imagesList.first
                                              : (data['imageUrl']?.toString());

                                          if (imgStr == null || imgStr.isEmpty) {
                                            return Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                color: Colors.grey.shade200,
                                              ),
                                              child: const Icon(Icons.image, color: Colors.grey),
                                            );
                                          }

                                          ImageProvider imgProvider;
                                          if (imgStr.startsWith('http')) {
                                            imgProvider = NetworkImage(imgStr);
                                          } else if (imgStr.contains('base64,')) {
                                            final cleanBase64 = imgStr.split('base64,').last;
                                            imgProvider = MemoryImage(base64Decode(cleanBase64));
                                          } else {
                                            imgProvider = MemoryImage(base64Decode(imgStr));
                                          }

                                          return Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              image: DecorationImage(image: imgProvider, fit: BoxFit.cover),
                                            ),
                                          );
                                        })(),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['malayalamName'] != null && data['malayalamName'].toString().isNotEmpty
                                                    ? '${data['name'] ?? 'Unknown'} (${data['malayalamName']})'
                                                    : data['name'] ?? 'Unknown',
                                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              const SizedBox(height: 2),
                                              Text('${data['category'] ?? ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Text('₹$currentPrice / kg', style: const TextStyle(color: lightBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                                                  const SizedBox(width: 6),
                                                  InkWell(
                                                    onTap: () => _editPrice(productId, currentPrice),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey.shade100,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: Colors.grey.shade300)
                                                      ),
                                                      child: const Icon(Icons.edit, size: 13, color: Colors.black54),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Active / Inactive Status Toggle
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
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
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Transform.scale(
                                              scale: 0.85,
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
