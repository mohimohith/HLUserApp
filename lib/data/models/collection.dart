import 'json_utils.dart';
import 'product.dart';

/// A merchandised group of products (best-selling / special), rendered as a
/// horizontal rail on the homepage. `type` mirrors backend CollectionType.
class ProductCollection {
  final String id;
  final String type;
  final String name;
  final String? image;
  final List<Product> products;

  const ProductCollection({
    required this.id,
    required this.type,
    required this.name,
    this.image,
    this.products = const [],
  });

  bool get isBestSelling => type == 'BEST_SELLING';

  factory ProductCollection.fromJson(Map<String, dynamic> j) =>
      ProductCollection(
        id: asString(j['id']),
        type: asString(j['type']),
        name: asString(j['name']),
        image: asStringOrNull(j['image']),
        products: asMapList(j['products']).map(Product.fromJson).toList(),
      );
}
