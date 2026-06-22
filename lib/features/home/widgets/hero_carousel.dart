import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../data/models/banner.dart';

/// Auto-playing hero banner carousel with a smooth page indicator.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key, required this.banners, this.onTap});

  final List<AppBanner> banners;
  final void Function(AppBanner banner)? onTap;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 160,
            viewportFraction: 0.92,
            autoPlay: widget.banners.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            enlargeCenterPage: true,
            enlargeFactor: 0.18,
            onPageChanged: (i, _) => setState(() => _current = i),
          ),
          items: widget.banners.map((b) {
            return GestureDetector(
              onTap: () => widget.onTap?.call(b),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: b.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(color: const Color(0xffF0E9F6)),
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xffF0E9F6)),
                ),
              ),
            );
          }).toList(),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 10),
          AnimatedSmoothIndicator(
            activeIndex: _current,
            count: widget.banners.length,
            effect: const ExpandingDotsEffect(
              dotHeight: 7,
              dotWidth: 7,
              expansionFactor: 3,
              activeDotColor: Color(0xff960ad7),
              dotColor: Color(0xffDCCDE8),
            ),
          ),
        ],
      ],
    );
  }
}
