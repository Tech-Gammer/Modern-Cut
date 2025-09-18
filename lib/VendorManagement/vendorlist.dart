import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
// Assuming VendorRegisterPage is correctly imported
// Ensure the path is correct for your project structure.
// If VendorRegisterPage is in the same directory:
// import 'vendor_register_page.dart';
// If it's in VendorManagement/ as per your previous code:
import 'package:saloon/VendorManagement/registervendor.dart';


class VendorListPage extends StatefulWidget {
  // Add const constructor if your VendorRegisterPage has it
  const VendorListPage({super.key});

  @override
  _VendorListPageState createState() => _VendorListPageState();
}

class _VendorListPageState extends State<VendorListPage> {
  final DatabaseReference _vendorsRef = FirebaseDatabase.instance.ref().child("vendors");
  String _searchTerm = ""; // For search functionality
  // _allVendors will now be populated directly within the StreamBuilder's builder
  // We don't need to store it as a separate state variable that _filterVendors modifies directly.

  // Define your color scheme (can be moved to a theme file later)
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color accentColor = Color(0xFF4FC3F7);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF2D3748);
  static const Color subtleTextColor = Color(0xFF718096);

  Stream<DatabaseEvent>? _vendorsStream;

  @override
  void initState() {
    super.initState();
    _vendorsStream = _vendorsRef.orderByChild("name").onValue; // Example: order by name
  }

  // MODIFIED: This function now RETURNS the filtered list
  List<Map<String, dynamic>> _getFilteredVendors(List<Map<String, dynamic>> allVendors) {
    if (_searchTerm.isEmpty) {
      return List.from(allVendors); // Return a copy
    } else {
      return allVendors.where((vendor) {
        final nameLower = (vendor["name"] ?? "").toLowerCase();
        final contactLower = (vendor["contact"] ?? "").toLowerCase();
        final emailLower = (vendor["email"] ?? "").toLowerCase();
        final searchLower = _searchTerm.toLowerCase();
        return nameLower.contains(searchLower) ||
            contactLower.contains(searchLower) ||
            emailLower.contains(searchLower);
      }).toList();
    }
    // No setState() here
  }

  Future<void> _deleteVendor(String vendorId) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this vendor? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await _vendorsRef.child(vendorId).remove();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vendor deleted successfully"), backgroundColor: Colors.green),
          );
          // StreamBuilder will automatically update the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting vendor: ${e.toString()}"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _navigateToRegisterPage({Map<String, dynamic>? vendorToEdit}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VendorRegisterPage(vendor: vendorToEdit),
      ),
    );
    // StreamBuilder should reflect changes automatically.
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vendors Directory", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              onChanged: (value) {
                // This setState is correct as it's in an event handler,
                // not directly in a build method.
                if (mounted) {
                  setState(() {
                    _searchTerm = value;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Search vendors by name, contact, email...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: StreamBuilder(
        stream: _vendorsStream,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
                  SizedBox(height: 16),
                  Text("Loading vendors...", style: TextStyle(fontSize: 16, color: primaryColor)),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text("Error loading vendors: ${snapshot.error}", textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700])),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                    onPressed: () {
                      if(mounted) {
                        setState(() {
                          _vendorsStream = _vendorsRef.orderByChild("name").onValue;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                  )
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("No Vendors Found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 8),
                  Text(
                    "Tap the 'ADD VENDOR' button to get started.",
                    style: TextStyle(fontSize: 16, color: subtleTextColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Process data from snapshot
          final rawData = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map<dynamic,dynamic>);
          final List<Map<String, dynamic>> allVendors = rawData.entries.map((entry) {
            final vendorData = Map<String, dynamic>.from(entry.value as Map<dynamic,dynamic>);
            return {
              'id': entry.key,
              'name': vendorData['name'] ?? 'N/A',
              'contact': vendorData['contact'] ?? 'N/A',
              'email': vendorData['email'] ?? 'N/A',
              'address': vendorData['address'] ?? 'N/A',
              'gstin': vendorData['gstin'] ?? 'N/A',
            };
          }).toList();

          // Get the filtered list to display
          final List<Map<String, dynamic>> displayVendors = _getFilteredVendors(allVendors);

          if (displayVendors.isEmpty && _searchTerm.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("No Vendors Found for '$_searchTerm'", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 8),
                  Text(
                    "Try a different search term or clear the search.",
                    style: TextStyle(fontSize: 16, color: subtleTextColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          // If allVendors is not empty but displayVendors is (and search is empty),
          // this means something is wrong or the "No Vendors Found" (initial) case should have caught it.
          // However, the initial "No Vendors Found" handles the empty `allVendors` case.


          return RefreshIndicator(
            onRefresh: () async {
              if (mounted) {
                setState(() {
                  _vendorsStream = _vendorsRef.orderByChild("name").onValue;
                });
              }
              await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
            },
            color: primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80), // Padding for FAB
              itemCount: displayVendors.length, // Use the filtered list
              itemBuilder: (context, index) {
                final vendor = displayVendors[index]; // Use the filtered list
                return _buildVendorCard(vendor);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToRegisterPage(),
        icon: const Icon(Icons.add_business_outlined, color: Colors.white),
        label: const Text("ADD VENDOR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: accentColor,
        elevation: 4.0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToRegisterPage(vendorToEdit: vendor),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.15),
                ),
                child: const Icon(Icons.storefront_outlined, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor["name"] ?? "No Name",
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (vendor["contact"] != null && vendor["contact"] != 'N/A' && vendor["contact"].isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: subtleTextColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              vendor["contact"],
                              style: const TextStyle(fontSize: 13, color: subtleTextColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (vendor["email"] != null && vendor["email"] != 'N/A' && vendor["email"].isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 14, color: subtleTextColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              vendor["email"],
                              style: const TextStyle(fontSize: 13, color: subtleTextColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (vendor["address"] != null && vendor["address"] != 'N/A' && vendor["address"].isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: subtleTextColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              vendor["address"],
                              style: const TextStyle(fontSize: 13, color: subtleTextColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 22),
                    onPressed: () => _navigateToRegisterPage(vendorToEdit: vendor),
                    tooltip: "Edit Vendor",
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                    onPressed: () => _deleteVendor(vendor["id"]),
                    tooltip: "Delete Vendor",
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
