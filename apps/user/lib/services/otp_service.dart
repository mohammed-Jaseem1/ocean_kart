import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Production-grade Service wrapper for MSG91 / SendOTP Flutter SDK.
/// Falls back to Firebase Cloud Functions callable backend on SDK failure.
class OtpService {
  OtpService._();

  // ── OceanKart credentials loaded from .env ──────────────────────────────
  static String get _widgetId => dotenv.env['MSG91_WIDGET_ID'] ?? '';
  static String get _authToken => dotenv.env['MSG91_AUTH_TOKEN'] ?? '';
  // ─────────────────────────────────────────────────────────────────────────

  static String? _currentReqId;
  static String? _lastError;
  static bool _nativeInitialized = false;

  /// Gets the current active request ID for OTP verification or retry.
  static String? get currentReqId => _currentReqId;

  /// Gets the last error message for debugging.
  static String? get lastError => _lastError;

  /// Initializes / caches widget credentials.
  static void initialize() {
    debugPrint('OtpService credentials cached (native init deferred).');
  }

  /// Ensure the native SendOTP SDK is initialized lazily right before the first call.
  static void _ensureInitialized() {
    if (_nativeInitialized) return;
    if (_widgetId.isEmpty || _authToken.isEmpty) return;
    try {
      debugPrint('Lazily initializing SendOTP native SDK...');
      OTPWidget.initializeWidget(_widgetId, _authToken);
      _nativeInitialized = true;
      _lastError = null;
      debugPrint('SendOTP SDK initialized successfully.');
    } catch (e) {
      _lastError = 'SDK init error: $e';
      debugPrint('SendOTP SDK initialization failed: $e');
    }
  }

  /// Normalizes identifier: strips formatting and adds country code 91 for 10-digit mobile numbers.
  static String _normalizeIdentifier(String identifier) {
    var clean = identifier.replaceAll(RegExp(r'[+\s-]'), '').trim();
    if (!clean.contains('@') && clean.length == 10) {
      clean = '91$clean';
    }
    return clean;
  }

  // ---------------------------------------------------------------------------
  // sendOtp
  // ---------------------------------------------------------------------------

  /// Sends OTP to [identifier] (phone number with country code, or email).
  /// 1. Tries the native SendOTP Flutter SDK first.
  /// 2. Falls back to Firebase Cloud Function backend on SDK failure.
  static Future<Map<String, dynamic>> sendOtp(String identifier) async {
    final cleanIdentifier = _normalizeIdentifier(identifier);

    _ensureInitialized();

    try {
      debugPrint('Sending OTP to $cleanIdentifier...');
      final response = await OTPWidget.sendOTP({'identifier': cleanIdentifier});

      if (response == null) {
        _lastError = 'SDK returned null response';
        debugPrint('sendOTP: $_lastError — falling back to Cloud Function.');
        return await _sendOtpViaCloudFunction(cleanIdentifier);
      }

      final Map<String, dynamic> mapResponse = Map<String, dynamic>.from(response);

      if (mapResponse['type'] == 'error') {
        _lastError = mapResponse['message']?.toString() ?? 'Unknown error';
        debugPrint('sendOTP SDK error: $_lastError — falling back to Cloud Function.');
        return await _sendOtpViaCloudFunction(cleanIdentifier);
      }

      // Handle auto-verification via network token (SIM-card detection)
      if (mapResponse.containsKey('access-token')) {
        _currentReqId = mapResponse['access-token']?.toString();
        debugPrint('Auto-verified via network token.');
        return mapResponse;
      }

      // Extract reqId from SDK success response
      _currentReqId = mapResponse['message']?.toString() ??
          mapResponse['reqId']?.toString();

      debugPrint('SendOTP SDK success: reqId=$_currentReqId');
      return mapResponse;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('sendOTP SDK exception: $e — falling back to Cloud Function.');
      try {
        return await _sendOtpViaCloudFunction(cleanIdentifier);
      } catch (cfErr) {
        debugPrint('Cloud Function also failed: $cfErr');
        return {'type': 'error', 'message': 'Failed to send OTP: $cfErr'};
      }
    }
  }

