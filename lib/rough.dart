// import 'package:flutter/services.dart'; // <-- ADD THIS IMPORT for rootBundle
// // ... other imports ...
// import 'package:pdf/widgets.dart' as pw;
// import 'package:pdf/pdf.dart';
// import 'package:printing/printing.dart';
// import 'package:intl/intl.dart';
//
//
// // ... inside _InvoicePageState class ...
//
// Future<void> _generatePdf() async {
//   final pdf = pw.Document();
//   final pw.TextStyle boldStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold);
//   final pw.TextStyle normalStyle = const pw.TextStyle();
//   final pw.TextStyle smallStyle = const pw.TextStyle(fontSize: 9); // For address
//   final pw.TextStyle headerStyle =
//   pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
//   final PdfColor primaryPdfColor = PdfColor.fromHex("#6C63FF");
//   final PdfColor accentPdfColor = PdfColor.fromHex("#4FC3F7");
//
//   // --- 1. Load the logo image ---
//   final ByteData logoData = await rootBundle.load('assets/images/logo.png');
//   final Uint8List logoBytes = logoData.buffer.asUint8List();
//   final pw.ImageProvider logoImage = pw.MemoryImage(logoBytes);
//
//   // --- Define Shop Details ---
//   const String shopName = "Modern Cut";
//   const String shopAddressLine1 = "123 Style Street, Fashion City";
//   const String shopAddressLine2 = "State, Country - 12345";
//   const String shopContact = "Ph: (555) 123-4567 | Email: contact@moderncut.com";
//
//
//   pdf.addPage(
//     pw.MultiPage(
//       pageFormat: PdfPageFormat.a4,
//       header: (pw.Context context) {
//         if (context.pageNumber == 1) {
//           return pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               // --- Shop Info and Logo ---
//               pw.Row(
//                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   pw.Column(
//                     crossAxisAlignment: pw.CrossAxisAlignment.start,
//                     children: [
//                       pw.Text(shopName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
//                       pw.SizedBox(height: 3),
//                       pw.Text(shopAddressLine1, style: smallStyle),
//                       pw.Text(shopAddressLine2, style: smallStyle),
//                       pw.Text(shopContact, style: smallStyle.copyWith(fontSize: 8)),
//                     ],
//                   ),
//                   pw.SizedBox( // Container for the logo
//                     height: 60, // Adjust height as needed
//                     width: 120, // Adjust width as needed
//                     child: pw.Image(logoImage, fit: pw.BoxFit.contain), // Use BoxFit.contain or cover
//                   ),
//                 ],
//               ),
//               pw.SizedBox(height: 20), // Space after shop info
//
//               // --- Invoice Title and Details ---
//               pw.Row(
//                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                   children: [
//                     pw.Text("INVOICE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryPdfColor.shade(0.8))), // Slightly darker shade for INVOICE text
//                     pw.Column(
//                         crossAxisAlignment: pw.CrossAxisAlignment.end,
//                         children: [
//                           pw.Text("Invoice #: $_invoiceNumber", style: boldStyle),
//                           pw.Text("Date: ${DateFormat('dd MMM, yyyy hh:mm a').format(DateTime.now())}", style: normalStyle),
//                         ]
//                     )
//                   ]
//               ),
//
//
//               pw.SizedBox(height: 15),
//               pw.Text("Bill To:", style: boldStyle),
//               pw.Text(_customerNameController.text.trim(), style: normalStyle),
//               pw.Divider(height: 25, thickness: 1, color: primaryPdfColor),
//             ],
//           );
//         }
//         return pw.Container(); // No header for subsequent pages or a simpler one
//       },
//       build: (pw.Context context) {
//         // --- Items Summary and Totals (Your existing build logic) ---
//         return [
//           pw.Text("Items Summary", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: accentPdfColor)),
//           pw.SizedBox(height: 10),
//           pw.Table.fromTextArray(
//               headers: ["#", "Item Name", "Price (Rs.)", "Qty", "Total (Rs.)"],
//               cellAlignment: pw.Alignment.centerLeft,
//               headerStyle: headerStyle,
//               headerDecoration: pw.BoxDecoration(color: primaryPdfColor),
//               cellHeight: 30,
//               cellAlignments: {
//                 0: pw.Alignment.center,
//                 2: pw.Alignment.centerRight,
//                 3: pw.Alignment.center,
//                 4: pw.Alignment.centerRight,
//               },
//               data: List<List<String>>.generate(
//                 _invoiceItems.length,
//                     (index) {
//                   final item = _invoiceItems[index];
//                   final itemPrice = (item["salePrice"] ?? 0.0).toDouble();
//                   final itemQty = (item["qty"] ?? 0).toInt();
//                   return [
//                     (index + 1).toString(),
//                     item["itemName"] ?? "N/A",
//                     itemPrice.toStringAsFixed(2),
//                     itemQty.toString(),
//                     (itemPrice * itemQty).toStringAsFixed(2),
//                   ];
//                 },
//               ),
//               border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
//               columnWidths: {
//                 0: const pw.FixedColumnWidth(30),
//                 1: const pw.FlexColumnWidth(3),
//                 2: const pw.FlexColumnWidth(1.5),
//                 3: const pw.FixedColumnWidth(40),
//                 4: const pw.FlexColumnWidth(1.5),
//               }),
//           pw.SizedBox(height: 15),
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.end,
//             children: [
//               pw.Text("Subtotal: ", style: normalStyle),
//               pw.Text("Rs.${_calculateSubtotal().toStringAsFixed(2)}", style: boldStyle),
//             ],
//           ),
//           if (_discountAmount > 0)
//             pw.Padding(
//               padding: const pw.EdgeInsets.only(top: 3),
//               child: pw.Row(
//                 mainAxisAlignment: pw.MainAxisAlignment.end,
//                 children: [
//                   pw.Text("Discount: ", style: normalStyle.copyWith(color: PdfColors.red500)),
//                   pw.Text("- Rs.${_discountAmount.toStringAsFixed(2)}", style: boldStyle.copyWith(color: PdfColors.red500)),
//                 ],
//               ),
//             ),
//           pw.Divider(color: PdfColors.grey, height: 12, thickness: 0.5),
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.end,
//             children: [
//               pw.Text("GRAND TOTAL: ", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
//               pw.Text("Rs.${_calculateGrandTotal().toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
//             ],
//           ),
//           pw.SizedBox(height: 30),
//           pw.Text("Thank you for your business!", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
//         ];
//       },
//       footer: (pw.Context context) {
//         return pw.Container(
//           alignment: pw.Alignment.centerRight,
//           margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
//           child: pw.Text("Page ${context.pageNumber} of ${context.pagesCount}",
//               style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey)),
//         );
//       },
//     ),
//   );
//
//   await Printing.layoutPdf(
//       onLayout: (PdfPageFormat format) async => pdf.save(),
//       name: 'Invoice-$_invoiceNumber.pdf');
// }
//
