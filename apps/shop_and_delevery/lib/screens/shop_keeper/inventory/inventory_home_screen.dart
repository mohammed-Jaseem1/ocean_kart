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

  Future<void> _updateStock(String productId, double currentStock, double change) async {
    final newStock = currentStock + change;
    if (newStock < 0) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('products')
          .doc(productId)
          .update({'stockQuantity': newStock});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating stock: $e')));
    }
  }

  Future<void> _editPrice(String productId, double currentPrice) async {
    final _priceController = TextEditingController(text: currentPrice.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Sale Price (₹)', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          content: TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.black),
            decoration: const InputDecoration(
              hintText: 'Enter new price',
              hintStyle: TextStyle(color: Colors.grey),
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
                final newPrice = double.tryParse(_priceController.text);
                Navigator.pop(context, newPrice);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
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
                                  Text('No active products found', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                                ],
                              ),
                            )
                          : ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), // Padding for FAB
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final productId = docs[index].id;
                    final currentStock = (data['stockQuantity'] as num?)?.toDouble() ?? 0.0;
                    final currentPrice = (data['pricePerKg'] as num?)?.toDouble() ?? 0.0;

                    return Card(
                      color: Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['malayalamName'] != null && data['malayalamName'].toString().isNotEmpty
                                        ? '${data['name'] ?? 'Unknown'} (${data['malayalamName']})'
                                        : data['name'] ?? 'Unknown',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${data['category'] ?? ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text('₹$currentPrice / kg', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _editPrice(productId, currentPrice),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.grey.shade300)
                                          ),
                                          child: const Icon(Icons.edit, size: 14, color: Colors.black54),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                const Text('Stock (kg)', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _updateStock(productId, currentStock, -1.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                        child: const Icon(Icons.remove, size: 16, color: Colors.black),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text(
                                        currentStock == currentStock.toInt() ? '${currentStock.toInt()}' : currentStock.toStringAsFixed(1), 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _updateStock(productId, currentStock, 1.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: lightBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                        child: const Icon(Icons.add, size: 16, color: lightBlue),
                                      ),
                                    ),
                                  ],
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
