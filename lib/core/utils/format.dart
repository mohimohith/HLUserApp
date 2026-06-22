/// Currency / number formatting helpers shared across the new UI.
class Money {
  Money._();

  /// Formats a rupee amount with the ₹ symbol and no trailing decimals when
  /// whole (e.g. 49 → "₹49", 49.5 → "₹49.50").
  static String rupees(num value) {
    final isWhole = value == value.roundToDouble();
    return isWhole ? '₹${value.toStringAsFixed(0)}' : '₹${value.toStringAsFixed(2)}';
  }
}
