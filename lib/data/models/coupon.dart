import 'json_utils.dart';

/// Result of `GET /coupons/validate`. On success `valid` is true and [discount]
/// holds the computed rupee discount; otherwise [reason] explains the failure.
class CouponValidation {
  final bool valid;
  final double discount;
  final String? reason;
  final double? minAmount;
  final String? code;

  const CouponValidation({
    required this.valid,
    this.discount = 0,
    this.reason,
    this.minAmount,
    this.code,
  });

  String get failureMessage {
    switch (reason) {
      case 'expired':
        return 'This coupon has expired.';
      case 'min_amount':
        return 'Add items worth ₹${minAmount?.toStringAsFixed(0) ?? ''} to use this coupon.';
      default:
        return 'This coupon cannot be applied.';
    }
  }

  factory CouponValidation.fromJson(Map<String, dynamic> j) {
    final coupon = j['coupon'];
    return CouponValidation(
      valid: asBool(j['valid']),
      discount: asDouble(j['discount']),
      reason: asStringOrNull(j['reason']),
      minAmount: asDoubleOrNull(j['minAmount']),
      code: coupon is Map ? asStringOrNull(coupon['code']) : null,
    );
  }
}
