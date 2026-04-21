import 'dart:convert';
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

  List<Uint8List> imageBytesList = []; // Replaces singular imageBytes
  String? selectedScale = '1:64';
  String? selectedBrand;
  List<String> availableBrands = [];

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
      final data = await supabase.from('brands').select('name').order('name', ascending: true);
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

  // --- AI SECTION: Uses the first image picked ---
  Future<void> autoFillWithAI() async {
    if (imageBytesList.isEmpty) return;

    setState(() => isAnalyzing = true);

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: 'YOUR_API_KEY', 
      );

      final prompt = TextPart("Identify this die-cast car. Return JSON: {'brand': 'string', 'title': 'string', 'scale': 'string'}. Only return JSON.");
      
      // We send the first image (the hero shot) for analysis
      final imagePart = DataPart('image/jpeg', imageBytesList.first);

      final response = await model.generateContent([Content.multi([prompt, imagePart])]);

      if (response.text == null) return;

      final String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> result = jsonDecode(cleanJson);

      setState(() {
        titleController.text = result['title'] ?? "";
        if (['1:64', '1:43', '1:24', '1:18'].contains(result['scale'])) {
          selectedScale = result['scale'];
        }
        String detectedBrand = result['brand'] ?? "";
        bool brandExists = availableBrands.any((b) => b.toLowerCase() == detectedBrand.toLowerCase());

        if (brandExists) {
          selectedBrand = availableBrands.firstWhere((b) => b.toLowerCase() == detectedBrand.toLowerCase());
          isOtherSelected = false;
        } else {
          selectedBrand = "Other";
          isOtherSelected = true;
          otherBrandController.text = detectedBrand;
        }
      });
    } catch (e) {
      _showError("AI could not read image.");
    } finally {
      setState(() => isAnalyzing = false);
    }
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

  // --- UPLOAD SECTION: Handles multiple files ---
  Future<void> uploadListing() async {
    final String title = titleController.text.trim();
    final int? price = int.tryParse(priceController.text.trim());
    final String phone = phoneController.text.trim();
    final String finalBrand = isOtherSelected ? otherBrandController.text.trim() : (selectedBrand ?? "");

    if (imageBytesList.isEmpty || title.isEmpty || price == null || phone.isEmpty || finalBrand.isEmpty) {
      _showError("Please complete all fields and pick at least one photo");
      return;
    }

    setState(() => isUploading = true);

    try {
      List<String> uploadedUrls = [];

      // Loop through all images and upload to Supabase
      for (int i = 0; i < imageBytesList.length; i++) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        await supabase.storage.from('listing-images').uploadBinary(
          fileName, 
          imageBytesList[i],
          fileOptions: const FileOptions(contentType: 'image/jpeg')
        );

        final url = supabase.storage.from('listing-images').getPublicUrl(fileName);
        uploadedUrls.add(url);
      }

      // Insert into DB using the 'image_urls' (array) column
      await supabase.from('listings').insert({
        'title': title,
        'price': price,
        'scale': selectedScale,
        'brand': finalBrand,
        'seller_phone': phone,
        'image_urls': uploadedUrls, // Saved as an array
        'status': 'available',
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
      appBar: AppBar(title: const Text("LIST NEW CAR"), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // MULTI-IMAGE PREVIEW
                Stack(
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
                            ? const Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.blueAccent))
                            : PageView.builder(
                                itemCount: imageBytesList.length,
                                itemBuilder: (context, index) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.memory(imageBytesList[index], fit: BoxFit.cover),
                                  );
                                },
                              ),
                      ),
                    ),
                    if (imageBytesList.isNotEmpty) ...[
                      // AI Button
                      Positioned(
                        bottom: 15,
                        right: 15,
                        child: FloatingActionButton.extended(
                          onPressed: isAnalyzing ? null : autoFillWithAI,
                          backgroundColor: Colors.blueAccent,
                          icon: isAnalyzing 
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 18),
                          label: Text(isAnalyzing ? "ANALYZING..." : "AI AUTO-FILL"),
                        ),
                      ),
                      // Indicator for multiple images
                      Positioned(
                        top: 15,
                        left: 15,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                          child: Text("${imageBytesList.length} Photos", style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 30),
                // Brands Dropdown
                isLoadingBrands
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField<String>(
                        value: availableBrands.contains(selectedBrand) ? selectedBrand : "Other",
                        dropdownColor: Colors.grey[900],
                        decoration: _inputDecoration("Brand"),
                        items: availableBrands.map((brand) => DropdownMenuItem(value: brand, child: Text(brand, style: const TextStyle(color: Colors.white)))).toList(),
                        onChanged: (val) => setState(() { selectedBrand = val; isOtherSelected = (val == "Other"); }),
                      ),

                if (isOtherSelected) ...[
                  const SizedBox(height: 15),
                  _buildTextField(otherBrandController, "Custom Brand Name"),
                ],

                const SizedBox(height: 15),
                _buildTextField(titleController, "Model Name"),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _buildTextField(priceController, "Price (₹)", isNumber: true)),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedScale,
                        dropdownColor: Colors.grey[900],
                        decoration: _inputDecoration("Scale"),
                        items: ['1:64', '1:43', '1:24', '1:18'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) => setState(() => selectedScale = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _buildTextField(phoneController, "WhatsApp Number", isNumber: true),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isUploading ? null : uploadListing,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text("ADD TO GARAGE"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: Colors.white.withOpacity(0.05),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
  );

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) => TextField(
    controller: controller, keyboardType: isNumber ? TextInputType.number : TextInputType.text,
    style: const TextStyle(color: Colors.white), decoration: _inputDecoration(label),
  );
}