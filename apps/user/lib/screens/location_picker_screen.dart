import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
  String _currentAddress = 'Loading...';
  bool _isLoading = true;
  bool _isSearching = false;

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
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setDefaultPosition();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setDefaultPosition();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _setDefaultPosition();
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _getAddressFromLatLng(_currentPosition!);
    } catch (e) {
      _setDefaultPosition();
    }
  }

  void _setDefaultPosition() {
    setState(() {
      _currentPosition = const LatLng(9.9312, 76.2673); // Kochi
      _isLoading = false;
    });
    _getAddressFromLatLng(_currentPosition!);
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() {
      _currentAddress = 'Fetching address...';
    });
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'OceanKartApp/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          setState(() {
            _currentAddress = data['display_name'];
          });
        } else {
          setState(() {
            _currentAddress = 'Address not found';
          });
        }
      } else {
        setState(() {
          _currentAddress = 'Failed to fetch address';
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = 'Error: $e';
      });
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'OceanKartApp/1.0',
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
          });

          _mapController.move(newPos, 15.0);
          _getAddressFromLatLng(newPos);
        } else {
          setState(() {
            _isSearching = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location not found')),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentPosition!,
                          initialZoom: 15.0,
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
                            userAgentPackageName: 'com.example.ocean_kart',
                          ),
                        ],
                      ),
                      // Center pin
                      const Padding(
                        padding: EdgeInsets.only(bottom: 40), // Adjust to point exactly at center
                        child: Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 48,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
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
                                children: [
                                  const Icon(Icons.location_on, color: Color(0xFF00B4D8)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _currentAddress,
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context, {
                                    'address': _currentAddress,
                                    'lat': _currentPosition?.latitude,
                                    'lon': _currentPosition?.longitude,
                                  });
                                },
                                child: const Text(
                                  'Confirm Location',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Floating button to locate me
                      Positioned(
                        bottom: 150,
                        right: 16,
                        child: FloatingActionButton(
                          backgroundColor: Colors.white,
                          onPressed: () async {
                            setState(() {
                              _isLoading = true;
                            });
                            await _determinePosition();
                            if (_currentPosition != null) {
                              _mapController.move(_currentPosition!, 15.0);
                            }
                          },
                          child: const Icon(Icons.my_location, color: Colors.blue),
                        ),
                      ),
                      // Search Bar
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: Colors.grey.shade800),
                            decoration: InputDecoration(
                              hintText: 'Search location...',
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
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            onSubmitted: _searchLocation,
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
