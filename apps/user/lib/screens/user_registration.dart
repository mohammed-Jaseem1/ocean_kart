import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserRegistrationPage extends StatefulWidget {
  const UserRegistrationPage({super.key});

  @override
  State<UserRegistrationPage> createState() => _UserRegistrationPageState();
}

class _UserRegistrationPageState extends State<UserRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  // Personal Details
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Address Details
  final _houseController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _landmarkController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isGettingLocation = false;

  // Mock GPS Location
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _houseController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    // Simulate a network/GPS delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _latitude = 12.9716; // Example coordinate
        _longitude = 77.5946;
        _isGettingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS Location fetched successfully!'),
          backgroundColor: Colors.greenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // If email is empty, create a dummy email using the phone number
      // so we can still use Firebase Auth's Email/Password provider.
      String loginEmail = _emailController.text.trim();
      if (loginEmail.isEmpty) {
        loginEmail = '${_mobileController.text.trim()}@oceankart.com';
      }

      // Create user with Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: loginEmail,
        password: _passwordController.text,
      );

      final String uid = userCredential.user!.uid;

      // Prepare user data
      final Map<String, dynamic> userData = {
        'uid': uid,
        'role': 'customer',
        'name': _nameController.text.trim(),
        'mobileNumber': _mobileController.text.trim(),
        'email': _emailController.text.trim(), // The actual provided email (or empty)
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active', // Customers are active immediately
        'addresses': [
          {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'isDefault': true,
            'houseNumber': _houseController.text.trim(),
            'street': _streetController.text.trim(),
            'city': _cityController.text.trim(),
            'district': _districtController.text.trim(),
            'pincode': _pincodeController.text.trim(),
            'landmark': _landmarkController.text.trim(),
            'latitude': _latitude,
            'longitude': _longitude,
          }
        ]
      };

      // Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);

      // Sign out immediately or keep them signed in? 
      // Usually after registration you can redirect them directly to the dashboard, 
      // but let's sign them out and let them log in properly for better state management.
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              alignment: Alignment.topCenter,
              insetPadding: const EdgeInsets.only(top: 60, left: 24, right: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: const Color(0xFF132238),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.greenAccent,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to OceanKart!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your account has been created successfully. You can now log in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        // Automatically close dialog and navigate back after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop(); // Go back to login
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during registration.';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email or mobile number.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
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

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    const primaryBlue = Color(0xFF00B4D8);
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: primaryBlue, size: 22),
            const SizedBox(width: 10),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(color: Colors.white.withOpacity(0.1), thickness: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    bool isEmail = false,
    bool isPhone = false,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? customValidator,
  }) {
    const primaryBlue = Color(0xFF00B4D8);
    const darkBackground = Color(0xFF0A1628);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        obscureText: obscureText,
        keyboardType: isEmail
            ? TextInputType.emailAddress
            : isPhone
                ? TextInputType.phone
                : TextInputType.text,
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon: Icon(icon, color: primaryBlue.withOpacity(0.8)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          filled: true,
          fillColor: darkBackground.withOpacity(0.5),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryBlue),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
        validator: customValidator ??
            (value) {
              if (isRequired && (value == null || value.trim().isEmpty)) {
                return 'This field is required';
              }
              if (isEmail && value != null && value.trim().isNotEmpty) {
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
              }
              if (isPhone && value != null && value.trim().isNotEmpty) {
                if (value.length < 10) {
                  return 'Please enter a valid mobile number';
                }
              }
              return null;
            },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF00B4D8);
    const darkBackground = Color(0xFF0A1628);
    const cardColor = Color(0xFF132238);

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Customer Registration',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
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
                      const Text(
                        'Create your OceanKart Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join us and start shopping for fresh items',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Personal Details Section
                      _buildSectionHeader('Personal Details', icon: Icons.person_outline),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.badge_outlined,
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _mobileController,
                        label: 'Mobile Number',
                        icon: Icons.phone_android_outlined,
                        isRequired: true,
                        isPhone: true,
                      ),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address (Optional)',
                        icon: Icons.email_outlined,
                        isRequired: false,
                        isEmail: true,
                      ),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        isRequired: true,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                        customValidator: (value) {
                          if (value == null || value.isEmpty) return 'Password is required';
                          if (value.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        icon: Icons.lock_outline,
                        isRequired: true,
                        isPassword: true,
                        obscureText: _obscureConfirmPassword,
                        onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        customValidator: (value) {
                          if (value == null || value.isEmpty) return 'Please confirm your password';
                          if (value != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),

                      // Address Details Section
                      _buildSectionHeader('Address Details', icon: Icons.home_outlined),
                      _buildTextField(
                        controller: _houseController,
                        label: 'House/Flat Number',
                        icon: Icons.door_front_door_outlined,
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _streetController,
                        label: 'Street/Area',
                        icon: Icons.signpost_outlined,
                        isRequired: true,
                      ),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cityController,
                              label: 'City',
                              icon: Icons.location_city_outlined,
                              isRequired: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _districtController,
                              label: 'District',
                              icon: Icons.map_outlined,
                              isRequired: true,
                            ),
                          ),
                        ],
                      ),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _pincodeController,
                              label: 'Pincode',
                              icon: Icons.pin_drop_outlined,
                              isRequired: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _landmarkController,
                              label: 'Landmark (Optional)',
                              icon: Icons.landscape_outlined,
                              isRequired: false,
                            ),
                          ),
                        ],
                      ),

                      // Location & GPS Section
                      _buildSectionHeader('Location', icon: Icons.gps_fixed),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: darkBackground.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Current Location (GPS)',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _latitude != null 
                                          ? 'Location captured successfully' 
                                          : 'Pinpoint your exact location for accurate delivery.',
                                        style: TextStyle(
                                          color: _latitude != null ? Colors.greenAccent : Colors.white.withOpacity(0.6),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _isGettingLocation ? null : _getCurrentLocation,
                                  icon: _isGettingLocation 
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(_latitude != null ? Icons.check : Icons.my_location, size: 18),
                                  label: Text(_latitude != null ? 'Fetched' : 'Fetch GPS'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _latitude != null ? Colors.green.withOpacity(0.2) : primaryBlue.withOpacity(0.2),
                                    foregroundColor: _latitude != null ? Colors.greenAccent : primaryBlue,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                )
                              ],
                            ),
                            const Divider(height: 24, color: Colors.white10),
                            Row(
                              children: [
                                const Icon(Icons.library_add_check_outlined, color: Colors.white70, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Save Multiple Addresses (You can add more addresses later from your Profile menu)',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: darkBackground,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(darkBackground),
                                ),
                              )
                            : const Text(
                                'Register Account',
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
      ),
    );
  }
}
