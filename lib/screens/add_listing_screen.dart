import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final supabase = Supabase.instance.client;

  final titleController = TextEditingController();
  final priceController = TextEditingController();
  final phoneController = TextEditingController();
  final otherBrandController = TextEditingController();
  final subcategoryController = TextEditingController();

  List<Uint8List> imageBytesList = [];
  String? selectedScale = '1:64';
  String? selectedBrand;
  String selectedCondition = 'Mint (Carded)';
  String selectedStatus = 'private'; // NEW: Default to Inventory
  bool isFantasy = false; // NEW: Mainline vs Fantasy Toggle
  List<String> availableBrands = [];

  // Options lists
  final List<String> statusOptions = ['private', 'for_sale', 'trade_only'];
  final List<String> conditionOptions = [
    'Mint (Carded)',
    'Near Mint (Carded)',
    'Loose (Mint)',
    'Loose (Played)',
    'Damaged Packaging',
  ];

  bool isUploading = false;
  bool isLoadingBrands = true;
  bool isAnalyzing = false;
  bool isOtherSelected = false;

  @override
  void initState() {
    super.initState();
    _getBrands();
  }

  Future<void> _getBrands() async {
    try {
      final data = await supabase
          .from('brands')
          .select('name')
          .order('name', ascending: true);
      setState(() {
        availableBrands = List<String>.from(data.map((e) => e['name']));
        availableBrands.add("Other");
        if (availableBrands.isNotEmpty) selectedBrand = availableBrands[0];
      });
    } catch (e) {
      setState(() {
        if (availableBrands.isEmpty) availableBrands.add("Other");
        selectedBrand = "Other";
        isOtherSelected = true;
      });
    } finally {
      setState(() => isLoadingBrands = false);
    }
  }

  Future<void> autoFillWithAI() async {
    if (imageBytesList.isEmpty) return;
    setState(() => isAnalyzing = true);

    // --- SETTINGS FOR RELIABILITY ---
    const int maxRetries = 3;
    int retryCount = 0;
    bool success = false;

    while (retryCount < maxRetries && !success) {
      try {
        // Switch to 'lite' for better availability during high demand
        final model = GenerativeModel(
          model: 'gemini-2.5-flash-lite',
          apiKey: dotenv.env['GEMINI_API_KEY']!,
        );

        final prompt = TextPart(
          "Identify this die-cast car. Return JSON: "
          "{'brand': 'string', 'title': 'string', 'scale': 'string', 'subcategory': 'string', 'is_fantasy': bool}. "
          "The 'subcategory' is the series name like 'Muscle Mania'. Only return JSON.",
        );

        final imagePart = DataPart('image/jpeg', imageBytesList.first);
        final response = await model.generateContent([
          Content.multi([prompt, imagePart]),
        ]);

        if (response.text == null) throw Exception("Empty response");

        final String cleanJson = response.text!
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final Map<String, dynamic> result = jsonDecode(cleanJson);

        setState(() {
          titleController.text = result['title'] ?? "";
          subcategoryController.text = result['subcategory'] ?? "";
          isFantasy = result['is_fantasy'] ?? false;

          // Match brand logic
          String detectedBrand = result['brand'] ?? "";
          bool brandExists = availableBrands.any(
            (b) => b.toLowerCase() == detectedBrand.toLowerCase(),
          );
          if (brandExists) {
            selectedBrand = availableBrands.firstWhere(
              (b) => b.toLowerCase() == detectedBrand.toLowerCase(),
            );
            isOtherSelected = false;
          } else {
            selectedBrand = "Other";
            isOtherSelected = true;
            otherBrandController.text = detectedBrand;
          }
        });

        success = true; // Break the loop
      } catch (e) {
        retryCount++;
        if (e.toString().contains('503') && retryCount < maxRetries) {
          // Wait 2 seconds before retrying
          await Future.delayed(const Duration(seconds: 2));
        } else {
          print("AI Scan Error: $e");
          _showError(
            "AI Scan failed. Servers are busy, please try once more or fill manually.",
          );
          break;
        }
      }
    }

    setState(() => isAnalyzing = false);
  }

  Future<void> pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result != null) {
      setState(() {
        imageBytesList = result.files.map((file) => file.bytes!).toList();
      });
    }
  }

  Future<void> uploadListing() async {
    final String title = titleController.text.trim();
    final int? price = int.tryParse(priceController.text.trim());
    final String phone = phoneController.text.trim();
    final String finalBrand = isOtherSelected
        ? otherBrandController.text.trim()
        : (selectedBrand ?? "");

    // VALIDATION: Price and Phone are optional if the status is 'private'
    bool isPrivate = selectedStatus == 'private';
    if (imageBytesList.isEmpty ||
        title.isEmpty ||
        finalBrand.isEmpty ||
        (!isPrivate && (price == null || phone.isEmpty))) {
      _showError("Please complete all required fields.");
      return;
    }

    setState(() => isUploading = true);

    try {
      List<String> uploadedUrls = [];
      for (int i = 0; i < imageBytesList.length; i++) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await supabase.storage
            .from('listing-images')
            .uploadBinary(
              fileName,
              imageBytesList[i],
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        uploadedUrls.add(
          supabase.storage.from('listing-images').getPublicUrl(fileName),
        );
      }

      await supabase.from('listings').insert({
        'title': title,
        'price': price ?? 0, // Default to 0 if private
        'scale': selectedScale,
        'brand': finalBrand,
        'condition': selectedCondition,
        'subcategory': subcategoryController.text.trim(),
        'status': selectedStatus, // NEW
        'is_fantasy': isFantasy, // NEW
        'seller_phone': phone,
        'image_urls': uploadedUrls,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError("Upload failed: $e");
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text("ADD TO GARAGE"),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                _buildImagePicker(),
                const SizedBox(height: 30),

                // NEW: Status Dropdown (Private/Sale/Trade)
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  dropdownColor: Colors.grey[900],
                  decoration: _inputDecoration("Garage Status"),
                  items: statusOptions
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s.toUpperCase().replaceAll('_', ' '),
                            style: TextStyle(
                              color: s == 'private'
                                  ? Colors.grey
                                  : Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => selectedStatus = val!),
                ),

                const SizedBox(height: 15),

                // NEW: Fantasy Toggle
                SwitchListTile(
                  title: const Text(
                    "Fantasy / Concept Car",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    "Mark as non-real-world theme",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  value: isFantasy,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) => setState(() => isFantasy = val),
                ),

                const SizedBox(height: 15),

                _buildDropdown(
                  "Brand",
                  availableBrands,
                  selectedBrand,
                  (val) => setState(() {
                    selectedBrand = val;
                    isOtherSelected = (val == "Other");
                  }),
                ),

                if (isOtherSelected) ...[
                  const SizedBox(height: 15),
                  _buildTextField(otherBrandController, "Custom Brand Name"),
                ],

                const SizedBox(height: 15),
                _buildTextField(
                  titleController,
                  "Model Name (e.g. Porsche 911)",
                ),

                const SizedBox(height: 15),
                _buildTextField(
                  subcategoryController,
                  "Series / Sub-series (e.g. Exoticas)",
                ),

                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        priceController,
                        "Price (₹)",
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildDropdown(
                        "Scale",
                        ['1:64', '1:43', '1:24', '1:18'],
                        selectedScale,
                        (val) => setState(() => selectedScale = val),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),
                _buildDropdown(
                  "Condition",
                  conditionOptions,
                  selectedCondition,
                  (val) => setState(() => selectedCondition = val!),
                ),

                const SizedBox(height: 15),
                _buildTextField(
                  phoneController,
                  "WhatsApp Number",
                  isNumber: true,
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isUploading ? null : uploadListing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    child: isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("ADD TO GARAGE"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI Re-usable Components ---
  Widget _buildImagePicker() => Stack(
    children: [
      GestureDetector(
        onTap: pickImages,
        child: Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: imageBytesList.isEmpty
              ? const Center(
                  child: Icon(
                    Icons.add_a_photo,
                    size: 50,
                    color: Colors.blueAccent,
                  ),
                )
              : PageView.builder(
                  itemCount: imageBytesList.length,
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.memory(imageBytesList[i], fit: BoxFit.cover),
                  ),
                ),
        ),
      ),
      if (imageBytesList.isNotEmpty)
        Positioned(
          bottom: 15,
          right: 15,
          child: FloatingActionButton.extended(
            onPressed: isAnalyzing ? null : autoFillWithAI,
            backgroundColor: Colors.blueAccent,
            icon: isAnalyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(isAnalyzing ? "ANALYZING..." : "AI AUTO-FILL"),
          ),
        ),
    ],
  );

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    value: items.contains(value) ? value : (items.isNotEmpty ? items[0] : null),
    dropdownColor: Colors.grey[900],
    decoration: _inputDecoration(label),
    items: items
        .map(
          (brand) => DropdownMenuItem(
            value: brand,
            child: Text(brand, style: const TextStyle(color: Colors.white)),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white.withOpacity(0.05),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
    labelStyle: const TextStyle(color: Colors.grey),
  );

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
  }) => TextField(
    controller: controller,
    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
    style: const TextStyle(color: Colors.white),
    decoration: _inputDecoration(label),
  );
}
