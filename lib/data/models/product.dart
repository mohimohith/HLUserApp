import 'json_utils.dart';

/// A single sellable size/pack of a product (e.g. "500 g", "1 L").
class ProductVariant {
  final String id;
  final String name;
  final double mrp;
  final double sellingPrice;
  final double? wholesalePrice;
  final int stock;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.mrp,
    required this.sellingPrice,
    this.wholesalePrice,
    required this.stock,
  });

  bool get inStock => stock > 0;
  double get savings => (mrp - sellingPrice).clamp(0, double.infinity);

  /// Discount as a whole-number percentage, 0 when there's no markdown.
  int get discountPercent {
    if (mrp <= 0 || sellingPrice >= mrp) return 0;
    return (((mrp - sellingPrice) / mrp) * 100).round();
  }

  factory ProductVariant.fromJson(Map<String, dynamic> j) => ProductVariant(
        id: asString(j['id']),
        name: asString(j['name']),
        mrp: asDouble(j['mrp']),
        sellingPrice: asDouble(j['sellingPrice']),
        wholesalePrice: asDoubleOrNull(j['wholesalePrice']),
        stock: asInt(j['stock']),
      );
}

class ProductImage {
  final String id;
  final String url;
  final int position;

  const ProductImage({required this.id, required this.url, required this.position});

  factory ProductImage.fromJson(Map<String, dynamic> j) => ProductImage(
        id: asString(j['id']),
        url: asString(j['url']),
        position: asInt(j['position']),
      );
}

/// A product highlight or info row (kind = HIGHLIGHT | INFO on the backend).
class ProductAttribute {
  final String kind;
  final String attribute;
  final String value;

  const ProductAttribute({
    required this.kind,
    required this.attribute,
    required this.value,
  });

  bool get isHighlight => kind == 'HIGHLIGHT';

  factory ProductAttribute.fromJson(Map<String, dynamic> j) => ProductAttribute(
        kind: asString(j['kind']),
        attribute: asString(j['attribute']),
        value: asString(j['value']),
      );
}

class Product {
  final String id;
  final String name;
  final String? nameTelugu;
  final String? description;
  final List<String> tags;
  final String categoryId;
  final String? brandId;
  final String? brandName;
  final List<ProductVariant> variants;
  final List<ProductImage> images;
  final List<ProductAttribute> attributes;

  const Product({
    required this.id,
    required this.name,
    this.nameTelugu,
    this.description,
    this.tags = const [],
    required this.categoryId,
    this.brandId,
    this.brandName,
    this.variants = const [],
    this.images = const [],
    this.attributes = const [],
  });

  /// The cheapest active variant — what we show on cards by default.
  ProductVariant? get defaultVariant =>
      variants.isEmpty ? null : variants.first;

  String? get primaryImage => images.isNotEmpty ? images.first.url : null;

  double get displayPrice => defaultVariant?.sellingPrice ?? 0;
  double get displayMrp => defaultVariant?.mrp ?? 0;
  int get discountPercent => defaultVariant?.discountPercent ?? 0;
  bool get inStock => variants.any((v) => v.inStock);

  factory Product.fromJson(Map<String, dynamic> j) {
    final brand = j['brand'];
    return Product(
      id: asString(j['id']),
      name: asString(j['name']),
      nameTelugu: asStringOrNull(j['nameTelugu']),
      description: asStringOrNull(j['description']),
      tags: (j['tags'] is List)
          ? (j['tags'] as List).map((e) => e.toString()).toList()
          : const [],
      categoryId: asString(j['categoryId']),
      brandId: asStringOrNull(j['brandId']),
      brandName: brand is Map ? asStringOrNull(brand['name']) : null,
      variants: asMapList(j['variants']).map(ProductVariant.fromJson).toList(),
      images: asMapList(j['images']).map(ProductImage.fromJson).toList(),
      attributes:
          asMapList(j['attributes']).map(ProductAttribute.fromJson).toList(),
    );
  }
}
