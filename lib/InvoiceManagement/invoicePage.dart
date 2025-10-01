import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class InvoicePage extends StatefulWidget {
  final Map<String, dynamic>? invoice; // For editing existing invoices

  const InvoicePage({super.key, this.invoice});

  @override
  _InvoicePageState createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _discountPercentageController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _commissionPercentageController = TextEditingController();

  String _invoiceNumber = "";
  List<Map<String, dynamic>> _availableItems = [];
  List<Map<String, dynamic>> _invoiceItems = [];
  List<Map<String, dynamic>> _availableEmployees = [];

  // Discount and Commission variables
  double _discountAmount = 0.0;
  bool _discountIsPercentage = false;
  double _commissionAmount = 0.0;
  bool _commissionIsPercentage = false;
  String? _selectedEmployeeId;
  Map<String, dynamic>? _selectedEmployee;

  bool _isLoadingItems = true;
  bool _isLoadingEmployees = true;
  bool _isSaving = false;

  // Define your color scheme
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color accentColor = Color(0xFF4FC3F7);
  static const Color cardBackgroundColor = Colors.white;
  static const Color inputBorderColor = Colors.grey;
  static const Color textColor = Color(0xFF2D3748);
  static const Color subtleTextColor = Color(0xFF718096);
  static const Color errorColor = Colors.redAccent;
  static const Color successColor = Colors.green;

  @override
  void initState() {
    super.initState();

    // Add debug prints to see what data we're receiving
    print('=== EDIT MODE DEBUG ===');
    print('Invoice data received: ${widget.invoice != null}');
    if (widget.invoice != null) {
      print('Invoice ID: ${widget.invoice!["id"]}');
      print('Customer: ${widget.invoice!["customerName"]}');
      print('Items count: ${(widget.invoice!["items"] as List).length}');
      print('Employee ID: ${widget.invoice!["employeeId"]}');
      print('Discount Amount: ${widget.invoice!["discountAmount"]}');
      print('Discount Is Percentage: ${widget.invoice!["discountIsPercentage"]}');
      print('Commission Amount: ${widget.invoice!["commissionAmount"]}');
      print('Commission Is Percentage: ${widget.invoice!["commissionIsPercentage"]}');
      print('All invoice keys: ${widget.invoice!.keys.toList()}');
      print('All invoice values: $widget.invoice');
    }
    print('====================');

    _initializeFields();
    _fetchAvailableItems();
    _fetchAvailableEmployees();
  }

  void _initializeFields() {
    if (widget.invoice != null) {
      // Editing existing invoice
      _invoiceNumber = widget.invoice!["invoiceNumber"] ?? _generateNewInvoiceNumber();
      _customerNameController.text = widget.invoice!["customerName"] ?? "";

      // Initialize discount fields with null safety
      _discountAmount = _parseDouble(widget.invoice!["discountAmount"]) ?? 0.0;
      _discountIsPercentage = widget.invoice!["discountIsPercentage"] ?? false;

      // Use discountValue if available, otherwise use discountAmount
      final discountValue = _parseDouble(widget.invoice!["discountValue"]) ?? _discountAmount;
      _discountAmount = discountValue;

      // Set discount controllers based on type
      if (_discountIsPercentage) {
        _discountPercentageController.text = _discountAmount > 0 ? _discountAmount.toStringAsFixed(2) : "";
        _discountController.text = "";
      } else {
        _discountController.text = _discountAmount > 0 ? _discountAmount.toStringAsFixed(2) : "";
        _discountPercentageController.text = "";
      }

      // Initialize commission and employee fields with null safety
      _commissionAmount = _parseDouble(widget.invoice!["commissionAmount"]) ?? 0.0;
      _commissionIsPercentage = widget.invoice!["commissionIsPercentage"] ?? false;

      // Use commissionValue if available, otherwise use commissionAmount
      final commissionValue = _parseDouble(widget.invoice!["commissionValue"]) ?? _commissionAmount;
      _commissionAmount = commissionValue;

      _selectedEmployeeId = widget.invoice!["employeeId"]?.toString();

      // Set commission controllers based on type
      if (_commissionIsPercentage) {
        _commissionPercentageController.text = _commissionAmount > 0 ? _commissionAmount.toStringAsFixed(2) : "";
        _commissionController.text = "";
      } else {
        _commissionController.text = _commissionAmount > 0 ? _commissionAmount.toStringAsFixed(2) : "";
        _commissionPercentageController.text = "";
      }

      // Initialize items with null safety and proper type conversion
      _invoiceItems = List<Map<String, dynamic>>.from(widget.invoice!["items"] ?? []).map((item) {
        return {
          "id": item["id"]?.toString() ?? UniqueKey().toString(),
          "itemName": item["itemName"]?.toString() ?? "Unknown Item",
          "salePrice": _parseDouble(item["salePrice"]) ?? 0.0,
          "qty": _parseInt(item["qty"]) ?? 1,
        };
      }).toList();

      // Initialize employee object if we have employee data
      if (widget.invoice!["employeeName"] != null || _selectedEmployeeId != null) {
        _selectedEmployee = {
          "id": _selectedEmployeeId,
          "name": widget.invoice!["employeeName"]?.toString() ?? "Previous Employee",
          "phoneNumber": widget.invoice!["employeePhone"]?.toString() ?? "",
          "address": widget.invoice!["employeeAddress"]?.toString() ?? "",
        };
      }

      print('=== FIELD INITIALIZATION COMPLETE ===');
      print('Invoice Number: $_invoiceNumber');
      print('Customer Name: ${_customerNameController.text}');
      print('Discount Amount: $_discountAmount (isPercentage: $_discountIsPercentage)');
      print('Commission Amount: $_commissionAmount (isPercentage: $_commissionIsPercentage)');
      print('Employee ID: $_selectedEmployeeId');
      print('Employee Data: $_selectedEmployee');
      print('Items Count: ${_invoiceItems.length}');
      print('==================================');

    } else {
      // New invoice - initialize with default values
      _invoiceNumber = _generateNewInvoiceNumber();
      _customerNameController.text = "";
      _discountController.text = "";
      _discountPercentageController.text = "";
      _commissionController.text = "";
      _commissionPercentageController.text = "";
      _discountAmount = 0.0;
      _commissionAmount = 0.0;
      _discountIsPercentage = false;
      _commissionIsPercentage = false;
      _selectedEmployeeId = null;
      _selectedEmployee = null;
      _invoiceItems = [];
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<Uint8List> buildThermalInvoicePdf(BuildContext context) async {
    final pdf = pw.Document();
    final ByteData logoData = await rootBundle.load('assets/images/logo.jpg');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final pw.ImageProvider logoImage = pw.MemoryImage(logoBytes);
    // Styles
    final pw.TextStyle titleStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );
    final pw.TextStyle normalStyle = pw.TextStyle(fontSize: 8);
    final pw.TextStyle smallStyle = pw.TextStyle(fontSize: 7);
    final pw.TextStyle boldStyle = pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    );

    // ✅ Thermal roll style: 80mm width, flexible height
    final pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity, // auto-grow height
      marginAll: 2,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Wrap(
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.SizedBox(
                      height: 60,
                      width: 120,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                    pw.Text("MODERN CUT",
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text("DC Colony Neelam Block", style: smallStyle),
                    pw.Text("Main Market, Gujranwala", style: smallStyle),
                    pw.Text("Ph: (055) 2035111", style: smallStyle),
                    pw.Divider(thickness: 1),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              // Invoice Info
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("INVOICE", style: titleStyle),
                      pw.Text("#$_invoiceNumber", style: boldStyle),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Date: ${DateFormat('dd/MM/yy hh:mm a').format(DateTime.now())}",
                    style: smallStyle,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text("Customer: ${_customerNameController.text.trim()}",
                      style: normalStyle),
                  if (_selectedEmployee != null)
                    pw.Text("Employee: ${_selectedEmployee!["name"]}",
                        style: smallStyle),

                ]
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),

              // Items Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text("Item", style: boldStyle)),
                  pw.Expanded(flex: 1, child: pw.Text("Qty", style: boldStyle)),
                  pw.Expanded(flex: 2, child: pw.Text("Price", style: boldStyle)),
                  pw.Expanded(flex: 2, child: pw.Text("Total", style: boldStyle)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // Items
              ..._invoiceItems.map((item) {
                final itemName = item["itemName"] ?? "N/A";
                final price = (item["salePrice"] ?? 0.0).toDouble();
                final qty = (item["qty"] ?? 0).toInt();
                final total = price * qty;
                final truncatedName = itemName.length > 20
                    ? '${itemName.substring(0, 20)}...'
                    : itemName;

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(truncatedName, style: normalStyle)),
                      pw.Expanded(flex: 1, child: pw.Text(qty.toString(), style: normalStyle)),
                      pw.Expanded(flex: 2, child: pw.Text(price.toStringAsFixed(0), style: normalStyle)),
                      pw.Expanded(flex: 2, child: pw.Text(total.toStringAsFixed(0), style: normalStyle)),
                    ],
                  ),
                );
              }).toList(),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),

              // Totals
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text("Subtotal:", style: normalStyle)),
                  pw.Expanded(flex: 2, child: pw.Text("Rs.${_calculateSubtotal().toStringAsFixed(0)}", style: normalStyle)),
                ],
              ),

              // ✅ Show Discount both % and Amount
              if (_discountAmount > 0)
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        "Discount (${_discountAmount.toStringAsFixed(0)}%):",
                        style: normalStyle.copyWith(color: PdfColors.red),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        "-Rs.${_calculateDiscountAmount().toStringAsFixed(0)}",
                        style: normalStyle.copyWith(color: PdfColors.red),
                      ),
                    ),
                  ],
                ),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1),
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text("GRAND TOTAL:", style: titleStyle)),
                  pw.Expanded(flex: 2, child: pw.Text("Rs.${_calculateGrandTotal().toStringAsFixed(0)}", style: titleStyle)),
                ],
              ),

              pw.SizedBox(height: 8),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text("Thank you for your business!",
                        style: smallStyle.copyWith(fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(height: 4),
                    pw.Text("www.moderncut.com", style: smallStyle),
                    pw.SizedBox(height: 2),
                    pw.Text("***", style: smallStyle),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    // Preview
    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = 'blank'
        ..download = 'thermal_invoice.pdf'
        ..click();
      html.window.open(url, '_blank');
      html.Url.revokeObjectUrl(url);
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: 350,
              height: 500,
              child: PdfPreview(
                build: (format) => pdfBytes,
                allowPrinting: true,
                allowSharing: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }

    return pdfBytes;
  }

  double _calculateCommissionAmount() {
    final subtotal = _calculateSubtotal();

    if (_commissionAmount <= 0 || _selectedEmployee == null) {
      return 0.0;
    }

    if (_commissionIsPercentage) {
      // Percentage-based commission
      return subtotal * (_commissionAmount / 100);
    } else {
      // Fixed amount commission
      return _commissionAmount;
    }
  }

  double _calculateGrandTotal() {
    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscountAmount();
    final commission = _calculateCommissionAmount();

    return subtotal - discount;
  }

  String _generateNewInvoiceNumber() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _fetchAvailableItems() async {
    if (!mounted) return;
    setState(() {
      _isLoadingItems = true;
    });
    try {
      final ref = FirebaseDatabase.instance.ref("items");
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        if (mounted) {
          _availableItems = data.entries.map((entry) {
            final item = Map<String, dynamic>.from(entry.value as Map);
            return {
              "id": entry.key ?? 'N/A',
              "itemName": item["itemName"] ?? "Unnamed Item",
              "salePrice": (item["salePrice"] ?? 0.0).toDouble(),
              "image": item["image"] ?? "",
              "qtyOnHand": item["qtyOnHand"] ?? 0,
            };
          }).toList();
        }
      } else {
        _availableItems = [];
      }
    } catch (e) {
      print("Error fetching items: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching available items: ${e.toString()}"), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingItems = false;
        });
      }
    }
  }

  Future<void> _fetchAvailableEmployees() async {
    if (!mounted) return;
    setState(() {
      _isLoadingEmployees = true;
    });
    try {
      final ref = FirebaseDatabase.instance.ref("employees");
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        if (mounted) {
          _availableEmployees = data.entries.map((entry) {
            final employee = Map<String, dynamic>.from(entry.value as Map);
            return {
              "id": entry.key?.toString() ?? 'N/A',
              "name": employee["name"]?.toString() ?? "Unnamed Employee",
              "phoneNumber": employee["phoneNumber"]?.toString() ?? "",
              "address": employee["address"]?.toString() ?? "",
            };
          }).toList();

          // If editing and employee was previously selected, find and set it
          if (widget.invoice != null && _selectedEmployeeId != null) {
            print('Looking for employee with ID: $_selectedEmployeeId');
            print('Available employees: ${_availableEmployees.map((e) => e["id"]).toList()}');

            try {
              final employee = _availableEmployees.firstWhere(
                    (emp) => emp["id"] == _selectedEmployeeId,
              );
              if (employee.isNotEmpty) {
                _selectedEmployee = employee;
                print('✅ Found employee in available list: ${employee["name"]}');
              }
            } catch (e) {
              print("❌ Previously selected employee not found in available list: $e");
              // Keep the employee data we already set in initState
              if (_selectedEmployee == null && widget.invoice!["employeeName"] != null) {
                _selectedEmployee = {
                  "id": _selectedEmployeeId,
                  "name": widget.invoice!["employeeName"]?.toString() ?? "Previous Employee",
                  "phoneNumber": widget.invoice!["employeePhone"]?.toString() ?? "",
                  "address": widget.invoice!["employeeAddress"]?.toString() ?? "",
                };
                print('🔄 Using employee data from invoice: ${_selectedEmployee!["name"]}');
              }
            }
          }
        }
      } else {
        _availableEmployees = [];
      }
    } catch (e) {
      print("Error fetching employees: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching employees: ${e.toString()}"), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = false;
        });
      }
    }
  }

  void _addItemToInvoice(Map<String, dynamic> item) {
    if (!mounted) return;
    final existingItemIndex = _invoiceItems.indexWhere((invItem) => invItem["id"] == item["id"]);

    setState(() {
      if (existingItemIndex != -1) {
        _invoiceItems[existingItemIndex]["qty"] = (_invoiceItems[existingItemIndex]["qty"] ?? 1) + 1;
      } else {
        _invoiceItems.add({
          "id": item["id"],
          "itemName": item["itemName"],
          "salePrice": item["salePrice"],
          "qty": 1,
        });
      }
    });
  }

  void _updateInvoiceItemQuantity(int index, int newQuantity) {
    if (!mounted) return;
    if (newQuantity <= 0) {
      setState(() {
        _invoiceItems.removeAt(index);
      });
    } else {
      setState(() {
        _invoiceItems[index]["qty"] = newQuantity;
      });
    }
  }

  void _updateInvoiceItemPrice(int index, double newPrice) {
    if (!mounted) return;
    if (newPrice >= 0) {
      setState(() {
        _invoiceItems[index]["salePrice"] = newPrice;
      });
    }
  }

  void _removeInvoiceItem(int index) {
    if (!mounted) return;
    setState(() {
      _invoiceItems.removeAt(index);
    });
  }

  double _calculateSubtotal() {
    double subtotal = 0.0;
    for (var item in _invoiceItems) {
      subtotal += ((item["salePrice"] ?? 0.0).toDouble() * (item["qty"] ?? 0).toInt());
    }
    return subtotal;
  }

  double _calculateDiscountAmount() {
    final subtotal = _calculateSubtotal();
    if (_discountIsPercentage) {
      return subtotal * (_discountAmount / 100);
    }
    return _discountAmount;
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please add at least one item to the invoice."),
            backgroundColor: errorColor),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final commissionAmount = _calculateCommissionAmount();

      final invoiceData = {
        "invoiceNumber": _invoiceNumber,
        "customerName": _customerNameController.text.trim(),
        "items": _invoiceItems
            .map((item) => {
          "id": item["id"],
          "itemName": item["itemName"],
          "salePrice": item["salePrice"],
          "qty": item["qty"],
        })
            .toList(),
        "subtotal": _calculateSubtotal(),
        "discountAmount": _calculateDiscountAmount(),
        "discountIsPercentage": _discountIsPercentage,
        "discountValue": _discountAmount,
        "commissionAmount": commissionAmount,
        "commissionIsPercentage": _commissionIsPercentage,
        "commissionValue": _commissionAmount,
        "employeeId": _selectedEmployeeId,
        "employeeName": _selectedEmployee?["name"],
        "total": _calculateGrandTotal(),
        "updatedAt": DateTime.now().toIso8601String(),

        // Additional commission tracking fields
        "commissionPaid": false, // Track if commission has been paid
        "commissionPaidDate": null,
      };

      DatabaseReference ref;
      String invoiceDatabaseId;

      if (widget.invoice != null && widget.invoice!["id"] != null) {
        invoiceData["createdAt"] = widget.invoice!["createdAt"];
        invoiceDatabaseId = widget.invoice!["id"];
        invoiceData["id"] = invoiceDatabaseId;
        ref = FirebaseDatabase.instance.ref("invoices/$invoiceDatabaseId");
      } else {
        invoiceData["createdAt"] = DateTime.now().toIso8601String();
        ref = FirebaseDatabase.instance.ref("invoices").push();
        invoiceDatabaseId = ref.key!;
        invoiceData["id"] = invoiceDatabaseId;
      }

      await ref.set(invoiceData);

      // Also update employee's total commission earned
      if (_selectedEmployeeId != null && commissionAmount > 0) {
        await _updateEmployeeCommission(_selectedEmployeeId!, commissionAmount);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.invoice != null
                  ? "Invoice updated successfully!"
                  : "Invoice saved successfully!"),
              backgroundColor: successColor),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Error saving invoice: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error saving invoice: ${e.toString()}"),
              backgroundColor: errorColor),
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

