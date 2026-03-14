import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

enum ProfileImageType { base64, network, assetImage }

/// A widget to display a profile picture from various sources (base64, network URL, or asset).
/// it automatically detects the type of the image based on the provided string.
class ProfilePictureWidget extends StatelessWidget {
  /// Creates a ProfilePicture widget. which displays an image based on the provided [imageValue].
  /// and automatically detects the type of image (base64, network URL, or asset).
  const ProfilePictureWidget({
    super.key,
    required this.imageValue,
    required this.size,
    this.imageType,
    this.borderRadius,
    this.backgroundColor,
    this.errorColor,
    this.centerImageProgressLoader = true,
  });

  final String imageValue;
  final double size;
  final double? borderRadius;
  final Color? errorColor;
  final Color? backgroundColor;
  final ProfileImageType? imageType;

  /// Center the CircularProgress indicator loader
  final bool centerImageProgressLoader;

  @override
  Widget build(BuildContext context) {
    final type = imageType ?? _detectType();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? size / 2),
      child: Container(
        width: size,
        height: size,
        color: backgroundColor ?? Colors.grey.shade200,
        child: _buildImage(type),
      ),
    );
  }

  Widget _buildImage(ProfileImageType type) {
    switch (type) {
      case ProfileImageType.base64:
        try {
          final decodedBytes = base64Decode(imageValue);
          return Image.memory(
            decodedBytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallback(),
          );
        } catch (_) {
          return _buildFallback();
        }

      case ProfileImageType.network:
        return CachedNetworkImage(
          imageUrl: imageValue,
          fit: BoxFit.cover,
          progressIndicatorBuilder: (context, url, progress) {
            if (centerImageProgressLoader) {
              return const Center(child: CircularProgressIndicator());
            }
            return const CircularProgressIndicator();
          },
          errorWidget: (_, __, ___) => _buildFallback(),
        );

      case ProfileImageType.assetImage:
        return Image.asset(
          imageValue,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
    }
  }

  Widget _buildFallback() {
    return Center(
      child: Icon(Icons.broken_image),
    );
  }

  ProfileImageType _detectType() {
    if (imageValue.isEmpty) return ProfileImageType.assetImage;

    if (imageValue.startsWith('http://') || imageValue.startsWith('https://')) {
      return ProfileImageType.network;
    }

    final base64RegExp = RegExp(r'^[A-Za-z0-9+/=]+$');
    if (base64RegExp.hasMatch(imageValue) && imageValue.length % 4 == 0) {
      return ProfileImageType.base64;
    }

    return ProfileImageType.assetImage;
  }
}
