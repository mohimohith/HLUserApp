import 'json_utils.dart';

class Branch {
  final String id;
  final String name;
  final String? managerName;
  final String? phone;
  final bool isActive;

  const Branch({
    required this.id,
    required this.name,
    this.managerName,
    this.phone,
    this.isActive = true,
  });

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
        id: asString(j['id']),
        name: asString(j['name']),
        managerName: asStringOrNull(j['managerName']),
        phone: asStringOrNull(j['phone']),
        isActive: asBool(j['isActive'], true),
      );
}
