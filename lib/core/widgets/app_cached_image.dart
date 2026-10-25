import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppCachedImage extends StatelessWidget {
  final String image;
  final BoxFit fit;
  final IconData icon;
  final String? fallbackKey;

  const AppCachedImage({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.icon = Icons.image_rounded,
    this.fallbackKey,
  });

  @override
  Widget build(BuildContext context) {
    final cleanImage = image.trim();

    if (cleanImage.isEmpty) return _fallback();

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
        return Image.memory(
          base64Decode(cleanImage.split(',').last),
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
      return Image.memory(
        base64Decode(cleanImage),
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
      color: AppColors.softPink.withOpacity(.45),
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

  String _fallbackAsset() {
    final key = (fallbackKey ?? '').toLowerCase();
    if (key.contains('كريب') || key.contains('crepe')) {
      return 'assets/images/default_crepe.jpg';
    }
    if (key.contains('فرايد') ||
        key.contains('تشيكن') ||
        key.contains('فراخ') ||
        key.contains('استربس') ||
        key.contains('زنجر') ||
        key.contains('بانيه') ||
        key.contains('كرانشي') ||
        key.contains('chicken')) {
      return 'assets/images/default_fried_chicken.jpg';
    }
    return 'assets/images/default_sandwich.jpg';
  }

  Widget _fallback() {
    return Image.asset(
      _fallbackAsset(),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.softPink,
        child: Icon(icon, color: AppColors.primary, size: 28.sp),
      ),
    );
  }
}
