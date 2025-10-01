import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class CommissionReportPage extends StatefulWidget {
  const CommissionReportPage({super.key});

  @override
  State<CommissionReportPage> createState() => _CommissionReportPageState();
}

class _CommissionReportPageState extends State<CommissionReportPage> {
  final DatabaseReference _invoicesRef = FirebaseDatabase.instance.ref().child('invoices');
  final DatabaseReference _employeesRef = FirebaseDatabase.instance.ref().child('employees');

  List<Map<String, dynamic>> _commissionData = [];
  List<Map<String, dynamic>> _employeeCommissionSummary = [];
  List<Map<String, dynamic>> _filteredCommissionData = [];

  bool _isLoading = true;
  String _errorMessage = '';
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String _selectedEmployee = 'All Employees';
  List<String> _employeeList = ['All Employees'];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCommissionData();
    _searchController.addListener(_filterCommissionData);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCommissionData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load employees for filter
      final employeesSnapshot = await _employeesRef.get();
      if (employeesSnapshot.exists) {
        final employeesData = Map<dynamic, dynamic>.from(employeesSnapshot.value as Map);
        _employeeList = ['All Employees'];
        _employeeList.addAll(
          employeesData.entries.map((entry) {
            final employee = Map<String, dynamic>.from(entry.value as Map);
            return (employee['name'] ?? 'Unknown').toString(); // 👈 force String
          }),
        );
      }

      // Load invoices with commissions
      final invoicesSnapshot = await _invoicesRef.get();
      if (!mounted) return;

