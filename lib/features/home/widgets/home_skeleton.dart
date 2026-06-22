import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Full-page shimmer placeholder shown on the very first home load, shaped to
/// match the real layout so the transition to content feels seamless.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xffEDE7F2),
      highlightColor: const Color(0xffF8F5FB),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _box(double.infinity, 44, radius: 12), // search
            const SizedBox(height: 16),
            _box(double.infinity, 150, radius: 16), // hero
            const SizedBox(height: 20),
            _box(120, 16), // section title
            const SizedBox(height: 12),
            SizedBox(
              height: 84,
              child: Row(
                children: List.generate(
                  4,
                  (_) => const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: _Circle(size: 64),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _box(160, 16),
            const SizedBox(height: 12),
            SizedBox(
              height: 210,
              child: Row(
                children: List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: _CardSkeleton(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(double w, double h, {double radius = 8}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      );
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      );
}
