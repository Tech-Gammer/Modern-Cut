class Employee {
  final String? id;
  final String name;
  final String fatherName;
  final String phoneNumber;
  final String address;
  final DateTime createdAt;
  final double totalCommission;
  final double pendingCommission;
  final double paidCommission;

  Employee({
    this.id,
    required this.name,
    required this.fatherName,
    required this.phoneNumber,
    required this.address,
    required this.createdAt,
    this.totalCommission = 0.0,
    this.pendingCommission = 0.0,
    this.paidCommission = 0.0,
  });

  factory Employee.fromJson(String id, Map<dynamic, dynamic> json) {
    return Employee(
      id: id,
      name: json['name'] ?? '',
      fatherName: json['fatherName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      address: json['address'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      totalCommission: (json['totalCommission'] ?? 0.0).toDouble(),
      pendingCommission: (json['pendingCommission'] ?? 0.0).toDouble(),
      paidCommission: (json['paidCommission'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'fatherName': fatherName,
      'phoneNumber': phoneNumber,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'totalCommission': totalCommission,
      'pendingCommission': pendingCommission,
      'paidCommission': paidCommission,
    };
  }
}