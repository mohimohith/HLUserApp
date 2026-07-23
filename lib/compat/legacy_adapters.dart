import '../data/models/address.dart';
import '../data/models/banner.dart';
import '../data/models/catalog.dart';
import '../data/models/collection.dart';
import '../data/models/order.dart';
import '../data/models/product.dart';

/// Converts the new typed backend models into the loosely-typed
/// `Map<String, dynamic>` shapes the legacy widgets read (`product['variants']`,
/// `product['images'][0]`, `banner['banner_image']`, ...).
///
/// IMPORTANT: image values produced here are already ABSOLUTE URLs (the new
/// backend returns full URLs), so the ported widgets render them directly
/// instead of prefixing the old `ApiConstants.BASE_URL + '/product_api_project/'`.
class LegacyAdapters {
  LegacyAdapters._();

  /// Product → old product map consumed by ProductCard / SpProduct / detail.
  static Map<String, dynamic> product(Product p) {
    return {
      'id': p.id,
      'name': p.name,
      'name_telugu': p.nameTelugu ?? '',
      'description': p.description ?? '',
      'category_id': p.categoryId,
      'brand_id': p.brandId ?? '',
      'brand_name': p.brandName ?? '',
      // List of absolute image URLs; widgets use images[0] directly.
      'images': p.images.map((i) => i.url).toList(),
      'image': p.primaryImage ?? '',
      'tags': p.tags,
      'attributes': p.attributes
          .map((a) => {'kind': a.kind, 'attribute': a.attribute, 'value': a.value})
          .toList(),
      'variants': p.variants.map(variant).toList(),
    };
  }

  static Map<String, dynamic> variant(ProductVariant v) => {
        'id': v.id,
        'name': v.name,
        'price': v.mrp,
        'selling_price': v.sellingPrice,
        'stock': v.stock,
      };

  static List<Map<String, dynamic>> products(Iterable<Product> list) =>
      list.map(product).toList();

  /// AppBanner → old banner map (`banner_image`, `category_id`, ...).
  static Map<String, dynamic> banner(AppBanner b) => {
        'banner_image': b.imageUrl,
        'image': b.imageUrl,
        'title': b.title ?? '',
        'category_id': b.categoryId ?? '',
        'subcategory_id': b.subCategoryId ?? '',
        'category_name': b.title ?? '',
        'category_image': b.imageUrl,
        'section_id': b.sectionId ?? '',
        'section_name': b.sectionName ?? '',
      };

  static List<Map<String, dynamic>> banners(Iterable<AppBanner> list) =>
      list.map(banner).toList();

  /// Category → old category/subcategory tile map.
  static Map<String, dynamic> category(Category c) => {
        'id': c.id,
        'category_id': c.id,
        'name': c.name,
        'category_name': c.name,
        'name_telugu': c.nameTelugu ?? '',
        'image': c.image ?? '',
        'category_image': c.image ?? '',
        'main_category_id': c.mainCategoryId,
        'subcategories': c.subCategories.map(subCategory).toList(),
      };

  static Map<String, dynamic> subCategory(SubCategory s) => {
        'id': s.id,
        'sub_category_name': s.name,
        'name': s.name,
        'name_telugu': s.nameTelugu ?? '',
        'sub_category_image': s.image ?? '',
        'image': s.image ?? '',
        'category_id': s.categoryId,
      };

  static Map<String, dynamic> mainCategory(MainCategory m) => {
        'id': m.id,
        'name': m.name,
        'name_telugu': m.nameTelugu ?? '',
        'image': m.image ?? '',
        'position': m.position,
        'categories': m.categories.map(category).toList(),
      };

  static Map<String, dynamic> brand(Brand b) => {
        'id': b.id,
        'brand_name': b.name,
        'name': b.name,
        'brand_image': b.image ?? '',
        'image': b.image ?? '',
      };

  /// Raw backend coupon map (from `/coupons/available`) → old coupon card map.
  static Map<String, dynamic> coupon(Map<String, dynamic> c) {
    final discountType = (c['discountType'] ?? '').toString();
    return {
      'code_name': c['code'] ?? '',
      'title': c['title'] ?? '',
      'description': c['description'] ?? '',
      'expri_date': c['expiresAt']?.toString() ?? '',
      'status': 'Public',
      'discount_type': discountType,
      'discount_value': c['discountValue'],
      'min_amount': c['minAmount'],
    };
  }

  /// ProductCollection → old special-category map.
  static Map<String, dynamic> productCollection(ProductCollection c) => {
        'id': c.id,
        'name': c.name,
        'banner_image': c.image ?? '',
        'products': products(c.products),
      };

  /// Order → old `{order: {...}, items: [...]}` shape consumed by order_screen,
  /// order_summary and track_order.
  static Map<String, dynamic> order(Order o) => {
        'order': {
          'id': o.orderNumber.isNotEmpty ? o.orderNumber : o.id,
          'order_id': o.id,
          'status': o.status,
          'final_amount': o.finalAmount,
          'grand_total': o.finalAmount,
          'amount': o.finalAmount,
          'items_total': o.itemsTotal,
          'discount_amount': o.discountAmount,
          'delivery_charge': o.deliveryCharge,
          'handling_charge': o.handlingCharge,
          'coupon_code': o.couponCode ?? '',
          'order_datetime': o.placedAt?.toIso8601String() ?? '',
          'order_date': o.placedAt?.toIso8601String() ?? '',
          'estimated_delivery_at': o.estimatedDeliveryAt?.toIso8601String() ?? '',
          'delivery_slot': o.deliverySlot ?? '',
          'payment_method': o.paymentMethod,
          'payment_status': o.paymentStatus,
          'status_label': o.statusLabel,
          'pipeline_index': o.pipelineIndex,
        },
        'items': o.items
            .map((it) => {
                  'id': it.id,
                  'name': it.productName,
                  'product_name': it.productName,
                  'variant_name': it.variantName ?? '',
                  'quantity': it.quantity,
                  'price': it.unitPrice,
                  'selling_price': it.unitPrice,
                  'line_total': it.lineTotal,
                  'image': it.imageUrl ?? '',
                  'image_url': it.imageUrl ?? '',
                })
            .toList(),
        'address': o.address == null ? null : address(o.address!),
      };

  static List<Map<String, dynamic>> orders(Iterable<Order> list) =>
      list.map(order).toList();

  /// DeliveryAddress → old address map.
  static Map<String, dynamic> address(DeliveryAddress a) => {
        'id': a.id,
        'name': a.name,
        'phone': a.phone,
        'full_address': a.fullAddress,
        'address': a.fullAddress,
        'pin_code': a.pinCode ?? '',
        'landmark': a.landmark ?? '',
        'is_default': a.isDefault,
        'latitude': a.latitude,
        'longitude': a.longitude,
      };

  static List<Map<String, dynamic>> addresses(Iterable<DeliveryAddress> list) =>
      list.map(address).toList();
}
