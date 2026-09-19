import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shop_keeper/dashboard_screen.dart';
import '../delevery_partner/delivery_partner_dashboard.dart';

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

class _LocationSetupScreenState extends State<LocationSetupScreen> with SingleTickerProviderStateMixin {
  static const Color _primaryCyan = Color(0xFF00B4D8);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _successGreen = Color(0xFF10B981);

  LatLng _currentPosition = const LatLng(9.9312, 76.2673); // Default Kochi
  LatLng? _userGpsPosition;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  String _currentAddress = 'Detecting location...';
  bool _isLoadingLocation = true;
  bool _isSaving = false;
  bool _isSearching = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _determineInitialPosition(isManualTrigger: false);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determineInitialPosition({bool isManualTrigger = false}) async {
    setState(() => _isLoadingLocation = true);

    // 1. If not a manual GPS trigger, check if location was already saved in Firestore
    if (!isManualTrigger) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final col = widget.role == 'Shopkeeper' ? 'shop_owners' : 'delivery_partners';
          final docSnap = await FirebaseFirestore.instance.collection(col).doc(user.uid).get();
          final data = docSnap.data();
          if (data != null && data['latitude'] != null && data['longitude'] != null) {
            final double? lat = (data['latitude'] as num?)?.toDouble();
            final double? lon = (data['longitude'] as num?)?.toDouble();
            if (lat != null && lon != null) {
              final savedPos = LatLng(lat, lon);
              if (mounted) {
                setState(() {
                  _currentPosition = savedPos;
                  _userGpsPosition = savedPos;
                  _currentAddress = data['pinnedAddress'] ?? data['location'] ?? data['address'] ?? 'Saved Store Location';
                  _isLoadingLocation = false;
                });
                try {
                  _mapController.move(savedPos, 16.5);
                } catch (_) {}
                return;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error reading pre-existing location: $e');
      }
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (isManualTrigger && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('GPS / Location services are turned off.'),
              action: SnackBarAction(
                label: 'Enable GPS',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
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
        if (isManualTrigger && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission is permanently denied. Please enable in App Settings.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        _setFallbackPosition();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final newPos = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _userGpsPosition = newPos;
          _currentPosition = newPos;
          _isLoadingLocation = false;
        });
        _mapController.move(newPos, 17.0);
        _fetchAddressFromLatLng(newPos);
        
        if (isManualTrigger) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Current GPS location detected!'),
              backgroundColor: _primaryCyan,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _setFallbackPosition();
    }
  }

  void _setFallbackPosition() {
    if (!mounted) return;
    setState(() {
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
          setState(() => _currentAddress = 'Pinned Store Location');
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

          _mapController.move(newPos, 16.5);
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
      if (user == null) throw Exception('No user session found.');

      final updatePayload = {
        'latitude': _currentPosition.latitude,
        'longitude': _currentPosition.longitude,
        'isLocationPinned': true,
        'isLocationLogged': true,
        'pinnedAddress': _currentAddress,
        'location': _currentAddress,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      };

      // Update corresponding role collection and users collection for consistency
      final String targetCollection = widget.role == 'Shopkeeper' ? 'shop_owners' : 'delivery_partners';
      await FirebaseFirestore.instance
          .collection(targetCollection)
          .doc(user.uid)
          .set(updatePayload, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updatePayload, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store Location Pinned Successfully!'),
            backgroundColor: _successGreen,
          ),
        );

        if (!widget.isInitialSetup) {
          Navigator.pop(context);
        } else {
          if (widget.role == 'Shopkeeper') {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DeliveryPartnerDashboard()),
              (route) => false,
            );
          }
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

  Future<void> _skipLocationSetup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final skipPayload = {
        'isLocationLogged': true,
      };
      final String targetCollection = widget.role == 'Shopkeeper' ? 'shop_owners' : 'delivery_partners';
      await FirebaseFirestore.instance
          .collection(targetCollection)
          .doc(user.uid)
          .set(skipPayload, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(skipPayload, SetOptions(merge: true));
    }
    if (mounted) {
      if (widget.role == 'Shopkeeper') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DeliveryPartnerDashboard()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isShop = widget.role == 'Shopkeeper';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: !widget.isInitialSetup,
        title: Text(
          isShop ? 'Set Store Location' : 'Set Base Location',
          style: const TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: _textDark),
        actions: [
          if (widget.isInitialSetup) ...[
            TextButton(
              onPressed: _skipLocationSetup,
              child: const Text(
                'Skip for now',
                style: TextStyle(color: _primaryCyan, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Log Out',
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout, size: 18, color: _textMuted),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // 1. Full Screen Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 16.5,
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
                fallbackUrl: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.oceankart.shop_and_delivery',
                maxZoom: 19,
                panBuffer: 1,
              ),
              if (_userGpsPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userGpsPosition!,
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primaryCyan.withValues(alpha: 0.25),
                            ),
                          ),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primaryCyan,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. Fixed Center Pin with Pulsing Effect
          Center(
            child: IgnorePointer(
              child: Transform.translate(
                offset: const Offset(0, -22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _textDark,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _primaryCyan,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isShop ? 'Your Store Pin' : 'Your Base Pin',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 46,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Top Floating Search, Instructions & Use Current Location
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isInitialSetup)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0096C7),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryCyan.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.info_outline, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Please pin your exact store location so delivery partners can navigate to your store.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Search Bar Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 12.0),
                        child: Icon(Icons.search_rounded, color: _primaryCyan, size: 20),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13.5, color: _textDark),
                          textInputAction: TextInputAction.search,
                          onSubmitted: _searchLocation,
                          decoration: InputDecoration(
                            hintText: 'Search city, landmark, or street...',
                            hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: _textMuted),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(5),
                        child: ElevatedButton(
                          onPressed: _isSearching ? null : () => _searchLocation(_searchController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryCyan,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSearching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. Floating Locate Me (GPS) Button with Label
          Positioned(
            right: 16,
            bottom: 230,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _determineInitialPosition(isManualTrigger: true),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _primaryCyan.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isLoadingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _primaryCyan),
                            )
                          : const Icon(Icons.my_location_rounded, size: 20, color: _primaryCyan),
                      const SizedBox(width: 6),
                      const Text(
                        'Locate Me',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Bottom Card: Address & Confirm Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: _cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coordinates badge & title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primaryCyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on_outlined, color: _primaryCyan, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Pinned Location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_currentPosition.latitude.toStringAsFixed(4)}, ${_currentPosition.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Readable Address
                  Text(
                    _currentAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveLocation,
                      icon: _isSaving
                          ? const SizedBox.shrink()
                          : const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                      label: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              isShop ? 'Confirm & Pin Store Location' : 'Confirm & Pin Base Location',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryCyan,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
