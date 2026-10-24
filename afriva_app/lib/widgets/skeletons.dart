import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme.dart';

/// Shimmering wrapper for skeleton layouts.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: const Color(0xFFFAFAFA),
        period: const Duration(milliseconds: 1300),
        child: child,
      );
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = 8});
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class PosterCardSkeleton extends StatelessWidget {
  const PosterCardSkeleton({super.key, this.width});
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 3 / 4, child: SkeletonBox(radius: AppRadii.poster)),
            SizedBox(height: 8),
            SkeletonBox(height: 12),
            SizedBox(height: 6),
            SkeletonBox(height: 10, width: 60),
            SizedBox(height: 6),
            SkeletonBox(height: 14, width: 44, radius: 999),
          ],
        ),
      );
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Skeleton(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const SkeletonBox(height: 200, radius: 10),
            const SizedBox(height: 12),
            for (var i = 0; i < 2; i++) ...[
              const SkeletonBox(height: 120, radius: 10),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            const SkeletonBox(height: 20, width: 140),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: posterGridDelegate,
              itemCount: 3,
              itemBuilder: (_, _) => const PosterCardSkeleton(),
            ),
          ],
        ),
      );
}

class GridSkeleton extends StatelessWidget {
  const GridSkeleton({super.key, this.count = 9});
  final int count;

  @override
  Widget build(BuildContext context) => Skeleton(
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: posterGridDelegate,
          itemCount: count,
          itemBuilder: (_, _) => const PosterCardSkeleton(),
        ),
      );
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 6, this.thumbWidth = 64});
  final int count;
  final double thumbWidth;

  @override
  Widget build(BuildContext context) => Skeleton(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, _) => Row(
            children: [
              SizedBox(
                width: thumbWidth,
                child: const AspectRatio(aspectRatio: 3 / 4, child: SkeletonBox()),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(height: 12, width: 120),
                    SizedBox(height: 8),
                    SkeletonBox(height: 10, width: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Standard 3-column poster grid.
const posterGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  crossAxisSpacing: 10,
  mainAxisSpacing: 16,
  childAspectRatio: 0.44,
);