  /// Sends OTP via Firebase Cloud Function callable backend.
  static Future<Map<String, dynamic>> _sendOtpViaCloudFunction(
      String identifier) async {
    debugPrint('Calling Cloud Function sendOtp for $identifier...');
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('sendOtp');
      final result = await callable.call({'identifier': identifier});
      final data = Map<String, dynamic>.from(result.data as Map);
      debugPrint('Cloud Function sendOtp result: $data');

      if (data['success'] == true) {
        _currentReqId = data['reqId']?.toString() ?? '';
        return {
          'type': 'success',
          'message': _currentReqId,
          'reqId': _currentReqId,
        };
      }
      return {'type': 'error', 'message': data['error'] ?? 'Cloud Function failed'};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function sendOtp FirebaseFunctionsException: [${e.code}] ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // retryOtp
  // ---------------------------------------------------------------------------

  /// Retries sending OTP for [reqId] or active [_currentReqId].
  /// [retryChannel] optional: 11=SMS, 4=Voice, 3=Email, 12=WhatsApp.
  static Future<Map<String, dynamic>> retryOtp(
      {String? reqId, String? mobileNumber, int? retryChannel}) async {
    final targetReqId = reqId ?? _currentReqId;
    if (targetReqId == null || targetReqId.isEmpty) {
      return {'type': 'error', 'message': 'No active request ID for retry'};
    }

    _ensureInitialized();

    final data = <String, dynamic>{'reqId': targetReqId};
    if (retryChannel != null) {
      data['retryChannel'] = retryChannel;
    }

    try {
      final response = await OTPWidget.retryOTP(data);
      if (response == null) {
        // Fallback to Cloud Function
        return await _retryOtpViaCloudFunction(targetReqId, retryChannel);
      }
      final mapRes = Map<String, dynamic>.from(response);
      if (mapRes['type'] == 'error') {
        return await _retryOtpViaCloudFunction(targetReqId, retryChannel);
      }
      return mapRes;
    } catch (e) {
      debugPrint('retryOtp SDK error: $e');
      try {
        return await _retryOtpViaCloudFunction(targetReqId, retryChannel);
      } catch (_) {
        return {'type': 'error', 'message': e.toString()};
      }
    }
  }

  static Future<Map<String, dynamic>> _retryOtpViaCloudFunction(
      String reqId, int? retryChannel) async {
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('retryOtp');
      final result = await callable.call({
        'reqId': reqId,
        if (retryChannel != null) 'retryChannel': retryChannel,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['success'] == true
          ? {'type': 'success', 'message': 'OTP resent successfully.'}
          : {'type': 'error', 'message': 'Retry failed via Cloud Function'};
    } on FirebaseFunctionsException catch (e) {
      return {'type': 'error', 'message': e.message ?? 'Retry failed'};
    }
  }

  // ---------------------------------------------------------------------------
  // verifyOtp
  // ---------------------------------------------------------------------------

  /// Verifies the OTP entered by user for [reqId] or active [_currentReqId].
  static Future<Map<String, dynamic>> verifyOtp(
      {required String otp, String? reqId, String? mobileNumber}) async {
    final targetReqId = reqId ?? _currentReqId;
    if (targetReqId == null || targetReqId.isEmpty) {
      return {'type': 'error', 'message': 'No active request ID for verification'};
    }

    _ensureInitialized();

    final data = {
      'reqId': targetReqId,
      'otp': otp.trim(),
    };

    try {
      final response = await OTPWidget.verifyOTP(data);
      if (response == null) {
        return await _verifyOtpViaCloudFunction(
            reqId: targetReqId, otp: otp, mobileNumber: mobileNumber);
      }

      final mapResponse = Map<String, dynamic>.from(response);
      debugPrint('verifyOtp SDK response: $mapResponse');

      if (mapResponse['type'] == 'error') {
        // Try Cloud Function backend
        return await _verifyOtpViaCloudFunction(
            reqId: targetReqId, otp: otp, mobileNumber: mobileNumber);
      }
      return mapResponse;
    } catch (e) {
      debugPrint('verifyOtp SDK error: $e');
      try {
        return await _verifyOtpViaCloudFunction(
            reqId: targetReqId, otp: otp, mobileNumber: mobileNumber);
      } catch (cfErr) {
        return {'type': 'error', 'message': 'OTP verification failed: $cfErr'};
      }
    }
  }

  static Future<Map<String, dynamic>> _verifyOtpViaCloudFunction({
    required String reqId,
    required String otp,
    String? mobileNumber,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('verifyOtp');
      final result = await callable.call({
        'reqId': reqId,
        'otp': otp,
        if (mobileNumber != null) 'mobileNumber': mobileNumber,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      debugPrint('verifyOtp Cloud Function result: $data');
      if (data['success'] == true) {
        return {'type': 'success', 'message': 'OTP verified successfully.', ...data};
      }
      return {'type': 'error', 'message': 'Verification failed via Cloud Function'};
    } on FirebaseFunctionsException catch (e) {
      return {'type': 'error', 'message': e.message ?? 'OTP verification failed'};
    }
  }

  // ---------------------------------------------------------------------------
  // verifyAccessToken
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> verifyAccessToken({
    required String accessToken,
    String? mobileNumber,
  }) async {
    debugPrint('verifyAccessToken: verifying JWT via Cloud Function...');
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('verifyAccessToken');
      final result = await fn.call({
        'accessToken': accessToken,
        if (mobileNumber != null) 'mobileNumber': mobileNumber,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      debugPrint('verifyAccessToken CF result: $data');

      if (data['success'] == true) {
        return {
          'type': 'success',
          'message': 'Auto-verified via network.',
          'customToken': data['customToken'],
          'uid': data['uid'],
          'mobile': data['mobile'],
        };
      }
      return {'type': 'error', 'message': 'Access token verification failed'};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('verifyAccessToken CF error [${e.code}]: ${e.message}');
      return {'type': 'error', 'message': e.message ?? 'Access token verification failed'};
    } catch (e) {
      return {'type': 'error', 'message': 'Access token verification failed: $e'};
    }
  }

  static void clearReqId() {
    _currentReqId = null;
  }
}
