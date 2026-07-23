import 'json_utils.dart';

/// A reward the customer unlocks by crossing [targetAmount] in cart value —
/// drives the cart "unlock a free gift" progress bar.
class Gift {
  final String id;
  final String name;
  final double price;
  final double targetAmount;
  final String? image;

  const Gift({
    required this.id,
    required this.name,
    required this.price,
    required this.targetAmount,
    this.image,
  });

  factory Gift.fromJson(Map<String, dynamic> j) => Gift(
        id: asString(j['id']),
        name: asString(j['name']),
        price: asDouble(j['price']),
        targetAmount: asDouble(j['targetAmount']),
        image: asStringOrNull(j['image']),
      );
}
