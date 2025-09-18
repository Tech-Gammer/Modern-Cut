import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';

class ItemRegisterPage extends StatefulWidget {
  final Map<String, dynamic>? item;

  const ItemRegisterPage({super.key, this.item});

  @override
  _ItemRegisterPageState createState() => _ItemRegisterPageState();
}

class _ItemRegisterPageState extends State<ItemRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _qtyOnHandController = TextEditingController();

  String? _selectedVendor;
  List<Map<String, dynamic>> _vendors = [];
  bool _isLoadingVendors = true;
  bool _isSaving = false; // For loading indicator on save

  File? _imageFile;
  Uint8List? _webImage;

  final picker = ImagePicker();

  // Define your color scheme
  static const Color primaryColor = Color(0xFF6C63FF); // Example primary color
  static const Color accentColor = Color(0xFF4FC3F7); // Example accent color
  static const Color cardBackgroundColor = Colors.white;
  static const Color inputBorderColor = Colors.grey;


  @override
  void initState() {
    super.initState();
    _fetchVendors();

    if (widget.item != null) {
      final item = widget.item!;
      _itemNameController.text = item["itemName"] ?? "";
      _descriptionController.text = item["description"] ?? "";
      _costPriceController.text = (item["costPrice"] ?? 0.0).toString();
      _salePriceController.text = (item["salePrice"] ?? 0.0).toString();
      _qtyOnHandController.text = (item["qtyOnHand"] ?? 0).toString();
      _selectedVendor = item["vendor"];
      if (item["image"] != null && item["image"].isNotEmpty) {
        try {
          _webImage = base64Decode(item["image"]);
        } catch (e) {
          print("Error decoding image: $e");
          // Optionally show a placeholder or error message for the image
        }
      }
    }
  }

  Future<void> _fetchVendors() async {
    setState(() {
      _isLoadingVendors = true;
    });
    try {
      final DatabaseReference ref = FirebaseDatabase.instance.ref("vendors");
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        if (mounted) {
          setState(() {
            _vendors = data.entries.map((entry) {
              final vendor = Map<String, dynamic>.from(entry.value as Map);
              return {
                "id": entry.key,
                "name": vendor["name"] ?? "Unknown Vendor",
              };
            }).toList();
            // If editing, ensure the prefilled vendor is valid
            if (widget.item != null && _selectedVendor != null) {
              if (!_vendors.any((v) => v["name"] == _selectedVendor)) {
                _selectedVendor = null; // Reset if vendor no longer exists
              }
            }
            _isLoadingVendors = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingVendors = false);
      }
    } catch (e) {
      print("Error fetching vendors: $e");
      if (mounted) {
        setState(() => _isLoadingVendors = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching vendors: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Optionally compress image
      maxWidth: 1000,   // Optionally resize
    );

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
          _imageFile = null;
        });
      } else {
        setState(() {
          _imageFile = File(pickedFile.path);
          _webImage = null;
        });
      }
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    String? base64Image;
    try {
      if (_imageFile != null) {
        List<int> imageBytes = await _imageFile!.readAsBytes();
        base64Image = base64Encode(imageBytes);
      } else if (_webImage != null) {
        base64Image = base64Encode(_webImage!);
      }

      DatabaseReference ref;
      String itemId;

      if (widget.item != null && widget.item!["id"] != null) {
        itemId = widget.item!["id"];
        ref = FirebaseDatabase.instance.ref("items/$itemId");
      } else {
        ref = FirebaseDatabase.instance.ref("items").push();
        itemId = ref.key!; // Get the new key
      }

      await ref.set({
        "id": itemId, // Store the id within the item data
        "itemName": _itemNameController.text.trim(),
        "description": _descriptionController.text.trim(),
        "costPrice": double.tryParse(_costPriceController.text.trim()) ?? 0.0,
        "salePrice": double.tryParse(_salePriceController.text.trim()) ?? 0.0,
        "qtyOnHand": int.tryParse(_qtyOnHandController.text.trim()) ?? 0,
        "vendor": _selectedVendor ?? "",
        "image": base64Image ?? "",
        "updatedAt": ServerValue.timestamp, // Track updates
        if (widget.item == null) "createdAt": ServerValue.timestamp, // Track creation
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item != null ? "Item updated successfully!" : "Item saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Pop and indicate success
      }
    } catch (e) {
      print("Error saving item: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving item: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item != null ? "Edit Item" : "Register New Item",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isSaving
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
            SizedBox(height: 16),
            Text("Saving item, please wait...", style: TextStyle(fontSize: 16, color: primaryColor)),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle("Item Details"),
              _buildTextField(
                controller: _itemNameController,
                labelText: "Item Name",
                hintText: "Enter item name (e.g., T-Shirt)",
                icon: Icons.label_important_outline,
                validator: (value) =>
                value!.isEmpty ? "Please enter item name" : null,
              ),
              _buildTextField(
                controller: _descriptionController,
                labelText: "Description",
                hintText: "Provide a brief description",
                icon: Icons.description_outlined,
                maxLines: 3,
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _costPriceController,
                      labelText: "Cost Price (Rs)",
                      hintText: "0.00",
                      icon: Icons.monetization_on_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter cost price';
                        if (double.tryParse(value) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _salePriceController,
                      labelText: "Sale Price (Rs)",
                      hintText: "0.00",
                      icon: Icons.price_check_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter sale price';
                        if (double.tryParse(value) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              _buildTextField(
                controller: _qtyOnHandController,
                labelText: "Quantity On Hand",
                hintText: "0",
                icon: Icons.inventory_2_outlined,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter quantity';
                  if (int.tryParse(value) == null) return 'Invalid number';
                  return null;
                },
              ),

              const SizedBox(height: 24),
              _buildSectionTitle("Vendor Information"),
              _buildVendorDropdown(),

              const SizedBox(height: 24),
              _buildSectionTitle("Item Image"),
              _buildImagePickerSection(),

              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: Icon(_isSaving ? Icons.hourglass_empty_outlined : (widget.item != null ? Icons.save_alt_outlined : Icons.add_circle_outline), color: Colors.white),
                label: Text(
                  _isSaving ? "SAVING..." : (widget.item != null ? "UPDATE ITEM" : "SAVE ITEM"),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                onPressed: _isSaving ? null : _saveItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryColor.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: inputBorderColor.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: inputBorderColor.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          filled: true,
          fillColor: cardBackgroundColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
        ),
        validator: validator,
        maxLines: maxLines,
        style: TextStyle(color: Colors.black87),
      ),
    );
  }

  Widget _buildVendorDropdown() {
    if (_isLoadingVendors) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedVendor,
        decoration: InputDecoration(
          labelText: "Select Vendor",
          prefixIcon: Icon(Icons.storefront_outlined, color: primaryColor, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: inputBorderColor.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: inputBorderColor.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          filled: true,
          fillColor: cardBackgroundColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
        ),
        items: _vendors.isEmpty
            ? [
          DropdownMenuItem(
            value: null,
            child: Text("No vendors available", style: TextStyle(color: Colors.grey)),
            enabled: false,
          )
        ]
            : _vendors.map((vendor) {
          return DropdownMenuItem<String>(
            value: vendor["name"],
            child: Text(vendor["name"] ?? "Unnamed Vendor"),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedVendor = value;
          });
        },
        validator: (value) => value == null && _vendors.isNotEmpty ? "Please select a vendor" : null,
        hint: _vendors.isEmpty ? Text("Add vendors first") : Text("Choose a vendor"),
        isExpanded: true,
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: inputBorderColor.withOpacity(0.5)),
          ),
          child: (_imageFile == null && _webImage == null)
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_outlined, size: 50, color: Colors.grey[600]),
                const SizedBox(height: 8),
                Text("No image selected", style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          )
              : ClipRRect(
            borderRadius: BorderRadius.circular(11), // slightly less than container
            child: _imageFile != null
                ? Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                : Image.memory(_webImage!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: Icon(Icons.photo_library_outlined, color: primaryColor),
          label: Text("Pick Image from Gallery", style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
          onPressed: _pickImage,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: primaryColor.withOpacity(0.5)),
            ),
          ),
        ),
      ],
    );
  }
}
