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
}
