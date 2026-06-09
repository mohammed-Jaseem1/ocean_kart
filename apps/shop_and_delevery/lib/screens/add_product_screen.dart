import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();
  
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

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _simulateImageUpload() async {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate network delay for image upload
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _imageUrl = 'https://images.unsplash.com/photo-1615141982883-c7ad0e69fd62?w=800&q=80'; // Mock URL
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully! (Mock)')),
      );
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
      await FirebaseFirestore.instance.collection('products').add({
        'shopId': user.uid,
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'pricePerKg': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'stockAvailable': double.tryParse(_stockController.text.trim()) ?? 0.0,
        'description': _descriptionController.text.trim(),
        'imageUrl': _imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active', // active or out_of_stock
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product added successfully!'),
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
    const navyBlue = Color(0xFF0A1628);
    const cardColor = Color(0xFF132238);
    const lightBlue = Color(0xFF00B4D8);

    final inputDecoration = InputDecoration(
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      filled: true,
      fillColor: navyBlue.withOpacity(0.5),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightBlue),
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

    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Add New Product',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            color: cardColor,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Upload Section
                    Center(
                      child: GestureDetector(
                        onTap: _isLoading ? null : _simulateImageUpload,
                        child: Container(
                          height: 150,
                          width: 150,
                          decoration: BoxDecoration(
                            color: navyBlue.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _imageUrl != null ? Colors.greenAccent : Colors.white.withOpacity(0.2),
                              width: 2,
                            ),
                            image: _imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _imageUrl == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.white.withOpacity(0.5)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload Image',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, color: navyBlue, size: 16),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Product Details Form
                    const Text(
                      'Product Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration.copyWith(
                        labelText: 'Fish / Product Name',
                        prefixIcon: const Icon(Icons.set_meal_outlined, color: lightBlue),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      dropdownColor: cardColor,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration.copyWith(
                        labelText: 'Category',
                        prefixIcon: const Icon(Icons.category_outlined, color: lightBlue),
                      ),
                      items: _categories.map((String category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category, style: const TextStyle(color: Colors.white)),
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
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: inputDecoration.copyWith(
                              labelText: 'Price per Kg (₹)',
                              prefixIcon: const Icon(Icons.currency_rupee, color: lightBlue),
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: inputDecoration.copyWith(
                              labelText: 'Stock (Kg)',
                              prefixIcon: const Icon(Icons.inventory_2_outlined, color: lightBlue),
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      decoration: inputDecoration.copyWith(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 60.0),
                          child: Icon(Icons.description_outlined, color: lightBlue),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lightBlue,
                        foregroundColor: navyBlue,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(navyBlue),
                              ),
                            )
                          : const Text(
                              'Save Product',
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
