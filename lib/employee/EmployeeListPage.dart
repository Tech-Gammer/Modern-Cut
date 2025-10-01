// In a new file, e.g., employee_management/employee_list_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

import 'AddEmployeePage.dart';
import 'employeemodel.dart'; // For date formatting
   // Adjust path

const Color listPagePrimaryColor = Color(0xFF6C63FF); // Use dashboard primary
const Color listPageAccentColor = Color(0xFF4FC3F7);
const Color listPageTextColor = Color(0xFF2D3748);
const Color listPageSubtleTextColor = Color(0xFF757575);

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  final DatabaseReference _employeesRef = FirebaseDatabase.instance.ref().child('employees');
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
    _searchController.addListener(_filterEmployees);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterEmployees);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final snapshot = await _employeesRef.orderByChild('createdAt').get(); // Order by creation time
      if (!mounted) return;

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final List<Employee> loadedEmployees = [];
        data.forEach((key, value) {
          loadedEmployees.add(Employee.fromJson(key, value as Map<dynamic, dynamic>));
        });
        // Sort by createdAt descending (newest first)
        loadedEmployees.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        setState(() {
          _employees = loadedEmployees;
          _filteredEmployees = List.from(_employees); // Initialize filtered list
          _isLoading = false;
        });
      } else {
        setState(() {
          _employees = [];
          _filteredEmployees = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Error fetching employees: $e";
        _isLoading = false;
      });
      _showError(_errorMessage!);
    }
  }

  void _filterEmployees() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEmployees = List.from(_employees);
      } else {
        _filteredEmployees = _employees.where((employee) {
          return employee.name.toLowerCase().contains(query) ||
              employee.phoneNumber.contains(query) || // Search by phone too
              employee.fatherName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  void _navigateToAddEmployeePage({Employee? employee}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEmployeePage(employeeToEdit: employee)),
    );
    if (result == true && mounted) {
      _fetchEmployees(); // Refresh list if an employee was added/updated
    }
  }

  Future<void> _deleteEmployee(String employeeId, String employeeName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Employee?'),
          content: Text('Are you sure you want to delete "$employeeName"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: listPageSubtleTextColor)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _employeesRef.child(employeeId).remove();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee deleted successfully'), backgroundColor: Colors.green),
        );
        _fetchEmployees(); // Refresh the list
      } catch (e) {
        if (!mounted) return;
        _showError("Failed to delete employee: $e");
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Employee Management', style: TextStyle(color: Colors.white)),
        backgroundColor: listPagePrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _fetchEmployees,
            tooltip: 'Refresh Employees',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, father...',
                prefixIcon: Icon(Icons.search, color: listPagePrimaryColor.withOpacity(0.8), size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: const BorderSide(color: listPagePrimaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _buildEmployeeList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEmployeePage(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('ADD EMPLOYEE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: listPageAccentColor,
        tooltip: 'Add New Employee',
      ),
    );
  }
  // Method to show commission details
  void _showCommissionDetails(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${employee.name}'s Commission", style: TextStyle(color: listPagePrimaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommissionRow("Total Commission", "Rs. ${employee.totalCommission.toStringAsFixed(2)}", listPagePrimaryColor),
            _buildCommissionRow("Pending Commission", "Rs. ${employee.pendingCommission.toStringAsFixed(2)}", Colors.orange),
            _buildCommissionRow("Paid Commission", "Rs. ${employee.paidCommission.toStringAsFixed(2)}", Colors.green),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }


  Widget _buildEmployeeList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(listPagePrimaryColor)));
    }
    if (_errorMessage != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
            const SizedBox(height: 10),
            Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _fetchEmployees, child: const Text("Retry"))
          ],
        ),
      ));
    }
    if (_filteredEmployees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 70, color: listPageSubtleTextColor.withOpacity(0.6)),
            const SizedBox(height: 20),
            Text(
              _searchController.text.isEmpty ? 'No Employees Found' : 'No employees match your search',
              style: const TextStyle(fontSize: 19, color: listPageSubtleTextColor, fontWeight: FontWeight.w500),
            ),
            if (_searchController.text.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Tap the "+" button to add your first employee.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: listPageSubtleTextColor.withOpacity(0.8)),
                ),
              ),
          ],
        ),
      );
    }


    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 80.0), // Padding for FAB
      itemCount: _filteredEmployees.length,
      itemBuilder: (context, index) {
        final employee = _filteredEmployees[index];
        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            leading: CircleAvatar(
              backgroundColor: listPagePrimaryColor.withOpacity(0.15),
              child: Text(
                employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                style: const TextStyle(color: listPagePrimaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(employee.name, style: const TextStyle(fontWeight: FontWeight.w600, color: listPageTextColor, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text("Father: ${employee.fatherName.isNotEmpty ? employee.fatherName : 'N/A'}", style: const TextStyle(color: listPageSubtleTextColor, fontSize: 13)),
                Text("Phone: ${employee.phoneNumber}", style: const TextStyle(color: listPageSubtleTextColor, fontSize: 13)),
                Text("Address: ${employee.address.isNotEmpty ? employee.address : 'N/A'}", style: const TextStyle(color: listPageSubtleTextColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis,),
                const SizedBox(height: 3),
                // Commission information
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: listPagePrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attach_money, size: 12, color: listPagePrimaryColor),
                      const SizedBox(width: 4),
                      Text(
                        "Commission: Rs. ${employee.totalCommission.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 11, color: listPagePrimaryColor, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Pending: Rs. ${employee.pendingCommission.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Text("Added: ${DateFormat('dd MMM, yyyy').format(employee.createdAt)}", style: TextStyle(color: listPageSubtleTextColor.withOpacity(0.7), fontSize: 11)),

              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: listPageSubtleTextColor),
              onSelected: (value) {
                if (value == 'edit') {
                  _navigateToAddEmployeePage(employee: employee);
                } else if (value == 'delete') {
                  _deleteEmployee(employee.id!, employee.name);
                } else if (value == 'commission') {
                  _showCommissionDetails(employee);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(leading: Icon(Icons.edit_outlined, size: 20), title: Text('Edit', style: TextStyle(fontSize: 14))),
                ),
                const PopupMenuItem<String>(
                  value: 'commission',
                  child: ListTile(leading: Icon(Icons.attach_money, size: 20), title: Text('Commission Details', style: TextStyle(fontSize: 14))),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), title: Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 14))),
                ),
              ],
            ),
            onTap: () {
              // Optional: Navigate to a detailed employee view page if you create one
              _navigateToAddEmployeePage(employee: employee); // Or just open edit
            },
          ),
        );
      },
    );
  }
}
