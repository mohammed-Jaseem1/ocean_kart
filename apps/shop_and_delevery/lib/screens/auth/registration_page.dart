import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  // Basic Information Controllers
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Shop Details Controllers
  final _shopAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _landmarkController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _selectedRole = 'Shopkeeper';
  final List<String> _roles = ['Shopkeeper', 'Delivery Boy'];

  // Delivery Boy Controllers
  final _aadhaarNumberController = TextEditingController();
  String? _aadhaarCardFileName;
  String? _selfieFileName;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _mobileNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shopAddressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    _aadhaarNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickAadhaarCard() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _aadhaarCardFileName = image.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking Aadhaar: $e');
    }
  }

  Future<void> _pickSelfie() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
      final XFile? finalImage = image ?? await _picker.pickImage(source: ImageSource.gallery);
      if (finalImage != null) {
        setState(() {
          _selfieFileName = finalImage.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking Selfie: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create user with Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final String uid = userCredential.user!.uid;

      // Prepare common data
      final Map<String, dynamic> userData = {
        'uid': uid,
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'name': _ownerNameController.text.trim(),
        'mobileNumber': _mobileNumberController.text.trim(),
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', // Account status
      };

      // Add role-specific data
      if (_selectedRole == 'Shopkeeper') {
        userData['shopName'] = _shopNameController.text.trim();
        userData['shopAddress'] = _shopAddressController.text.trim();
        userData['landmark'] = _landmarkController.text.trim();
      } else if (_selectedRole == 'Delivery Boy') {
        userData['houseAddress'] = _shopAddressController.text.trim(); // Reusing the same controller
        userData['aadhaarNumber'] = _aadhaarNumberController.text.trim();
        // In a real app, you would upload the files to Firebase Storage and save the download URLs here
        userData['aadhaarCardFile'] = _aadhaarCardFileName; 
        userData['selfieFile'] = _selfieFileName; 
      }

      // Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);

      // Sign out immediately so we don't automatically navigate to the dashboard
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
                      'Registration Submitted!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your registration request has been submitted. You will be able to log in once an Admin approves your account.',
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

        // Automatically close dialog and navigate back after 4 seconds
        Future.delayed(const Duration(seconds: 4), () {
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
        errorMessage = 'The account already exists for that email.';
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

  Widget _buildSectionHeader(String title) {
    const primaryBlue = Color(0xFF00B4D8);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: primaryBlue,
        ),
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
    bool isMobileNumber = false,
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
        inputFormatters: isMobileNumber ? [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ] : (isPhone ? [FilteringTextInputFormatter.digitsOnly] : null),
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixText: isMobileNumber ? '+91 ' : null,
          prefixStyle: isMobileNumber ? const TextStyle(color: Colors.white, fontSize: 16) : null,
          prefixIcon: Icon(icon, color: primaryBlue),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
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
                return 'Please enter $label';
              }
              if (isEmail && value != null && value.isNotEmpty) {
                if (!RegExp(r'^[a-zA-Z0-9._%+-]{3,}@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                    .hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
              }
              if (isMobileNumber && value != null && value.isNotEmpty) {
                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim())) {
                  return 'Please enter a valid 10-digit number';
                }
              }
              return null;
            },
      ),
    );
  }

  Widget _buildFileUploadField({
    required String label,
    required String? fileName,
    required Future<void> Function() onTap,
  }) {
    const primaryBlue = Color(0xFF00B4D8);
    const darkBackground = Color(0xFF0A1628);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: FormField<String>(
        validator: (value) {
          if (fileName == null) {
            return 'Please upload $label';
          }
          return null;
        },
        builder: (FormFieldState<String> state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () async {
                  await onTap();
                  // Validate immediately after picking
                  state.validate();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: darkBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: state.hasError ? Colors.redAccent : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.upload_file, color: state.hasError ? Colors.redAccent : primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label + ' *',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              fileName ?? 'No file selected',
                              style: TextStyle(
                                color: fileName != null ? Colors.white : Colors.white54,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (fileName == null)
                        const Text(
                          'BROWSE',
                          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
                        )
                      else
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                ),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, top: 8.0),
                  child: Text(
                    state.errorText!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required List<String> items,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    const primaryBlue = Color(0xFF00B4D8);
    const darkBackground = Color(0xFF0A1628);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: value,
        style: const TextStyle(color: Colors.white),
        dropdownColor: darkBackground,
        decoration: InputDecoration(
          labelText: label + ' *',
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon: Icon(icon, color: primaryBlue),
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
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (val) {
          if (val == null || val.isEmpty) {
            return 'Please select a $label';
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
        title: const Text('Account Registration'),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
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
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Color(0x1F00B4D8),
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 48,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      _buildSectionHeader(_selectedRole == 'Shopkeeper' ? 'Basic Information' : 'Personal Information'),
                      _buildDropdownField(
                        label: 'Select Role',
                        icon: Icons.badge_outlined,
                        items: _roles,
                        value: _selectedRole,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedRole = newValue;
                          });
                        },
                      ),
                      if (_selectedRole == 'Shopkeeper')
                        _buildTextField(
                          controller: _shopNameController,
                          label: 'Shop Name',
                          icon: Icons.store,
                          isRequired: true,
                        ),
                      _buildTextField(
                        controller: _ownerNameController,
                        label: _selectedRole == 'Shopkeeper' ? 'Owner Name' : 'Full Name',
                        icon: Icons.person,
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _mobileNumberController,
                        label: 'Mobile Number',
                        icon: Icons.phone,
                        isRequired: true,
                        isPhone: true,
                        isMobileNumber: true,
                      ),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        icon: Icons.email,
                        isRequired: true,
                        isEmail: true,
                      ),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock,
                        isRequired: true,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onToggleObscure: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        icon: Icons.lock_outline,
                        isRequired: true,
                        isPassword: true,
                        obscureText: _obscureConfirmPassword,
                        onToggleObscure: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        customValidator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      const Divider(color: Colors.white24, height: 48),

                      _buildSectionHeader(_selectedRole == 'Shopkeeper' ? 'Shop Details' : 'Address Information'),
                      _buildTextField(
                        controller: _shopAddressController,
                        label: _selectedRole == 'Shopkeeper' ? 'Shop Address' : 'House Address',
                        icon: Icons.location_on,
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _cityController,
                        label: 'City',
                        icon: Icons.location_city,
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _districtController,
                        label: 'District',
                        icon: Icons.map,
                        isRequired: true,
                      ),
                      _buildTextField(
                        controller: _pincodeController,
                        label: 'Pincode',
                        icon: Icons.pin_drop,
                        isRequired: true,
                        isPhone: true, // Typically pincodes are numbers
                      ),
                      if (_selectedRole == 'Shopkeeper')
                        _buildTextField(
                          controller: _landmarkController,
                          label: 'Landmark (Optional)',
                          icon: Icons.landscape,
                          isRequired: false,
                        ),

                      if (_selectedRole == 'Delivery Boy') ...[
                        const Divider(color: Colors.white24, height: 48),

                        _buildSectionHeader('Identity Verification'),
                        _buildTextField(
                          controller: _aadhaarNumberController,
                          label: 'Aadhaar Number',
                          icon: Icons.badge,
                          isRequired: true,
                          isPhone: true, // Typically numerical
                        ),
                        _buildFileUploadField(
                          label: 'Upload Aadhaar Card',
                          fileName: _aadhaarCardFileName,
                          onTap: _pickAadhaarCard,
                        ),
                        _buildFileUploadField(
                          label: 'Upload Selfie/Profile Photo',
                          fileName: _selfieFileName,
                          onTap: _pickSelfie,
                        ),
                      ],

                      const SizedBox(height: 32),
                      
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: darkBackground,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(darkBackground),
                                ),
                              )
                            : const Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 16,
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
