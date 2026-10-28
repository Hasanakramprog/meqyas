import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class ScannerErrorView extends StatefulWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<String> onSimulateCode;

  const ScannerErrorView({
    super.key,
    required this.errorMessage,
    required this.onRetry,
    required this.onSimulateCode,
  });

  @override
  State<ScannerErrorView> createState() => _ScannerErrorViewState();
}

class _ScannerErrorViewState extends State<ScannerErrorView> {
  final _testController = TextEditingController();

  @override
  void dispose() {
    _testController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.no_photography_rounded,
                  size: 48,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'الكاميرا غير متوفرة أو الإذن معلق',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.errorMessage.isNotEmpty
                    ? widget.errorMessage
                    : 'يرجى التأكد من منح تطبيق مقياس إذن استخدام الكاميرا لمسح ملصقات قطع الألمنيوم.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amberPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
                onPressed: widget.onRetry,
              ),
              const SizedBox(height: 28),

              // Manual testing card (useful for emulators & workshop manual lookup)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.terminal_rounded, size: 18, color: AppColors.amberPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'تجربة فحص كود يدوياً (للمحاكي والاختبار)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.slate300 : AppColors.slate700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _testController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: 'ألصق كود JSON أو جرب الكود الافتراضي...',
                        hintStyle: const TextStyle(fontSize: 11),
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('كود تجريبي نموذج', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              const sample = '{"v":1,"p":"sample_proj","u":"شباك الصالون #1","i":"kaab","n":"كعب 2000 مفرد","l":58.75,"b":1,"r":false}';
                              _testController.text = sample;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.slate700 : AppColors.slate300,
                            foregroundColor: isDark ? Colors.white : Colors.black87,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('فحص', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            if (_testController.text.trim().isNotEmpty) {
                              widget.onSimulateCode(_testController.text.trim());
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
