import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter

class VendorRegisterPage extends StatefulWidget {
  final Map<String, dynamic>? vendor; // To pass vendor data for editing

  const VendorRegisterPage({super.key, this.vendor});

  @override
  _VendorRegisterPageState createState() => _VendorRegisterPageState();
}

class _VendorRegisterPageState extends State<VendorRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); // Added Email
  final TextEditingController _addressController = TextEditingController();

  bool _isSaving = false;

  // Define your color scheme (consistent with other pages)
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color cardBackgroundColor = Colors.white;
  static const Color inputBorderColor = Colors.grey;

  @override
  void initState() {
    super.initState();

    if (widget.vendor != null) {
      // Pre-fill form fields if editing an existing vendor
      _nameController.text = widget.vendor!["name"] ?? "";
      _contactController.text = widget.vendor!["contact"] ?? "";
      _emailController.text = widget.vendor!["email"] ?? "";
      _addressController.text = widget.vendor!["address"] ?? "";
    }
  }

  Future<void> _saveVendor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      DatabaseReference ref;
      String vendorId;

      if (widget.vendor != null && widget.vendor!["id"] != null) {
        // Updating existing vendor
        vendorId = widget.vendor!["id"];
        ref = FirebaseDatabase.instance.ref("vendors/$vendorId");
      } else {
        // Creating new vendor
        ref = FirebaseDatabase.instance.ref("vendors").push();
        vendorId = ref.key!; // Get the new key
      }

      await ref.set({
        "id": vendorId, // Store/update the ID within the vendor's data
        "name": _nameController.text.trim(),
        "contact": _contactController.text.trim(),
        "email": _emailController.text.trim(),
        "address": _addressController.text.trim(),
        "updatedAt": ServerValue.timestamp,
        if (widget.vendor == null) "createdAt": ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.vendor != null
                ? "Vendor updated successfully!"
                : "Vendor saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Pop and indicate success
      }
    } catch (e) {
      print("Error saving vendor: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving vendor: ${e.toString()}'),
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
          widget.vendor != null ? "Edit Vendor" : "Register New Vendor",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isSaving
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
            SizedBox(height: 16),
            Text("Saving vendor, please wait...",
                style: TextStyle(fontSize: 16, color: primaryColor)),
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
              _buildSectionTitle("Vendor Information"),
              _buildTextField(
                controller: _nameController,
                labelText: "Vendor Name *",
                hintText: "Enter full name or company name",
                icon: Icons.storefront_outlined,
                validator: (value) =>
                value!.isEmpty ? "Vendor name is required" : null,
              ),
              _buildTextField(
                controller: _contactController,
                labelText: "Contact Number *",
                hintText: "Enter mobile or landline number",
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Contact number is required";
                  }
                  if (value.length < 10) { // Basic length check
                    return "Enter a valid contact number";
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _emailController,
                labelText: "Email Address",
                hintText: "Enter vendor's email (optional)",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty && !RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _addressController,
                labelText: "Full Address",
                hintText: "Enter complete address",
                icon: Icons.location_on_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: Icon(
                    _isSaving
                        ? Icons.hourglass_empty_outlined
                        : (widget.vendor != null
                        ? Icons.save_alt_outlined
                        : Icons.add_business_outlined),
                    color: Colors.white),
                label: Text(
                  _isSaving
                      ? "SAVING..."
                      : (widget.vendor != null
                      ? "UPDATE VENDOR"
                      : "SAVE VENDOR"),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                onPressed: _isSaving ? null : _saveVendor,
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
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
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
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
        ),
        validator: validator,
        maxLines: maxLines,
        style: TextStyle(color: Colors.black87),
      ),
    );
  }
}
