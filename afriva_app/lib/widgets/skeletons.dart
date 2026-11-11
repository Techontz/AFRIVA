import 'package:flutter/rendering.dart' show SliverConstraints, SliverGridLayout, SliverGridRegularTileLayout;
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme.dart';
import 'poster_card.dart' show posterCaptionHeight, shelfItemWidth;

/// Shimmering wrapper for skeleton layouts.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: AppColors.shimmerHighlight,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 9 / 16, child: SkeletonBox(radius: AppRadii.poster)),
            SizedBox(height: 10),
            SkeletonBox(height: 12),
            SizedBox(height: 6),
            SkeletonBox(height: 10, width: 60),
          ],
        ),
      );
}

/// Placeholder shelf: a heading and a row of poster cards.
class ShelfSkeleton extends StatelessWidget {
  const ShelfSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = shelfItemWidth(MediaQuery.sizeOf(context).width);
    return SizedBox(
      height: w * 16 / 9 + posterCaptionHeight(MediaQuery.textScalerOf(context)),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => PosterCardSkeleton(width: w),
      ),
    );
  }
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key, this.topInset = 0});
  final double topInset;

  @override
  Widget build(BuildContext context) => Skeleton(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: topInset + 12),
          children: const [
            Center(child: SizedBox(width: 163, height: 290, child: SkeletonBox(radius: 18))),
            SizedBox(height: 24),
            Center(child: SkeletonBox(height: 26, width: 220)),
            SizedBox(height: 14),
            Center(child: SkeletonBox(height: 44, width: 200, radius: 22)),
            SizedBox(height: 34),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(alignment: Alignment.centerLeft, child: SkeletonBox(height: 18, width: 140)),
            ),
            SizedBox(height: 14),
            ShelfSkeleton(),
          ],
        ),
      );
}

class GridSkeleton extends StatelessWidget {
  const GridSkeleton({super.key, this.count = 9, this.topInset = 0});
  final int count;
  final double topInset;

  @override
  Widget build(BuildContext context) => Skeleton(
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16 + topInset, 16, 16),
          gridDelegate: posterGrid(context),
          itemCount: count,
          itemBuilder: (_, _) => const PosterCardSkeleton(),
        ),
      );
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 6, this.thumbWidth = 56});
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
                child: const AspectRatio(aspectRatio: 9 / 16, child: SkeletonBox()),
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

/// Standard poster grid: 3 columns on phones, more on tablets. Tiles are as
/// tall as a full 9:16 poster plus the caption under it.
SliverGridDelegate posterGrid(BuildContext context) =>
    PosterGridDelegate(textScaler: MediaQuery.textScalerOf(context));

class PosterGridDelegate extends SliverGridDelegate {
  const PosterGridDelegate({required this.textScaler});
  final TextScaler textScaler;

  static const _gapX = 12.0;
  static const _gapY = 22.0;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final w = constraints.crossAxisExtent;
    final columns = w >= 768 ? 5 : (w >= 600 ? 4 : 3);
    final tile = (w - _gapX * (columns - 1)) / columns;
    final h = tile * 16 / 9 + posterCaptionHeight(textScaler);
    return SliverGridRegularTileLayout(
      crossAxisCount: columns,
      mainAxisStride: h + _gapY,
      crossAxisStride: tile + _gapX,
      childMainAxisExtent: h,
      childCrossAxisExtent: tile,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(PosterGridDelegate old) => old.textScaler != textScaler;
}
