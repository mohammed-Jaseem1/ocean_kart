import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'location_picker_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  bool _isSaving = false;
  bool _isLoadingAddress = true;
  bool _addressModified = false;

  String? _profileImageUrl;
  String? _currentAddress;
  double? _currentLat;
  double? _currentLon;

  bool _isSendingVerification = false;

  bool get _isEmailVerified {
    final user = FirebaseAuth.instance.currentUser;
    return user?.emailVerified == true || widget.userData['emailVerified'] == true;
  }

  final Color _lightBlue = const Color(0xFF00B4D8);
  final Color _textColor = const Color(0xFF0F172A);

  String _cleanDisplayAddress(String? address) {
    if (address == null || address.trim().isEmpty) return '';
    return address
        .replaceFirst(RegExp(r'^[A-Z0-9]{2,8}\+[A-Z0-9]{2,4}[\s,]+'), '')
        .trim();
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name'] ?? '');

    String getEmail() {
      if (widget.userData['email'] != null &&
          widget.userData['email'].toString().trim().isNotEmpty) {
        return widget.userData['email'];
      }
      final authEmail = FirebaseAuth.instance.currentUser?.email;
      if (authEmail != null && authEmail.trim().isNotEmpty) return authEmail;
      return '';
    }

    _emailController = TextEditingController(text: getEmail());

    String getPhone() {
      if (widget.userData['mobileNumber'] != null &&
          widget.userData['mobileNumber'].toString().trim().isNotEmpty) {
        return widget.userData['mobileNumber'];
      }
      final authPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
      if (authPhone != null && authPhone.trim().isNotEmpty) return authPhone;
      return '';
    }

    _phoneController = TextEditingController(text: getPhone());

    _profileImageUrl = widget.userData['photoUrl']?.toString();

    // Pre-populate address from userData if present
    if (widget.userData['address'] != null &&
        widget.userData['address'].toString().trim().isNotEmpty) {
      _currentAddress = _cleanDisplayAddress(widget.userData['address'].toString());
      _currentLat = (widget.userData['lat'] as num?)?.toDouble();
      _currentLon = (widget.userData['lon'] as num?)?.toDouble();
      _isLoadingAddress = false;
    }

    _loadAddressFromFirestore();

    // Reload auth user to fetch latest email verification state
    FirebaseAuth.instance.currentUser?.reload().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  Future<void> _pickProfileImage() async {
    final List<String> presetAvatars = [
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a preset avatar photo for your account',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: presetAvatars.map((url) {
                  final isSelected = _profileImageUrl == url;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _profileImageUrl = url;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: const Color(0xFF00B4D8), width: 3)
                            : null,
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(url),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              if (_profileImageUrl != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _profileImageUrl = null;
                    });
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent, size: 20),
                  label: const Text('Remove Photo',
                      style: TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadAddressFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingAddress = false);
      return;
    }

    try {
      final primaryDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc('primary')
          .get();

      if (primaryDoc.exists && mounted) {
        final data = primaryDoc.data()!;
        setState(() {
          _currentAddress = _cleanDisplayAddress(data['address']?.toString());
          _currentLat = (data['lat'] as num?)?.toDouble();
          _currentLon = (data['lon'] as num?)?.toDouble();
          _isLoadingAddress = false;
        });
        return;
      }

      // Check root user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        final uData = userDoc.data()!;
        if (uData['address'] != null && uData['address'].toString().trim().isNotEmpty) {
          setState(() {
            _currentAddress = _cleanDisplayAddress(uData['address']?.toString());
            _currentLat = (uData['lat'] as num?)?.toDouble();
            _currentLon = (uData['lon'] as num?)?.toDouble();
            _isLoadingAddress = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading address in edit profile: $e');
    }

    if (mounted) {
      setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _pickLocationOnMap() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationPickerBottomSheet(),
    );

    if (result != null && mounted) {
      final double? lat = result['lat'] as double?;
      final double? lon = result['lon'] as double?;
      final String rawAddress = result['address'] as String? ?? '';
      final String cleanAddress = _cleanDisplayAddress(rawAddress);

      if (lat == null || lon == null || cleanAddress.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not determine map location. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      setState(() {
        _currentAddress = cleanAddress;
        _currentLat = lat;
        _currentLon = lon;
        _addressModified = true;
      });

      // Save immediately to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('addresses')
              .doc('primary')
              .set({
            'address': cleanAddress,
            'lat': lat,
            'lon': lon,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'address': cleanAddress,
            'lat': lat,
            'lon': lon,
          }, SetOptions(merge: true));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Delivery location updated!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update address: $e')),
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address first.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    setState(() => _isSendingVerification = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (user.email != null && user.email!.toLowerCase() == email.toLowerCase()) {
          await user.sendEmailVerification();
        } else {
          try {
            await user.verifyBeforeUpdateEmail(email);
          } catch (_) {
            await user.sendEmailVerification();
          }
        }
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': email,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification link sent to $email! Check your inbox.'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to send verification email.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending email: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingVerification = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final rawPhone = _phoneController.text.trim();
        final rawEmail = _emailController.text.trim();
        final updateMap = <String, dynamic>{
          'name': _nameController.text.trim(),
          'email': rawEmail,
          'mobileNumber': rawPhone,
          'photoUrl': _profileImageUrl ?? '',
        };

        if (_currentAddress != null && _currentAddress!.isNotEmpty) {
          updateMap['address'] = _currentAddress;
          if (_currentLat != null) updateMap['lat'] = _currentLat;
          if (_currentLon != null) updateMap['lon'] = _currentLon;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(updateMap, SetOptions(merge: true));

        // Sync name & photo in Firebase Auth profile
        try {
          await user.updateDisplayName(_nameController.text.trim());
          if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
            await user.updatePhotoURL(_profileImageUrl);
          }
        } catch (authErr) {
          debugPrint('Auth displayName/photoURL update note: $authErr');
        }

        // Sync to Firebase Auth via linkPhoneNumber callable
        if (rawPhone.isNotEmpty) {
          try {
            final linkFn = FirebaseFunctions.instanceFor(region: 'us-central1')
                .httpsCallable('linkPhoneNumber');
            await linkFn.call({'uid': user.uid, 'mobileNumber': rawPhone});
          } catch (linkErr) {
            debugPrint('Error linking phone in auth during profile edit: $linkErr');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Return true if address was modified even if user pressed back
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: _textColor, size: 20),
            onPressed: () => Navigator.pop(context, _addressModified),
          ),
          title: Text(
            'Personal Information',
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          iconTheme: IconThemeData(color: _textColor),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickProfileImage,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _lightBlue.withValues(alpha: 0.3),
                                width: 2.5,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: const Color(0xFFF1F5F9),
                              backgroundImage: _profileImageUrl != null &&
                                      _profileImageUrl!.isNotEmpty
                                  ? NetworkImage(_profileImageUrl!)
                                  : null,
                              child: _profileImageUrl != null &&
                                      _profileImageUrl!.isNotEmpty
                                  ? null
                                  : Icon(Icons.person_rounded,
                                      size: 52, color: _lightBlue),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: _lightBlue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 15, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  _buildLabel('Full Name'),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Enter your full name',
                    icon: Icons.person_outline,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Email Address'),
                  _buildTextField(
                    controller: _emailController,
                    hint: 'Enter your email address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: _isEmailVerified,
                    fillColor: _isEmailVerified ? const Color(0xFFF8FAFC) : null,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val.trim())) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    suffixIcon: _isEmailVerified
                        ? const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_rounded,
                                    size: 18, color: Color(0xFF94A3B8)),
                              ],
                            ),
                          )
                        : null,
                    helperText: _isEmailVerified
                        ? 'Email address is verified and cannot be changed'
                        : null,
                  ),
                  if (!_isEmailVerified) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: _isSendingVerification ? null : _sendVerificationEmail,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _lightBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _lightBlue.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSendingVerification) ...[
                                SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _lightBlue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ] else ...[
                                Icon(Icons.send_rounded, size: 13, color: _lightBlue),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                _isSendingVerification
                                    ? 'Sending verification...'
                                    : 'Send Verification Email',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _lightBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  _buildLabel('Phone Number'),
                  _buildTextField(
                    controller: _phoneController,
                    hint: 'Phone number',
                    icon: Icons.phone_outlined,
                    readOnly: true,
                    fillColor: const Color(0xFFF8FAFC),
                    suffixIcon: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded,
                              size: 18, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                    helperText: 'Phone number is verified and cannot be changed',
                  ),
                  const SizedBox(height: 24),

                  // ── Delivery Address Section ─────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel('Delivery Address'),
                      InkWell(
                        onTap: _pickLocationOnMap,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_location_alt_rounded,
                                  size: 16, color: _lightBlue),
                              const SizedBox(width: 4),
                              Text(
                                _currentAddress != null &&
                                        _currentAddress!.isNotEmpty
                                    ? 'Change on Map'
                                    : 'Set on Map',
                                style: TextStyle(
                                  color: _lightBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _isLoadingAddress
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2),
                              ),
                            ),
                          )
                        : (_currentAddress != null &&
                                _currentAddress!.isNotEmpty)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _lightBlue
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          color: _lightBlue,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _currentAddress!,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: _textColor,
                                                height: 1.35,
                                              ),
                                            ),
                                            if (_currentLat != null &&
                                                _currentLon != null) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.gps_fixed_rounded,
                                                    size: 12,
                                                    color: Colors.green.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${_currentLat!.toStringAsFixed(4)}° N, ${_currentLon!.toStringAsFixed(4)}° E',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      color: Colors.grey.shade600,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green
                                                          .withValues(alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'GPS Verified',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.green.shade700,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _pickLocationOnMap,
                                      icon: Icon(Icons.map_rounded,
                                          size: 16, color: _lightBlue),
                                      label: Text(
                                        'Update Location on Map',
                                        style: TextStyle(
                                          color: _lightBlue,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        side: BorderSide(
                                            color: _lightBlue
                                                .withValues(alpha: 0.4)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        backgroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.location_off_rounded,
                                          color: Colors.grey.shade600,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'No delivery address set',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: _textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Set your delivery location using the map.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _pickLocationOnMap,
                                      icon: const Icon(
                                          Icons.add_location_alt_rounded,
                                          size: 16,
                                          color: Colors.white),
                                      label: const Text(
                                        'Set Location on Map',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _lightBlue,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                  ),


                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _lightBlue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Profile',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textColor),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffixIcon,
    Color? fillColor,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 15,
        color: readOnly ? const Color(0xFF64748B) : Colors.black87,
        fontWeight: readOnly ? FontWeight.w600 : FontWeight.normal,
      ),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: Colors.grey.shade400)
            : Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(icon, color: Colors.grey.shade400),
              ),
        suffixIcon: suffixIcon,
        helperText: helperText,
        helperStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
        filled: true,
        fillColor: fillColor ?? Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: readOnly
                  ? const Color(0xFFE2E8F0)
                  : Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: readOnly ? const Color(0xFFE2E8F0) : _lightBlue,
              width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
      ),
    );
  }
}
