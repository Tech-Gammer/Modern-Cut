import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart'; // Changed import
import 'package:intl/intl.dart';
import 'InvoiceManagement/invoiceListPage.dart';
import 'ItemManagement/itemsList.dart';
import 'Providers/authprovider.dart'; // Ensure this path is correct
import 'VendorManagement/vendorlist.dart';
import 'employee/EmployeeListPage.dart';
import 'employee/reports.dart'; // Ensure this path is correct

class SalesData {
  final String dateString; // Formatted date string (e.g., "MMM dd") for display
  final double sales;
  final DateTime actualDate; // Actual date for sorting

  SalesData(this.dateString, this.sales, this.actualDate);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _invoices = [];

  // For fl_chart
  List<BarChartGroupData> _barChartGroups = [];
  Map<int, String> _xAxisLabels = {}; // To map numerical X index to date string
  double _maxYValueForChart = 0; // To help fl_chart determine the Y-axis scale

  bool _loadingChart = true;
  double _totalSales = 0.0;
  int _totalInvoices = 0;

  @override
  void initState() {
    super.initState();
    _fetchInvoiceData();
  }

  Future<void> _fetchInvoiceData() async {
    setState(() {
      _loadingChart = true;
    });

    final ref = FirebaseDatabase.instance.ref("invoices");
    final snapshot = await ref.get();

    if (snapshot.exists && snapshot.value != null) {
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      List<Map<String, dynamic>> allInvoices = data.entries.map((entry) {
        final invoice = Map<String, dynamic>.from(entry.value);
        return {
          "id": entry.key,
          "invoiceNumber": invoice["invoiceNumber"] ?? "",
          "customerName": invoice["customerName"] ?? "",
          "total": (invoice["total"] ?? 0.0).toDouble(),
          "createdAt": invoice["createdAt"] ?? DateTime.now().toIso8601String(),
          "items": invoice["items"] ?? [],
        };
      }).toList();

      List<Map<String, dynamic>> filteredInvoices = allInvoices.where((invoice) {
        DateTime invoiceDate = DateTime.parse(invoice["createdAt"]);
        // Ensure the date range comparison is correct
        return !invoiceDate.isBefore(_startDate.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)) &&
            !invoiceDate.isAfter(_endDate.copyWith(hour: 23, minute: 59, second: 59, millisecond: 999));
      }).toList();

      filteredInvoices.sort((a, b) => DateTime.parse(a["createdAt"]).compareTo(DateTime.parse(b["createdAt"])));

      setState(() {
        _invoices = filteredInvoices;
        _generateChartData();
        _loadingChart = false;
      });
    } else {
      setState(() {
        _invoices = [];
        _barChartGroups = [];
        _xAxisLabels = {};
        _maxYValueForChart = 0;
        _loadingChart = false;
        _totalSales = 0.0;
        _totalInvoices = 0;
      });
    }
  }

  void _generateChartData() {
    Map<DateTime, double> dailySalesRaw = {}; // Use DateTime as key for proper sorting

    for (var invoice in _invoices) {
      DateTime date = DateTime.parse(invoice["createdAt"]);
      // Normalize date to ignore time for grouping by day
      DateTime dateKey = DateTime(date.year, date.month, date.day);

      dailySalesRaw[dateKey] = (dailySalesRaw[dateKey] ?? 0.0) + invoice["total"];
    }

    // Convert to SalesData list for sorting and further processing
    List<SalesData> salesDataList = dailySalesRaw.entries.map((entry) {
      return SalesData(
        DateFormat('MMM dd').format(entry.key), // Formatted string for labels
        entry.value,                           // Sales amount
        entry.key,                             // Actual DateTime for sorting
      );
    }).toList();

    // Sort by actual date
    salesDataList.sort((a, b) => a.actualDate.compareTo(b.actualDate));

    List<BarChartGroupData> tempBarGroups = [];
    Map<int, String> tempXAxisLabels = {};
    _maxYValueForChart = 0;
    int xIndex = 0;

    for (var dataPoint in salesDataList) {
      if (dataPoint.sales > _maxYValueForChart) {
        _maxYValueForChart = dataPoint.sales;
      }
      tempBarGroups.add(
        BarChartGroupData(
          x: xIndex,
          barRods: [
            BarChartRodData(
              toY: dataPoint.sales,
              color: const Color(0xFF6C63FF), // Primary color
              width: 16,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ],
        ),
      );
      tempXAxisLabels[xIndex] = dataPoint.dateString;
      xIndex++;
    }

    _totalSales = _invoices.fold(0.0, (sum, invoice) => sum + (invoice["total"] as double));
    _totalInvoices = _invoices.length;

    setState(() {
      _barChartGroups = tempBarGroups;
      _xAxisLabels = tempXAxisLabels;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)), // Allow selecting today fully
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _fetchInvoiceData(); // Re-fetch and generate chart data
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    const Color primaryColor = Color(0xFF6C63FF);
    const Color secondaryColor = Color(0xFF4FC3F7);
    const Color backgroundColor = Color(0xFFF8F9FA);
    const Color cardColor = Colors.white;
    const Color textColor = Color(0xFF2D3748);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        elevation: 0,
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => authProvider.signOut(),
          ),
        ],
      ),
      body: Container(
        color: backgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Changed for better layout
            children: [
              // Profile Card
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, secondaryColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            (user?.email?.isNotEmpty == true ? user!.email![0] : "U").toUpperCase(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.email ?? "User",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              "Welcome back!", // Simpler message
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Quick Actions
              const Text(
                "Quick Actions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 15),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                childAspectRatio: 1, // Adjusted for better text fit
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildDashboardCard(
                    context,
                    icon: Icons.inventory_2_outlined,
                    title: "Items",
                    color: const Color(0xFF6C63FF),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>  ItemListPage()));
                    },
                  ),
                  _buildDashboardCard(
                    context,
                    icon: Icons.store_outlined,
                    title: "Vendors", // Plural
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>  VendorListPage()));
                    },
                  ),
                  _buildDashboardCard(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: "Invoices", // Plural
                    color: const Color(0xFFFF9800),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>  InvoiceListPage()));
                    },
                  ),
                  _buildDashboardCard(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: "Employee", // Plural
                    color: const Color(0xFFFF9800),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>  EmployeeListPage()));
                    },
                  ),
                  _buildDashboardCard(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: "Commission Reports", // Plural
                    color: const Color(0xFFFF9800),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CommissionReportPage()),
                      );                    },
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // Sales Analytics Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Sales Analytics",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _selectDateRange,
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            "${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd').format(_endDate)}",
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            "Total Sales",
                            "Rs. ${_totalSales.toStringAsFixed(2)}",
                            Icons.trending_up, // More relevant icon
                            const Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            "Total Invoices",
                            _totalInvoices.toString(),
                            Icons.receipt_outlined, // More relevant icon
                            const Color(0xFFFF9800),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Chart Section
                    if (_loadingChart)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_barChartGroups.isEmpty)
                      Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bar_chart_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              "No sales data for selected period",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        height: 230, // Adjusted for rotated labels
                        padding: const EdgeInsets.only(top: 10),
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _maxYValueForChart > 0 ? _maxYValueForChart * 1.2 : 100, // Give headroom or default
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  String dateKey = _xAxisLabels[group.x.toInt()] ?? '';
                                  return BarTooltipItem(
                                    '$dateKey\n',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    children: <TextSpan>[
                                      TextSpan(
                                        text: "Rs. ${rod.toY.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          color: rod.color ?? Colors.yellow, // Use rod color or default
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 38, // Increased for rotated labels
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    final String text = _xAxisLabels[value.toInt()] ?? '';
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      space: 4,
                                      angle: -0.785, // Rotate labels (approx 45 degrees)
                                      child: Text(text, style: const TextStyle(fontSize: 10, color: textColor)),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 45, // Adjusted for labels
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0 && _maxYValueForChart == 0) return const Text(''); // Avoid 0 if max is 0
                                    if (value == meta.max || value == meta.min || value % ((meta.max - meta.min)/4).clamp(1, double.infinity) == 0 ) { // Show ~5 labels
                                      return Padding(
                                        padding: const EdgeInsets.only(left:4.0),
                                        child: Text("Rs${value.toInt()}", style: const TextStyle(fontSize: 10, color: textColor)),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _barChartGroups,
                            gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: (
                                    _maxYValueForChart > 0 ? _maxYValueForChart / 4 : 20
                                ).clamp(1.0, double.infinity).toDouble(),
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 0.5);
                                }
                            ),
                          ),
                          swapAnimationDuration: const Duration(milliseconds: 250),
                          swapAnimationCurve: Curves.linear,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20), // Added some padding at the bottom
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13, // Slightly larger
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 17, // Slightly larger
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required IconData icon,
        required String title,
        required Color color,
        required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15), // Slightly increased shadow
              blurRadius: 10, // Softer shadow
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16), // Made icon background larger
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
              ),
              child: Icon(icon, size: 28, color: color), // Icon size adjusted
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15, // Adjusted size
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.9), // Slightly softer color
              ),
            )
          ],
        ),
      ),
    );
  }
}