// Method to update employee's total commission
  Future<void> _updateEmployeeCommission(String employeeId, double commissionAmount) async {
    try {
      final employeeRef = FirebaseDatabase.instance.ref("employees/$employeeId");
      final snapshot = await employeeRef.get();

      if (snapshot.exists) {
        final employeeData = Map<String, dynamic>.from(snapshot.value as Map);
        final currentTotalCommission = (employeeData["totalCommission"] ?? 0.0).toDouble();
        final currentPendingCommission = (employeeData["pendingCommission"] ?? 0.0).toDouble();

        await employeeRef.update({
          "totalCommission": currentTotalCommission + commissionAmount,
          "pendingCommission": currentPendingCommission + commissionAmount,
          "lastCommissionUpdate": DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print("Error updating employee commission: $e");
    }
  }

  void _showEmployeeSelectionDialog() {
    // Create a combined list including the currently selected employee (if any)
    List<Map<String, dynamic>> displayedEmployees = List.from(_availableEmployees);

    // If editing and the previously selected employee isn't in available list, add it
    if (widget.invoice != null &&
        _selectedEmployeeId != null &&
        !_availableEmployees.any((emp) => emp["id"] == _selectedEmployeeId) &&
        _selectedEmployee != null) {

      // Add the employee from invoice data to the list
      displayedEmployees.add({
        "id": _selectedEmployeeId,
        "name": _selectedEmployee!["name"] ?? "Previous Employee",
        "phoneNumber": _selectedEmployee!["phoneNumber"] ?? "N/A",
        "address": _selectedEmployee!["address"] ?? "N/A",
        "isPrevious": true, // Flag to indicate this is from previous data
      });
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Select Employee", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          content: SizedBox(
            width: double.maxFinite,
            child: displayedEmployees.isEmpty
                ? Center(child: Text("No employees available.", style: TextStyle(color: subtleTextColor)))
                : ListView.builder(
              shrinkWrap: true,
              itemCount: displayedEmployees.length,
              itemBuilder: (context, index) {
                final employee = displayedEmployees[index];
                final bool isSelected = _selectedEmployeeId == employee["id"];
                final bool isPreviousEmployee = employee["isPrevious"] == true;

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  color: isPreviousEmployee ? Colors.orange[50] : null,
                  child: ListTile(
                    leading: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                          isPreviousEmployee ? Icons.person_off_outlined : Icons.person_outlined,
                          color: isPreviousEmployee ? Colors.orange : primaryColor
                      ),
                    ),
                    title: Text(
                        employee["name"] ?? "N/A",
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: isPreviousEmployee ? Colors.orange[700] : textColor
                        )
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Phone: ${employee["phoneNumber"] ?? "N/A"}", style: TextStyle(fontSize: 12, color: subtleTextColor)),
                        if (isPreviousEmployee)
                          Text("(Previous employee - may not be current)", style: TextStyle(fontSize: 10, color: Colors.orange)),
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: successColor)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedEmployeeId = employee["id"];
                        _selectedEmployee = employee;
                        // Keep commission values when changing employee
                        if (_commissionAmount > 0) {
                          // Commission values remain the same
                        }
                      });
                      Navigator.pop(dialogContext);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            if (_selectedEmployeeId != null)
              TextButton(
                child: Text("Clear Selection", style: TextStyle(color: errorColor)),
                onPressed: () {
                  setState(() {
                    _selectedEmployeeId = null;
                    _selectedEmployee = null;
                    _commissionAmount = 0.0;
                    _commissionController.text = "";
                    _commissionPercentageController.text = "";
                  });
                  Navigator.pop(dialogContext);
                },
              ),
            TextButton(
              child: Text("Close", style: TextStyle(color: primaryColor)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        );
      },
    );
  }

  void _showItemSearchDialog() {
    TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> displayedItems = List.from(_availableItems);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Select Item to Add", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Search by item name...",
                        prefixIcon: const Icon(Icons.search, color: primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        stfSetState(() {
                          if (value.isEmpty) {
                            displayedItems = List.from(_availableItems);
                          } else {
                            displayedItems = _availableItems
                                .where((item) => (item["itemName"]?.toString() ?? "")
                                .toLowerCase()
                                .contains(value.toLowerCase()))
                                .toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: displayedItems.isEmpty
                          ? Center(child: Text("No items match your search.", style: TextStyle(color: subtleTextColor)))
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: displayedItems.length,
                        itemBuilder: (context, index) {
                          final item = displayedItems[index];
                          Uint8List? imageBytes;
                          if (item["image"] != null && item["image"].toString().isNotEmpty) {
                            try { imageBytes = base64Decode(item["image"]); } catch (_) {}
                          }
                          final bool alreadyAdded = _invoiceItems.any((invItem) => invItem["id"] == item["id"]);

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              leading: imageBytes != null
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(imageBytes, width: 45, height: 45, fit: BoxFit.cover),
                              )
                                  : Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)), child: Icon(Icons.inventory_2_outlined, color: Colors.grey[500])),
                              title: Text(item["itemName"] ?? "N/A", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                              subtitle: Text("Price: Rs.${(item["salePrice"] ?? 0.0).toStringAsFixed(2)}  |  Stock: ${item["qtyOnHand"] ?? 0}", style: TextStyle(fontSize: 12, color: subtleTextColor)),
                              trailing: alreadyAdded
                                  ? Icon(Icons.check_circle, color: successColor.withOpacity(0.7))
                                  : Icon(Icons.add_circle_outline, color: primaryColor),
                              onTap: () {
                                _addItemToInvoice(item);
                                Navigator.pop(dialogContext);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Close", style: TextStyle(color: primaryColor)),
                  onPressed: () => Navigator.pop(dialogContext),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final pw.TextStyle boldStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    final pw.TextStyle normalStyle = const pw.TextStyle();
    final pw.TextStyle smallStyle = const pw.TextStyle(fontSize: 9);
    final pw.TextStyle headerStyle = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    final PdfColor primaryPdfColor = PdfColor.fromHex("#6C63FF");
    final PdfColor accentPdfColor = PdfColor.fromHex("#4FC3F7");

    // Load the logo image
    final ByteData logoData = await rootBundle.load('assets/images/logo.jpg');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final pw.ImageProvider logoImage = pw.MemoryImage(logoBytes);

    // Define Shop Details
    const String shopName = "Modern Cut";
    const String shopAddressLine1 = "DC Colony Neelam Block Main Market";
    const String shopAddressLine2 = "Gujranwala, Pakistan - 12345";
    const String shopContact = "Ph: (055) 2035111";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Shop Info and Logo
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(shopName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
                        pw.SizedBox(height: 3),
                        pw.Text(shopAddressLine1, style: smallStyle),
                        pw.Text(shopAddressLine2, style: smallStyle),
                        pw.Text(shopContact, style: smallStyle.copyWith(fontSize: 8)),
                      ],
                    ),
                    pw.SizedBox(
                      height: 60,
                      width: 120,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Invoice Title and Details
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("INVOICE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryPdfColor.shade(0.8))),
                      pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text("Invoice #: $_invoiceNumber", style: boldStyle),
                            pw.Text("Date: ${DateFormat('dd MMM, yyyy hh:mm a').format(DateTime.now())}", style: normalStyle),
                          ]
                      )
                    ]
                ),

                pw.SizedBox(height: 15),
                pw.Text("Bill To:", style: boldStyle),
                pw.Text(_customerNameController.text.trim(), style: normalStyle),

                // Employee information if selected
                if (_selectedEmployee != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Text("Employee: ${_selectedEmployee!["name"]}", style: normalStyle),
                ],

                pw.Divider(height: 25, thickness: 1, color: primaryPdfColor),
              ],
            );
          }
          return pw.Container();
        },
        build: (pw.Context context) {
          return [
            pw.Text("Items Summary", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: accentPdfColor)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
                headers: ["#", "Item Name", "Price (Rs.)", "Qty", "Total (Rs.)"],
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: headerStyle,
                headerDecoration: pw.BoxDecoration(color: primaryPdfColor),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                },
                data: List<List<String>>.generate(
                  _invoiceItems.length,
                      (index) {
                    final item = _invoiceItems[index];
                    final itemPrice = (item["salePrice"] ?? 0.0).toDouble();
                    final itemQty = (item["qty"] ?? 0).toInt();
                    return [
                      (index + 1).toString(),
                      item["itemName"] ?? "N/A",
                      itemPrice.toStringAsFixed(2),
                      itemQty.toString(),
                      (itemPrice * itemQty).toStringAsFixed(2),
                    ];
                  },
                ),
                border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FixedColumnWidth(40),
                  4: const pw.FlexColumnWidth(1.5),
                }),
            pw.SizedBox(height: 15),

            // Subtotal
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text("Subtotal: ", style: normalStyle),
                pw.Text("Rs.${_calculateSubtotal().toStringAsFixed(2)}", style: boldStyle),
              ],
            ),

            // Discount
            if (_discountAmount > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text("Discount${_discountIsPercentage ? " (${_discountAmount}%)" : ""}: ", style: normalStyle.copyWith(color: PdfColors.red500)),
                    pw.Text("- Rs.${_calculateDiscountAmount().toStringAsFixed(2)}", style: boldStyle.copyWith(color: PdfColors.red500)),
                  ],
                ),
              ),

            // Commission
            if (_commissionAmount > 0 && _selectedEmployee != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text("Commission${_commissionIsPercentage ? " (${_commissionAmount}%)" : ""}: ", style: normalStyle.copyWith(color: PdfColors.green700)),
                    pw.Text("Rs.${_calculateCommissionAmount().toStringAsFixed(2)}", style: boldStyle.copyWith(color: PdfColors.green700)),
                  ],
                ),
              ),

            pw.Divider(color: PdfColors.grey, height: 12, thickness: 0.5),

            // Grand Total
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text("GRAND TOTAL: ", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
                pw.Text("Rs.${_calculateGrandTotal().toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Text("Thank you for your business!", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text("Page ${context.pageNumber} of ${context.pagesCount}",
                style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey)),
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Invoice-$_invoiceNumber.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.invoice != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Invoice" : "Create New Invoice", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isEditing)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("EDIT MODE", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          SizedBox(width: 8),
          // Thermal Print Button
          TextButton.icon(
            icon: const Icon(Icons.print_outlined, color: Colors.white, size: 18),
            label: const Text(
              "Thermal",
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            onPressed: _invoiceItems.isEmpty
                ? null
                : () async {
              await buildThermalInvoicePdf(context);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              backgroundColor: Colors.orange[700],
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            label: const Text("Export PDF", style: TextStyle(color: Colors.white)),
            onPressed: _invoiceItems.isEmpty ? null : _generatePdf,
            style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 16)),
          ),
        ],
      ),
      body: _isSaving
          ? _buildLoadingIndicator("Saving Invoice...")
          : (_isLoadingItems || _isLoadingEmployees)
          ? _buildLoadingIndicator("Loading...")
          : _buildInvoiceForm(),
      bottomNavigationBar: _isSaving ? null : _buildBottomBar(),
    );
  }

  Widget _buildLoadingIndicator(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 16, color: primaryColor)),
        ],
      ),
    );
  }

  Widget _buildInvoiceForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Fixed header section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Invoice #: $_invoiceNumber", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
                    if (widget.invoice != null && widget.invoice!["createdAt"] != null)
                      Text(
                          "Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(widget.invoice!["createdAt"]))}",
                          style: TextStyle(fontSize: 13, color: subtleTextColor)
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customerNameController,
                  decoration: InputDecoration(
                    labelText: "Customer Name *",
                    hintText: "Enter customer's full name",
                    prefixIcon: const Icon(Icons.person_outline, color: primaryColor, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? "Customer name is required" : null,
                  style: TextStyle(color: textColor),
                ),
                const SizedBox(height: 12),

                // Employee Selection
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline, color: primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text("Employee", style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _selectedEmployee != null
                            ? ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(Icons.person, color: primaryColor, size: 20),
                          ),
                          title: Text(_selectedEmployee!["name"] ?? "N/A", style: TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(_selectedEmployee!["phoneNumber"] ?? "N/A", style: TextStyle(fontSize: 12, color: subtleTextColor)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: primaryColor, size: 20),
                                onPressed: _showEmployeeSelectionDialog,
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: errorColor, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _selectedEmployee = null;
                                    _selectedEmployeeId = null;
                                    _commissionAmount = 0.0;
                                    _commissionController.text = "";
                                    _commissionPercentageController.text = "";
                                  });
                                },
                              ),
                            ],
                          ),
                        )
                            : SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.person_add_outlined, size: 18),
                            label: Text("Select Employee"),
                            onPressed: _showEmployeeSelectionDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

               Row(
                 children: [
                   // Commission Section (only show if employee is selected)
                   if (_selectedEmployee != null) ...[
                     Expanded(
                       child: Card(
                         elevation: 1,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         child: Padding(
                           padding: const EdgeInsets.all(12.0),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 children: [
                                   Icon(Icons.percent_outlined, color: primaryColor, size: 20),
                                   const SizedBox(width: 8),
                                   Text("Commission for ${_selectedEmployee!["name"]}", style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                                 ],
                               ),
                               const SizedBox(height: 8),
                               Row(
                                 children: [
                                   Expanded(
                                     child: TextFormField(
                                       controller: _commissionController,
                                       decoration: InputDecoration(
                                         labelText: "Commission Amount (Rs.)",
                                         hintText: "Enter amount",
                                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                       ),
                                       keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                       inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                       onChanged: (value) {
                                         setState(() {
                                           _commissionAmount = double.tryParse(value) ?? 0.0;
                                           _commissionIsPercentage = false;
                                           if (value.isNotEmpty) {
                                             _commissionPercentageController.text = "";
                                           }
                                         });
                                       },
                                       style: TextStyle(color: textColor),
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   Text("OR", style: TextStyle(color: subtleTextColor, fontWeight: FontWeight.bold)),
                                   const SizedBox(width: 8),
                                   Expanded(
                                     child: TextFormField(
                                       controller: _commissionPercentageController,
                                       decoration: InputDecoration(
                                         labelText: "Commission (%)",
                                         hintText: "Enter percentage",
                                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                       ),
                                       keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                       inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                       onChanged: (value) {
                                         setState(() {
                                           _commissionAmount = double.tryParse(value) ?? 0.0;
                                           _commissionIsPercentage = true;
                                           if (value.isNotEmpty) {
                                             _commissionController.text = "";
                                           }
                                         });
                                       },
                                       style: TextStyle(color: textColor),
                                     ),
                                   ),
                                 ],
                               ),
                             ],
                           ),
                         ),
                       ),
                     ),
                     Expanded(
                       child: Card (
                         elevation: 1,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         child: Padding(
                           padding: const EdgeInsets.all(12.0),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 children: [
                                   Icon(Icons.local_offer_outlined, color: primaryColor, size: 20),
                                   const SizedBox(width: 8),
                                   Text("Discount", style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                                 ],
                               ),
                               const SizedBox(height: 8),
                               Row(
                                 children: [
                                   Expanded(
                                     child: TextFormField(
                                       controller: _discountController,
                                       decoration: InputDecoration(
                                         labelText: "Discount Amount (Rs.)",
                                         hintText: "Enter amount",
                                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                       ),
                                       keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                       inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                       onChanged: (value) {
                                         setState(() {
                                           _discountAmount = double.tryParse(value) ?? 0.0;
                                           _discountIsPercentage = false;
                                           if (value.isNotEmpty) {
                                             _discountPercentageController.text = "";
                                           }
                                         });
                                       },
                                       style: TextStyle(color: textColor),
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   Text("OR", style: TextStyle(color: subtleTextColor, fontWeight: FontWeight.bold)),
                                   const SizedBox(width: 8),
                                   Expanded(
                                     child: TextFormField(
                                       controller: _discountPercentageController,
                                       decoration: InputDecoration(
                                         labelText: "Discount (%)",
                                         hintText: "Enter percentage",
                                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                       ),
                                       keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                       inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                       onChanged: (value) {
                                         setState(() {
                                           _discountAmount = double.tryParse(value) ?? 0.0;
                                           _discountIsPercentage = true;
                                           if (value.isNotEmpty) {
                                             _discountController.text = "";
                                           }
                                         });
                                       },
                                       style: TextStyle(color: textColor),
                                     ),
                                   ),
                                 ],
                               ),
                             ],
                           ),
                         ),
                       ),
                     ),
                   ],
                 ],
               ),
                 SizedBox(height: 12),
                // Add Item Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search_outlined, size: 20),
                    label: const Text("Search & Add Item"),
                    onPressed: _showItemSearchDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Scrollable items section
          Expanded(
            child: _invoiceItems.isEmpty
                ? _buildEmptyItemsPlaceholder()
                : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: List.generate(
                        _invoiceItems.length,
                            (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildInvoiceItemTile(index, _invoiceItems[index]),
                        ),
                      ),
                    ),
                  ),
                  // Add some extra space at the bottom to account for the bottom navigation bar
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItemsPlaceholder() {
    return SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.4,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_shopping_cart_outlined, size: 70, color: Colors.grey[350]),
              const SizedBox(height: 12),
              Text("No items added to invoice yet.", style: TextStyle(fontSize: 16, color: subtleTextColor)),
              const SizedBox(height: 4),
              Text("Click 'Search & Add Item' to begin.", style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceItemTile(int index, Map<String, dynamic> item) {
    final itemName = item["itemName"] ?? "N/A";
    final salePrice = (item["salePrice"] ?? 0.0).toDouble();
    final quantity = (item["qty"] ?? 1).toInt();
    final itemTotal = salePrice * quantity;

    final priceController = TextEditingController(text: salePrice.toStringAsFixed(2));

    return Card(
      elevation: 1.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(itemName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: errorColor.withOpacity(0.8), size: 22),
                  onPressed: () => _removeInvoiceItem(index),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  tooltip: "Remove Item",
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Price (Rs.)", style: TextStyle(fontSize: 11, color: subtleTextColor)),
                      SizedBox(
                        height: 38,
                        child: TextFormField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: inputBorderColor.withOpacity(0.5))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            final newPrice = double.tryParse(value);
                            if (newPrice != null) {
                              _updateInvoiceItemPrice(index, newPrice);
                            }
                          },
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Quantity", style: TextStyle(fontSize: 11, color: subtleTextColor)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _quantityButton(
                            icon: Icons.remove,
                            onPressed: quantity > 1 ? () => _updateInvoiceItemQuantity(index, quantity - 1) : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Text(quantity.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                          ),
                          _quantityButton(
                            icon: Icons.add,
                            onPressed: () => _updateInvoiceItemQuantity(index, quantity + 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Total (Rs.)", style: TextStyle(fontSize: 11, color: subtleTextColor)),
                      Text(
                        itemTotal.toStringAsFixed(2),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityButton({required IconData icon, VoidCallback? onPressed}) {
    return SizedBox(
      width: 30, height: 30,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          backgroundColor: accentColor.withOpacity(onPressed != null ? 0.2 : 0.05),
          foregroundColor: onPressed != null ? primaryColor : Colors.grey,
          elevation: 0,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildBottomBar() {
    final subtotal = _calculateSubtotal();
    final discountAmount = _calculateDiscountAmount();
    final commissionAmount = _calculateCommissionAmount();
    final grandTotal = _calculateGrandTotal();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 0, blurRadius: 5, offset: const Offset(0, -2)),
        ],
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Subtotal: Rs. ${subtotal.toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 12, color: subtleTextColor)),
                if (discountAmount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text("Discount${_discountIsPercentage ? " (${_discountAmount}%)" : ""}: - Rs. ${discountAmount.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 12, color: errorColor.withOpacity(0.9))),
                  ),
                if (commissionAmount > 0 && _selectedEmployee != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text("Commission${_commissionIsPercentage ? " (${_commissionAmount}%)" : ""}: Rs. ${commissionAmount.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 12, color: successColor.withOpacity(0.9))),
                  ),
                const SizedBox(height: 2),
                Text("GRAND TOTAL", style: TextStyle(fontSize: 11, color: subtleTextColor.withOpacity(0.8), fontWeight: FontWeight.w500)),
                Text(
                  "Rs. ${grandTotal.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: successColor),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: Icon(_isSaving ? Icons.hourglass_empty_outlined : (widget.invoice != null ? Icons.save_alt_outlined : Icons.check_circle_outline), color: Colors.white, size: 20),
            label: Text(
              _isSaving ? "SAVING..." : (widget.invoice != null ? "UPDATE INVOICE" : "SAVE INVOICE"),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onPressed: _isSaving ? null : _saveInvoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }
}