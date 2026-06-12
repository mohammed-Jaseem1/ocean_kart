import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'add_product_screen.dart';
import 'product_management_screen.dart';

class AddStockScreen extends StatefulWidget {
  final String? initialProductId;

  const AddStockScreen({super.key, this.initialProductId});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _inwardPriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  
  String? _selectedProductId;
  String? _selectedProductName;
  String? _imageUrl;
  Uint8List? _imageBytes;
  double _currentStock = 0.0;
  List<DocumentSnapshot> _products = [];
  bool _isLoading = false;
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .get();
        if (mounted) {
          setState(() {
            _products = querySnapshot.docs;
            _isLoadingProducts = false;

            if (widget.initialProductId != null) {
              final exists = _products.any((doc) => doc.id == widget.initialProductId);
              if (exists) {
                _selectedProductId = widget.initialProductId;
                final selectedDoc = _products.firstWhere((doc) => doc.id == _selectedProductId);
                final data = selectedDoc.data() as Map<String, dynamic>;
                _selectedProductName = data['name'];
                _imageUrl = data['imageUrl'];
                _currentStock = (data['stockQuantity'] as num?)?.toDouble() ?? 0.0;
                _quantityController.text = _currentStock.toString();
                if (data['inwardPrice'] != null) {
                  _inwardPriceController.text = data['inwardPrice'].toString();
                }
                if (data['pricePerKg'] != null) {
                  _salePriceController.text = data['pricePerKg'].toString();
                }
              }
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingProducts = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _inwardPriceController.dispose();
    _salePriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);

      if (mounted) {
        setState(() {
          _imageUrl = base64String;
          _imageBytes = bytes;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      final inwardPrice = double.tryParse(_inwardPriceController.text.trim()) ?? 0.0;
      final salePrice = double.tryParse(_salePriceController.text.trim()) ?? 0.0;
      final newTotalQuantity = double.tryParse(_quantityController.text.trim()) ?? 0.0;

      final selectedDoc = _products.firstWhere((doc) => doc.id == _selectedProductId);
      final data = selectedDoc.data() as Map<String, dynamic>;
      final previousQuantity = (data['stockQuantity'] as num?)?.toDouble() ?? 0.0;
      final inwardQuantity = newTotalQuantity - previousQuantity;

      // 1. Add to stocks collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stocks')
          .add({
        'productId': _selectedProductId,
        'productName': _selectedProductName,
        'inwardPrice': inwardPrice,
        'salePrice': salePrice,
        'inwardQuantity': inwardQuantity,
        'currentQuantity': newTotalQuantity,
        'date': FieldValue.serverTimestamp(),
      });

      // 2. Update the product's current stock and sale price
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .doc(_selectedProductId)
          .update({
        'pricePerKg': salePrice,
        'inwardPrice': inwardPrice,
        'stockQuantity': newTotalQuantity,
        if (_imageUrl != null) 'imageUrl': _imageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding stock: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _deleteProduct() async {
    if (_selectedProductId == null) return;
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product', style: TextStyle(color: Colors.black)),
          content: const Text('Are you sure you want to delete this product? This action cannot be undone.', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('products')
              .doc(_selectedProductId)
              .delete();
              
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product deleted successfully'), backgroundColor: Colors.green),
            );
            Navigator.pop(context);
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
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Colors.white;
    const cardColor = Color(0xFFF5F7FA);
    const accentColor = Colors.black;

    final inputDecoration = InputDecoration(
      hintStyle: TextStyle(color: Colors.black.withOpacity(0.4), fontSize: 14),
      filled: true,
      fillColor: Colors.black.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );

    Widget buildLabel(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black.withOpacity(0.7),
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Add Stock',
          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: accentColor),
        actions: [
          if (_selectedProductId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteProduct,
              tooltip: 'Delete Product',
            ),
        ],
      ),
      body: _isLoadingProducts
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  color: cardColor,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Colors.black.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Stock Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),

                          buildLabel('SELECT PRODUCT *'),
                          DropdownButtonFormField<String>(
                            value: _selectedProductId,
                            isExpanded: true,
                            dropdownColor: cardColor,
                            style: const TextStyle(color: Colors.black),
                            decoration: inputDecoration.copyWith(
                              hintText: 'Select Product',
                            ),
                            items: _products.isEmpty
                                ? [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('No products available', style: TextStyle(color: Colors.grey)),
                                    )
                                  ]
                                : _products.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    String displayName = data['name'] ?? 'Unknown';
                                    if (data['malayalamName'] != null && data['malayalamName'].toString().trim().isNotEmpty) {
                                      displayName += ' / ${data['malayalamName']}';
                                    }
                                    return DropdownMenuItem<String>(
                                      value: doc.id,
                                      child: Text(
                                        displayName, 
                                        style: const TextStyle(color: Colors.black),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                            onChanged: _products.isEmpty
                                ? null
                                : (String? newValue) {
                                    if (newValue != null) {
                                      final selectedDoc = _products.firstWhere((doc) => doc.id == newValue);
                                      final data = selectedDoc.data() as Map<String, dynamic>;
                                      setState(() {
                                        _selectedProductId = newValue;
                                        _selectedProductName = data['name'];
                                        _imageUrl = data['imageUrl'];
                                        _imageBytes = null; // Clear picked bytes if any
                                        _currentStock = (data['stockQuantity'] as num?)?.toDouble() ?? 0.0;
                                        _quantityController.text = _currentStock.toString();
                                        if (data['inwardPrice'] != null) {
                                          _inwardPriceController.text = data['inwardPrice'].toString();
                                        } else {
                                          _inwardPriceController.clear();
                                        }
                                        if (data['pricePerKg'] != null) {
                                          _salePriceController.text = data['pricePerKg'].toString();
                                        } else {
                                          _salePriceController.clear();
                                        }
                                      });
                                    }
                                  },
                            validator: (value) => value == null ? 'Required' : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AddProductScreen()),
                                );
                              },
                              icon: const Icon(Icons.add, color: accentColor, size: 16),
                              label: const Text('Add New Product', style: TextStyle(color: accentColor)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_selectedProductId != null) ...[
                            Center(
                              child: GestureDetector(
                                onTap: _isLoading ? null : _pickAndUploadImage,
                                child: Container(
                                  height: 110,
                                  width: 110,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _imageUrl != null ? Colors.green : Colors.black.withOpacity(0.2),
                                      width: 2,
                                    ),
                                    image: _imageBytes != null
                                        ? DecorationImage(
                                            image: MemoryImage(_imageBytes!),
                                            fit: BoxFit.cover,
                                          )
                                        : (_imageUrl != null
                                            ? DecorationImage(
                                                image: _imageUrl!.startsWith('http') 
                                                    ? NetworkImage(_imageUrl!) as ImageProvider
                                                    : MemoryImage(base64Decode(_imageUrl!)),
                                                fit: BoxFit.cover,
                                              )
                                            : null),
                                  ),
                                  child: (_imageUrl == null && _imageBytes == null)
                                      ? Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.black.withOpacity(0.5)),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Add Image',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black.withOpacity(0.5),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Align(
                                          alignment: Alignment.topRight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.greenAccent,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.edit, color: bgColor, size: 16),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          buildLabel('INWARD PRICE / PER KG *'),
                          TextFormField(
                            controller: _inwardPriceController,
                            style: const TextStyle(color: Colors.black),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: inputDecoration.copyWith(
                              hintText: 'e.g. 250',
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),

                          buildLabel('SALE PRICE / KG *'),
                          TextFormField(
                            controller: _salePriceController,
                            style: const TextStyle(color: Colors.black),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: inputDecoration.copyWith(
                              hintText: 'e.g. 280',
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),

                          buildLabel('TOTAL STOCK QUANTITY (KG / ITEMS) *'),
                          TextFormField(
                            controller: _quantityController,
                            style: const TextStyle(color: Colors.black),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: inputDecoration.copyWith(
                              hintText: 'e.g. 10',
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 32),

                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: bgColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(bgColor),
                                    ),
                                  )
                                : const Text(
                                    'Save Stock',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
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
    );
  }
}
