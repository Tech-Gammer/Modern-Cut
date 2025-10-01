// In a new file, e.g., employee_management/add_employee_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

import 'employeemodel.dart';

const Color formPrimaryColor = Color(0xFF6C63FF); // Use dashboard primary
const Color formAccentColor = Color(0xFF4FC3F7);
const Color formTextColor = Color(0xFF2D3748);

class AddEmployeePage extends StatefulWidget {
  final Employee? employeeToEdit; // Pass employee data if editing

  const AddEmployeePage({super.key, this.employeeToEdit});

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseReference _employeesRef = FirebaseDatabase.instance.ref().child('employees');

  late TextEditingController _nameController;
  late TextEditingController _fatherNameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _addressController;

  bool _isLoading = false;
  bool get _isEditing => widget.employeeToEdit != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employeeToEdit?.name);
    _fatherNameController = TextEditingController(text: widget.employeeToEdit?.fatherName);
    _phoneNumberController = TextEditingController(text: widget.employeeToEdit?.phoneNumber);
    _addressController = TextEditingController(text: widget.employeeToEdit?.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    final employee = Employee(
      id: _isEditing ? widget.employeeToEdit!.id : null, // Preserve ID if editing
      name: _nameController.text.trim(),
      fatherName: _fatherNameController.text.trim(),
      phoneNumber: _phoneNumberController.text.trim(),
      address: _addressController.text.trim(),
      createdAt: _isEditing ? widget.employeeToEdit!.createdAt : DateTime.now(),
    );

    try {
      if (_isEditing) {
        await _employeesRef.child(employee.id!).update(employee.toJson());
      } else {
        await _employeesRef.push().set(employee.toJson());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Employee ${_isEditing ? "updated" : "added"} successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // Pop with true to indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save employee: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Employee' : 'Add New Employee', style: const TextStyle(color: Colors.white)),
        backgroundColor: formPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _isEditing ? 'Update Employee Details' : 'Enter Employee Information',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: formPrimaryColor),
                ),
                const SizedBox(height: 24),
                _buildTextFormField(
                  controller: _nameController,
                  label: 'Full Name*',
                  icon: Icons.person_outline,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter name' : null,
                ),
                _buildTextFormField(
                  controller: _fatherNameController,
                  label: "Father's Name",
                  icon: Icons.supervisor_account_outlined,
                ),
                _buildTextFormField(
                  controller: _phoneNumberController,
                  label: 'Phone Number*',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15)],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Please enter phone number';
                    if (value.length < 7) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                _buildTextFormField(
                  controller: _addressController,
                  label: 'Address',
                  icon: Icons.location_on_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(formPrimaryColor)))
                    : ElevatedButton.icon(
                  icon: Icon(_isEditing ? Icons.save_outlined : Icons.person_add_alt_1_outlined, color: Colors.white),
                  label: Text(
                    _isEditing ? 'UPDATE EMPLOYEE' : 'ADD EMPLOYEE',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: _saveEmployee,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: formAccentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int? maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: formTextColor.withOpacity(0.8)),
          prefixIcon: Icon(icon, color: formPrimaryColor.withOpacity(0.9), size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: formPrimaryColor, width: 1.5)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
        ),
        validator: validator,
        maxLines: maxLines,
        style: const TextStyle(color: formTextColor),
      ),
    );
  }
}
