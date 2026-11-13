import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import '../../domain/models/project_unit.dart';

/// Per-window / per-item customization sections for Accessories ("تخصيص الإكسسوارات")
/// and Screen Mesh ("تخصيص شبك المنخل"), matching the owner's specification.
class UnitAccessoriesAndMeshSection extends StatefulWidget {
  final ProjectUnit unit;
  final String effectiveGlazingMode;
  final ValueChanged<ProjectUnit> onUnitChanged;

  const UnitAccessoriesAndMeshSection({
    super.key,
    required this.unit,
    required this.effectiveGlazingMode,
    required this.onUnitChanged,
  });

  @override
  State<UnitAccessoriesAndMeshSection> createState() =>
      _UnitAccessoriesAndMeshSectionState();
}

class _UnitAccessoriesAndMeshSectionState
    extends State<UnitAccessoriesAndMeshSection> {
  late final TextEditingController _puttyCtrl;
  late final FocusNode _puttyFocus;
  Timer? _puttyDebounce;

  static const _brushColors = ['أسود', 'بني', 'رمادي', 'أبيض'];
  static const _fiberWidths = [0, 80, 100, 120, 150, 214, 240];
  static const _aluminumWidths = [0, 80, 100, 120, 150, 180];

  @override
  void initState() {
    super.initState();
    _puttyCtrl = TextEditingController(
      text: widget.unit.puttyQtyPerUnit.toString(),
    );
    _puttyFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant UnitAccessoriesAndMeshSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_puttyFocus.hasFocus) {
      final parsed = int.tryParse(_puttyCtrl.text) ?? 0;
      if (parsed != widget.unit.puttyQtyPerUnit) {
        _puttyCtrl.text = widget.unit.puttyQtyPerUnit.toString();
      }
    }
  }

  @override
  void dispose() {
    _puttyDebounce?.cancel();
    _puttyFocus.dispose();
    _puttyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final u = widget.unit;

    final resolvedGlassRollerType = u.glassRollerType.isNotEmpty
        ? u.glassRollerType
        : (widget.effectiveGlazingMode == 'double'
            ? 'roller_2000_double'
            : 'roller_2000_single');

    final resolvedBrushColor =
        _brushColors.contains(u.brushColor) ? u.brushColor : 'أسود';

    final resolvedGlassRollerCount =
        [2, 4, 6, 8].contains(u.glassRollerCount) ? u.glassRollerCount : 4;

    final resolvedScreenRollerType =
        ['slider', 'modified_2000', 'milled'].contains(u.rollerType)
            ? u.rollerType
            : 'slider';

    final meshWidths = u.meshType == 'aluminum' ? _aluminumWidths : _fiberWidths;
    final resolvedMeshWidth =
        meshWidths.contains(u.meshRollWidthCm) ? u.meshRollWidthCm : 0;

    final boxBg = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.65)
        : const Color(0xFFF4F7FA);
    final boxBorder = isDark ? AppColors.darkBorder : const Color(0xFFDDE5EE);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. تخصيص الإكسسوارات ──────────────────────────────────────
        _SectionHeaderPill(
          title: 'تخصيص الإكسسوارات',
          subtitle: 'خاص بهذا العنصر',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: boxBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: boxBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: resolvedBrushColor,
                      decoration: const InputDecoration(
                        labelText: 'لون الفراشة 900 و 450',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: _brushColors
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          widget.onUnitChanged(u.copyWith(brushColor: val));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: resolvedGlassRollerType,
                      decoration: const InputDecoration(
                        labelText: 'نوع دواليب الزجاج',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'roller_2000_single',
                          child: Text('دولاب 2000 مفرد'),
                        ),
                        DropdownMenuItem(
                          value: 'roller_2000_double',
                          child: Text('دولاب 2000 دبل'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          widget.onUnitChanged(
                            u.copyWith(glassRollerType: val),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: resolvedGlassRollerCount,
                      decoration: const InputDecoration(
                        labelText: 'عدد دواليب الزجاج (زوجي)',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('2')),
                        DropdownMenuItem(value: 4, child: Text('4')),
                        DropdownMenuItem(value: 6, child: Text('6')),
                        DropdownMenuItem(value: 8, child: Text('8')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          widget.onUnitChanged(
                            u.copyWith(glassRollerCount: val),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: resolvedScreenRollerType,
                      decoration: const InputDecoration(
                        labelText: 'حركة المنخل · 2 لكل شباك',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'slider',
                          child: Text('زحّافة'),
                        ),
                        DropdownMenuItem(
                          value: 'modified_2000',
                          child: Text('دولاب 2000 معدل'),
                        ),
                        DropdownMenuItem(
                          value: 'milled',
                          child: Text('دولاب تفريز'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          widget.onUnitChanged(u.copyWith(rollerType: val));
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: u.frameGasketType == 'none'
                          ? 'none'
                          : 'frame_gasket',
                      decoration: const InputDecoration(
                        labelText: 'نوع جوان الكادر · 4',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'frame_gasket',
                          child: Text('جوان تجميع الكادر'),
                        ),
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('بدون جوان'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          widget.onUnitChanged(
                            u.copyWith(frameGasketType: val),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: u.screenCornerType == 'none'
                          ? 'none'
                          : 'screen_corner',
                      decoration: const InputDecoration(
                        labelText: 'نوع زوايا المنخل · 4',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'screen_corner',
                          child: Text('زاوية تجميع المنخل'),
                        ),
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('بدون زوايا'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          widget.onUnitChanged(
                            u.copyWith(
                              screenCornerType: val,
                              hasCorners: val != 'none',
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _puttyCtrl,
                focusNode: _puttyFocus,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'معجونة · كمية لكل شباك (اختيارية)',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                onChanged: (val) {
                  final qty = int.tryParse(val.trim());
                  if (qty != null && qty >= 0) {
                    _puttyDebounce?.cancel();
                    _puttyDebounce = Timer(
                      const Duration(milliseconds: 450),
                      () => widget.onUnitChanged(
                        u.copyWith(puttyQtyPerUnit: qty),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        // ── 2. تخصيص شبك المنخل ───────────────────────────────────────
        if (u.hasScreen) ...[
          const SizedBox(height: 12),
          _SectionHeaderPill(
            title: 'تخصيص شبك المنخل',
            subtitle: 'خاص بهذا العنصر',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: boxBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue:
                        u.meshType == 'aluminum' ? 'aluminum' : 'fiber',
                    decoration: const InputDecoration(
                      labelText: 'نوع الشبك',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'fiber', child: Text('فيبر')),
                      DropdownMenuItem(
                        value: 'aluminum',
                        child: Text('ألمنيوم'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        final allowed =
                            val == 'aluminum' ? _aluminumWidths : _fiberWidths;
                        final nextWidth = allowed.contains(u.meshRollWidthCm)
                            ? u.meshRollWidthCm
                            : 0;
                        widget.onUnitChanged(
                          u.copyWith(meshType: val, meshRollWidthCm: nextWidth),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: resolvedMeshWidth,
                    decoration: const InputDecoration(
                      labelText: 'عرض لفّة الشبك',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    items: meshWidths.map((w) {
                      return DropdownMenuItem<int>(
                        value: w,
                        child: Text(
                          w == 0 ? 'اقتراح تلقائي أقل هدراً' : '$w سم',
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        widget.onUnitChanged(u.copyWith(meshRollWidthCm: val));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeaderPill extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeaderPill({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF144E78),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.slate400,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
