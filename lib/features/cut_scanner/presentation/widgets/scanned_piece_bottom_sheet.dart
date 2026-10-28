import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../projects/presentation/screens/project_detail_screen.dart';
import '../../../rules/data/rules_repository.dart';
import '../../domain/models/scanned_piece_info.dart';

class ScannedPieceBottomSheet extends ConsumerWidget {
  final ScannedPieceInfo piece;
  final VoidCallback onScanAnother;

  const ScannedPieceBottomSheet({
    super.key,
    required this.piece,
    required this.onScanAnother,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String workshopId = ref.watch(activeWorkshopIdProvider) ?? '';
    final query = (workshopId: workshopId, projectId: piece.projectId);
    final projectAsync = ref.watch(projectDetailProvider(query));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 14,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : AppColors.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Row: Status Chip & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: piece.isFromRemnant
                              ? Colors.purple.withValues(alpha: 0.15)
                              : AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: piece.isFromRemnant
                                ? Colors.purple.withValues(alpha: 0.4)
                                : AppColors.success.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              piece.isFromRemnant ? Icons.recycling_rounded : Icons.check_circle_rounded,
                              size: 14,
                              color: piece.isFromRemnant ? Colors.purple : AppColors.success,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              piece.isFromRemnant ? 'من فضلة مخزنة' : 'قضيب خام جديد 660سم',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: piece.isFromRemnant ? Colors.purple : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate700 : AppColors.slate200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'قضيب #${piece.barNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.slate300 : AppColors.slate700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Piece Name & Large Length Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            AppColors.amberPrimary.withValues(alpha: 0.12),
                            AppColors.darkSurface,
                          ]
                        : [
                            AppColors.amberPrimary.withValues(alpha: 0.08),
                            Colors.white,
                          ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.amberPrimary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            piece.nameArabic.isNotEmpty ? piece.nameArabic : piece.itemCode,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'كود الصنف: ${piece.itemCode}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.slate400 : AppColors.slate500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.straighten_rounded, size: 14, color: AppColors.slate400),
                              const SizedBox(width: 4),
                              Text(
                                'زوايا القص: ${piece.cutAngleLeft} / ${piece.cutAngleRight}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.slate300 : AppColors.slate600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Big Length Display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.amberPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.amberPrimary.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${piece.lengthCm}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.amberPrimary,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'سنتيمتر',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.amberPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Project & Unit Context Details
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800.withValues(alpha: 0.5) : AppColors.slate100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.slate700 : AppColors.slate200,
                  ),
                ),
                child: Column(
                  children: [
                    // Unit Tag
                    Row(
                      children: [
                        const Icon(Icons.window_rounded, size: 18, color: AppColors.amberPrimary),
                        const SizedBox(width: 10),
                        const Text(
                          'عنصر القياس:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            piece.unitTag.isNotEmpty ? piece.unitTag : 'غير محدد في الوسم',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.slate300 : AppColors.slate700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),

                    // Project Details (Enriched if found, fallback if offline)
                    projectAsync.when(
                      data: (project) {
                        if (project != null) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.folder_open_rounded, size: 18, color: AppColors.info),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'المشروع:',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      project.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (project.clientName.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.slate400),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'العميل:',
                                      style: TextStyle(fontSize: 12, color: AppColors.slate400),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        project.clientName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.slate300 : AppColors.slate700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          );
                        } else {
                          // Offline fallback or project not yet loaded
                          return Row(
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.slate400),
                              const SizedBox(width: 10),
                              const Text(
                                'معرف المشروع:',
                                style: TextStyle(fontSize: 12, color: AppColors.slate400),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  piece.projectId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                      loading: () => const Row(
                        children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('جاري التحقق من المشروع...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      error: (_, _) => Row(
                        children: [
                          const Icon(Icons.offline_bolt_rounded, size: 18, color: AppColors.warning),
                          const SizedBox(width: 10),
                          const Text('مشروع مخزن محلياً', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text('مسح قطعة أخرى'),
                      onPressed: () {
                        Navigator.pop(context);
                        onScanAnother();
                      },
                    ),
                  ),
                  if (piece.projectId.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amberPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('فتح المشروع'),
                        onPressed: () {
                          Navigator.pop(context); // close bottom sheet
                          context.push('/dashboard/owner/projects/${piece.projectId}?workshopId=$workshopId');
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