      if (invoicesSnapshot.exists) {
        final invoicesData = Map<dynamic, dynamic>.from(invoicesSnapshot.value as Map);
        final List<Map<String, dynamic>> loadedCommissions = [];

        invoicesData.forEach((invoiceId, invoiceData) {
          final invoice = Map<String, dynamic>.from(invoiceData as Map);
          final commissionAmount = (invoice['commissionAmount'] ?? 0.0).toDouble();
          final employeeId = invoice['employeeId'];
          final employeeName = invoice['employeeName'];
          final createdAt = DateTime.parse(invoice['createdAt'] ?? DateTime.now().toIso8601String());

          // Only include invoices with commission and within date range
          if (commissionAmount > 0 &&
              employeeId != null &&
              createdAt.isAfter(_dateRange.start) &&
              createdAt.isBefore(_dateRange.end.add(const Duration(days: 1)))) {

            loadedCommissions.add({
              'invoiceId': invoiceId,
              'invoiceNumber': invoice['invoiceNumber'] ?? 'N/A',
              'employeeId': employeeId,
              'employeeName': employeeName ?? 'Unknown Employee',
              'customerName': invoice['customerName'] ?? 'N/A',
              'commissionAmount': commissionAmount,
              'commissionIsPercentage': invoice['commissionIsPercentage'] ?? false,
              'commissionValue': (invoice['commissionValue'] ?? 0.0).toDouble(),
              'subtotal': (invoice['subtotal'] ?? 0.0).toDouble(),
              'total': (invoice['total'] ?? 0.0).toDouble(),
              'createdAt': createdAt,
              'commissionPaid': invoice['commissionPaid'] ?? false,
              'commissionPaidDate': invoice['commissionPaidDate'],
            });
          }
        });

        // Sort by date descending
        loadedCommissions.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));

        setState(() {
          _commissionData = loadedCommissions;
          _filteredCommissionData = List.from(_commissionData);
          _calculateEmployeeSummary();
          _isLoading = false;
        });
      } else {
        setState(() {
          _commissionData = [];
          _filteredCommissionData = [];
          _employeeCommissionSummary = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Error loading commission data: $e";
        _isLoading = false;
      });
    }
  }

  void _calculateEmployeeSummary() {
    final Map<String, Map<String, dynamic>> summaryMap = {};

    for (final commission in _commissionData) {
      final employeeName = commission['employeeName'];
      final amount = commission['commissionAmount'];
      final isPaid = commission['commissionPaid'] ?? false;

      if (!summaryMap.containsKey(employeeName)) {
        summaryMap[employeeName] = {
          'employeeName': employeeName,
          'totalCommission': 0.0,
          'paidCommission': 0.0,
          'pendingCommission': 0.0,
          'invoiceCount': 0,
        };
      }

      summaryMap[employeeName]!['totalCommission'] += amount;
      summaryMap[employeeName]!['invoiceCount'] += 1;

      if (isPaid) {
        summaryMap[employeeName]!['paidCommission'] += amount;
      } else {
        summaryMap[employeeName]!['pendingCommission'] += amount;
      }
    }

    setState(() {
      _employeeCommissionSummary = summaryMap.values.toList()
        ..sort((a, b) => b['totalCommission'].compareTo(a['totalCommission']));
    });
  }

  void _filterCommissionData() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty && _selectedEmployee == 'All Employees') {
        _filteredCommissionData = List.from(_commissionData);
      } else {
        _filteredCommissionData = _commissionData.where((commission) {
          final matchesSearch = query.isEmpty ||
              commission['employeeName'].toLowerCase().contains(query) ||
              commission['customerName'].toLowerCase().contains(query) ||
              commission['invoiceNumber'].toLowerCase().contains(query);

          final matchesEmployee = _selectedEmployee == 'All Employees' ||
              commission['employeeName'] == _selectedEmployee;

          return matchesSearch && matchesEmployee;
        }).toList();
      }
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );

    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
      _loadCommissionData();
    }
  }

  Future<void> _markAsPaid(Map<String, dynamic> commission) async {
    try {
      await _invoicesRef.child(commission['invoiceId']).update({
        'commissionPaid': true,
        'commissionPaidDate': DateTime.now().toIso8601String(),
      });

      // Update employee's commission status
      final employeeSnapshot = await _employeesRef.child(commission['employeeId']).get();
      if (employeeSnapshot.exists) {
        final employeeData = Map<String, dynamic>.from(employeeSnapshot.value as Map);
        final currentPending = (employeeData['pendingCommission'] ?? 0.0).toDouble();
        final currentPaid = (employeeData['paidCommission'] ?? 0.0).toDouble();

        await _employeesRef.child(commission['employeeId']).update({
          'pendingCommission': currentPending - commission['commissionAmount'],
          'paidCommission': currentPaid + commission['commissionAmount'],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commission marked as paid for ${commission['employeeName']}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCommissionData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking commission as paid: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double get _totalCommission => _commissionData.fold(0.0, (sum, commission) => sum + commission['commissionAmount']);
  double get _totalPaidCommission => _commissionData.fold(0.0, (sum, commission) => sum + (commission['commissionPaid'] ? commission['commissionAmount'] : 0));
  double get _totalPendingCommission => _totalCommission - _totalPaidCommission;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Commission Reports', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6C63FF),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadCommissionData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : _errorMessage.isNotEmpty
          ? _buildErrorWidget()
          : _buildCommissionReport(),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF))),
          SizedBox(height: 16),
          Text('Loading Commission Data...', style: TextStyle(color: Color(0xFF6C63FF))),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCommissionData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommissionReport() {
    return Column(
      children: [
        // Filters Section
        _buildFiltersSection(),

        // Summary Cards
        _buildSummaryCards(),

        // Charts Section
        _buildChartsSection(),

        // Data Section
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: const Color(0xFF6C63FF),
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Employee Summary'),
                    Tab(text: 'Commission Details'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildEmployeeSummaryTab(),
                      _buildCommissionDetailsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by employee, customer, invoice...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedEmployee,
                  items: _employeeList.map((employee) {
                    return DropdownMenuItem<String>(
                      value: employee,
                      child: Text(employee),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedEmployee = value!;
                    });
                    _filterCommissionData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  '${DateFormat('dd MMM yyyy').format(_dateRange.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange.end)}',
                ),
                onPressed: _selectDateRange,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                  side: const BorderSide(color: Color(0xFF6C63FF)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Commission',
              'Rs. ${_totalCommission.toStringAsFixed(2)}',
              const Color(0xFF6C63FF),
              Icons.attach_money,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Pending',
              'Rs. ${_totalPendingCommission.toStringAsFixed(2)}',
              Colors.orange,
              Icons.pending_actions,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Paid',
              'Rs. ${_totalPaidCommission.toStringAsFixed(2)}',
              Colors.green,
              Icons.check_circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    if (_employeeCommissionSummary.isEmpty) {
      return Container();
    }

    return SizedBox(
      height: 200,
      child: SfCircularChart(
        title: ChartTitle(text: 'Commission Distribution'),
        legend: Legend(isVisible: true, position: LegendPosition.bottom),
        series: <CircularSeries>[
          DoughnutSeries<Map<String, dynamic>, String>(
            dataSource: _employeeCommissionSummary,
            xValueMapper: (data, _) => data['employeeName'],
            yValueMapper: (data, _) => data['totalCommission'],
            dataLabelMapper: (data, _) => '${data['employeeName']}\nRs. ${data['totalCommission'].toStringAsFixed(0)}',
            dataLabelSettings: const DataLabelSettings(isVisible: true),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeSummaryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _employeeCommissionSummary.length,
      itemBuilder: (context, index) {
        final summary = _employeeCommissionSummary[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary['employeeName'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItem('Total', 'Rs. ${summary['totalCommission'].toStringAsFixed(2)}', const Color(0xFF6C63FF)),
                    _buildSummaryItem('Paid', 'Rs. ${summary['paidCommission'].toStringAsFixed(2)}', Colors.green),
                    _buildSummaryItem('Pending', 'Rs. ${summary['pendingCommission'].toStringAsFixed(2)}', Colors.orange),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Invoices: ${summary['invoiceCount']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildCommissionDetailsTab() {
    if (_filteredCommissionData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 50, color: Colors.grey),
            SizedBox(height: 16),
            Text('No commission records found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCommissionData.length,
      itemBuilder: (context, index) {
        final commission = _filteredCommissionData[index];
        final isPaid = commission['commissionPaid'] ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: isPaid ? Colors.green : Colors.orange,
              child: Icon(
                isPaid ? Icons.check : Icons.pending,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              commission['employeeName'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice: ${commission['invoiceNumber']}'),
                Text('Customer: ${commission['customerName']}'),
                Text('Date: ${DateFormat('dd MMM yyyy').format(commission['createdAt'])}'),
                Text(
                  'Commission: Rs. ${commission['commissionAmount'].toStringAsFixed(2)} '
                      '(${commission['commissionIsPercentage'] ? '${commission['commissionValue']}%' : 'Fixed'})',
                  style: TextStyle(
                    color: const Color(0xFF6C63FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Rs. ${commission['commissionAmount'].toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isPaid ? Colors.green : Colors.orange,
                  ),
                ),
                if (!isPaid) ...[
                  const SizedBox(height: 4),
                  ElevatedButton(
                    onPressed: () => _markAsPaid(commission),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: const Text('Mark Paid', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}