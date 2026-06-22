import 'json_utils.dart';

/// Per-branch storefront configuration: charges, thresholds and help contacts.
class BranchSettings {
  final double deliveryCharge;
  final double handlingCharge;
  final double? freeDeliveryThreshold;
  final double minOrderAmount;
  final String deliveryTimeText;
  final String? helpCallNumber;
  final String? helpEmail;
  final String? helpWhatsapp;

  const BranchSettings({
    this.deliveryCharge = 0,
    this.handlingCharge = 0,
    this.freeDeliveryThreshold,
    this.minOrderAmount = 0,
    this.deliveryTimeText = '30 Minutes',
    this.helpCallNumber,
    this.helpEmail,
    this.helpWhatsapp,
  });

  /// Delivery charge after applying the free-delivery threshold for [subtotal].
  double effectiveDeliveryCharge(double subtotal) {
    final t = freeDeliveryThreshold;
    if (t != null && subtotal >= t) return 0;
    return deliveryCharge;
  }

  factory BranchSettings.fromJson(Map<String, dynamic> j) => BranchSettings(
        deliveryCharge: asDouble(j['deliveryCharge']),
        handlingCharge: asDouble(j['handlingCharge']),
        freeDeliveryThreshold: asDoubleOrNull(j['freeDeliveryThreshold']),
        minOrderAmount: asDouble(j['minOrderAmount']),
        deliveryTimeText: asString(j['deliveryTimeText'], '30 Minutes'),
        helpCallNumber: asStringOrNull(j['helpCallNumber']),
        helpEmail: asStringOrNull(j['helpEmail']),
        helpWhatsapp: asStringOrNull(j['helpWhatsapp']),
      );
}
