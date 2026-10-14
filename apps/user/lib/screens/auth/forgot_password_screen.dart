import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/otp_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? prefilledMobile;

  const ForgotPasswordScreen({super.key, this.prefilledMobile});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 0; // 0 = phone, 1 = OTP, 2 = new password, 3 = success

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  String _errorMessage = '';
  String _successMessage = '';
  String _verifiedPhone = '';
  String? _accountEmail;
  String? _reqId;

  int _otpCountdown = 0;
  Timer? _timer;

  // OceanKart Theme Colors
  static const Color _primary = Color(0xFF00B4D8);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFD0D5DD);
  static const Color _errorRed = Color(0xFFDC2626);
  static const Color _successGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    if (widget.prefilledMobile != null && widget.prefilledMobile!.isNotEmpty) {
      _phoneController.text = widget.prefilledMobile!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  // ── Step 0: Send OTP ──────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final last10 = cleanDigits.length >= 10
          ? cleanDigits.substring(cleanDigits.length - 10)
          : cleanDigits;

      // Check if user exists via Cloud Function (safely checks without unauthenticated permission issues)
      try {
        final checkCallable = FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('checkMobileRegistered');
        final checkRes = await checkCallable.call({'mobileNumber': last10});
        final checkData = Map<String, dynamic>.from(checkRes.data as Map);
        if (checkData['exists'] == false) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = 'No customer account found with this mobile number.';
          });
          return;
        }
        _accountEmail = checkData['email']?.toString();
      } catch (checkErr) {
        debugPrint('checkMobileRegistered note: $checkErr');
        // If callable is propagating, continue to send OTP; resetPasswordWithMobile will validate server-side
      }

      // Send OTP via OtpService (MSG91)
      final res = await OtpService.sendOtp(last10);
      if (!mounted) return;

      if (res['type'] != 'error') {
        _verifiedPhone = '+91 $last10';
        _reqId = res['reqId']?.toString() ??
            res['message']?.toString() ??
            OtpService.currentReqId;
        setState(() {
          _isLoading = false;
          _currentStep = 1;
          _errorMessage = '';
        });
        _startOtpTimer();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_otpFocusNodes[0].canRequestFocus) {
            _otpFocusNodes[0].requestFocus();
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['message']?.toString() ??
              'Failed to send OTP. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Please try again: $e';
      });
    }
  }

  // ── OTP Timer ─────────────────────────────────────────────────────
  void _startOtpTimer() {
    _otpCountdown = 29;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _otpCountdown = 0);
      } else {
        if (mounted) setState(() => _otpCountdown--);
      }
    });
  }

  // ── Resend OTP ────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    if (_otpCountdown > 0) return;

    final phone = _phoneController.text.trim();
    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = cleanDigits.length >= 10
        ? cleanDigits.substring(cleanDigits.length - 10)
        : cleanDigits;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await OtpService.retryOtp(
        reqId: _reqId,
        mobileNumber: last10,
        retryChannel: 11,
      );

      if (!mounted) return;

      if (res['type'] != 'error') {
        setState(() {
          _isLoading = false;
          _errorMessage = '';
        });
        _startOtpTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code resent successfully!'),
            backgroundColor: _successGreen,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              res['message']?.toString() ?? 'Failed to resend code.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to resend code: $e';
      });
    }
  }

  // ── Step 1: Verify OTP ───────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the OTP.');
      return;
    }

    final phone = _phoneController.text.trim();
    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = cleanDigits.length >= 10
        ? cleanDigits.substring(cleanDigits.length - 10)
        : cleanDigits;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await OtpService.verifyOtp(
        otp: otp,
        reqId: _reqId,
        mobileNumber: last10,
      );

      if (!mounted) return;

      if (res['type'] != 'error') {
        setState(() {
          _isLoading = false;
          _currentStep = 2;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['message']?.toString() ??
              'Invalid OTP code. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid OTP code or verification error.';
      });
    }
  }

  // ── Step 2: Set New Password ──────────────────────────────────────
  Future<void> _resetPassword() async {
    final newPass = _newPassController.text.trim();
    final confirmPass = _confirmPassController.text.trim();

    if (newPass.isEmpty) {
      setState(() => _errorMessage = 'Please enter a new password.');
      return;
    }
    if (newPass.length < 6) {
      setState(
          () => _errorMessage = 'Password must be at least 6 characters long.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    final phone = _phoneController.text.trim();
    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = cleanDigits.length >= 10
        ? cleanDigits.substring(cleanDigits.length - 10)
        : cleanDigits;
    final otp = _otpControllers.map((c) => c.text).join();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('resetPasswordWithMobile');

      final result = await callable.call({
        'mobileNumber': last10,
        'otp': otp,
        'reqId': _reqId,
        'newPassword': newPass,
      });

      final data = Map<String, dynamic>.from(result.data as Map);

      if (!mounted) return;

      if (data['success'] == true) {
        setState(() {
          _isLoading = false;
          _currentStep = 3;
          _errorMessage = '';
          _successMessage =
              'Password has been reset successfully. You can now log in with your new password.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              data['message']?.toString() ?? 'Failed to reset password.';
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            e.message ?? 'Failed to reset password. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to reset password: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: _textPrimary),
          onPressed: () {
            if (_currentStep > 0 && _currentStep < 3) {
              setState(() {
                _currentStep--;
                _errorMessage = '';
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: _buildCurrentStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildPhoneStep();
      case 1:
        return _buildOtpStep();
      case 2:
        return _buildPasswordStep();
      case 3:
        return _buildSuccessStep();
      default:
        return _buildPhoneStep();
    }
  }

  // ── Step 0: Enter Phone Number (Poyoka Style) ─────────────────────
  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Enter your registered mobile number. We'll send you a verification code to confirm your identity.",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: _textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // Poyoka-styled AuthTextField
        _buildPoyokaTextField(
          controller: _phoneController,
          hintText: 'Enter 10-digit mobile number',
          keyboardType: TextInputType.phone,
          maxLength: 10,
          prefixText: '+91',
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),

        const SizedBox(height: 8),
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _errorRed,
              ),
            ),
          ),
        const SizedBox(height: 16),

        _buildPoyokaButton(
          text: 'Send OTP',
          isLoading: _isLoading,
          onPressed: _sendOtp,
        ),
      ],
    );
  }

  // ── Step 1: Enter OTP (Poyoka Style) ─────────────────────────────
  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verify OTP',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the 6-digit code sent to $_verifiedPhone',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: _textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // 6-digit Poyoka OTP Input Grid
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 46,
              height: 56,
              child: TextFormField(
                controller: _otpControllers[i],
                focusNode: _otpFocusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary, width: 2),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && i < 5) {
                    _otpFocusNodes[i + 1].requestFocus();
                  } else if (val.isEmpty && i > 0) {
                    _otpFocusNodes[i - 1].requestFocus();
                  }
                  // Auto-verify when all 6 digits are filled
                  if (i == 5 && val.isNotEmpty) {
                    final otp = _otpControllers.map((c) => c.text).join();
                    if (otp.length == 6) _verifyOtp();
                  }
                },
              ),
            );
          }),
        ),

        const SizedBox(height: 8),
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _errorRed,
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Timer / Resend Button
        Center(
          child: _otpCountdown > 0
              ? Text(
                  'Resend code in 00:${_otpCountdown.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                )
              : GestureDetector(
                  onTap: _isLoading ? null : _resendOtp,
                  child: const Text(
                    'Resend Code',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
        ),

        const SizedBox(height: 24),
        _buildPoyokaButton(
          text: 'Verify OTP',
          isLoading: _isLoading,
          onPressed: _verifyOtp,
        ),
      ],
    );
  }

  // ── Step 2: Set New Password (Poyoka Style) ───────────────────────
  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set New Password',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your identity has been verified. Create a new password for your account.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: _textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // New Password Field
        _buildPoyokaTextField(
          controller: _newPassController,
          innerLabel: 'New Password',
          hintText: 'At least 6 characters',
          obscureText: _obscureNewPass,
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: _textSecondary, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureNewPass
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _textSecondary,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscureNewPass = !_obscureNewPass),
          ),
        ),
        const SizedBox(height: 14),

        // Confirm Password Field
        _buildPoyokaTextField(
          controller: _confirmPassController,
          innerLabel: 'Confirm Password',
          hintText: 'Re-enter password',
          obscureText: _obscureConfirmPass,
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: _textSecondary, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPass
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _textSecondary,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscureConfirmPass = !_obscureConfirmPass),
          ),
        ),

        const SizedBox(height: 8),
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _errorRed,
              ),
            ),
          ),
        const SizedBox(height: 16),

        _buildPoyokaButton(
          text: 'Reset Password',
          isLoading: _isLoading,
          onPressed: _resetPassword,
        ),
      ],
    );
  }

  // ── Step 3: Success (Poyoka Style) ───────────────────────────────
  Widget _buildSuccessStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: _successGreen,
            size: 44,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Password Reset Successful!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          _successMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: _textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _buildPoyokaButton(
          text: 'Back to Login',
          onPressed: () {
            Navigator.of(context).pop(_accountEmail);
          },
        ),
      ],
    );
  }

  // ── Poyoka TextField Builder ─────────────────────────────────────
  Widget _buildPoyokaTextField({
    required TextEditingController controller,
    String? innerLabel,
    String? hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    final hasInnerLabel = innerLabel != null && innerLabel.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1.1),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: prefixIcon != null ? 12 : 16,
        vertical: hasInnerLabel ? 6 : 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasInnerLabel) ...[
            Text(
              innerLabel,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 1),
          ],
          Row(
            children: [
              if (prefixIcon != null) ...[
                prefixIcon,
                const SizedBox(width: 8),
              ],
              if (prefixText != null) ...[
                Text(
                  prefixText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextFormField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  maxLength: maxLength,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w400,
                    ),
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              ?suffixIcon,
            ],
          ),
        ],
      ),
    );
  }

  // ── Poyoka Button Builder ────────────────────────────────────────
  Widget _buildPoyokaButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          disabledBackgroundColor: _primary.withValues(alpha: 0.6),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}
