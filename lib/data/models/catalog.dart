import 'json_utils.dart';

class Brand {
  final String id;
  final String name;
  final String? image;

  const Brand({required this.id, required this.name, this.image});

  factory Brand.fromJson(Map<String, dynamic> j) => Brand(
        id: asString(j['id']),
        name: asString(j['name']),
        image: asStringOrNull(j['image']),
      );
}

class SubCategory {
  final String id;
  final String name;
  final String? nameTelugu;
  final String? image;
  final String categoryId;

  const SubCategory({
    required this.id,
    required this.name,
    this.nameTelugu,
    this.image,
    required this.categoryId,
  });

  factory SubCategory.fromJson(Map<String, dynamic> j) => SubCategory(
        id: asString(j['id']),
        name: asString(j['name']),
        nameTelugu: asStringOrNull(j['nameTelugu']),
        image: asStringOrNull(j['image']),
        categoryId: asString(j['categoryId']),
      );
}

class Category {
  final String id;
  final String name;
  final String? nameTelugu;
  final String? image;
  final String mainCategoryId;
  final List<SubCategory> subCategories;

  const Category({
    required this.id,
    required this.name,
    this.nameTelugu,
    this.image,
    required this.mainCategoryId,
    this.subCategories = const [],
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: asString(j['id']),
        name: asString(j['name']),
        nameTelugu: asStringOrNull(j['nameTelugu']),
        image: asStringOrNull(j['image']),
        mainCategoryId: asString(j['mainCategoryId']),
        subCategories:
            asMapList(j['subCategories']).map(SubCategory.fromJson).toList(),
      );
}

class MainCategory {
  final String id;
  final String name;
  final String? nameTelugu;
  final String? image;
  final int position;
  final List<Category> categories;

  const MainCategory({
    required this.id,
    required this.name,
    this.nameTelugu,
    this.image,
    this.position = 0,
    this.categories = const [],
  });

  factory MainCategory.fromJson(Map<String, dynamic> j) => MainCategory(
        id: asString(j['id']),
        name: asString(j['name']),
        nameTelugu: asStringOrNull(j['nameTelugu']),
        image: asStringOrNull(j['image']),
        position: asInt(j['position']),
        categories: asMapList(j['categories']).map(Category.fromJson).toList(),
      );
}
