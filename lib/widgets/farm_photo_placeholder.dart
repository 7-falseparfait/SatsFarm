import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Farm photography slot with a deliberate vector fallback for offline use.
class FarmPhotoPlaceholder extends StatelessWidget {
  const FarmPhotoPlaceholder({
    required this.imageUrl,
    this.height,
    this.borderRadius = 24,
    this.icon = LucideIcons.sprout,
    this.overlay = true,
    this.child,
    super.key,
  });

  final String imageUrl;
  final double? height;
  final double borderRadius;
  final IconData icon;
  final bool overlay;
  final Widget? child;

  static const String northernFieldsImage =
      'https://images.unsplash.com/photo-1500382017468-9049fed747ef'
      '?auto=format&fit=crop&w=1400&q=85';

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _offlineFallback(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _offlineFallback(),
          ),
          if (overlay)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x120A2618), Color(0xCC0A2618)],
                ),
              ),
            ),
          ?child,
        ],
      ),
    ),
  );

  Widget _offlineFallback() => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF82965F), Color(0xFF254C35), Color(0xFF182D22)],
      ),
    ),
    child: Center(child: Icon(icon, size: 46, color: const Color(0x99FFFFFF))),
  );
}
