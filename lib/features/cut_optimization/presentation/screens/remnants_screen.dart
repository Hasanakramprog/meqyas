import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../rules/data/rules_repository.dart';
import '../../data/cut_plan_repository.dart';

class RemnantsScreen extends ConsumerStatefulWidget {
  final String workshopId;
  final bool embedded;

  const RemnantsScreen({
    super.key,
    required this.workshopId,
    this.embedded = false,
  });

  @override
  ConsumerState<RemnantsScreen> createState() => _RemnantsScreenState();
}

class _RemnantsScreenState extends ConsumerState<RemnantsScreen> {
  bool _showAvailableOnly = true;
  String? _filterItemCode;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final remnantsAsync = ref.watch(remnantsProvider(widget.workshopId));

    final content = remnantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ في تحميل الفضلات: $e')),
      data: (allRemnants) {
        final filtered = allRemnants.where((r) {
          if (_showAvailableOnly && !r.isAvailable) return false;
            if (_filterItemCode != null && r.itemCode != _filterItemCode) {
              return false;
            }
            return true;
          }).toList();

          // Map itemCode -> Arabic display name
          final itemNameByCode = <String, String>{};
          for (final r in allRemnants) {
            if (r.nameArabic.isNotEmpty) {
              itemNameByCode[r.itemCode] = r.nameArabic;
            }
          }
          final itemCodes = allRemnants
              .map((r) => r.itemCode)
              .toSet()
              .toList()
            ..sort();

          // Available remnants summary per item
          final availableSummary = <String, _ItemSummary>{};
          for (final r in allRemnants.where((r) => r.isAvailable)) {
            availableSummary.putIfAbsent(
              r.itemCode,
              () => _ItemSummary(
                nameArabic: r.nameArabic,
                count: 0,
                totalLengthCm: 0,
              ),
            );
            availableSummary[r.itemCode]!.count++;
            availableSummary[r.itemCode]!.totalLengthCm += r.lengthCm;
          }

          // Group filtered remnants by itemCode
          final grouped = <String, List<RemnantDoc>>{};
          for (final r in filtered) {
            grouped.putIfAbsent(r.itemCode, () => []).add(r);
          }

          return Column(
            children: [
              // ── Summary Banner ──────────────────────────────────────
              if (availableSummary.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: isDark
                      ? AppColors.darkCard
                      : AppColors.amberPrimary.withValues(alpha: 0.06),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: availableSummary.entries.map((e) {
                      return _SummaryChip(
                        label: e.value.nameArabic.isNotEmpty
                            ? e.value.nameArabic
                            : e.key,
                        count: e.value.count,
                        totalCm: e.value.totalLengthCm,
                      );
                    }).toList(),
                  ),
                ),

              // ── Filter row ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: itemCodes.contains(_filterItemCode)
                            ? _filterItemCode
                            : null,
                        decoration: InputDecoration(
                          labelText: 'تصفية حسب الصنف',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('الكل'),
                          ),
                          ...itemCodes.map((code) {
                            final arName = itemNameByCode[code];
                            return DropdownMenuItem(
                              value: code,
                              child: Text(
                                arName != null && arName.isNotEmpty
                                    ? '$arName ($code)'
                                    : code,
                              ),
                            );
                          }),
                        ],
                        onChanged: (v) =>
                            setState(() => _filterItemCode = v),
                      ),
                    ),
                  ],
                ),
              ),

              // ── List ────────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        children: grouped.entries.map((entry) {
                          return _ItemGroupSection(
                            itemCode: entry.key,
                            remnants: entry.value,
                            isDark: isDark,
                            onMarkUsed: (remnantId) => _markUsed(remnantId),
                            onMarkAvailable: (remnantId) =>
                                _markAvailable(remnantId),
                            onDelete: (remnant) => _deleteRemnant(remnant),
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
      );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('مخزن الفضلات'),
              centerTitle: false,
              backgroundColor:
                  isDark ? AppColors.darkSurface : AppColors.lightSurface,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.amberPrimary,
                  ),
                  tooltip: 'إضافة فضلة أو قضيب يدوياً',
                  onPressed: () => _showAddManualRemnantDialog(context),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.amberPrimary,
                  ),
                  tooltip: 'ماسح قطع الألمنيوم QR',
                  onPressed: () => context.push('/scanner'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: FilterChip(
                    label: const Text('المتاح فقط'),
                    selected: _showAvailableOnly,
                    onSelected: (v) => setState(() => _showAvailableOnly = v),
                    selectedColor: AppColors.amberPrimary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.amberPrimary,
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.amberPrimary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'إضافة فضلة / مخزون يدوياً',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showAddManualRemnantDialog(context),
      ),
      body: widget.embedded
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Text(
                        'مخزن الفضلات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: AppColors.amberPrimary,
                        ),
                        tooltip: 'ماسح قطع الألمنيوم QR',
                        onPressed: () => context.push('/scanner'),
                      ),
                      FilterChip(
                        label: const Text('المتاح فقط'),
                        selected: _showAvailableOnly,
                        onSelected: (v) =>
                            setState(() => _showAvailableOnly = v),
                        selectedColor:
                            AppColors.amberPrimary.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.amberPrimary,
                      ),
                    ],
                  ),
                ),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.layers_clear_rounded,
              size: 64,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
            const SizedBox(height: 16),
            Text(
              _showAvailableOnly
                  ? 'لا توجد فضلات متاحة حالياً'
                  : 'لا توجد فضلات مسجّلة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'الفضلات تُحفظ تلقائياً عند حفظ خطة القص، أو يمكنك إضافة فضلات وقضبان يدوياً ليتم خصمها واستخدامها تلقائياً في القص القادم.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amberPrimary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () => _showAddManualRemnantDialog(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'إضافة فضلة / مخزون يدوياً',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddManualRemnantDialog(BuildContext context) async {
    final effectiveRules =
        ref.read(effectiveRulesProvider(widget.workshopId)).value ??
        SeedRules.getSystem2000BeadedRules();

    // Extract unique profile items from rules so itemCode matches CutOptimizer
    final profileOptions = <({String itemCode, String nameArabic})>[];
    final seenCodes = <String>{};
    for (final r in effectiveRules) {
      if (r.outputKind == 'profile' && seenCodes.add(r.itemCode)) {
        profileOptions.add((
          itemCode: r.itemCode,
          nameArabic: r.nameArabic.isNotEmpty ? r.nameArabic : r.itemCode,
        ));
      }
    }
    if (profileOptions.isEmpty) {
      for (final r in SeedRules.getSystem2000BeadedRules()) {
        if (r.outputKind == 'profile' && seenCodes.add(r.itemCode)) {
          profileOptions.add((itemCode: r.itemCode, nameArabic: r.nameArabic));
        }
      }
    }

    const customOptionKey = '__custom__';
    String selectedCode = profileOptions.first.itemCode;
    final customNameCtrl = TextEditingController();
    final customCodeCtrl = TextEditingController();
    final lengthCtrl = TextEditingController(text: '200');
    final qtyCtrl = TextEditingController(text: '1');
    final sourceCtrl = TextEditingController(text: 'شراء مباشر / مخزون الورشة');
    String selectedColor = 'أبيض';
    String? errorText;
    bool isSaving = false;

    const colorChoices = ['أبيض', 'أسود', 'بيج', 'شامبين', 'رمادي', 'خشبي'];
    const quickLengths = [660.0, 330.0, 250.0, 200.0, 150.0, 100.0];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isCustom = selectedCode == customOptionKey;

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.amberPrimary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'إضافة فضلة / مخزون للرف يدوياً',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.amberPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.amberPrimary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.auto_mode_rounded,
                              size: 18,
                              color: AppColors.amberPrimary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'أي قطاع تضيفه هنا يُعتبر متاحاً في مخزن الفضلات، وسيقوم محرك القص باستخدامه تلقائياً في المشاريع القادمة قبل فتح قضيب جديد.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 1. Profile / Item selector
                      DropdownButtonFormField<String>(
                        initialValue: selectedCode,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'نوع القطاع / الصنف',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          ...profileOptions.map(
                            (p) => DropdownMenuItem(
                              value: p.itemCode,
                              child: Text(
                                '${p.nameArabic} (${p.itemCode})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: customOptionKey,
                            child: Text('صنف آخر (إدخال حر)...'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCode = val;
                              errorText = null;
                            });
                          }
                        },
                      ),

                      if (isCustom) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم الصنف بالعربي',
                            hintText: 'مثال: سكة سحاب خاص / زاوية ألمنيوم',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: customCodeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'رمز الصنف (اختياري لمطابقة قواعد القص)',
                            hintText: 'مثال: track أو custom_profile',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // 2. Length (cm) + Quantity
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: lengthCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'الطول للقطعة الواحدة (سم)',
                                suffixText: 'سم',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'العدد (قطع)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Quick length chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: quickLengths.map((len) {
                          final isFullBar = len == 660.0;
                          return ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              isFullBar
                                  ? '660 سم (قضيب كامل)'
                                  : '${len.toInt()} سم',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                lengthCtrl.text = len.toInt().toString();
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      // 3. Color selector
                      const Text(
                        'اللون:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: colorChoices.map((c) {
                          final isSelected = selectedColor == c;
                          return ChoiceChip(
                            label: Text(
                              c,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.amberPrimary.withValues(
                              alpha: 0.25,
                            ),
                            onSelected: (_) {
                              setDialogState(() => selectedColor = c);
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      // 4. Source / Note
                      TextField(
                        controller: sourceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'المصدر / ملاحظة',
                          hintText: 'مثال: شراء مباشر / مخزون الورشة',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),

                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amberPrimary,
                    foregroundColor: Colors.black,
                  ),
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text(
                    'إضافة للمخزن',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final lengthVal = double.tryParse(
                            lengthCtrl.text.trim(),
                          );
                          final qtyVal =
                              int.tryParse(qtyCtrl.text.trim()) ?? 1;

                          if (lengthVal == null || lengthVal <= 0) {
                            setDialogState(() {
                              errorText =
                                  'يرجى إدخال طول صحيح أكبر من صفر (بالسنتيمتر).';
                            });
                            return;
                          }
                          if (qtyVal <= 0 || qtyVal > 200) {
                            setDialogState(() {
                              errorText = 'يرجى إدخال عدد قطع بين 1 و 200.';
                            });
                            return;
                          }

                          String finalCode = selectedCode;
                          String finalName = '';
                          if (isCustom) {
                            finalName = customNameCtrl.text.trim();
                            if (finalName.isEmpty) {
                              setDialogState(() {
                                errorText = 'يرجى كتابة اسم الصنف بالعربي.';
                              });
                              return;
                            }
                            final customCode = customCodeCtrl.text.trim();
                            finalCode = customCode.isNotEmpty
                                ? customCode
                                : 'custom_${DateTime.now().millisecondsSinceEpoch}';
                          } else {
                            final match = profileOptions.firstWhere(
                              (p) => p.itemCode == selectedCode,
                            );
                            finalName = match.nameArabic;
                          }

                          setDialogState(() {
                            isSaving = true;
                            errorText = null;
                          });

                          await ref
                              .read(cutPlanRepositoryProvider)
                              .addManualRemnants(
                                workshopId: widget.workshopId,
                                itemCode: finalCode,
                                nameArabic: finalName,
                                lengthCm: lengthVal,
                                color: selectedColor,
                                quantity: qtyVal,
                                sourceNote: sourceCtrl.text.trim(),
                              );

                          if (mounted && ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تمت إضافة $qtyVal قطعة ($finalName — ${lengthVal.toStringAsFixed(1)} سم) إلى مخزن الفضلات ✅',
                                ),
                              ),
                            );
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _markUsed(String remnantId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الاستخدام'),
        content: const Text(
          'هل تم استخدام هذه الفضلة فعلاً؟\nيمكنك إرجاعها للمتاح لاحقاً إذا لزم الأمر.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'نعم، تم استخدامها',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref
          .read(cutPlanRepositoryProvider)
          .markRemnantUsed(widget.workshopId, remnantId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث حالة الفضلة')));
      }
    }
  }

  Future<void> _markAvailable(String remnantId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إرجاع للمتاح'),
        content: const Text(
          'هل تريد إعادة هذه الفضلة إلى قائمة الفضلات المتاحة للاستخدام في القص؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'نعم، أعدها للمتاح',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref
          .read(cutPlanRepositoryProvider)
          .markRemnantAvailable(widget.workshopId, remnantId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إعادة الفضلة إلى المخزن المتاح ✅'),
          ),
        );
      }
    }
  }

  Future<void> _deleteRemnant(RemnantDoc remnant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الفضلة نهائياً'),
        content: Text(
          'هل تريد حذف (${remnant.nameArabic.isNotEmpty ? remnant.nameArabic : remnant.itemCode} — ${remnant.lengthCm.toStringAsFixed(1)} سم) من مخزن الفضلات؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref
          .read(cutPlanRepositoryProvider)
          .deleteRemnant(widget.workshopId, remnant.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الفضلة من المخزن')),
        );
      }
    }
  }
}

// ── Item Group Section ────────────────────────────────────────────────────────

class _ItemGroupSection extends StatefulWidget {
  final String itemCode;
  final List<RemnantDoc> remnants;
  final bool isDark;
  final void Function(String id) onMarkUsed;
  final void Function(String id) onMarkAvailable;
  final void Function(RemnantDoc remnant) onDelete;

  const _ItemGroupSection({
    required this.itemCode,
    required this.remnants,
    required this.isDark,
    required this.onMarkUsed,
    required this.onMarkAvailable,
    required this.onDelete,
  });

  @override
  State<_ItemGroupSection> createState() => _ItemGroupSectionState();
}

class _ItemGroupSectionState extends State<_ItemGroupSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final available = widget.remnants.where((r) => r.isAvailable).toList();
    final nameArabic = widget.remnants.first.nameArabic;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: widget.isDark ? AppColors.darkCard : Colors.white,
      child: Column(
        children: [
          // Group header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.amberPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nameArabic.isNotEmpty ? nameArabic : widget.itemCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${available.length} متاحة · ${available.fold(0.0, (s, r) => s + r.lengthCm).toStringAsFixed(0)} سم',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark
                                ? AppColors.slate400
                                : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ],
              ),
            ),
          ),

          // Remnant tiles
          if (_expanded)
            ...widget.remnants.map(
              (r) => _RemnantTile(
                remnant: r,
                isDark: widget.isDark,
                onMarkUsed: () => widget.onMarkUsed(r.id),
                onMarkAvailable: () => widget.onMarkAvailable(r.id),
                onDelete: () => widget.onDelete(r),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Remnant Tile ──────────────────────────────────────────────────────────────

class _RemnantTile extends StatelessWidget {
  final RemnantDoc remnant;
  final bool isDark;
  final VoidCallback onMarkUsed;
  final VoidCallback onMarkAvailable;
  final VoidCallback onDelete;

  const _RemnantTile({
    required this.remnant,
    required this.isDark,
    required this.onMarkUsed,
    required this.onMarkAvailable,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = remnant.isAvailable;
    final isManual = remnant.sourceProjectId == 'manual';
    final dateFmt = DateFormat('d MMM yyyy', 'ar');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAvailable
            ? (isDark
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.success.withValues(alpha: 0.05))
            : (isDark ? AppColors.slate700 : AppColors.slate100),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAvailable
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.slate300.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Length — prominent
          Container(
            width: 72,
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(
                  remnant.lengthCm.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isAvailable ? AppColors.success : AppColors.slate400,
                  ),
                ),
                Text(
                  'سم',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Color chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate600 : AppColors.slate100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.slate300),
                      ),
                      child: Text(
                        remnant.color,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    // State chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.slate300.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isAvailable ? 'متاحة ✅' : 'مستخدمة',
                        style: TextStyle(
                          fontSize: 11,
                          color: isAvailable
                              ? AppColors.success
                              : AppColors.slate500,
                        ),
                      ),
                    ),
                    if (isManual)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amberPrimary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'إضافة يدوية',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.amberPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isManual
                      ? remnant.sourceProjectName
                      : 'من: ${remnant.sourceProjectName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.slate300 : AppColors.slate600,
                  ),
                ),
                Text(
                  dateFmt.format(remnant.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          if (isAvailable)
            TextButton(
              onPressed: onMarkUsed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text(
                'تم\nاستخدامها',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),
            )
          else
            TextButton(
              onPressed: onMarkAvailable,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text(
                'إرجاع\nللمتاح',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'حذف الفضلة',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Summary Chip ──────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final double totalCm;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.totalCm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.amberPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.amberPrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '$label: $count فضلة · ${totalCm.toStringAsFixed(0)} سم',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.amberPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ItemSummary {
  final String nameArabic;
  int count;
  double totalLengthCm;

  _ItemSummary({
    required this.nameArabic,
    required this.count,
    required this.totalLengthCm,
  });
}
