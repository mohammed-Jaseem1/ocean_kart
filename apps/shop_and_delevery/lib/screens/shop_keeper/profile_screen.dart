import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import '../common/location_setup_screen.dart';
import '../../widgets/cached_product_image.dart';

Uint8List? _processProfileWebpInIsolate(Uint8List rawBytes) {
  try {
    final decodedImage = img.decodeImage(rawBytes);
    if (decodedImage == null) return rawBytes;

    img.Image resized = decodedImage;
    if (decodedImage.width > 600 || decodedImage.height > 600) {
      if (decodedImage.width >= decodedImage.height) {
        resized = img.copyResize(decodedImage, width: 600);
      } else {
        resized = img.copyResize(decodedImage, height: 600);
      }
    }

    final webpBytes = img.encodeWebP(resized);
    return Uint8List.fromList(webpBytes);
  } catch (e) {
    return rawBytes;
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _primaryCyan = Color(0xFF00B4D8);
  static const Color _darkNavy = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  bool _isLoading = true;
  bool _isUploadingImage = false;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('shop_owners').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _userData = doc.data() as Map<String, dynamic>;
          });
        } else {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            setState(() {
              _userData = userDoc.data() as Map<String, dynamic>;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
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

  Future<void> _showImagePickerOptions() async {
    final hasImage = (_userData['profileImage'] ?? _userData['shopImage'] ?? _userData['imageUrl']) != null &&
        (_userData['profileImage'] ?? _userData['shopImage'] ?? _userData['imageUrl']).toString().trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Store Profile Image',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkNavy,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: _primaryCyan),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadProfileImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.purple),
                  ),
                  title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadProfileImage(ImageSource.camera);
                  },
                ),
                if (hasImage) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    ),
                    title: const Text('Remove Image', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      _removeProfileImage();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );

      if (pickedFile == null || !mounted) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        maxWidth: 600,
        maxHeight: 600,
        compressQuality: 75,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Store Profile Image',
            toolbarColor: _darkNavy,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Store Profile Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final bytes = await croppedFile.readAsBytes();
      final webpBytes = await compute(_processProfileWebpInIsolate, bytes);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Upload to Firebase Storage bucket
      final storageRef = FirebaseFirestore.instance.app.options.storageBucket != null &&
              FirebaseFirestore.instance.app.options.storageBucket!.isNotEmpty
          ? FirebaseStorage.instanceFor(bucket: 'gs://${FirebaseFirestore.instance.app.options.storageBucket}')
              .ref()
              .child('shop_profiles/${user.uid}.webp')
          : FirebaseStorage.instance.ref().child('shop_profiles/${user.uid}.webp');

      final uploadTask = await storageRef.putData(
        webpBytes ?? bytes,
        SettableMetadata(contentType: 'image/webp'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('shop_owners').doc(user.uid).set({
        'profileImage': downloadUrl,
        'shopImage': FieldValue.delete(),
        'imageUrl': FieldValue.delete(),
      }, SetOptions(merge: true));

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'profileImage': downloadUrl,
          'shopImage': FieldValue.delete(),
          'imageUrl': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Sync user document profileImage error: $e');
      }

      if (mounted) {
        setState(() {
          _userData['profileImage'] = downloadUrl;
          _userData.remove('shopImage');
          _userData.remove('imageUrl');
          _isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store profile image updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      await FirebaseFirestore.instance.collection('shop_owners').doc(user.uid).set({
        'profileImage': FieldValue.delete(),
        'shopImage': FieldValue.delete(),
        'imageUrl': FieldValue.delete(),
      }, SetOptions(merge: true));

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'profileImage': FieldValue.delete(),
          'shopImage': FieldValue.delete(),
          'imageUrl': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Sync remove user profile image error: $e');
      }

      if (mounted) {
        setState(() {
          _userData.remove('profileImage');
          _userData.remove('shopImage');
          _userData.remove('imageUrl');
          _isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store profile image removed'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleStoreOpenStatus(bool currentStatus) async {
    final newStatus = !currentStatus;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('shop_owners').doc(user.uid).set({
        'isStoreOpen': newStatus,
      }, SetOptions(merge: true));

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isStoreOpen': newStatus,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Legacy user store open sync skipped: $e');
      }
      setState(() {
        _userData['isStoreOpen'] = newStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Store is now OPEN for orders' : 'Store is now CLOSED for orders'),
            backgroundColor: newStatus ? Colors.green : Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating store status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocationPinned = _userData['isLocationPinned'] == true && _userData['latitude'] != null;
    final String pinnedAddress = _userData['pinnedAddress'] ?? _userData['shopAddress'] ?? _userData['address'] ?? 'Not configured yet';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Store Profile',
          style: TextStyle(
            color: _darkNavy,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: _darkNavy),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryCyan),
              ),
            )
          : RefreshIndicator(
              color: _primaryCyan,
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Profile Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _isUploadingImage ? null : () => _pickAndUploadProfileImage(ImageSource.gallery),
                            onLongPress: _isUploadingImage ? null : _showImagePickerOptions,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _primaryCyan.withValues(alpha: 0.3), width: 1.5),
                                  ),
                                  child: _isUploadingImage
                                      ? const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2.5, color: _primaryCyan),
                                          ),
                                        )
                                      : CachedProductImage(
                                          imageSource: _userData['profileImage'] ?? _userData['shopImage'] ?? _userData['imageUrl'],
                                          width: 68,
                                          height: 68,
                                          borderRadius: BorderRadius.circular(18),
                                          defaultIcon: Icons.storefront_rounded,
                                        ),
                                ),
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: _darkNavy,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userData['shopName'] ?? _userData['name'] ?? 'Shop Name',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Verified Shopkeeper',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Store Open / Closed Status Toggle Card
                    (() {
                      final bool isStoreOpen = _userData['isStoreOpen'] == true;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isStoreOpen ? Colors.green.shade200 : _cardBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isStoreOpen ? Colors.green : Colors.grey).withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isStoreOpen ? Colors.green.shade50 : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isStoreOpen ? Icons.store_rounded : Icons.store_outlined,
                                color: isStoreOpen ? Colors.green.shade700 : const Color(0xFF64748B),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        isStoreOpen ? 'Store is OPEN' : 'Store is CLOSED',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isStoreOpen ? Colors.green.shade800 : _darkNavy,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isStoreOpen ? 'Accepting customer orders' : 'Not accepting new orders',
                                    style: const TextStyle(fontSize: 12, color: _textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isStoreOpen,
                              activeThumbColor: Colors.green.shade600,
                              activeTrackColor: Colors.green.shade100,
                              inactiveThumbColor: Colors.grey.shade400,
                              inactiveTrackColor: Colors.grey.shade200,
                              onChanged: (val) => _toggleStoreOpenStatus(isStoreOpen),
                            ),
                          ],
                        ),
                      );
                    })(),

                    const SizedBox(height: 20),

                    // Store Location Pin Section Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isLocationPinned ? const Color(0xFF10B981).withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: (isLocationPinned ? const Color(0xFF10B981) : Colors.amber).withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isLocationPinned ? const Color(0xFF10B981) : Colors.amber).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isLocationPinned ? Icons.location_on_rounded : Icons.wrong_location_rounded,
                                      color: isLocationPinned ? const Color(0xFF10B981) : Colors.amber.shade700,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isLocationPinned ? 'Store GPS Pinned' : 'Location Not Pinned',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isLocationPinned ? const Color(0xFF10B981) : Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              if (isLocationPinned && _userData['latitude'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_userData['latitude'].toStringAsFixed(4)}, ${_userData['longitude'].toStringAsFixed(4)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _textMuted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            pinnedAddress,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: _darkNavy,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LocationSetupScreen(
                                      role: 'Shopkeeper',
                                      isInitialSetup: false,
                                    ),
                                  ),
                                );
                                _loadProfile();
                              },
                              icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                              label: Text(
                                isLocationPinned ? 'Update Store Pin on Map' : 'Pin Store Location Now',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryCyan,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Information List
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                      child: Text(
                        'Store Information',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _darkNavy,
                        ),
                      ),
                    ),

                    _buildInfoTile(Icons.store_outlined, 'Store Name', _userData['name'] ?? _userData['shopName'] ?? 'Not provided'),
                    _buildInfoTile(Icons.phone_outlined, 'Mobile Number', _userData['mobileNumber'] ?? _userData['phone'] ?? 'Not provided'),
                    _buildInfoTile(Icons.email_outlined, 'Email Address', _userData['email'] ?? 'Not provided'),
                    _buildInfoTile(Icons.store_mall_directory_outlined, 'Registered Address', _userData['shopAddress'] ?? _userData['address'] ?? 'Not provided'),

                    const SizedBox(height: 20),

                    // Logout Button
                    OutlinedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          navigator.pop();
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primaryCyan, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _darkNavy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

