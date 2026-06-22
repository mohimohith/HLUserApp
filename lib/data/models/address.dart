import 'json_utils.dart';

class DeliveryAddress {
  final String id;
  final String name;
  final String phone;
  final String fullAddress;
  final String? pinCode;
  final String? landmark;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const DeliveryAddress({
    required this.id,
    required this.name,
    required this.phone,
    required this.fullAddress,
    this.pinCode,
    this.landmark,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> j) => DeliveryAddress(
        id: asString(j['id']),
        name: asString(j['name']),
        phone: asString(j['phone']),
        fullAddress: asString(j['fullAddress']),
        pinCode: asStringOrNull(j['pinCode']),
        landmark: asStringOrNull(j['landmark']),
        latitude: asDoubleOrNull(j['latitude']),
        longitude: asDoubleOrNull(j['longitude']),
        isDefault: asBool(j['isDefault']),
      );

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        'phone': phone,
        'fullAddress': fullAddress,
        if (pinCode != null) 'pinCode': pinCode,
        if (landmark != null) 'landmark': landmark,
        'isDefault': isDefault,
      };
}
