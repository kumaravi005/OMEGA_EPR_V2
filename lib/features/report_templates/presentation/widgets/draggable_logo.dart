import 'package:flutter/material.dart';

/// The logo within the A4 preview's header strip - drag to move, drag the
/// corner handle to resize. All positions/sizes are reported back as
/// fractions (0..1) of the header area, not pixels, so they mean the
/// same thing regardless of how big the preview happens to be rendered -
/// matching [LogoPlacement] in `core/export/report_branding.dart`. This
/// is the one genuinely free-form "move/resize" interaction the designer
/// offers - every other element is a show/hide toggle plus a text field,
/// per "keep the editor simple".
class DraggableLogo extends StatelessWidget {
  const DraggableLogo({
    super.key,
    required this.logoUrl,
    required this.xFraction,
    required this.yFraction,
    required this.widthFraction,
    required this.headerSize,
    required this.onChanged,
  });

  final String logoUrl;
  final double xFraction;
  final double yFraction;
  final double widthFraction;
  final Size headerSize;

  /// Called with the updated (x, y, width) fractions whenever the admin
  /// drags or resizes the logo.
  final void Function(double x, double y, double width) onChanged;

  @override
  Widget build(BuildContext context) {
    final width = (widthFraction * headerSize.width).clamp(24.0, headerSize.width);
    final left = (xFraction * headerSize.width).clamp(0.0, headerSize.width - width);
    final top = (yFraction * headerSize.height).clamp(0.0, headerSize.height);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) {
          final newX = ((left + details.delta.dx) / headerSize.width).clamp(0.0, 1.0 - widthFraction);
          final newY = ((top + details.delta.dy) / headerSize.height).clamp(0.0, 1.0);
          onChanged(newX, newY, widthFraction);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1)),
              child: Image.network(
                logoUrl,
                width: width,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: width,
                  height: width,
                  alignment: Alignment.center,
                  color: Colors.black12,
                  child: const Icon(Icons.broken_image_outlined, size: 18),
                ),
              ),
            ),
            Positioned(
              right: -7,
              bottom: -7,
              child: GestureDetector(
                onPanUpdate: (details) {
                  final newWidth = ((width + details.delta.dx) / headerSize.width).clamp(0.04, 1.0 - xFraction);
                  onChanged(xFraction, yFraction, newWidth);
                },
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.open_in_full, size: 9, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
