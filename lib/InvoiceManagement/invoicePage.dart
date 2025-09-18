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

class InvoicePage extends StatefulWidget {
  final Map<String, dynamic>? invoice; // For editing existing invoices

  const InvoicePage({super.key, this.invoice});

  @override
  _InvoicePageState createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(); // ADDED for discount
  double _discountAmount = 0.0; // ADDED for discount value

  String _invoiceNumber = "";
  List<Map<String, dynamic>> _availableItems = []; // All items from DB
  List<Map<String, dynamic>> _invoiceItems = [];   // Items added to the current invoice

  bool _isLoadingItems = true; // For fetching available items
  bool _isSaving = false;    // For saving invoice

  // Define your color scheme (consistent with other pages)
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

    if (widget.invoice != null) {
      // Editing existing invoice
      _invoiceNumber = widget.invoice!["invoiceNumber"] ?? _generateNewInvoiceNumber();
      _customerNameController.text = widget.invoice!["customerName"] ?? "";
      _discountAmount = (widget.invoice!["discountAmount"] ?? 0.0).toDouble();
      _discountController.text = _discountAmount > 0 ? _discountAmount.toStringAsFixed(2) : "";


      _invoiceItems = List<Map<String, dynamic>>.from(widget.invoice!["items"] ?? []).map((item) {
        return {
          "id": item["id"] ?? UniqueKey().toString(), // Fallback id
          "itemName": item["itemName"] ?? "Unknown Item",
          "salePrice": (item["salePrice"] ?? 0.0).toDouble(),
          "qty": (item["qty"] ?? 1).toInt(),
        };
      }).toList();
    } else {
      // New invoice
      _invoiceNumber = _generateNewInvoiceNumber();
      _discountController.text = ""; // Initialize for new invoice
    }
    _fetchAvailableItems();
  }

  String _generateNewInvoiceNumber() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString(); // 6-digit random
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

  double _calculateGrandTotal() {
    final subtotal = _calculateSubtotal();
    return subtotal - _discountAmount;
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
        "discountAmount": _discountAmount,
        "total": _calculateGrandTotal(), // Grand Total
        "updatedAt":
        DateTime.now().toIso8601String(),
      };

      DatabaseReference ref;
      String invoiceDatabaseId;

      if (widget.invoice != null && widget.invoice!["id"] != null) {
        invoiceData["createdAt"] =
        widget.invoice!["createdAt"];
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
    final pw.TextStyle headerStyle = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    final PdfColor primaryPdfColor = PdfColor.fromHex("#6C63FF");
    final PdfColor accentPdfColor = PdfColor.fromHex("#4FC3F7");

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("INVOICE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
                  pw.SizedBox(height: 5),
                  pw.Text("Invoice #: $_invoiceNumber", style: boldStyle),
                  pw.Text("Date: ${DateFormat('dd MMM, yyyy hh:mm a').format(DateTime.now())}", style: normalStyle),
                  pw.SizedBox(height: 10),
                  pw.Text("Bill To:", style: boldStyle),
                  pw.Text(_customerNameController.text.trim(), style: normalStyle),
                  pw.Divider(height: 20, thickness: 1, color: primaryPdfColor),
                ]
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
                }
            ),
            pw.SizedBox(height: 15),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text("Subtotal: ", style: normalStyle),
                pw.Text("Rs.${_calculateSubtotal().toStringAsFixed(2)}", style: boldStyle),
              ],
            ),
            if (_discountAmount > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text("Discount: ", style: normalStyle.copyWith(color: PdfColors.red500)),
                    pw.Text("- Rs.${_discountAmount.toStringAsFixed(2)}", style: boldStyle.copyWith(color: PdfColors.red500)),
                  ],
                ),
              ),
            pw.Divider(color: PdfColors.grey, height:12, thickness: 0.5),
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
        name: 'Invoice-$_invoiceNumber.pdf'
    );
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
          : _isLoadingItems
          ? _buildLoadingIndicator("Loading items...")
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
          Padding(
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
                TextFormField( // DISCOUNT FIELD
                  controller: _discountController,
                  decoration: InputDecoration(
                    labelText: "Discount Amount (Rs.)",
                    hintText: "Enter discount (e.g., 50.00)",
                    prefixIcon: const Icon(Icons.local_offer_outlined, color: primaryColor, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  onChanged: (value) {
                    setState(() {
                      _discountAmount = double.tryParse(value) ?? 0.0;
                    });
                  },
                  style: TextStyle(color: textColor),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search_outlined, size: 20),
                    label: const Text("Search & Add Item"),
                    onPressed: _showItemSearchDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor.withOpacity(0.8),foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: _invoiceItems.isEmpty
                ? _buildEmptyItemsPlaceholder()
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _invoiceItems.length,
              itemBuilder: (context, index) => _buildInvoiceItemTile(index, _invoiceItems[index]),
              separatorBuilder: (context, index) => const SizedBox(height: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItemsPlaceholder() {
    return Center(
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
                Text("Subtotal: Rs. ${_calculateSubtotal().toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 12, color: subtleTextColor)),
                if (_discountAmount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text("Discount: - Rs. ${_discountAmount.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 12, color: errorColor.withOpacity(0.9))),
                  ),
                const SizedBox(height: 2),
                Text("GRAND TOTAL", style: TextStyle(fontSize: 11, color: subtleTextColor.withOpacity(0.8), fontWeight: FontWeight.w500)),
                Text(
                  "Rs. ${_calculateGrandTotal().toStringAsFixed(2)}",
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
