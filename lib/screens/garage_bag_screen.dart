import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CartItem {
  final String id;
  final String title;
  final int price;
  final String imageUrl;
  final String sellerPhone;
  final String scale;

  CartItem({
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.sellerPhone,
    required this.scale,
  });
}

// Temporary global list for testing
List<CartItem> garageBag = [];

class GarageBagScreen extends StatefulWidget {
  const GarageBagScreen({super.key});

  @override
  State<GarageBagScreen> createState() => _GarageBagScreenState();
}

class _GarageBagScreenState extends State<GarageBagScreen> {
  
  // Logic to group items by seller phone
  Map<String, List<CartItem>> get groupedItems {
    Map<String, List<CartItem>> groups = {};
    for (var item in garageBag) {
      groups.putIfAbsent(item.sellerPhone, () => []).add(item);
    }
    return groups;
  }

  void removeItem(int index) {
    setState(() {
      garageBag.removeAt(index);
    });
  }

  Future<void> _sendWhatsAppBundle(String phone, List<CartItem> items) async {
    final String itemText = items.map((i) => "• ${i.title} (${i.scale}) - ₹${i.price}").join("\n");
    final int total = items.fold(0, (sum, item) => sum + item.price);
    
    final message = "Hi! I'm interested in these models from your MiniGarage:\n\n$itemText\n\nTotal: ₹$total\nAre these still available?";
    
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupedItems;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text("MY GARAGE BAG", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: garageBag.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.keys.length,
              itemBuilder: (context, index) {
                String phone = groups.keys.elementAt(index);
                List<CartItem> items = groups[phone]!;

                return _buildSellerSection(phone, items);
              },
            ),
    );
  }

  Widget _buildSellerSection(String phone, List<CartItem> items) {
    int sectionTotal = items.fold(0, (sum, item) => sum + item.price);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Seller Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 8),
                Text("SELLER: $phone", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                Text("${items.length} ITEMS", style: const TextStyle(color: Colors.blueAccent, fontSize: 10)),
              ],
            ),
          ),
          
          // List of Cars from this Seller
          ...items.map((item) => _buildCartTile(item)).toList(),

          // Section Footer & WhatsApp Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("SUBTOTAL", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    Text("₹$sectionTotal", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _sendWhatsAppBundle(phone, items),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat, size: 18, color: Colors.white),
                  label: const Text("CONTACT SELLER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartTile(CartItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(image: NetworkImage(item.imageUrl), fit: BoxFit.cover),
        ),
      ),
      title: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text("Scale ${item.scale} • ₹${item.price}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
        onPressed: () {
          setState(() {
            garageBag.removeWhere((i) => i.id == item.id);
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text("Your bag is empty", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}