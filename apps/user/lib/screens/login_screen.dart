import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'user_registration.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // Sign in existing user
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'No user found for this email.';
        } else if (e.code == 'wrong-password') {
          _errorMessage = 'Wrong password provided.';
        } else if (e.code == 'invalid-credential') {
          _errorMessage = 'Invalid email or password.';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'This email is already registered.';
        } else if (e.code == 'weak-password') {
          _errorMessage = 'Password must be at least 6 characters.';
        } else {
          _errorMessage = e.message ?? 'An error occurred. Please try again.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again later.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // For Flutter Web, we use GoogleAuthProvider directly
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // For iOS/Android, GoogleAuthProvider also works directly in newer SDKs
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithProvider(googleProvider);
      }

      if (userCredential.user != null) {
        // Check if user exists in Firestore
        final doc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
        if (!doc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'email': userCredential.user!.email ?? '',
            'name': userCredential.user!.displayName ?? 'Google User',
            'role': 'customer',
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google Sign-In failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithPhone() async {
    final phoneController = TextEditingController();
    
    // Show dialog to get phone number
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF132238),
        title: const Text('Enter Phone Number', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: phoneController,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '+1 234 567 8900',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00B4D8))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, phoneController.text.trim()),
            child: const Text('Send OTP', style: TextStyle(color: Color(0xFF00B4D8))),
          ),
        ],
      ),
    );

    if (phone == null || phone.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithPhoneCredential(credential, phone);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _errorMessage = 'Phone verification failed: ${e.message}';
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) async {
          setState(() {
            _isLoading = false;
          });
          // Show dialog to enter OTP
          final otpController = TextEditingController();
          final otp = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF132238),
              title: const Text('Enter OTP', style: TextStyle(color: Colors.white)),
              content: TextField(
                controller: otpController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '123456',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00B4D8))),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, otpController.text.trim()),
                  child: const Text('Verify', style: TextStyle(color: Color(0xFF00B4D8))),
                ),
              ],
            ),
          );

          if (otp != null && otp.isNotEmpty) {
            setState(() {
              _isLoading = true;
            });
            PhoneAuthCredential credential = PhoneAuthProvider.credential(
              verificationId: verificationId,
              smsCode: otp,
            );
            await _signInWithPhoneCredential(credential, phone);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: $e';
      });
    }
  }

  Future<void> _signInWithPhoneCredential(AuthCredential credential, String phone) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
        if (!doc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'phone': phone,
            'name': 'Phone User',
            'role': 'customer',
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Phone Sign-In failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Phone Sign-In failed: $e';
      });
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
    const primaryBlue = Color(0xFF00B4D8);
    const darkBackground = Color(0xFF0A1628);
    const cardColor = Color(0xFF132238);

    return Scaffold(
      backgroundColor: darkBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Color(0x1F00B4D8),
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: 36,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'OceanKart Users',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to access your user account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                          prefixIcon: const Icon(Icons.email_outlined, color: primaryBlue),
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
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                          prefixIcon: const Icon(Icons.lock_outlined, color: primaryBlue),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

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
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserRegistrationPage(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: primaryBlue,
                        ),
                        child: const Text(
                          'Don\'t have an account? Sign Up',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR CONTINUE WITH',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Text(
                                  'G', 
                                  style: TextStyle(
                                    color: Colors.black, 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  )
                                ),
                              ),
                              label: const Text('Google', style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInWithPhone,
                              icon: const Icon(Icons.phone_android, color: Colors.white, size: 20),
                              label: const Text('Phone', style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
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
