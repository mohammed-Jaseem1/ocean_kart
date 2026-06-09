import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileDialog extends StatefulWidget {
  const ProfileDialog({super.key});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _userData = {};
  
  // Controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  
  // Shopkeeper specific
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _landmarkController = TextEditingController();
  
  // Delivery Boy specific
  final _houseAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();
          
      if (doc.exists && mounted) {
        setState(() {
          _userData = doc.data() as Map<String, dynamic>;
          _isLoading = false;
          _initControllers();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _initControllers() {
    _nameController.text = _userData['name'] ?? '';
    _mobileController.text = _userData['mobileNumber'] ?? '';
    _cityController.text = _userData['city'] ?? '';
    _districtController.text = _userData['district'] ?? '';
    
    if (_userData['role'] == 'Shopkeeper') {
      _shopNameController.text = _userData['shopName'] ?? '';
      _shopAddressController.text = _userData['shopAddress'] ?? '';
      _landmarkController.text = _userData['landmark'] ?? '';
    } else if (_userData['role'] == 'Delivery Boy') {
      _houseAddressController.text = _userData['houseAddress'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _landmarkController.dispose();
    _houseAddressController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'mobileNumber': _mobileController.text.trim(),
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim(),
      };

      if (_userData['role'] == 'Shopkeeper') {
        updates['shopName'] = _shopNameController.text.trim();
        updates['shopAddress'] = _shopAddressController.text.trim();
        updates['landmark'] = _landmarkController.text.trim();
      } else if (_userData['role'] == 'Delivery Boy') {
        updates['houseAddress'] = _houseAddressController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update(updates);

      if (mounted) {
        setState(() {
          _userData.addAll(updates); // Update local state
          _isEditing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    if (!_isEditing) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              controller.text.isEmpty ? 'N/A' : controller.text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          filled: true,
          fillColor: const Color(0xFF0A1628).withOpacity(0.5),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00B4D8)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Dialog(
        backgroundColor: Color(0xFF132238),
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
              ),
            ],
          ),
        ),
      );
    }

    if (_userData.isEmpty) {
      return const Dialog(
        backgroundColor: Color(0xFF132238),
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Error loading profile',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final role = _userData['role'] ?? 'Unknown';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF132238),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    if (!_isEditing)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFF00B4D8)),
                        onPressed: () => setState(() => _isEditing = true),
                        tooltip: 'Edit Profile',
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 32),
            
            _buildTextField('Name', _nameController),
            
            // Email and Role are non-editable
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email (Non-editable)', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                  const SizedBox(height: 4),
                  Text(_userData['email'] ?? 'N/A', style: const TextStyle(fontSize: 16, color: Colors.white54, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            
            _buildTextField('Mobile Number', _mobileController),
            
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Role', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                  const SizedBox(height: 4),
                  Text(role, style: const TextStyle(fontSize: 16, color: Colors.white54, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            
            _buildTextField('City', _cityController),
            _buildTextField('District', _districtController),
            
            if (role == 'Shopkeeper') ...[
              const Divider(color: Colors.white24, height: 32),
              const Text(
                'Shop Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00B4D8)),
              ),
              const SizedBox(height: 16),
              _buildTextField('Shop Name', _shopNameController),
              _buildTextField('Shop Address', _shopAddressController),
              _buildTextField('Landmark', _landmarkController),
            ],

            if (role == 'Delivery Boy') ...[
              const Divider(color: Colors.white24, height: 32),
              const Text(
                'Delivery Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00B4D8)),
              ),
              const SizedBox(height: 16),
              _buildTextField('House Address', _houseAddressController),
              
              // Aadhaar is non-editable
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aadhaar Number (Non-editable)', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                    const SizedBox(height: 4),
                    Text(_userData['aadhaarNumber'] ?? 'N/A', style: const TextStyle(fontSize: 16, color: Colors.white54, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],

            if (_isEditing) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B4D8),
                    foregroundColor: const Color(0xFF0A1628),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveData,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Color(0xFF0A1628), strokeWidth: 2),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
