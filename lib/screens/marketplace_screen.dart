import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mini_garage/screens/garage_bag_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'add_listing_screen.dart';
import 'listing_detail_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final supabase = Supabase.instance.client;
  String selectedScale = 'All'; // Current filter state

  // Getter for the filtered stream
  String selectedSort = 'Newest'; // 'Price: Low to High', 'Price: High to Low'
  String selectedBrand = 'All Brands';

  Stream<List<Map<String, dynamic>>> get _listingsStream {
    // 1. Use 'dynamic' to handle the changing types of the Supabase builders
    dynamic query = supabase.from('listings').stream(primaryKey: ['id']);

    // 2. Chain the Scale Filter if needed
    if (selectedScale != 'All') {
      query = query.eq('scale', selectedScale);
    }

    // 3. Chain the Brand Filter if needed
    // This was likely the missing piece!
    if (selectedBrand != 'All Brands') {
      query = query.eq('brand', selectedBrand);
    }

    // 4. Pass the fully filtered query to the sorting helper
    return _applySort(query);
  }

  // the sorting helper
  Stream<List<Map<String, dynamic>>> _applySort(dynamic query) {
    if (selectedSort == 'Price: Low to High') {
      return query.order('price', ascending: true);
    } else if (selectedSort == 'Price: High to Low') {
      return query.order('price', ascending: false);
    }

    // Default: Newest first
    return query.order('created_at', ascending: false);
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
          // Shopping Bag Icon with Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GarageBagScreen(),
                  ),
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
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
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
          ),
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
      // 1. Wrap the body in LayoutBuilder for accurate mobile detection
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 600;
          final int crossAxisCount = isMobile
              ? 2
              : 5; // 2 for mobile, 5 for desktop

          return Column(
            children: [
              _buildFilterBar(isMobile), // Now passing the argument correctly
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
                      return const Center(
                        child: Text(
                          "No cars in this category.",
                          style: TextStyle(color: Colors.grey),
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
                        childAspectRatio: isMobile
                            ? 0.75
                            : 0.85, // Taller cards for mobile
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

  // Horizontal Scale Filter Bar
  Widget _buildFilterBar(bool isMobile) {
    return Container(
      height: isMobile ? 50 : 60, // Shorter bar on mobile
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
            value: selectedBrand,
            items: [
              'All Brands',
              'Hot Wheels',
              'Bburago',
              'Matchbox',
              'Maisto',
            ],
            onChanged: (val) => setState(() => selectedBrand = val!),
            icon: Icons.branding_watermark,
            isMobile: isMobile,
          ),

          if (!isMobile) // Hide divider on small screens to save space
            const VerticalDivider(
              color: Colors.white10,
              width: 40,
              indent: 10,
              endIndent: 10,
            ),

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
  final VoidCallback onBagTapped; // Callback to refresh the UI

  const CarListingCard({
    super.key,
    required this.car,
    required this.onBagTapped,
  });

  @override
  Widget build(BuildContext context) {
    // Check if car is already in the bag
    bool inBag = garageBag.any((item) => item.id == car['id'].toString());
    final List<String> carImages = List<String>.from(car['image_urls'] ?? []);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Image
            Positioned.fill(
              child: Image.network(
                carImages.isNotEmpty
                    ? carImages.first
                    : "", // Take the first one for the thumbnail
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.directions_car),
              ),
            ),

            // Info & Add Button Bar
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
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
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "₹${car['price']}",
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // NEW: Quick Add Button
                        GestureDetector(
                          onTap: () {
                            if (!inBag) {
                              garageBag.add(
                                CartItem(
                                  id: car['id'].toString(),
                                  title: car['title'],
                                  price: car['price'],
                                  imageUrl: car['image_url'],
                                  sellerPhone:
                                      car['seller_phone'] ?? "No Phone",
                                  scale: car['scale'] ?? "1:64",
                                ),
                              );
                            } else {
                              garageBag.removeWhere(
                                (item) => item.id == car['id'].toString(),
                              );
                            }
                            onBagTapped(); // Tell the screen to rebuild
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
                              size: 18,
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
