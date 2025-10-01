import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

// Assuming InvoicePage is correctly imported
// import 'invoicePage.dart';
// If it's in InvoiceManagement/ as in your HomePage example:
import 'package:saloon/InvoiceManagement/invoicePage.dart';


class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({super.key});

  @override
  _InvoiceListPageState createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  List<Map<String, dynamic>> _allInvoices = [];
  List<Map<String, dynamic>> _filteredInvoices = [];
  bool _isLoading = true;
  String _searchTerm = "";

  // Define your color scheme (can be moved to a theme file later)
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color accentColor = Color(0xFF4FC3F7);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF2D3748);
  static const Color subtleTextColor = Color(0xFF718096);
  static const Color successColor = Colors.green;
  static const Color errorColor = Colors.red;
  static const Color warningColor = Colors.orange;


  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final ref = FirebaseDatabase.instance.ref("invoices");
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        if (!mounted) return;

        _allInvoices = data.entries.map((entry) {
          final invoice = Map<String, dynamic>.from(entry.value as Map);
          final itemsList = (invoice["items"] as List<dynamic>?)?.map((item) {
            return Map<String, dynamic>.from(item as Map);
          }).toList() ?? [];

          return {
            "id": entry.key ?? 'N/A',
            "invoiceNumber": invoice["invoiceNumber"] ?? "N/A",
            "customerName": invoice["customerName"] ?? "N/A",
            "subtotal": (invoice["subtotal"] ?? 0.0).toDouble(),
            "discountAmount": (invoice["discountAmount"] ?? 0.0).toDouble(),
            "discountIsPercentage": invoice["discountIsPercentage"] ?? false,
            "discountValue": (invoice["discountValue"] ?? invoice["discountAmount"] ?? 0.0).toDouble(),
            "commissionAmount": (invoice["commissionAmount"] ?? 0.0).toDouble(),
            "commissionIsPercentage": invoice["commissionIsPercentage"] ?? false,
            "commissionValue": (invoice["commissionValue"] ?? invoice["commissionAmount"] ?? 0.0).toDouble(),
            "employeeId": invoice["employeeId"],
            "employeeName": invoice["employeeName"],
            "employeePhone": invoice["employeePhone"],
            "employeeAddress": invoice["employeeAddress"],
            "total": (invoice["total"] ?? 0.0).toDouble(),
            "createdAt": invoice["createdAt"] ?? DateTime.now().toIso8601String(),
            "updatedAt": invoice["updatedAt"],
            "items": itemsList,
          };
        }).toList();

        // Sort latest first
        _allInvoices.sort((a, b) {
          try {
            return DateTime.parse(b["createdAt"]).compareTo(DateTime.parse(a["createdAt"]));
          } catch (e) {
            return 0;
          }
        });
        _filterInvoices();
      } else {
        _allInvoices = [];
        _filteredInvoices = [];
      }
    } catch (e) {
      print("Error fetching invoices: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching invoices: ${e.toString()}"), backgroundColor: errorColor),
        );
      }
      _allInvoices = [];
      _filteredInvoices = [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterInvoices() {
    if (_searchTerm.isEmpty) {
      _filteredInvoices = List.from(_allInvoices);
    } else {
      final searchLower = _searchTerm.toLowerCase();
      _filteredInvoices = _allInvoices.where((invoice) {
        final invoiceNumberLower = (invoice["invoiceNumber"]?.toString() ?? "").toLowerCase();
        final customerNameLower = (invoice["customerName"]?.toString() ?? "").toLowerCase();
        return invoiceNumberLower.contains(searchLower) ||
            customerNameLower.contains(searchLower);
      }).toList();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _navigateToInvoicePage({Map<String, dynamic>? invoiceToEdit}) async {
    // Prepare the complete invoice data with all necessary fields
    Map<String, dynamic>? preparedInvoice;

    if (invoiceToEdit != null) {
      preparedInvoice = {
        "id": invoiceToEdit["id"],
        "invoiceNumber": invoiceToEdit["invoiceNumber"],
        "customerName": invoiceToEdit["customerName"],
        "items": invoiceToEdit["items"],
        "subtotal": invoiceToEdit["subtotal"],
        "discountAmount": invoiceToEdit["discountAmount"] ?? 0.0,
        "discountIsPercentage": invoiceToEdit["discountIsPercentage"] ?? false,
        "discountValue": invoiceToEdit["discountValue"] ?? invoiceToEdit["discountAmount"] ?? 0.0,
        "commissionAmount": invoiceToEdit["commissionAmount"] ?? 0.0,
        "commissionIsPercentage": invoiceToEdit["commissionIsPercentage"] ?? false,
        "commissionValue": invoiceToEdit["commissionValue"] ?? invoiceToEdit["commissionAmount"] ?? 0.0,
        "employeeId": invoiceToEdit["employeeId"],
        "employeeName": invoiceToEdit["employeeName"],
        "employeePhone": invoiceToEdit["employeePhone"],
        "employeeAddress": invoiceToEdit["employeeAddress"],
        "total": invoiceToEdit["total"],
        "createdAt": invoiceToEdit["createdAt"],
        "updatedAt": invoiceToEdit["updatedAt"],
      };

      print('=== NAVIGATING TO EDIT INVOICE ===');
      print('Employee ID: ${preparedInvoice["employeeId"]}');
      print('Employee Name: ${preparedInvoice["employeeName"]}');
      print('Discount Amount: ${preparedInvoice["discountAmount"]}');
      print('Discount Is Percentage: ${preparedInvoice["discountIsPercentage"]}');
      print('Commission Amount: ${preparedInvoice["commissionAmount"]}');
      print('Commission Is Percentage: ${preparedInvoice["commissionIsPercentage"]}');
      print('==================================');
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoicePage(invoice: preparedInvoice),
      ),
    );

    if (result == true && mounted) {
      _fetchInvoices();
    }
  }

  Future<void> _deleteInvoice(String invoiceId) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          content: const Text('Are you sure you want to delete this invoice? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: subtleTextColor)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: errorColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        final ref = FirebaseDatabase.instance.ref("invoices/$invoiceId");
        await ref.remove();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invoice deleted successfully"), backgroundColor: successColor),
          );
          _fetchInvoices(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting invoice: ${e.toString()}"), backgroundColor: errorColor),
          );
        }
      }
    }
  }


  void _showInvoiceDetailsDialog(Map<String, dynamic> invoice) {
    DateTime createdAtDate;
    try {
      createdAtDate = DateTime.parse(invoice["createdAt"]);
    } catch (e) {
      createdAtDate = DateTime.now();
    }

    final double subtotal = (invoice["subtotal"] ?? 0.0).toDouble();
    final double discountAmount = (invoice["discountAmount"] ?? 0.0).toDouble();
    final double commissionAmount = (invoice["commissionAmount"] ?? 0.0).toDouble();
    final double total = (invoice["total"] ?? 0.0).toDouble();
    final bool hasEmployee = invoice["employeeId"] != null && invoice["employeeId"].toString().isNotEmpty;

    final List<Widget> itemWidgets = (invoice["items"] as List<dynamic>).map((item) {
      final itemName = item["itemName"] ?? "N/A";
      final qty = (item["qty"] ?? 0).toInt();
      final salePrice = (item["salePrice"] ?? 0.0).toDouble();
      final itemTotal = qty * salePrice;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: Text(itemName, style: TextStyle(fontSize: 14)),
            ),
            Expanded(
              flex: 2,
              child: Text("Qty: $qty x Rs.${salePrice.toStringAsFixed(2)}", style: TextStyle(fontSize: 13, color: subtleTextColor)),
            ),
            Expanded(
              flex: 2,
              child: Text("Rs.${itemTotal.toStringAsFixed(2)}", textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Invoice Details", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18)),
              Text("#${invoice["invoiceNumber"]}", style: TextStyle(fontSize: 16, color: primaryColor, fontWeight: FontWeight.w600)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _buildDetailRow("Customer:", invoice["customerName"] ?? "N/A"),
                _buildDetailRow("Date:", DateFormat('dd MMM yyyy, hh:mm a').format(createdAtDate)),

                // Show employee info
                if (hasEmployee)
                  _buildDetailRow("Employee:", invoice["employeeName"] ?? "N/A"),

                const SizedBox(height: 12),
                const Text("Items:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                const SizedBox(height: 6),
                if (itemWidgets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text("No items in this invoice.", style: TextStyle(color: subtleTextColor)),
                  )
                else
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: itemWidgets,
                    ),
                  ),

                const Divider(height: 20),

                // Totals section
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Subtotal: Rs.${subtotal.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                      if (discountAmount > 0)
                        Text(
                          "Discount: -Rs.${discountAmount.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 14, color: errorColor),
                        ),
                      if (commissionAmount > 0 && hasEmployee)
                        Text(
                          "Commission: Rs.${commissionAmount.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 14, color: warningColor),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        "Grand Total: Rs.${total.toStringAsFixed(2)}",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: successColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Close", style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => Navigator.pop(context),
            )
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: textColor, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(color: subtleTextColor, fontSize: 14))),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoice Management", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    _searchTerm = value;
                    _filterInvoices();
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Search by Invoice # or Customer...',
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
        onPressed: () => _navigateToInvoicePage(),
        icon: const Icon(Icons.add_card_outlined, color: Colors.white),
        label: const Text("NEW INVOICE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            Text("Loading invoices...", style: TextStyle(fontSize: 16, color: primaryColor)),
          ],
        ),
      );
    }

    if (_allInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text("No Invoices Found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            Text(
              "Tap the 'NEW INVOICE' button to create your first one.",
              style: TextStyle(fontSize: 16, color: subtleTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_filteredInvoices.isEmpty && _searchTerm.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("No Invoices Found for '$_searchTerm'", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
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
      onRefresh: _fetchInvoices,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80), // Padding for FAB
        itemCount: _filteredInvoices.length,
        itemBuilder: (context, index) {
          final invoice = _filteredInvoices[index];
          return _buildInvoiceCard(invoice);
        },
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    DateTime createdAtDate;
    try {
      createdAtDate = DateTime.parse(invoice["createdAt"]);
    } catch (e) {
      createdAtDate = DateTime.now();
    }

    final double discountAmount = (invoice["discountAmount"] ?? 0.0).toDouble();
    final double commissionAmount = (invoice["commissionAmount"] ?? 0.0).toDouble();
    final bool hasEmployee = invoice["employeeId"] != null && invoice["employeeId"].toString().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showInvoiceDetailsDialog(invoice),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Invoice #${invoice["invoiceNumber"] ?? "N/A"}",
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  Text(
                    "Rs. ${(invoice["total"] ?? 0.0).toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: successColor),
                  ),
                ],
              ),

              // Show employee info if available
              if (hasEmployee)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 14, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        "Employee: ${invoice["employeeName"] ?? "N/A"}",
                        style: TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

              // Show discount info if available
              if (discountAmount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer, size: 12, color: errorColor),
                      const SizedBox(width: 4),
                      Text(
                        "Discount: Rs.${discountAmount.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 11, color: errorColor),
                      ),
                    ],
                  ),
                ),

              // Show commission info if available
              if (commissionAmount > 0 && hasEmployee)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    children: [
                      Icon(Icons.percent, size: 12, color: warningColor),
                      const SizedBox(width: 4),
                      Text(
                        "Commission: Rs.${commissionAmount.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 11, color: warningColor),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 16, thickness: 0.5),

              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: subtleTextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      invoice["customerName"] ?? "N/A",
                      style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: subtleTextColor),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(createdAtDate),
                    style: TextStyle(fontSize: 13, color: subtleTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _actionButton(
                    icon: Icons.edit_outlined,
                    label: "Edit",
                    color: warningColor,
                    onPressed: () => _navigateToInvoicePage(invoiceToEdit: invoice),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    icon: Icons.delete_outline,
                    label: "Delete",
                    color: errorColor,
                    onPressed: () => _deleteInvoice(invoice["id"]),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    icon: Icons.visibility_outlined,
                    label: "View",
                    color: accentColor.withOpacity(0.8),
                    onPressed: () => _showInvoiceDetailsDialog(invoice),
                    isTextButton: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isTextButton = false,
  }) {
    if (isTextButton) {
      return TextButton.icon(
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 1,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

