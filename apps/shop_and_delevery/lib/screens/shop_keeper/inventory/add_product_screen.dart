import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import '../../../widgets/cached_product_image.dart';

String? _processWebpInIsolate(Uint8List rawBytes) {
  try {
    final decodedImage = img.decodeImage(rawBytes);
    if (decodedImage == null) return null;

    img.Image resized = decodedImage;
    if (decodedImage.width > 600 || decodedImage.height > 600) {
      if (decodedImage.width >= decodedImage.height) {
        resized = img.copyResize(decodedImage, width: 600);
      } else {
        resized = img.copyResize(decodedImage, height: 600);
      }
    }

    final webpBytes = img.encodeWebP(resized);
    return 'data:image/webp;base64,${base64Encode(webpBytes)}';
  } catch (e) {
    return 'data:image/jpeg;base64,${base64Encode(rawBytes)}';
  }
}

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
  final _priceController = TextEditingController();
  final _offerPriceController = TextEditingController();

  bool _isOffer = false;
  
  String _selectedCategory = '';
  List<String> _categories = [];
  bool _isLoadingCategories = true;

  bool _isLoading = false;
  List<String> _productImages = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();

    if (widget.productData != null) {
      _nameController.text = widget.productData!['name'] ?? '';
      _malayalamNameController.text = widget.productData!['malayalamName'] ?? '';
      _selectedCategory = widget.productData!['category'] ?? '';
      _priceController.text = widget.productData!['pricePerKg']?.toString() ?? '';

      if (widget.productData!['images'] != null && widget.productData!['images'] is List) {
        _productImages = List<String>.from(
          (widget.productData!['images'] as List).map((e) => e.toString()),
        );
      } else if (widget.productData!['imageUrl'] != null &&
          widget.productData!['imageUrl'].toString().trim().isNotEmpty) {
        _productImages = [widget.productData!['imageUrl'].toString()];
      }
      
      if (widget.productData!['isOffer'] == true) {
        _isOffer = true;
        _offerPriceController.text = widget.productData!['offerPrice']?.toString() ?? '';
      }
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('categories').get();
      final fetchedCats = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? 'active').toString().toLowerCase();
            return status == 'active';
          })
          .map((doc) => (doc.data()['name'] ?? doc.data()['categoryName'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .toList();

      final uniqueCats = fetchedCats.toSet().toList();

      if (mounted) {
        setState(() {
          _categories = uniqueCats;
          if (_selectedCategory.isNotEmpty && !_categories.contains(_selectedCategory)) {
            _categories.insert(0, _selectedCategory);
          }
          if (_categories.isNotEmpty && (_selectedCategory.isEmpty || !_categories.contains(_selectedCategory))) {
            _selectedCategory = _categories.first;
          }
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _malayalamNameController.dispose();
    _priceController.dispose();
    _offerPriceController.dispose();
    super.dispose();
  }

  Future<String?> _compressAndEncodeToWebp(Uint8List rawBytes) async {
    try {
      return await compute(_processWebpInIsolate, rawBytes);
    } catch (e) {
      debugPrint('WebP encoding failed: $e');
      return 'data:image/jpeg;base64,${base64Encode(rawBytes)}';
    }
  }

  void _pickAndUploadImage() async {
    if (_productImages.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 4 images allowed per product'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );

    if (pickedFile == null || !mounted) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      maxWidth: 800,
      maxHeight: 800,
      compressQuality: 70,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Product Image',
            toolbarColor: const Color(0xFF0A1628),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true),
        IOSUiSettings(
          title: 'Crop Product Image',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.page,
        ),
      ],
    );

    if (croppedFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final bytes = await croppedFile.readAsBytes();
      final webpDataUrl = await _compressAndEncodeToWebp(bytes);

      if (webpDataUrl != null && mounted) {
        setState(() {
          _productImages.add(webpDataUrl);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image added! (${_productImages.length}/4)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_productImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 1 product image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      final productsRef = FirebaseFirestore.instance.collection('shop_owners').doc(user.uid).collection('products');
      
      final productPayload = {
        'shopId': user.uid,
        'name': _nameController.text.trim(),
        'malayalamName': _malayalamNameController.text.trim(),
        'category': _selectedCategory,
        'images': _productImages,
        'imageUrl': _productImages.first,
        'pricePerKg': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'stockQuantity': (widget.productData?['stockQuantity'] as num?)?.toDouble() ?? 100.0,
        'isOffer': _isOffer,
        'offerPrice': _isOffer ? (double.tryParse(_offerPriceController.text.trim()) ?? 0.0) : 0.0,
        'status': widget.productData?['status'] ?? 'active',
        'isAvailable': widget.productData?['isAvailable'] ?? true,
      };

      if (widget.productId != null) {
        await productsRef.doc(widget.productId).update({
          ...productPayload,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await productsRef.add({
          ...productPayload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.productId != null ? 'Product updated successfully!' : 'Product added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving product: $e'), backgroundColor: Colors.red),
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

  Widget _buildMultiImagePicker(Color primaryBlue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Product Images *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            Text(
              '${_productImages.length}/4 images',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            onReorderItem: (int oldIndex, int newIndex) {
              if (oldIndex >= _productImages.length) return;
              if (newIndex > _productImages.length) {
                newIndex = _productImages.length;
              }
              setState(() {
                final item = _productImages.removeAt(oldIndex);
                _productImages.insert(newIndex, item);
              });
            },
            itemCount: _productImages.length + (_productImages.length < 4 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < _productImages.length) {
                final imgUrl = _productImages[index];

                return ReorderableDelayedDragStartListener(
                  key: ValueKey('img_${imgUrl.hashCode}_$index'),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: index == 0 ? primaryBlue : Colors.grey.shade300,
                              width: index == 0 ? 2 : 1,
                            ),
                          ),
                          child: CachedProductImage(
                            imageSource: imgUrl,
                            width: 100,
                            height: 100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        if (index == 0)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryBlue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'COVER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _productImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return Container(
                  key: const ValueKey('add_image_tile'),
                  margin: const EdgeInsets.only(right: 12.0),
                  child: GestureDetector(
                    onTap: _isLoading ? null : _pickAndUploadImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 28, color: primaryBlue),
                          const SizedBox(height: 4),
                          Text(
                            '+ Add Image',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF00B4D8);
    const navyBlue = Color(0xFF0A1628);

    final inputDecoration = InputDecoration(
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
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
        padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.productId != null ? 'Edit Product' : 'Add New Product',
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Multi-Image Picker Widget (Limit 4, WebP compressed)
              _buildMultiImagePicker(primaryBlue),
              const SizedBox(height: 24),

              // Fish / Product Name
              buildLabel('Fish / Product Name *'),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                decoration: inputDecoration.copyWith(
                  hintText: 'e.g. King Fish, Sardine, Mackerel...',
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter product name' : null,
              ),
              const SizedBox(height: 16),

              // Malayalam Name
              buildLabel('Malayalam Name (Optional)'),
              TextFormField(
                controller: _malayalamNameController,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                decoration: inputDecoration.copyWith(
                  hintText: 'e.g. നെയ്മീൻ, ചാള, അയില...',
                ),
              ),
              const SizedBox(height: 16),

              // Category (Fetched dynamically from Firestore 'categories')
              buildLabel('Category *'),
              _isLoadingCategories
                  ? const SizedBox(
                      height: 48,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _categories.contains(_selectedCategory)
                          ? _selectedCategory
                          : (_categories.isNotEmpty ? _categories.first : null),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                      decoration: inputDecoration.copyWith(
                        hintText: 'Select category',
                      ),
                      items: _categories.map((String category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        }
                      },
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Please select a category' : null,
                    ),
              const SizedBox(height: 16),

              // Sale Price
              buildLabel('Sale Price (₹ per kg) *'),
              TextFormField(
                controller: _priceController,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: inputDecoration.copyWith(
                  hintText: 'e.g. 250',
                  prefixText: '₹ ',
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter sale price' : null,
              ),
              const SizedBox(height: 16),

              // Put on Offer Switch (Clean Inline Tile)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Special Offer Discount',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(
                          _isOffer ? 'Special discounted price active' : 'Enable offer price',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        value: _isOffer,
                        activeThumbColor: primaryBlue,
                        onChanged: (bool value) {
                          setState(() {
                            _isOffer = value;
                          });
                        },
                      ),
                      if (_isOffer) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildLabel('Offer Price (₹ per kg) *'),
                              TextFormField(
                                controller: _offerPriceController,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: inputDecoration.copyWith(
                                  hintText: 'e.g. 199',
                                  prefixText: '₹ ',
                                  fillColor: Colors.white,
                                ),
                                validator: (value) {
                                  if (!_isOffer) return null;
                                  if (value == null || value.trim().isEmpty) return 'Please enter offer price';
                                  return null;
                                 },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navyBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.productId != null ? 'Update Product' : 'Save Product',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
