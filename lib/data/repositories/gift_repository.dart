import '../../core/network/api_client.dart';
import '../models/gift.dart';

/// Active gifts for a branch (public). Returns an empty list on any failure so
/// the cart gift bar simply hides rather than blocking the screen.
class GiftRepository {
  GiftRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<Gift>> list(String branchId) async {
    try {
      final res = await _api.get<List<dynamic>>(
        '/gifts',
        query: {'branchId': branchId},
      );
      return res.data
          .whereType<Map>()
          .map((e) => Gift.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
