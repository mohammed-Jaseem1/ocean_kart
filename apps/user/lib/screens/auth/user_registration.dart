import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/otp_service.dart';

class UserRegistrationPage extends StatefulWidget {
  const UserRegistrationPage({super.key});

  @override
  State<UserRegistrationPage> createState() => _UserRegistrationPageState();
}

class _UserRegistrationPageState extends State<UserRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isPhoneVerified = false;
  bool _isSendingOtp = false;
  String? _profileImageUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  label: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSendOtp() async {
    final rawPhone = _mobileController.text.trim();
    if (rawPhone.isEmpty || !RegExp(r'^[6-9]\d{9}$').hasMatch(rawPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final response = await OtpService.sendOtp(rawPhone);

      if (response['type'] == 'error') {
        final errMsg = response['message']?.toString() ?? 'Failed to send OTP.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }

      if (response.containsKey('access-token')) {
        final accessToken = response['access-token']?.toString() ?? '';
        // Verify the JWT access-token server-side via Cloud Function
        final verifyResult = await OtpService.verifyAccessToken(
          accessToken: accessToken,
          mobileNumber: rawPhone,
        );
        if (verifyResult['type'] == 'success') {
          setState(() {
            _isPhoneVerified = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mobile number auto-verified via network!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(verifyResult['message']?.toString() ?? 'Auto-verification failed.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        return;
      }

      final String reqId = OtpService.currentReqId ??
          response['reqId']?.toString() ??
          response['message']?.toString() ??
          '';

      if (!mounted) return;
      final bool? isVerified = await _showOtpDialog(reqId, rawPhone);

      if (isVerified == true) {
        setState(() {
          _isPhoneVerified = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mobile number verified successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  Future<bool?> _showOtpDialog(String reqId, String mobileNumber) async {
    final TextEditingController otpController = TextEditingController();
    bool isVerifying = false;
    String? dialogError;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Enter OTP',
                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter the verification code sent to +91 $mobileNumber',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (dialogError != null) ...[
                    Text(
                      dialogError!,
                      style: TextStyle(
                        color: dialogError!.contains('successfully') || dialogError!.contains('Verified')
                            ? Colors.green
                            : Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Pinput(
                    length: 6,
                    controller: otpController,
                    autofocus: true,
                    defaultPinTheme: PinTheme(
                      width: 44,
                      height: 52,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 46,
                      height: 54,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00B4D8), width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2600B4D8),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            try {
                              final retryRes = await OtpService.retryOtp(
                                reqId: reqId,
                                mobileNumber: mobileNumber,
                                retryChannel: 11,
                              );
                              if (retryRes['type'] == 'error') {
                                setDialogState(() {
                                  dialogError = retryRes['message']?.toString() ??
                                      'Failed to resend OTP.';
                                });
                              } else {
                                setDialogState(() {
                                  dialogError = 'Resent OTP successfully!';
                                });
                              }
                            } catch (e) {
                              setDialogState(() {
                                dialogError = 'Failed to resend OTP: $e';
                              });
                            }
                          },
                    child: const Text(
                      'Resend OTP via SMS',
                      style: TextStyle(
                        color: Color(0xFF00B4D8),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final otp = otpController.text.trim();
                          if (otp.isEmpty) {
                            setDialogState(() {
                              dialogError = 'Please enter OTP';
                            });
                            return;
                          }
                          setDialogState(() {
                            isVerifying = true;
                            dialogError = null;
                          });
                          try {
                            final result = await OtpService.verifyOtp(
                              otp: otp,
                              reqId: reqId,
                              mobileNumber: mobileNumber,
                            );
                            if (result['type'] == 'error') {
                              setDialogState(() {
                                isVerifying = false;
                                dialogError = result['message']?.toString() ??
                                    'Invalid OTP or verification error.';
                              });
                            } else if (context.mounted) {
                              setDialogState(() {
                                isVerifying = false;
                                dialogError = 'Verified successfully!';
                              });
                              await Future.delayed(const Duration(milliseconds: 600));
                              if (context.mounted) {
                                Navigator.pop(context, true);
                              }
                            }
                          } catch (e) {
                            setDialogState(() {
                              isVerifying = false;
                              dialogError = 'Invalid OTP or verification error.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B4D8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please click "Send OTP" and verify your mobile number first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String rawPhone = _mobileController.text.trim();
      final String email = _emailController.text.trim();
      final String password = _passwordController.text;

      // Step 1: Create user with Email & Password
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;
      final String uid = user!.uid;

      // Step 2: Link verified phone number to Firebase Auth (shows as provider)
      try {
        final linkFn = FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('linkPhoneNumber');
        await linkFn.call({'uid': uid, 'mobileNumber': rawPhone});
      } catch (e) {
        // Non-fatal: phone linking failure should not block registration
        debugPrint('linkPhoneNumber warning: $e');
      }

      // Step 3: Send Email Verification link
      await user.sendEmailVerification();

      // Step 3: Save user data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'role': 'customer',
        'name': _nameController.text.trim(),
        'mobileNumber': rawPhone,
        'email': email,
        'address': _addressController.text.trim(),
        'photoUrl': _profileImageUrl ?? '',
        'phoneVerified': true,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending_email_verification',
      });

      // Keep user signed in and show the polling verification dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const EmailVerificationDialog();
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during registration.';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email address.';
      } else {
        errorMessage = e.message ?? errorMessage;
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    bool isEmail = false,
    bool isPhone = false,
    bool isPassword = false,
    bool obscureText = false,
    bool readOnly = false,
    String? hintText,
    VoidCallback? onToggleObscure,
    String? Function(String?)? customValidator,
  }) {
    const primaryBlue = Color(0xFF00B4D8);
    const textColor = Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Text(
              label + (isRequired ? ' *' : ''),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            style: const TextStyle(color: textColor, fontWeight: FontWeight.w500),
        obscureText: obscureText,
        keyboardType: isEmail
            ? TextInputType.emailAddress
            : isPhone
                ? TextInputType.phone
                : TextInputType.text,
        inputFormatters: isPhone
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ]
            : null,
        decoration: InputDecoration(
          hintText: hintText ?? 'Enter $label',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          prefixIcon: Icon(icon, color: primaryBlue, size: 20),
          suffixIcon: isPhone
              ? (_isPhoneVerified
                  ? Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text('Verified', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TextButton(
                        onPressed: _isSendingOtp ? null : _handleSendOtp,
                        style: TextButton.styleFrom(
                          foregroundColor: primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: _isSendingOtp
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
                              )
                            : const Text(
                                'Send OTP',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                      ),
                    ))
              : isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: const Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: onToggleObscure,
                    )
                  : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryBlue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          ),
        ),
        validator: customValidator ??
            (value) {
              if (isRequired && (value == null || value.trim().isEmpty)) {
                return 'This field is required';
              }
              if (isEmail && value != null && value.trim().isNotEmpty) {
                if (!RegExp(r'^[a-zA-Z0-9._%+-]{3,}@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value.trim())) {
                  return 'Please enter a valid email address (e.g., name@example.com)';
                }
              }
              if (isPhone && value != null && value.trim().isNotEmpty) {
                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim())) {
                  return 'Please enter a valid 10-digit mobile number';
                }
              }
              return null;
            },
      ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF00B4D8);
    const textColor = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Customer Registration',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: textColor),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Align(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                    shadowColor: primaryBlue.withValues(alpha: 0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Register Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Optional Profile Picture Picker
                  Center(
                    child: GestureDetector(
                      onTap: _pickProfileImage,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: primaryBlue.withValues(alpha: 0.3), width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: const Color(0xFFF1F5F9),
                              backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                  ? NetworkImage(_profileImageUrl!) as ImageProvider
                                  : null,
                              child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                                  ? const Icon(Icons.person_rounded, size: 42, color: primaryBlue)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Add Profile Photo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.badge_outlined,
                    isRequired: true,
                  ),
                  _buildTextField(
                    controller: _mobileController,
                    label: 'Mobile Number',
                    hintText: 'mobile number',
                    icon: Icons.phone_android_outlined,
                    isRequired: true,
                    isPhone: true,
                    readOnly: _isPhoneVerified,
                  ),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    isRequired: true,
                    isEmail: true,
                  ),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Area / Landmark (optional)',
                    hintText: 'e.g. Near Cochin University, Kalamassery',
                    icon: Icons.location_on_outlined,
                    isRequired: false,
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
                    hintText: 'Re-enter your password',
                    icon: Icons.lock_outline,
                    isRequired: true,
                    isPassword: true,
                    obscureText: _obscureConfirmPassword,
                    onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    customValidator: (value) {
                      if (value == null || value.isEmpty) return 'Confirm Password is required';
                      if (value != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmailVerificationDialog extends StatefulWidget {
  const EmailVerificationDialog({super.key});

  @override
  State<EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  Timer? _timer;
  bool _isVerified = false;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        await user.getIdToken(true);
        final freshUser = FirebaseAuth.instance.currentUser;
        if (freshUser != null && freshUser.emailVerified) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isVerified = true;
            });
            
            // Update Firestore
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'emailVerified': true,
              'status': 'active',
            });
            
            // Wait 1.5s for them to see success, then pop to root (AuthGate will take over)
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF00B4D8);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isVerified 
                    ? Colors.green.withValues(alpha: 0.1) 
                    : primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isVerified ? Icons.check_circle_rounded : Icons.mark_email_unread_outlined,
                color: _isVerified ? Colors.green : primaryBlue,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isVerified ? 'Email Verified!' : 'Verify Your Email',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isVerified
                  ? 'Your email has been verified successfully. Redirecting you to the dashboard...'
                  : 'A verification link has been sent to:\n$_userEmail\n\nWe are waiting for you to click the link. This screen will update automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            if (!_isVerified) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Sign out manually and pop to login if they want to cancel
                    FirebaseAuth.instance.signOut();
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Cancel & Return to Login',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
