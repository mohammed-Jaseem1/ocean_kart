import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationSetupScreen extends StatefulWidget {
  final String role; // 'Shopkeeper' or 'Delivery Boy'
  final bool isInitialSetup;

  const LocationSetupScreen({
    super.key,
    required this.role,
    this.isInitialSetup = true,
  });

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  static const Color primaryBlue = Color(0xFF00B4D8);
  static const Color darkBackground = Color(0xFF0A1628);
  static const Color cardColor = Color(0xFF132238);

  LatLng _currentPosition = const LatLng(9.9312, 76.2673); // Default Kochi
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  String _currentAddress = 'Detecting location...';
  bool _isLoadingLocation = true;
  bool _isSaving = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _determineInitialPosition();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determineInitialPosition() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setFallbackPosition();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setFallbackPosition();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setFallbackPosition();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final newPos = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentPosition = newPos;
          _isLoadingLocation = false;
        });
        _mapController.move(newPos, 16.0);
        _fetchAddressFromLatLng(newPos);
      }
    } catch (e) {
      _setFallbackPosition();
    }
  }

  void _setFallbackPosition() {
    if (!mounted) return;
    setState(() {
      _currentPosition = const LatLng(9.9312, 76.2673); // Kochi
      _isLoadingLocation = false;
    });
    _fetchAddressFromLatLng(_currentPosition);
  }

  Future<void> _fetchAddressFromLatLng(LatLng position) async {
    setState(() => _currentAddress = 'Fetching address details...');

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'OceanKartShopDeliveryApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null && mounted) {
          setState(() {
            _currentAddress = data['display_name'];
          });
        } else if (mounted) {
          setState(() => _currentAddress = 'Pinned Location');
        }
      } else if (mounted) {
        setState(() => _currentAddress = 'Coordinates: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _currentAddress = 'Coordinates: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&limit=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'OceanKartShopDeliveryApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && mounted) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newPos = LatLng(lat, lon);

          setState(() {
            _currentPosition = newPos;
          });

          _mapController.move(newPos, 16.0);
          _fetchAddressFromLatLng(newPos);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found. Please drag pin manually.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _saveLocation() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in.');

      final updatePayload = {
        'latitude': _currentPosition.latitude,
        'longitude': _currentPosition.longitude,
        'locationPinned': true,
        'pinnedAddress': _currentAddress,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      };

      // 1. Update user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updatePayload, SetOptions(merge: true));

      // 2. If shopkeeper, sync to shop_owners collection as well
      if (widget.role == 'Shopkeeper') {
        await FirebaseFirestore.instance
            .collection('shop_owners')
            .doc(user.uid)
            .set(updatePayload, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location pinned and saved successfully!'),
            backgroundColor: Color(0xFF2ED573),
          ),
        );

        if (!widget.isInitialSetup) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save location: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isShop = widget.role == 'Shopkeeper';
    final title = isShop ? 'Pin Your Store Location' : 'Pin Your Base Area';
    final subtitle = isShop
        ? 'Please place the pin on your store location so customers can discover your store within delivery radius.'
        : 'Please place the pin on your primary operating area to receive nearby delivery orders.';

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkBackground,
        elevation: 0,
        automaticallyImplyLeading: !widget.isInitialSetup,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (widget.isInitialSetup)
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout, color: Colors.white70),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top instructions bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isShop ? Icons.storefront : Icons.two_wheeler,
                        color: primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isShop ? 'Store Location Setup' : 'Delivery Partner Setup',
                        style: const TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  // Search box
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            textInputAction: TextInputAction.search,
                            onSubmitted: _searchLocation,
                            decoration: InputDecoration(
                              hintText: 'Search city, town, or area...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.white54),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSearching ? null : () => _searchLocation(_searchController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: darkBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        child: _isSearching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: darkBackground),
                              )
                            : const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Map Area with centered fixed pin
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPosition,
                      initialZoom: 15.0,
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          _currentPosition = position.center;
                        }
                      },
                      onMapEvent: (event) {
                        if (event is MapEventMoveEnd) {
                          _fetchAddressFromLatLng(_currentPosition);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        fallbackUrl: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.oceankart.shop_and_delivery',
                        maxZoom: 19,
                      ),
                    ],
                  ),

                  // Fixed Center Marker Pin
                  IgnorePointer(
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: darkBackground,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              isShop ? 'Store Pin' : 'Base Pin',
                              style: const TextStyle(
                                color: primaryBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.location_on,
                            size: 44,
                            color: isShop ? const Color(0xFFFF4757) : const Color(0xFF2ED573),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Locate Me button
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'locate_me_btn',
                      backgroundColor: cardColor,
                      foregroundColor: primaryBlue,
                      onPressed: _determineInitialPosition,
                      child: _isLoadingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom address card & confirm action
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Selected Location',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_currentPosition.latitude.toStringAsFixed(4)}, ${_currentPosition.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(color: primaryBlue, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: darkBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(darkBackground),
                              ),
                            )
                          : const Text(
                              'Confirm & Save Pin Location',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
