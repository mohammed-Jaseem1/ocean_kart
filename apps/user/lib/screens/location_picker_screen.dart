import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum LocationErrorType {
  none,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeoutOrFailed,
}

class LocationPickerBottomSheet extends StatefulWidget {
  const LocationPickerBottomSheet({super.key});

  @override
  State<LocationPickerBottomSheet> createState() =>
      _LocationPickerBottomSheetState();
}

class _LocationPickerBottomSheetState extends State<LocationPickerBottomSheet> {
  LatLng? _currentPosition;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  String _currentAddress = '';
  bool _isLoading = true;
  bool _isSearching = false;
  LocationErrorType _errorType = LocationErrorType.none;
  String _errorMessage = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorType = LocationErrorType.none;
      _errorMessage = '';
    });

    try {
      // 1. Check if GPS / Location services are enabled on the device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorType = LocationErrorType.serviceDisabled;
          _errorMessage =
              'GPS / Location service is turned off on your device. Please turn on GPS to fetch your location.';
        });
        return;
      }

      // 2. Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorType = LocationErrorType.permissionDenied;
            _errorMessage =
                'Location permission is required to detect your current delivery location.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorType = LocationErrorType.permissionDeniedForever;
          _errorMessage =
              'Location permission is permanently denied. Please grant location access in your device settings.';
        });
        return;
      }

      // 3. Try to get last known position first for quick response
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        final lastPos = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _currentPosition = lastPos;
          _isLoading = false;
        });
        _getAddressFromLatLng(lastPos);
      }

      // 4. Fetch the real, high-accuracy GPS position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;
      final realPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = realPos;
        _isLoading = false;
        _errorType = LocationErrorType.none;
        _errorMessage = '';
      });

      try {
        _mapController.move(realPos, 16.0);
      } catch (_) {}

      _getAddressFromLatLng(realPos);
    } catch (e) {
      debugPrint('Location detection error: $e');
      if (!mounted) return;
      // If we already have a position (from last known), keep it; otherwise show error
      if (_currentPosition == null) {
        setState(() {
          _isLoading = false;
          _errorType = LocationErrorType.timeoutOrFailed;
          _errorMessage =
              'Could not get GPS fix. Please ensure you have a clear GPS signal or search your location below.';
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  static const String _fallbackGoogleMapsKey =
      'AIzaSyDFkC8KCvcYhM-QDYsCZkO_YKghe8Z66Tk';

  String _getGoogleApiKey() {
    final envKey = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim();
    if (envKey != null && envKey.isNotEmpty) return envKey;
    return _fallbackGoogleMapsKey;
  }

  String _cleanGoogleAddress(String raw) {
    // Strips Plus Code prefix e.g. "923W+89 ", "923V+9H6, ", "923W+89 Koodaranji..."
    return raw.replaceFirst(RegExp(r'^[A-Z0-9]{2,8}\+[A-Z0-9]{2,4}[\s,]+'), '').trim();
  }

  String _selectBestGoogleAddress(List<dynamic> results) {
    if (results.isEmpty) return '';

    dynamic bestResult;

    // 1. Prefer a result with a 6-digit Indian PIN code and not exclusively a plus_code type
    for (var r in results) {
      final types = (r['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final addr = r['formatted_address']?.toString() ?? '';
      if (RegExp(r'\b\d{6}\b').hasMatch(addr) && !types.contains('plus_code')) {
        bestResult = r;
        break;
      }
    }

    // 2. If not found, look for any result with a 6-digit PIN code
    if (bestResult == null) {
      for (var r in results) {
        final addr = r['formatted_address']?.toString() ?? '';
        if (RegExp(r'\b\d{6}\b').hasMatch(addr)) {
          bestResult = r;
          break;
        }
      }
    }

    // 3. Fallback to first non-plus_code result
    if (bestResult == null) {
      for (var r in results) {
        final types = (r['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        if (!types.contains('plus_code')) {
          bestResult = r;
          break;
        }
      }
    }

    bestResult ??= results.first;
    final raw = bestResult['formatted_address']?.toString() ?? '';
    return _cleanGoogleAddress(raw);
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    if (!mounted) return;
    setState(() {
      _currentAddress = 'Fetching address...';
    });

    // 1. Query Google Geocoding API first
    final googleKey = _getGoogleApiKey();
    if (googleKey.isNotEmpty) {
      try {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$googleKey',
        );
        final response =
            await http.get(googleUrl).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final cleaned = _selectBestGoogleAddress(data['results'] as List);
            if (cleaned.isNotEmpty && mounted) {
              setState(() {
                _currentAddress = cleaned;
              });
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Google Geocoding error: $e');
      }
    }

    // 2. Fallback to OpenStreetMap Nominatim
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'OceanKartUserApp/1.0 (contact@oceankart.com)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          final cleanAddress = _formatCleanAddress(data, position);
          setState(() {
            _currentAddress = cleanAddress;
          });
        }
      } else if (mounted) {
        setState(() {
          _currentAddress =
              'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress =
              'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        });
      }
    }
  }

  String _formatCleanAddress(dynamic data, LatLng position) {
    if (data is! Map<String, dynamic>) {
      return 'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
    }

    final addr = data['address'] as Map<String, dynamic>?;
    if (addr == null) {
      return data['display_name'] ??
          'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
    }

    final List<String> parts = [];

    // 1. House / Building name
    final house = addr['house_number'] ?? addr['house_name'] ?? addr['building'];
    if (house != null && house.toString().trim().isNotEmpty) {
      parts.add(house.toString().trim());
    }

    // 2. Road / Street / Lane
    final road = addr['road'] ?? addr['street'] ?? addr['residential'] ?? addr['pedestrian'];
    if (road != null &&
        road.toString().trim().isNotEmpty &&
        !road.toString().toLowerCase().contains('unnamed')) {
      parts.add(road.toString().trim());
    }

    // 3. Suburb / Area / Locality
    final locality = addr['suburb'] ??
        addr['neighbourhood'] ??
        addr['residential'] ??
        addr['subdistrict'];
    if (locality != null &&
        locality.toString().trim().isNotEmpty &&
        !parts.contains(locality.toString().trim())) {
      parts.add(locality.toString().trim());
    }

    // 4. City / Town / Village / District
    final city = addr['city'] ??
        addr['town'] ??
        addr['village'] ??
        addr['municipality'] ??
        addr['county'] ??
        addr['district'];
    if (city != null &&
        city.toString().trim().isNotEmpty &&
        !parts.contains(city.toString().trim())) {
      parts.add(city.toString().trim());
    }

    // 5. State
    final state = addr['state'];
    if (state != null &&
        state.toString().trim().isNotEmpty &&
        !parts.contains(state.toString().trim())) {
      parts.add(state.toString().trim());
    }

    // 6. Postcode
    final postcode = addr['postcode'];
    if (postcode != null && postcode.toString().trim().isNotEmpty) {
      parts.add(postcode.toString().trim());
    }

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    return data['display_name'] ??
        'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    // 1. If Google key is available, search using Google Geocoding API
    final googleKey = _getGoogleApiKey();
    if (googleKey.isNotEmpty) {
      try {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$googleKey',
        );
        final response =
            await http.get(googleUrl).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final loc = data['results'][0]['geometry']['location'];
            final double lat = (loc['lat'] as num).toDouble();
            final double lon = (loc['lng'] as num).toDouble();
            final newPos = LatLng(lat, lon);
            final formatted = data['results'][0]['formatted_address'];

            if (mounted) {
              setState(() {
                _currentPosition = newPos;
                _isSearching = false;
                _errorType = LocationErrorType.none;
                _errorMessage = '';
                if (formatted != null) {
                  _currentAddress =
                      _cleanGoogleAddress(formatted.toString());
                }
              });
              _mapController.move(newPos, 16.0);
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Google Geocoding search error: $e');
      }
    }

    // 2. Fallback to OpenStreetMap Search
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&addressdetails=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'OceanKartUserApp/1.0 (contact@oceankart.com)',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newPos = LatLng(lat, lon);

          setState(() {
            _currentPosition = newPos;
            _isSearching = false;
            _errorType = LocationErrorType.none;
            _errorMessage = '';
          });

          _mapController.move(newPos, 15.0);
          _getAddressFromLatLng(newPos);
        } else {
          setState(() {
            _isSearching = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location not found. Please try a different query.')),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  Widget _buildErrorView() {
    IconData icon;
    String title;
    String buttonText;
    VoidCallback onButtonPressed;

    switch (_errorType) {
      case LocationErrorType.serviceDisabled:
        icon = Icons.location_off;
        title = 'GPS is Turned Off';
        buttonText = 'Turn On GPS';
        onButtonPressed = () async {
          await Geolocator.openLocationSettings();
          _determinePosition();
        };
        break;
      case LocationErrorType.permissionDenied:
        icon = Icons.lock_outline;
        title = 'Location Permission Needed';
        buttonText = 'Allow Location Access';
        onButtonPressed = () {
          _determinePosition();
        };
        break;
      case LocationErrorType.permissionDeniedForever:
        icon = Icons.settings;
        title = 'Permission Permanently Denied';
        buttonText = 'Open App Settings';
        onButtonPressed = () async {
          await Geolocator.openAppSettings();
        };
        break;
      default:
        icon = Icons.gps_not_fixed;
        title = 'Unable to Detect Location';
        buttonText = 'Retry GPS';
        onButtonPressed = () {
          _determinePosition();
        };
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.red.shade700),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B4D8),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: Text(
              buttonText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: onButtonPressed,
          ),
          const SizedBox(height: 16),
          // Or search manually
          Text(
            '— OR SEARCH YOUR LOCATION ABOVE —',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Delivery Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Colors.grey.shade900),
                decoration: InputDecoration(
                  hintText: 'Search city, street or area...',
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: _searchLocation,
              ),
            ),
          ),

          // Map or Loading or Error State
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Detecting current GPS location...',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _currentPosition == null
                    ? _buildErrorView()
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _currentPosition!,
                              initialZoom: 16.0,
                              onPositionChanged: (position, hasGesture) {
                                if (hasGesture) {
                                  setState(() {
                                    _currentPosition = position.center;
                                  });
                                }
                              },
                              onMapEvent: (event) {
                                if (event is MapEventMoveEnd) {
                                  if (_currentPosition != null) {
                                    _getAddressFromLatLng(_currentPosition!);
                                  }
                                }
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                fallbackUrl:
                                    'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.oceankartUser',
                                maxZoom: 19,
                              ),
                            ],
                          ),

                          // Center location pin
                          const Padding(
                            padding: EdgeInsets.only(bottom: 40),
                            child: Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 48,
                            ),
                          ),

                          // Floating button to re-detect current GPS
                          Positioned(
                            bottom: 170,
                            right: 16,
                            child: FloatingActionButton(
                              heroTag: 'locate_me_btn',
                              backgroundColor: Colors.white,
                              elevation: 4,
                              onPressed: () async {
                                await _determinePosition();
                              },
                              child: const Icon(Icons.my_location,
                                  color: Color(0xFF00B4D8)),
                            ),
                          ),

                          // Bottom address preview card & confirm button
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10,
                                    offset: Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on,
                                          color: Color(0xFF00B4D8)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _currentAddress.isEmpty
                                              ? 'Moving map...'
                                              : _currentAddress,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00B4D8),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: (_currentPosition == null ||
                                            _currentAddress ==
                                                'Fetching address...' ||
                                            _currentAddress.isEmpty)
                                        ? null
                                        : () {
                                            Navigator.pop(context, {
                                              'address': _currentAddress,
                                              'lat':
                                                  _currentPosition?.latitude,
                                              'lon':
                                                  _currentPosition?.longitude,
                                            });
                                          },
                                    child: const Text(
                                      'Confirm Location',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
