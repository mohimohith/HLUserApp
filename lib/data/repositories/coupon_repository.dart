import '../../core/network/api_client.dart';
import '../models/coupon.dart';

class CouponRepository {
  CouponRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<CouponValidation> validate({
    required String branchId,
    required String code,
    required double amount,
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/coupons/validate',
      query: {'branchId': branchId, 'code': code, 'amount': amount},
    );
    return CouponValidation.fromJson(res.data);
  }

  /// Public list of active, non-expired coupons for the branch (raw backend
  /// maps; adapt via [LegacyAdapters.coupon] for the legacy coupon cards).
  Future<List<Map<String, dynamic>>> available(String branchId) async {
    try {
      final res = await _api.get<List<dynamic>>(
        '/coupons/available',
        query: {'branchId': branchId},
      );
      return res.data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
