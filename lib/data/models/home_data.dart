import 'banner.dart';
import 'branch_settings.dart';
import 'catalog.dart';
import 'collection.dart';
import 'json_utils.dart';
import 'product.dart';
import 'section.dart';

/// The entire customer homepage in one object — the typed view of the
/// aggregated `GET /home` response that replaced ~30 legacy round-trips.
class HomeData {
  final String? branchId;
  final String? branchName;
  final BranchSettings settings;

  /// Banners grouped by placement string (HOME, MIDDLE, BOTTOM, OFFER, ...).
  final Map<String, List<AppBanner>> bannersByPlacement;
  final List<AppBanner> topCategories;

  final List<MainCategory> mainCategories;
  final List<Category> categories;
  final List<Brand> brands;
  final List<HomeSection> sections;
  final List<ProductCollection> collections;
  final List<Product> bestSelling;

  const HomeData({
    this.branchId,
    this.branchName,
    required this.settings,
    this.bannersByPlacement = const {},
    this.topCategories = const [],
    this.mainCategories = const [],
    this.categories = const [],
    this.brands = const [],
    this.sections = const [],
    this.collections = const [],
    this.bestSelling = const [],
  });

  List<AppBanner> bannersFor(String placement) =>
      bannersByPlacement[placement] ?? const [];

  /// The hero carousel: HOME placement, falling back to OFFER.
  List<AppBanner> get heroBanners {
    final home = bannersFor('HOME');
    return home.isNotEmpty ? home : bannersFor('OFFER');
  }

  List<ProductCollection> get specialCollections =>
      collections.where((c) => !c.isBestSelling).toList();

  factory HomeData.fromJson(Map<String, dynamic> j) {
    final branch = j['branch'];
    final settingsJson = j['settings'];

    final rawBanners = j['banners'];
    final grouped = <String, List<AppBanner>>{};
    if (rawBanners is Map) {
      rawBanners.forEach((key, value) {
        if (value is List) {
          grouped[key.toString()] = value
              .whereType<Map>()
              .map((e) => AppBanner.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      });
    }

    return HomeData(
      branchId: branch is Map ? asStringOrNull(branch['id']) : null,
      branchName: branch is Map ? asStringOrNull(branch['name']) : null,
      settings: settingsJson is Map
          ? BranchSettings.fromJson(Map<String, dynamic>.from(settingsJson))
          : const BranchSettings(),
      bannersByPlacement: grouped,
      topCategories:
          asMapList(j['topCategories']).map(AppBanner.fromJson).toList(),
      mainCategories:
          asMapList(j['mainCategories']).map(MainCategory.fromJson).toList(),
      categories: asMapList(j['categories']).map(Category.fromJson).toList(),
      brands: asMapList(j['brands']).map(Brand.fromJson).toList(),
      sections: asMapList(j['sections']).map(HomeSection.fromJson).toList(),
      collections:
          asMapList(j['collections']).map(ProductCollection.fromJson).toList(),
      bestSelling: asMapList(j['bestSelling']).map(Product.fromJson).toList(),
    );
  }
}
