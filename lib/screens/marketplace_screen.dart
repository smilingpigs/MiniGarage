import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mini_garage/data/garage_data.dart';
import 'package:mini_garage/screens/garage_bag_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'add_listing_screen.dart';
import 'listing_detail_screen.dart';
import 'my_inventory_screen.dart'; // Added for the new navigation button

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final supabase = Supabase.instance.client;

  String selectedView = 'Mainlines';
  String selectedScale = 'All';
  String selectedSort = 'Newest';
  String selectedFilter = 'All';

  // --- UPDATED: REFINED STREAM LOGIC ---
  Stream<List<Map<String, dynamic>>> get _listingsStream {
    bool lookingForFantasy = selectedView == 'Fantasy';

    // We use .eq() on the stream because it is server-side compatible.
    // We handle .neq() and complex logic inside the .map() function.
    return supabase
        .from('listings')
        .stream(primaryKey: ['id'])
        .eq('is_fantasy', lookingForFantasy)
        .map((list) {
          final filteredList = list.where((item) {
            // 1. Filter out 'private' items (Fixes the neq issue)
            if (item['status'] == 'private') return false;

            // 2. Scale Filter
            if (selectedScale != 'All' && item['scale'] != selectedScale)
              return false;

            // 3. Dynamic Filter (Brand or Theme)
            if (selectedFilter != 'All') {
              if (lookingForFantasy) {
                if (item['subcategory'] != selectedFilter) return false;
              } else {
                if (item['brand'] != selectedFilter) return false;
              }
            }
            return true;
          }).toList();

          // 4. Apply Sorting
          return _sortList(filteredList);
        });
  }

  // Helper to handle list sorting client-side
  List<Map<String, dynamic>> _sortList(List<Map<String, dynamic>> list) {
    if (selectedSort == 'Price: Low to High') {
      list.sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0));
    } else if (selectedSort == 'Price: High to Low') {
      list.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
    } else {
      // Default: Newest first
      list.sort(
        (a, b) => (b['created_at'] ?? "").compareTo(a['created_at'] ?? ""),
      );
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          "MINIGARAGE",
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // --- NEW: INVENTORY BUTTON ---
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyInventoryScreen()),
            ),
          ),
          _buildBagButton(),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.blueAccent,
              size: 28,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddListingScreen()),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 600;
          final int crossAxisCount = isMobile ? 2 : 5;

          return Column(
            children: [
              _buildViewSwitcher(),
              _buildFilterBar(isMobile),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _listingsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.blueAccent,
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          "No $selectedView in the showroom yet.",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final listings = snapshot.data!;

                    return GridView.builder(
                      padding: EdgeInsets.all(isMobile ? 12 : 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: isMobile ? 12 : 20,
                        mainAxisSpacing: isMobile ? 12 : 20,
                        childAspectRatio: isMobile ? 0.72 : 0.82,
                      ),
                      itemCount: listings.length,
                      itemBuilder: (context, index) {
                        final car = listings[index];
                        return Hero(
                          tag: 'car-image-${car['id']}',
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ListingDetailScreen(car: car),
                              ),
                            ).then((_) => setState(() {})),
                            child: CarListingCard(
                              car: car,
                              onBagTapped: () => setState(() {}),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // The rest of the helper methods (Switcher, FilterBar, BagButton, Dropdown)
  // stay exactly the same as in your provided marketplace_screen.dart...
  // [Truncated for brevity, but they should remain unchanged in your file]

  Widget _buildViewSwitcher() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: ['Mainlines', 'Fantasy'].map((view) {
          bool isSelected = selectedView == view;
          return GestureDetector(
            onTap: () => setState(() {
              selectedView = view;
              selectedFilter = 'All';
            }),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blueAccent
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                view,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    List<String> dynamicItems = selectedView == 'Mainlines'
        ? ['All', 'Hot Wheels', 'Bburago', 'Matchbox', 'Maisto']
        : ['All', 'Glow-in-the-dark', 'Space', 'Tooned', 'Monster Trucks'];

    return Container(
      height: isMobile ? 50 : 60,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
        children: [
          _buildDropdown(
            value: selectedSort,
            items: ['Newest', 'Price: Low to High', 'Price: High to Low'],
            onChanged: (val) => setState(() => selectedSort = val!),
            icon: Icons.sort,
            isMobile: isMobile,
          ),
          const SizedBox(width: 8),
          _buildDropdown(
            value: selectedFilter,
            items: dynamicItems,
            onChanged: (val) => setState(() => selectedFilter = val!),
            icon: selectedView == 'Mainlines'
                ? Icons.branding_watermark
                : Icons.auto_awesome,
            isMobile: isMobile,
          ),
          const VerticalDivider(color: Colors.white10, width: 20),
          ...['All', '1:64', '1:43', '1:24', '1:18'].map((scale) {
            final isSelected = selectedScale == scale;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(
                  scale,
                  style: TextStyle(fontSize: isMobile ? 11 : 13),
                ),
                selected: isSelected,
                onSelected: (val) => setState(() => selectedScale = scale),
                selectedColor: Colors.blueAccent,
                backgroundColor: Colors.white.withOpacity(0.05),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                ),
                visualDensity: isMobile
                    ? VisualDensity.compact
                    : VisualDensity.standard,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBagButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GarageBagScreen()),
          ).then((value) => setState(() {})),
        ),
        if (garageBag.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${garageBag.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(icon, size: isMobile ? 14 : 16, color: Colors.blueAccent),
          dropdownColor: const Color(0xFF1A1A1A),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: TextStyle(fontSize: isMobile ? 11 : 13),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class CarListingCard extends StatelessWidget {
  final Map<String, dynamic> car;
  final VoidCallback onBagTapped;

  const CarListingCard({
    super.key,
    required this.car,
    required this.onBagTapped,
  });

  @override
  Widget build(BuildContext context) {
    bool inBag = garageBag.any((item) => item.id == car['id'].toString());
    final List<String> carImages = List<String>.from(car['image_urls'] ?? []);

    // NEW: Logic to handle 'Trade Only' vs 'Price'
    bool isTradeOnly = car['status'] == 'trade_only';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                carImages.isNotEmpty ? carImages.first : "",
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.directions_car, color: Colors.white10),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                car['title'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // NEW: Display Price or Trade Badge
                              isTradeOnly
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orangeAccent.withOpacity(
                                          0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "TRADE ONLY",
                                        style: TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      "₹${car['price']}",
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (!inBag) {
                              garageBag.add(
                                CartItem(
                                  id: car['id'].toString(),
                                  title: car['title'],
                                  price: car['price'],
                                  imageUrl: carImages.isNotEmpty
                                      ? carImages.first
                                      : "",
                                  sellerPhone:
                                      car['seller_phone'] ?? "No Phone",
                                  scale: car['scale'] ?? "1:64",
                                  isTradeOnly:
                                      car['status'] == 'trade_only', // ADD THIS
                                ),
                              );
                            } else {
                              garageBag.removeWhere(
                                (item) => item.id == car['id'].toString(),
                              );
                            }
                            onBagTapped();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: inBag ? Colors.green : Colors.blueAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              inBag ? Icons.check : Icons.add_shopping_cart,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
