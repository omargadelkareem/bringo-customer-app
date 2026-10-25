import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppCachedImage extends StatelessWidget {
  final String image;
  final BoxFit fit;
  final IconData icon;

  const AppCachedImage({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.icon = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final cleanImage = image.trim();

    if (cleanImage.isEmpty) {
      return _fallback();
    }

    if (cleanImage.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: cleanImage,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => _loading(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }

    if (cleanImage.startsWith('data:image')) {
      try {
        final base64String = cleanImage.split(',').last;
        final bytes = base64Decode(base64String);

        return Image.memory(
          bytes,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      } catch (_) {
        return _fallback();
      }
    }

    try {
      final bytes = base64Decode(cleanImage);

      return Image.memory(
        bytes,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } catch (_) {
      return _fallback();
    }
  }

  Widget _loading() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF4F6F5),
      child: Center(
        child: SizedBox(
          width: 22.w,
          height: 22.w,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF4F6F5),
      alignment: Alignment.center,
      child: Container(
        width: 48.w,
        height: 48.w,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppColors.primary.withOpacity(.72),
          size: 25.sp,
        ),
      ),
    );
  }
}
