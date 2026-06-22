import 'json_utils.dart';

/// A promotional banner. `placement` mirrors the backend BannerPlacement enum
/// (HOME, MIDDLE, BOTTOM, DISCOUNT, OFFER, TOP_CATEGORY, MULTI_SECTION, ...).
class AppBanner {
  final String id;
  final String placement;
  final String imageUrl;
  final String? title;
  final int position;
  final String? categoryId;
  final String? subCategoryId;
  final String? sectionId;
  final String? sectionName;

  const AppBanner({
    required this.id,
    required this.placement,
    required this.imageUrl,
    this.title,
    this.position = 0,
    this.categoryId,
    this.subCategoryId,
    this.sectionId,
    this.sectionName,
  });

  factory AppBanner.fromJson(Map<String, dynamic> j) => AppBanner(
        id: asString(j['id']),
        placement: asString(j['placement']),
        imageUrl: asString(j['imageUrl']),
        title: asStringOrNull(j['title']),
        position: asInt(j['position']),
        categoryId: asStringOrNull(j['categoryId']),
        subCategoryId: asStringOrNull(j['subCategoryId']),
        sectionId: asStringOrNull(j['sectionId']),
        sectionName: asStringOrNull(j['sectionName']),
      );
}
