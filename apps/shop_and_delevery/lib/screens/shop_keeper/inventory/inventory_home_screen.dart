import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_product_screen.dart';
import 'add_stock_screen.dart';
import 'dart:convert';

class InventoryHomeScreen extends StatefulWidget {
  const InventoryHomeScreen({super.key});

  @override
  State<InventoryHomeScreen> createState() => _InventoryHomeScreenState();
}

class _InventoryHomeScreenState extends State<InventoryHomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _selectedCategory = 'All';

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
                  final stock = (data['stockQuantity'] as num?)?.toDouble() ?? 0.0;
                  final category = data['category'] ?? '';
                  final matchesCategory = _selectedCategory == 'All' || category == _selectedCategory;
                  return stock > 0 && matchesCategory;
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
                                  Text('No active products found', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                                ],
                              ),
                            )
                          : ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), // Padding for FAB
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      color: Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: data['imageUrl'] != null
                                ? DecorationImage(
                                    image: data['imageUrl'].startsWith('http')
                                        ? NetworkImage(data['imageUrl']) as ImageProvider
                                        : MemoryImage(base64Decode(data['imageUrl'])),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.grey.shade200,
                          ),
                          child: data['imageUrl'] == null ? const Icon(Icons.image, color: Colors.grey) : null,
                        ),
                        title: Text(
                          data['malayalamName'] != null && data['malayalamName'].toString().isNotEmpty
                              ? '${data['name'] ?? 'Unknown'} (${data['malayalamName']})'
                              : data['name'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text('${data['category'] ?? ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text('Inward: ₹${data['inwardPrice'] ?? 0}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(width: 12),
                                Text('Sale: ₹${data['pricePerKg'] ?? 0}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Stock: ${data['stockQuantity'] ?? 0} Kg', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddStockScreen(initialProductId: docs[index].id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_product',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddProductScreen()),
              );
            },
            backgroundColor: navyBlue,
            icon: const Icon(Icons.add_box_outlined, color: Colors.white),
            label: const Text('New Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'add_stock',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddStockScreen()),
              );
            },
            backgroundColor: lightBlue,
            icon: const Icon(Icons.inventory_2, color: navyBlue),
            label: const Text('Add Stock', style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue)),
          ),
        ],
      ),
    );
  }
}
