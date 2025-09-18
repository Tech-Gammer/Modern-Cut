import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:typed_data';
import 'package:saloon/ItemManagement/registerItem.dart';


class ItemListPage extends StatefulWidget {
  // Add const constructor if your ItemRegisterPage has it
  const ItemListPage({super.key});

  @override
  _ItemListPageState createState() => _ItemListPageState();
}

class _ItemListPageState extends State<ItemListPage> {
  final DatabaseReference _itemsRef = FirebaseDatabase.instance.ref("items");
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true; // Renamed for clarity
  String _searchTerm = ""; // For search functionality
  List<Map<String, dynamic>> _filteredItems = [];

  // Define your color scheme (can be moved to a theme file later)
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color accentColor = Color(0xFF4FC3F7);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF2D3748);
  static const Color subtleTextColor = Color(0xFF718096);


  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _itemsRef.orderByChild("itemName").get(); // Example: order by name

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        if (!mounted) return;
        setState(() {
          _items = data.entries.map((entry) {
            final item = Map<String, dynamic>.from(entry.value as Map);
            // Ensure all fields have defaults to prevent null issues
            return {
              "id": entry.key ?? 'N/A', // Good to have ID directly from key
              "itemName": item["itemName"] ?? "Unnamed Item",
              "description": item["description"] ?? "",
              "costPrice": (item["costPrice"] ?? 0.0).toDouble(),
              "salePrice": (item["salePrice"] ?? 0.0).toDouble(),
              "qtyOnHand": (item["qtyOnHand"] ?? 0).toInt(),
              "vendor": item["vendor"] ?? "N/A",
              "image": item["image"] ?? "",
            };
          }).toList();
          _filterItems(); // Apply initial filter
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _items = [];
          _filteredItems = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching items: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _items = [];
        _filteredItems = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching items: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  void _filterItems() {
    if (_searchTerm.isEmpty) {
      _filteredItems = List.from(_items);
    } else {
      _filteredItems = _items.where((item) {
        final itemNameLower = item["itemName"].toString().toLowerCase();
        final vendorLower = item["vendor"].toString().toLowerCase();
        final searchLower = _searchTerm.toLowerCase();
        return itemNameLower.contains(searchLower) || vendorLower.contains(searchLower);
      }).toList();
    }
    // Sort again if needed, or maintain original sort from _fetchItems
    // _filteredItems.sort((a, b) => a["itemName"].compareTo(b["itemName"]));
    setState(() {});
  }


  Future<void> _deleteItem(String itemId) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this item? This action cannot be undone.'),
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
        await _itemsRef.child(itemId).remove();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Item deleted successfully"), backgroundColor: Colors.green),
          );
          _fetchItems(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting item: ${e.toString()}"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _navigateToRegisterPage({Map<String, dynamic>? itemToEdit}) async {
    // The `true` indicates a successful save/update from ItemRegisterPage
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemRegisterPage(item: itemToEdit),
      ),
    );
    if (result == true && mounted) {
      _fetchItems(); // Refresh list if an item was saved/updated
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Items Inventory", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        // Simple Search Bar (can be expanded into a dedicated widget)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchTerm = value;
                  _filterItems();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search items by name or vendor...',
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
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToRegisterPage(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("ADD ITEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: accentColor,
        elevation: 4.0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
            SizedBox(height: 16),
            Text("Loading items...", style: TextStyle(fontSize: 16, color: primaryColor)),
          ],
        ),
      );
    }

    if (_items.isEmpty) { // Check original list for this message
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text("No Items Found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            Text(
              "Tap the 'ADD ITEM' button to get started.",
              style: TextStyle(fontSize: 16, color: subtleTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_filteredItems.isEmpty && _searchTerm.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("No Items Found for '$_searchTerm'", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
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


    return RefreshIndicator(
      onRefresh: _fetchItems,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80), // Padding for FAB
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          Uint8List? imageBytes;

          if (item["image"] != null && item["image"].isNotEmpty) {
            try {
              imageBytes = base64Decode(item["image"]);
            } catch (e) {
              imageBytes = null;
              print("Error decoding image for ${item['itemName']}: $e");
            }
          }
          return _buildItemCard(item, imageBytes);
        },
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, Uint8List? imageBytes) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Ensures content respects border radius
      child: InkWell(
        onTap: () => _navigateToRegisterPage(itemToEdit: item), // Allow tap on card to edit
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: imageBytes != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    imageBytes,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey[400]);
                    },
                  ),
                )
                    : Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey[400]),
              ),
              const SizedBox(width: 12),
              // Details Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["itemName"] ?? "No Name",
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Vendor: ${item["vendor"] ?? "N/A"}",
                      style: TextStyle(fontSize: 13, color: subtleTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Price: Rs. ${item["salePrice"]?.toStringAsFixed(2) ?? '0.00'}",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor),
                        ),
                        Text(
                          "Qty: ${item["qtyOnHand"] ?? 0}",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions Section
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 22),
                    onPressed: () => _navigateToRegisterPage(itemToEdit: item),
                    tooltip: "Edit Item",
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                    onPressed: () => _deleteItem(item["id"]),
                    tooltip: "Delete Item",
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

