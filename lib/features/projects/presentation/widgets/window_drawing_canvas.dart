import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:meqyas/app/theme/app_colors.dart';

class WindowDrawingCanvas extends StatelessWidget {
  final double widthCm;
  final double heightCm;
  final int sashCount;
  final bool hasScreen;
  final String unitType;
  final String glazingMode;
  final String color;

  const WindowDrawingCanvas({
    super.key,
    required this.widthCm,
    required this.heightCm,
    this.sashCount = 2,
    this.hasScreen = true,
    this.unitType = 'window',
    this.glazingMode = 'single',
    this.color = 'white',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D141C) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Drafting Grid Background
            Positioned.fill(
              child: CustomPaint(
                painter: _BlueprintGridPainter(isDark: isDark),
              ),
            ),

            // Interactive Zoom & Pan Canvas
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.5,
              boundaryMargin: const EdgeInsets.all(80),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: AspectRatio(
                    aspectRatio: widthCm > 0 && heightCm > 0
                        ? math.max(0.4, math.min(2.5, widthCm / heightCm))
                        : 1.0,
                    child: CustomPaint(
                      painter: _Window2DPainter(
                        widthCm: widthCm,
                        heightCm: heightCm,
                        sashCount: sashCount,
                        hasScreen: hasScreen,
                        unitType: unitType,
                        glazingMode: glazingMode,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top-left Blueprint Label Badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.architecture_rounded, size: 16, color: AppColors.glassBlueLight),
                    const SizedBox(width: 6),
                    Text(
                      'مخطط هندسي مقياسي (CAD)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom-right Scale Information
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Text(
                  '${widthCm.toStringAsFixed(1)} × ${heightCm.toStringAsFixed(1)} سم',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: AppColors.amberLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlueprintGridPainter extends CustomPainter {
  final bool isDark;

  const _BlueprintGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.45)
          : const Color(0xFFCBD5E1).withValues(alpha: 0.4)
      ..strokeWidth = 0.8;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintGridPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _Window2DPainter extends CustomPainter {
  final double widthCm;
  final double heightCm;
  final int sashCount;
  final bool hasScreen;
  final String unitType;
  final String glazingMode;
  final bool isDark;

  const _Window2DPainter({
    required this.widthCm,
    required this.heightCm,
    required this.sashCount,
    required this.hasScreen,
    required this.unitType,
    required this.glazingMode,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (widthCm <= 0 || heightCm <= 0) return;

    // Leave margin for dimension arrows
    const margin = 32.0;
    final drawArea = Rect.fromLTWH(
      margin,
      margin,
      size.width - (margin * 2),
      size.height - (margin * 2),
    );

    // Frame Profile Paints
    final frameFillPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;

    final frameBorderPaint = Paint()
      ..color = isDark ? AppColors.slate300 : AppColors.slate700
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final sashBorderPaint = Paint()
      ..color = isDark ? AppColors.amberLight : AppColors.amberPrimary
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final glassFillPaint = Paint()
      ..color = glazingMode == 'double'
          ? const Color(0xFF0284C7).withValues(alpha: isDark ? 0.35 : 0.25)
          : const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.25 : 0.15)
      ..style = PaintingStyle.fill;

    // 1. Draw Outer Frame Track & Jambs
    canvas.drawRect(drawArea, frameFillPaint);
    canvas.drawRect(drawArea, frameBorderPaint);

    // Track profile thickness visual scale
    final trackThickness = math.max(6.0, drawArea.height * 0.055);
    final jambThickness = math.max(6.0, drawArea.width * 0.045);

    final innerRect = Rect.fromLTWH(
      drawArea.left + jambThickness,
      drawArea.top + trackThickness,
      drawArea.width - (jambThickness * 2),
      drawArea.height - (trackThickness * 2),
    );

    // 2. Calculate Sashes with Overlap
    final sashes = sashCount <= 0 ? 2 : sashCount;
    const overlapFraction = 0.04; // standard 4% sash interlock overlap
    final singleSashWidth =
        (innerRect.width / sashes) + (innerRect.width * overlapFraction);
    final sashHeight = innerRect.height;

    for (var i = 0; i < sashes; i++) {
      final leftPos = innerRect.left + (i * (innerRect.width - singleSashWidth) / (sashes - 1));
      final sashRect = Rect.fromLTWH(leftPos, innerRect.top, singleSashWidth, sashHeight);

      // Draw Sash Profile Border
      canvas.drawRect(sashRect, sashBorderPaint);

      // Glass Pane inside Sash
      final sashProfileInset = math.max(5.0, singleSashWidth * 0.08);
      final glassRect = Rect.fromLTWH(
        sashRect.left + sashProfileInset,
        sashRect.top + sashProfileInset,
        sashRect.width - (sashProfileInset * 2),
        sashRect.height - (sashProfileInset * 2),
      );

      canvas.drawRect(glassRect, glassFillPaint);

      // Glass reflection diagonal highlight line
      final reflectionPaint = Paint()
        ..color = Colors.white.withValues(alpha: isDark ? 0.25 : 0.4)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(glassRect.left + 10, glassRect.bottom - 10),
        Offset(glassRect.right - 10, glassRect.top + 10),
        reflectionPaint,
      );

      // Draw Sash Handle
      final handlePaint = Paint()
        ..color = isDark ? Colors.white : Colors.black87
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      final handleX = i == 0 ? sashRect.right - (sashProfileInset / 2) : sashRect.left + (sashProfileInset / 2);
      final handleY = sashRect.top + (sashRect.height / 2);
      canvas.drawLine(
        Offset(handleX, handleY - 14),
        Offset(handleX, handleY + 14),
        handlePaint,
      );

      // Sliding Direction Arrow (<- or ->)
      _drawSlidingArrow(
        canvas: canvas,
        center: Offset(sashRect.center.dx, sashRect.bottom - 16),
        isLeft: i % 2 == 0,
        isDark: isDark,
      );
    }

    // 3. Draw Screen Mesh Texture if enabled (on the right sash by default)
    if (hasScreen) {
      final screenWidth = singleSashWidth * 0.95;
      final screenRect = Rect.fromLTWH(
        innerRect.right - screenWidth,
        innerRect.top,
        screenWidth,
        sashHeight,
      );

      final meshPaint = Paint()
        ..color = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)
        ..strokeWidth = 0.6;

      for (double mx = screenRect.left; mx < screenRect.right; mx += 6) {
        canvas.drawLine(Offset(mx, screenRect.top), Offset(mx, screenRect.bottom), meshPaint);
      }
      for (double my = screenRect.top; my < screenRect.bottom; my += 6) {
        canvas.drawLine(Offset(screenRect.left, my), Offset(screenRect.right, my), meshPaint);
      }
    }

    // 4. Engineering Dimension Callouts
    _drawDimensionLine(
      canvas: canvas,
      start: Offset(drawArea.left, 14),
      end: Offset(drawArea.right, 14),
      label: '${widthCm.toStringAsFixed(1)} سم',
      isDark: isDark,
      isVertical: false,
    );

    _drawDimensionLine(
      canvas: canvas,
      start: Offset(size.width - 12, drawArea.top),
      end: Offset(size.width - 12, drawArea.bottom),
      label: '${heightCm.toStringAsFixed(1)} سم',
      isDark: isDark,
      isVertical: true,
    );
  }

  void _drawSlidingArrow({
    required Canvas canvas,
    required Offset center,
    required bool isLeft,
    required bool isDark,
  }) {
    final arrowPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const length = 16.0;
    final startX = isLeft ? center.dx + (length / 2) : center.dx - (length / 2);
    final endX = isLeft ? center.dx - (length / 2) : center.dx + (length / 2);

    canvas.drawLine(Offset(startX, center.dy), Offset(endX, center.dy), arrowPaint);

    final tipX = isLeft ? endX + 4 : endX - 4;
    canvas.drawLine(Offset(endX, center.dy), Offset(tipX, center.dy - 3), arrowPaint);
    canvas.drawLine(Offset(endX, center.dy), Offset(tipX, center.dy + 3), arrowPaint);
  }

  void _drawDimensionLine({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required String label,
    required bool isDark,
    required bool isVertical,
  }) {
    final dimPaint = Paint()
      ..color = AppColors.amberPrimary
      ..strokeWidth = 1.2;

    canvas.drawLine(start, end, dimPaint);

    // Witness marks / arrows
    if (!isVertical) {
      canvas.drawLine(Offset(start.dx, start.dy - 4), Offset(start.dx, start.dy + 4), dimPaint);
      canvas.drawLine(Offset(end.dx, end.dy - 4), Offset(end.dx, end.dy + 4), dimPaint);
    } else {
      canvas.drawLine(Offset(start.dx - 4, start.dy), Offset(start.dx + 4, start.dy), dimPaint);
      canvas.drawLine(Offset(end.dx - 4, end.dy), Offset(end.dx + 4, end.dy), dimPaint);
    }

    // Text Label
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: isDark ? AppColors.amberLight : AppColors.amberPrimary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        fontFamily: 'Cairo',
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.rtl,
    );
    textPainter.layout();

    final mid = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );

    if (!isVertical) {
      textPainter.paint(
        canvas,
        Offset(mid.dx - (textPainter.width / 2), mid.dy - textPainter.height - 2),
      );
    } else {
      textPainter.paint(
        canvas,
        Offset(mid.dx - textPainter.width - 6, mid.dy - (textPainter.height / 2)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Window2DPainter oldDelegate) {
    return oldDelegate.widthCm != widthCm ||
        oldDelegate.heightCm != heightCm ||
        oldDelegate.sashCount != sashCount ||
        oldDelegate.hasScreen != hasScreen ||
        oldDelegate.unitType != unitType ||
        oldDelegate.glazingMode != glazingMode ||
        oldDelegate.isDark != isDark;
  }
}
