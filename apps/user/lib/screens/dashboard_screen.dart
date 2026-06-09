import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final Color _navyBlue = const Color(0xFF0A1628);
  final Color _cardColor = const Color(0xFF132238);
  final Color _lightBlue = const Color(0xFF00B4D8);

  // Mock Data
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Fish', 'icon': Icons.set_meal},
    {'name': 'Prawns', 'icon': Icons.water},
    {'name': 'Crab', 'icon': Icons.bug_report},
    {'name': 'Meat', 'icon': Icons.kebab_dining},
    {'name': 'Offers', 'icon': Icons.local_offer},
    {'name': 'Healthy', 'icon': Icons.favorite},
  ];

  final List<Map<String, dynamic>> _shops = [
    {
      'name': 'Ocean Catch Seafoods',
      'rating': '4.5',
      'tags': 'Fresh Water, Seafood',
      'price': '\$20 for two',
      'time': '30 mins',
      'distance': '2.5 km',
      'offer': '50% OFF up to \$5',
      'image': 'https://images.unsplash.com/photo-1615141982883-c7ad0e69fd62?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    },
    {
      'name': 'Marina Fresh Meats',
      'rating': '4.2',
      'tags': 'Chicken, Mutton, Fresh',
      'price': '\$15 for two',
      'time': '40 mins',
      'distance': '4.0 km',
      'offer': 'FREE DELIVERY',
      'image': 'https://images.unsplash.com/photo-1603048297172-c92544798d5e?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    },
    {
      'name': 'Deep Sea Delights',
      'rating': '4.8',
      'tags': 'Premium Seafood, Sushi',
      'price': '\$40 for two',
      'time': '45 mins',
      'distance': '5.2 km',
      'offer': '20% OFF',
      'image': 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    },
  ];

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navyBlue,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar / Header
            SliverAppBar(
              backgroundColor: _navyBlue,
              floating: true,
              pinned: true,
              elevation: 0,
              toolbarHeight: 70,
              title: _buildHeader(),
            ),
            
            // Search Bar
            SliverToBoxAdapter(
              child: _buildSearchBar(),
            ),

            // Categories
            SliverToBoxAdapter(
              child: _buildCategories(),
            ),

            // Promotional Banners
            SliverToBoxAdapter(
              child: _buildPromoBanners(),
            ),

            // Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Text(
                  '14 Shops around you',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Shops List
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildShopCard(_shops[index]);
                },
                childCount: _shops.length,
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 80)), // Padding for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.location_on, color: _lightBlue, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  const Text(
                    'Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.7), size: 20),
                ],
              ),
              Text(
                '123, Ocean Drive, Marina Layout...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: _cardColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.person, color: _lightBlue),
                      title: const Text('My Profile', style: TextStyle(color: Colors.white)),
                      onTap: () => Navigator.pop(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                      onTap: () {
                        Navigator.pop(context);
                        _handleLogout();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          child: CircleAvatar(
            backgroundColor: _cardColor,
            radius: 20,
            child: Icon(Icons.person, color: _lightBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search, color: _lightBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search for "Fresh Prawns"',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              width: 1,
              height: 24,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(width: 12),
            Icon(Icons.mic_none, color: _lightBlue),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: _cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: _lightBlue.withOpacity(0.3), width: 1),
                  ),
                  child: Icon(cat['icon'], color: _lightBlue, size: 30),
                ),
                const SizedBox(height: 8),
                Text(
                  cat['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoBanners() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: SizedBox(
        height: 160,
        child: PageView.builder(
          controller: PageController(viewportFraction: 0.9),
          itemCount: 3,
          itemBuilder: (context, index) {
            final colors = [
              [const Color(0xFF00B4D8), const Color(0xFF0A1628)],
              [const Color(0xFFFF6B6B), const Color(0xFFC44D56)],
              [const Color(0xFF1DD1A1), const Color(0xFF10A881)],
            ];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: colors[index],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors[index][0].withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Icons.water,
                      size: 150,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PRO DISCOUNT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Flat 50% OFF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'On your first OceanKart order',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image and Promo Overlay
          Stack(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _navyBlue,
                  image: DecorationImage(
                    image: NetworkImage(shop['image']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        _cardColor.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ),
              // Offers Badge
              Positioned(
                bottom: 12,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _lightBlue,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _lightBlue.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        shop['offer'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Time and Distance Badge
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${shop['time']} • ${shop['distance']}',
                    style: TextStyle(
                      color: _navyBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Shop Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        shop['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Text(
                            shop['rating'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.star, color: Colors.white, size: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        shop['tags'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      shop['price'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: _lightBlue,
        unselectedItemColor: Colors.white.withOpacity(0.4),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.delivery_dining)),
            label: 'Delivery',
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.shopping_basket_outlined)),
            label: 'Market',
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.receipt_long_outlined)),
            label: 'Orders',
          ),
        ],
      ),
    );
  }
}
