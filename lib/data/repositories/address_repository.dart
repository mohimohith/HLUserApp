import '../../core/network/api_client.dart';
import '../models/address.dart';

class AddressRepository {
  AddressRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<DeliveryAddress>> list() async {
    final res = await _api.get<List<dynamic>>('/addresses');
    return res.data
        .whereType<Map>()
        .map((e) => DeliveryAddress.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DeliveryAddress> create({
    required String name,
    required String phone,
    required String fullAddress,
    String? pinCode,
    String? landmark,
    bool isDefault = false,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/addresses',
      body: {
        'name': name,
        'phone': phone,
        'fullAddress': fullAddress,
        if (pinCode != null) 'pinCode': pinCode,
        if (landmark != null) 'landmark': landmark,
        'isDefault': isDefault,
      },
    );
    return DeliveryAddress.fromJson(res.data);
  }

  Future<DeliveryAddress> update(String id, Map<String, dynamic> patch) async {
    final res = await _api.patch<Map<String, dynamic>>('/addresses/$id', body: patch);
    return DeliveryAddress.fromJson(res.data);
  }

  Future<void> remove(String id) => _api.delete('/addresses/$id');
}
