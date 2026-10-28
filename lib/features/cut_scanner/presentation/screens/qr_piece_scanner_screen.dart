import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/services/qr_cut_payload_parser.dart';
import '../widgets/scanned_piece_bottom_sheet.dart';
import '../widgets/scanner_error_view.dart';
import '../widgets/scanner_overlay_painter.dart';

class QrPieceScannerScreen extends StatefulWidget {
  const QrPieceScannerScreen({super.key});

  @override
  State<QrPieceScannerScreen> createState() => _QrPieceScannerScreenState();
}

class _QrPieceScannerScreenState extends State<QrPieceScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animationController;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      formats: const [BarcodeFormat.qrCode],
      autoStart: true,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String rawValue) async {
    if (_isProcessing || !mounted) return;
    _isProcessing = true;

    final result = QrCutPayloadParser.parse(rawValue);

    if (result.isValid && result.pieceInfo != null) {
      // Haptic feedback for positive identification
      HapticFeedback.mediumImpact();

      // Pause scanner while sheet is open
      try {
        await _controller.stop();
      } catch (_) {}

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ScannedPieceBottomSheet(
          piece: result.pieceInfo!,
          onScanAnother: () {
            // Callback when "مسح قطعة أخرى" is pressed
          },
        ),
      );

      // Sheet was dismissed: resume scanning
      if (mounted) {
        _isProcessing = false;
        try {
          await _controller.start();
        } catch (_) {}
      }
    } else {
      // Haptic feedback for error/invalid code
      HapticFeedback.lightImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'رمز غير معروف'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 1.5s cooldown before accepting next barcode to prevent toast spam
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        _isProcessing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Camera Viewfinder or Error Fallback
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    _handleBarcode(raw);
                    break;
                  }
                }
              },
              errorBuilder: (context, error) {
                return ScannerErrorView(
                  errorMessage: error.errorDetails?.message ?? 'تعذر تشغيل الكاميرا في هذا الجهاز',
                  onRetry: () {
                    setState(() {});
                    _controller.start();
                  },
                  onSimulateCode: (code) => _handleBarcode(code),
                );
              },
            ),

            // 2. Animated Overlay & Laser Sweep (only when camera is active)
            LayoutBuilder(
              builder: (context, constraints) {
                final windowSize = (constraints.maxWidth * 0.72).clamp(240.0, 320.0);
                final center = Offset(
                  constraints.maxWidth / 2,
                  constraints.maxHeight / 2 - 20,
                );
                final scanWindow = Rect.fromCenter(
                  center: center,
                  width: windowSize,
                  height: windowSize,
                );

                return AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: ScannerOverlayPainter(
                        scanWindow: scanWindow,
                        animationProgress: _animationController.value,
                      ),
                    );
                  },
                );
              },
            ),

            // 3. Top Action Bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),

                    // Title
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, color: AppColors.amberPrimary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'ماسح قطع الألمنيوم',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Flash (Torch) toggle
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _controller,
                      builder: (context, state, _) {
                        final isTorchOn = state.torchState == TorchState.on;
                        return IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isTorchOn
                                  ? AppColors.amberPrimary
                                  : Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: isTorchOn ? Colors.black : Colors.white,
                              size: 20,
                            ),
                          ),
                          onPressed: () => _controller.toggleTorch(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 4. Bottom Hint Label
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Text(
                    'وجّه الكاميرا نحو ملصق QR الموجود على قضيب الألمنيوم',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
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
