import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/models/catalog.dart';

/// Horizontal scroller of main categories with circular thumbnails.
class CategoryStrip extends StatelessWidget {
  const CategoryStrip({super.key, required this.categories, this.onTap});

  final List<MainCategory> categories;
  final void Function(MainCategory category)? onTap;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 102,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final c = categories[i];
          return GestureDetector(
            onTap: () => onTap?.call(c),
            child: Column(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: const Color(0xffF5F0F8),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xffEADBF2)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: c.image != null && c.image!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: c.image!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.category_outlined, color: Color(0xffB99BD0)),
                        )
                      : const Icon(Icons.category_outlined, color: Color(0xffB99BD0)),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 70,
                  child: Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
