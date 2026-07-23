import '../data/models/banner.dart';
import '../data/models/catalog.dart';
import '../data/models/collection.dart';
import '../data/models/home_data.dart';
import '../data/models/section.dart';
import 'legacy_adapters.dart';

/// Maps the aggregated `HomeData` payload into the loosely-typed lists the legacy
/// `homeScreen.dart` widgets read. The old PHP backend scattered data across ~20
/// endpoints; the new `/home` endpoint returns everything in one shot, so this
/// adapter distributes into the exact bucket shapes the old build tree expects.
class LegacyHome {
  LegacyHome._();

  /// Produce the complete legacy state map consumed by homeScreen.dart.
  static Map<String, dynamic> from(HomeData d) => {
        // ---- Header ----
        'homeBannerImage': d.bannersFor('HOME').isNotEmpty
            ? d.bannersFor('HOME').first.imageUrl
            : null,
        'branchName': d.branchName ?? '',
        'deliveryTime': d.settings.deliveryTimeText,

        // ---- Banner placeholders ----
        'offerBanners': LegacyAdapters.banners(d.bannersFor('OFFER')),
        'discountBanner':
            d.bannersFor('DISCOUNT').isNotEmpty ? d.bannersFor('DISCOUNT').first.imageUrl : null,
        'occasionBanner':
            d.bannersFor('OCCASION').isNotEmpty ? d.bannersFor('OCCASION').first.imageUrl : null,
        'occasionCategoryList':
            LegacyAdapters.banners(d.bannersFor('OCCASION_CATEGORY')),
        'middleBannerImage':
            d.bannersFor('MIDDLE').isNotEmpty ? d.bannersFor('MIDDLE').first.imageUrl : null,
        'bottomBannerImage':
            d.bannersFor('BOTTOM').isNotEmpty ? d.bannersFor('BOTTOM').first.imageUrl : null,

        // ---- Top categories ----
        'topCategoryList': LegacyAdapters.banners(d.topCategories),

        // ---- Main categories (strip) ----
        'mainCategoryList': d.mainCategories
            .map(LegacyAdapters.mainCategory)
            .toList(),

        // ---- Category position lists (first/second/third/fourth are
        //      simulated by splitting sorted mainCategories) ----
        'mainFirstCategoryList': _firstN(d.mainCategories, 0),
        'mainSecondCategoryList': _firstN(d.mainCategories, 1),
        'mainThirdCategoryList': _firstN(d.mainCategories, 2),
        'mainFourthCategoryList': _firstN(d.mainCategories, 3),

        // ---- Brands ----
        'brandList': d.brands.map(LegacyAdapters.brand).toList(),

        // ---- Slider / carousel (uses any category-linked banners) ----
        'sliderList': [
          ...d.bannersFor('OFFER'),
          ...d.bannersFor('TOP_CATEGORY'),
          ...d.topCategories,
        ].map(LegacyAdapters.banner).toList(),

        // ---- Sections 1-6 + extra (mapped from new section model) ----
        'sectionList': d.sections.map(_section).toList(),

        // ---- Collections / special-category equivalents ----
        'specialCategories': d.specialCollections.map(_collection).toList(),

        // ---- Best-selling products ----
        'bestSellingProducts': LegacyAdapters.products(d.bestSelling),
      };

  /// HomeSection → old section map (public).
  static Map<String, dynamic> section(HomeSection s) => _section(s);

  /// HomeSection → old section map with section_image, section_name, name_telugu, id.
  /// Public so homeScreen can reference it for section list splitting.
  static Map<String, dynamic> sectionMap(String sectionId, String sectionName,
      String? nameTelugu, String? sectionImage, List<AppBanner> banners) => {
        'id': sectionId,
        'section_name': sectionName,
        'name_telugu': nameTelugu ?? '',
        'section_image': sectionImage ?? '',
        'banners': LegacyAdapters.banners(banners),
      };

  static Map<String, dynamic> _section(HomeSection s) => {
        'id': s.id,
        'section_name': s.name,
        'name_telugu': s.nameTelugu ?? '',
        'section_image': s.image ?? '',
        // Flatten MULTI_SECTION banners into the old products list when needed
        'banners': LegacyAdapters.banners(s.banners),
      };

  /// Collection → old special-category map.
  static Map<String, dynamic> _collection(ProductCollection c) => {
        'id': c.id,
        'name': c.name,
        'banner_image': c.image ?? '',
        'products': LegacyAdapters.products(c.products),
      };

  /// Grab one "position" slot from the sorted list (wrap around if too few).
  static List<Map<String, dynamic>> _firstN(
      List<MainCategory> list, int position) {
    // Each "position" in the old app was one main-category block with its
    // subcategories. We distribute the sorted list across 4 slots.
    final perSlot = (list.length / 4).ceil();
    final start = position * perSlot;
    final end = (start + perSlot).clamp(0, list.length);
    if (start >= list.length) return [];
    return list.sublist(start, end).map(LegacyAdapters.mainCategory).toList();
  }
}
