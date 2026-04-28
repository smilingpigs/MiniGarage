import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyInventoryScreen extends StatefulWidget {
  const MyInventoryScreen({super.key});

  @override
  State<MyInventoryScreen> createState() => _MyInventoryScreenState();
}

class _MyInventoryScreenState extends State<MyInventoryScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // This Map tracks your taps locally so the UI responds instantly
  final Map<String, String> _optimisticStatuses = {};

  Stream<List<Map<String, dynamic>>> get _inventoryStream =>
      supabase.from('listings').stream(primaryKey: ['id']).order('created_at', ascending: false);

  // --- UPDATED: OPTIMISTIC UPDATE LOGIC ---
  Future<void> _updateStatus(String id, String newStatus, String previousStatus) async {
    // 1. Update the local state immediately
    setState(() {
      _optimisticStatuses[id] = newStatus;
    });

    try {
      // 2. Perform the actual database update
      await supabase.from('listings').update({'status': newStatus}).eq('id', id);
    } catch (e) {
      // 3. Rollback on failure
      setState(() {
        _optimisticStatuses[id] = previousStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sync failed. Reverting status."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("MY INVENTORY", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search cars by name...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const TabBar(
                  indicatorColor: Colors.blueAccent,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                  tabs: [
                    Tab(text: "MAINLINES"),
                    Tab(text: "FANTASY"),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _inventoryStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
            
            final allItems = snapshot.data!.where((item) {
              return item['title'].toString().toLowerCase().contains(_searchQuery);
            }).toList();

            final mainlines = allItems.where((item) => item['is_fantasy'] == false).toList();
            final fantasy = allItems.where((item) => item['is_fantasy'] == true).toList();

            return TabBarView(
              children: [
                _buildInventoryList(mainlines, false),
                _buildInventoryList(fantasy, true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInventoryList(List<Map<String, dynamic>> items, bool isFantasy) {
    if (items.isEmpty) return const Center(child: Text("No matching cars found.", style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final String id = item['id'].toString();
        final List<String> images = List<String>.from(item['image_urls'] ?? []);
        
        // Resolve status: Check optimistic map first, then fall back to server data
        final String serverStatus = item['status'] ?? 'private';
        final String currentStatus = _optimisticStatuses[id] ?? serverStatus;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    images.isNotEmpty ? images.first : "",
                    width: 60, height: 60, fit: BoxFit.cover,
                    errorBuilder: (context, e, s) => const Icon(Icons.directions_car, color: Colors.white10),
                  ),
                ),
                title: Text(item['title'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  isFantasy ? "Theme: ${item['subcategory'] ?? 'Fantasy'}" : "Brand: ${item['brand'] ?? 'Mainline'}",
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statusButton(id, 'private', "PRIVATE", currentStatus, serverStatus),
                  const SizedBox(width: 8),
                  _statusButton(id, 'for_sale', "SELL", currentStatus, serverStatus),
                  const SizedBox(width: 8),
                  _statusButton(id, 'trade_only', "TRADE", currentStatus, serverStatus),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusButton(String id, String statusKey, String label, String currentStatus, String serverStatus) {
    bool isActive = currentStatus == statusKey;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (currentStatus != statusKey) {
            _updateStatus(id, statusKey, serverStatus);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? Colors.green : Colors.white10,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.green : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}