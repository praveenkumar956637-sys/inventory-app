import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Shows a product picture.
/// [imageUrl] can be an https link, or an asset path like assets/images/cement.png.
/// When it is empty, or the picture cannot load, a grey box icon is shown.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    this.size = 48,
    this.borderRadius = 12,
  });

  final String imageUrl;
  final double size;
  final double borderRadius;

  Widget _placeholder() {
    return Container(
      height: size,
      width: size,
      color: AppColors.lightGrey,
      child: Icon(
        Icons.inventory_2_outlined,
        color: AppColors.darkBlack,
        size: size * 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String path = imageUrl.trim();
    final Widget child;

    if (path.isEmpty) {
      child = _placeholder();
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      child = Image.network(
        path,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _placeholder();
        },
        loadingBuilder:
            (BuildContext context, Widget loaded, ImageChunkEvent? progress) {
              if (progress == null) return loaded;
              return SizedBox(
                height: size,
                width: size,
                child: const Center(
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              );
            },
      );
    } else {
      child = Image.asset(
        path,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _placeholder();
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }
}
