import 'banner.dart';
import 'json_utils.dart';

/// A homepage section header with its own banner strip (the backend joins the
/// MULTI_SECTION banners onto each section).
class HomeSection {
  final String id;
  final String name;
  final String? nameTelugu;
  final String? image;
  final int position;
  final List<AppBanner> banners;

  const HomeSection({
    required this.id,
    required this.name,
    this.nameTelugu,
    this.image,
    this.position = 0,
    this.banners = const [],
  });

  factory HomeSection.fromJson(Map<String, dynamic> j) => HomeSection(
        id: asString(j['id']),
        name: asString(j['name']),
        nameTelugu: asStringOrNull(j['nameTelugu']),
        image: asStringOrNull(j['image']),
        position: asInt(j['position']),
        banners: asMapList(j['banners']).map(AppBanner.fromJson).toList(),
      );
}
