import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double animationProgress; // 0.0 to 1.0

  const ScannerOverlayPainter({
    required this.scanWindow,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark semi-transparent background
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final windowRRect = RRect.fromRectAndRadius(
      scanWindow,
      const Radius.circular(18),
    );

    final windowPath = Path()..addRRect(windowRRect);

    // Cut out the scan window
    final transparentCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      windowPath,
    );
    canvas.drawPath(transparentCutout, backgroundPaint);

    // 2. Window border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(windowRRect, borderPaint);

    // 3. Golden corner brackets
    final cornerPaint = Paint()
      ..color = AppColors.amberPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;
    final r = scanWindow;

    // Top-left
    canvas.drawLine(Offset(r.left, r.top + cornerLength), Offset(r.left, r.top + 8), cornerPaint);
    canvas.drawLine(Offset(r.left + 8, r.top), Offset(r.left + cornerLength, r.top), cornerPaint);

    // Top-right
    canvas.drawLine(Offset(r.right - cornerLength, r.top), Offset(r.right - 8, r.top), cornerPaint);
    canvas.drawLine(Offset(r.right, r.top + 8), Offset(r.right, r.top + cornerLength), cornerPaint);

    // Bottom-left
    canvas.drawLine(Offset(r.left, r.bottom - cornerLength), Offset(r.left, r.bottom - 8), cornerPaint);
    canvas.drawLine(Offset(r.left + 8, r.bottom), Offset(r.left + cornerLength, r.bottom), cornerPaint);

    // Bottom-right
    canvas.drawLine(Offset(r.right - cornerLength, r.bottom), Offset(r.right - 8, r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.right, r.bottom - 8), Offset(r.right, r.bottom - cornerLength), cornerPaint);

    // 4. Animated Laser Line
    final laserY = scanWindow.top + (scanWindow.height * animationProgress);
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.amberPrimary.withValues(alpha: 0.0),
          AppColors.amberPrimary,
          AppColors.amberPrimary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(scanWindow.left, laserY, scanWindow.width, 2))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(scanWindow.left + 12, laserY),
      Offset(scanWindow.right - 12, laserY),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.scanWindow != scanWindow;
  }
}
