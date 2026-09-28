import 'dart:io';
import 'package:flutter/material.dart';

/// Service to check active network connectivity before performing critical Firestore operations.
class NetworkService {
  NetworkService._();

  /// Performs a fast DNS lookup to verify real internet connectivity.
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verifies active internet connectivity. If offline, immediately shows a
  /// styled 'No network connection' SnackBar and returns `false`.
  static Future<bool> checkConnection(BuildContext context) async {
    final isOnline = await hasInternetConnection();
    if (!isOnline && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No network connection. Please check your internet and try again.',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }
}
