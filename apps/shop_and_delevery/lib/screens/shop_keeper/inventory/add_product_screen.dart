import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'product_management_screen.dart';

class AddProductScreen extends StatefulWidget {
  final String? productId;
  final Map<String, dynamic>? productData;

  const AddProductScreen({
    super.key,
    this.productId,
    this.productData,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _malayalamNameController = TextEditingController();
  
  String _selectedCategory = 'Sea Water Fish';
  final List<String> _categories = [
    'Sea Water Fish',
    'Fresh Water Fish',
    'Prawns & Shrimps',
    'Crabs',
    'Exotic Seafood',
    'Others'
  ];

  bool _isLoading = false;
  String? _imageUrl; // Placeholder for uploaded image URL
  Uint8List? _imageBytes; // Store local bytes for preview

  @override
  void initState() {
    super.initState();
    if (widget.productData != null) {
      _nameController.text = widget.productData!['name'] ?? '';
      _malayalamNameController.text = widget.productData!['malayalamName'] ?? '';
      _selectedCategory = widget.productData!['category'] ?? 'Sea Water Fish';
      _imageUrl = widget.productData!['imageUrl'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _malayalamNameController.dispose();
    super.dispose();
  }

  void _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Convert to Base64 to store directly in Firestore
      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);

      if (mounted) {
        setState(() {
          _imageUrl = base64String;
          _imageBytes = bytes; // Use local bytes for preview
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an image first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Save to Firestore
      final productsRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products');
      
      final productPayload = {
        'shopId': user.uid,
        'name': _nameController.text.trim(),
        'malayalamName': _malayalamNameController.text.trim(),
        'category': _selectedCategory,
        'imageUrl': _imageUrl,
      };

      if (widget.productId != null) {
        // Update existing product
        await productsRef.doc(widget.productId).update({
          ...productPayload,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add new product
        await productsRef.add({
          ...productPayload,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active', // active or out_of_stock
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.productId != null ? 'Product updated successfully!' : 'Product added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e'), backgroundColor: Colors.red),
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
        title: Text(
          widget.productId != null ? 'Edit Product' : 'Add New Product',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProductManagementScreen()),
              );
            },
            icon: const Icon(Icons.edit_note, color: Colors.black),
            label: const Text('Manage Products', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                    // Image Upload Section
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
                                        image: NetworkImage(_imageUrl!),
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
                                      'Upload',
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
                                      child: const Icon(Icons.check, color: bgColor, size: 16),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Product Details Form
                    const Text(
                      '1. FISH LOCAL IDENTITY (പേര് വിവരങ്ങൾ)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 16),

                    buildLabel('FISH / PRODUCT NAME *'),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.black),
                      decoration: inputDecoration.copyWith(
                        hintText: 'e.g. King Fish, Sardine, Mackerel...',
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    buildLabel('MALAYALAM NAME (OPTIONAL)'),
                    TextFormField(
                      controller: _malayalamNameController,
                      style: const TextStyle(color: Colors.black),
                      decoration: inputDecoration.copyWith(
                        hintText: 'e.g. നെയ്മീൻ, ചാള, അയില...',
                      ),
                    ),
                    const SizedBox(height: 16),

                    buildLabel('CATEGORY *'),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      dropdownColor: cardColor,
                      style: const TextStyle(color: Colors.black),
                      decoration: inputDecoration.copyWith(
                        hintText: 'Select Category',
                      ),
                      items: _categories.map((String category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category, style: const TextStyle(color: Colors.black)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        }
                      },
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
                          : Text(
                              widget.productId != null ? 'Update Product' : 'Save Product',
                              style: const TextStyle(
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
