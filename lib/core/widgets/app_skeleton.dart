import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class AppSkeleton extends StatelessWidget {
  final Widget child;

  const AppSkeleton({
    super.key,
    required this.child,
  });

  static Widget box({
    required double width,
    required double height,
    double radius = 12,
  }) {
    return AppSkeleton(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  static Widget circle({required double size}) {
    return AppSkeleton(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF0E8EC),
      highlightColor: Colors.white,
      period: const Duration(milliseconds: 1150),
      child: child,
    );
  }
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 120.h),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        AppSkeleton(
          child: Container(
            height: 155.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
            ),
          ),
        ),
        SizedBox(height: 26.h),
        const _SectionLine(),
        SizedBox(height: 16.h),
        GridView.builder(
          itemCount: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 14.w,
            mainAxisSpacing: 18.h,
            childAspectRatio: .74,
          ),
          itemBuilder: (_, __) {
            return Column(
              children: [
                Expanded(
                  child: AppSkeleton(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                AppSkeleton(
                  child: Container(
                    width: 65.w,
                    height: 10.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: 28.h),
        const _SectionLine(),
        SizedBox(height: 14.h),
        SizedBox(
          height: 250.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => SizedBox(width: 14.w),
            itemBuilder: (_, __) {
              return AppSkeleton(
                child: Container(
                  width: 172.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22.r),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CategoriesSkeleton extends StatelessWidget {
  const CategoriesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 120.h),
      itemCount: 12,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14.w,
        mainAxisSpacing: 22.h,
        childAspectRatio: .82,
      ),
      itemBuilder: (_, __) {
        return Column(
          children: [
            Expanded(
              child: AppSkeleton(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22.r),
                  ),
                ),
              ),
            ),
            SizedBox(height: 9.h),
            AppSkeleton(
              child: Container(
                width: 72.w,
                height: 11.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ProductCardsSkeleton extends StatelessWidget {
  const ProductCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => SizedBox(width: 14.w),
        itemBuilder: (_, __) {
          return AppSkeleton(
            child: Container(
              width: 172.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22.r),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLine extends StatelessWidget {
  const _SectionLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppSkeleton(
          child: Container(
            width: 70.w,
            height: 12.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
        ),
        const Spacer(),
        AppSkeleton(
          child: Container(
            width: 130.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
        ),
      ],
    );
  }
}
