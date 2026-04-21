import 'package:flutter/material.dart';
import 'package:mini_garage/screens/garage_bag_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// Ensure CartItem and garageBag are accessible here
class ListingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> car;

  const ListingDetailScreen({super.key, required this.car});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool get isAlreadyInBag =>
      garageBag.any((item) => item.id == widget.car['id'].toString());

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Move these functions out of the build method for better performance
  void _nextImage(int total) {
    if (_currentPage < total - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevImage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = List<String>.from(
      widget.car['image_urls'] ?? [],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 500,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F0F),
            flexibleSpace: FlexibleSpaceBar(
              background: images.isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.directions_car,
                        color: Colors.white10,
                        size: 100,
                      ),
                    )
                  : Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController, // ATTACHED CONTROLLER
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index; // UPDATES BUTTON VISIBILITY
                            });
                          },
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, e, s) => const Icon(
                                Icons.broken_image,
                                color: Colors.white24,
                              ),
                            );
                          },
                        ),

                        // Navigation Arrows
                        if (images.length > 1) ...[
                          // Left Arrow - Only shows if not on first page
                          if (_currentPage > 0)
                            Positioned(
                              left: 15,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _carouselButton(
                                  Icons.chevron_left,
                                  _prevImage,
                                ),
                              ),
                            ),

                          // Right Arrow - Only shows if not on last page
                          if (_currentPage < images.length - 1)
                            Positioned(
                              right: 15,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _carouselButton(
                                  Icons.chevron_right,
                                  () => _nextImage(images.length),
                                ),
                              ),
                            ),
                        ],

                        // Indicator dots
                        if (images.length > 1)
                          Positioned(
                            bottom: 25,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                images.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: _currentPage == index ? 12 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: _currentPage == index
                                        ? Colors.blueAccent
                                        : Colors.white38,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),

          // ... The rest of your SliverToBoxAdapter and BottomNavigationBar
          // (They stay exactly the same as your previous version)
          // 2. Listing Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _badge("SCALE ${widget.car['scale'] ?? '1:64'}"),
                      _badge(
                        widget.car['status'] ?? 'AVAILABLE',
                        color: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.car['title'].toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "₹${widget.car['price']}",
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 80, color: Colors.white10),

                  const Text(
                    "COLLECTOR'S DESCRIPTION",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "This is a verified listing in the MiniGarage community. Mint condition guaranteed unless stated otherwise. For more detailed photos of the casting and base, please reach out via WhatsApp.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 150),
                ],
              ),
            ),
          ),
        ],
      ),

      // 3. The Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: ElevatedButton(
          onPressed: () {
            if (!isAlreadyInBag) {
              setState(() {
                garageBag.add(
                  CartItem(
                    id: widget.car['id'].toString(),
                    title: widget.car['title'],
                    price: widget.car['price'],
                    // Use the first image from the list as the thumbnail
                    imageUrl: images.isNotEmpty ? images.first : "",
                    sellerPhone: widget.car['seller_phone'] ?? "No Phone",
                    scale: widget.car['scale'] ?? "1:64",
                  ),
                );
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Added to your Garage Bag! 🏎️"),
                  backgroundColor: Colors.blueAccent,
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GarageBagScreen(),
                ),
              ).then((_) => setState(() {}));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isAlreadyInBag
                ? Colors.grey[900]
                : Colors.blueAccent,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: isAlreadyInBag
                  ? const BorderSide(color: Colors.white10)
                  : BorderSide.none,
            ),
          ),
          child: Text(
            isAlreadyInBag ? "VIEW IN BAG" : "ADD TO BAG",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _carouselButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _badge(String label, {Color color = Colors.blueAccent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
