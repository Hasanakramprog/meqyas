import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import 'package:meqyas/features/auth/presentation/controllers/auth_controller.dart';
import '../../../../features/rules/data/rules_repository.dart';
import '../../data/projects_repository.dart';
import '../../domain/models/project_unit.dart';

class QuickEntrySheet extends ConsumerStatefulWidget {
  final String projectId;
  final String? workshopId;
  final VoidCallback? onUnitAdded;

  const QuickEntrySheet({
    super.key,
    required this.projectId,
    this.workshopId,
    this.onUnitAdded,
  });

  @override
  ConsumerState<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<QuickEntrySheet> {
  final _nameController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _locationController = TextEditingController();
  int _quantity = 1;
  String _unitType = 'window';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _clearFields() {
    _nameController.clear();
    _widthController.clear();
    _heightController.clear();
    _locationController.clear();
    setState(() {
      _quantity = 1;
      _unitType = 'window';
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final width = double.tryParse(_widthController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final location = _locationController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم العنصر (مثل: شباك صالون)')),
      );
      return;
    }

    if (width == null || width <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال عرض صحيح أكبر من صفر')),
      );
      return;
    }

    if (height == null || height <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال ارتفاع صحيح أكبر من صفر')),
      );
      return;
    }

    final activeId = ref.read(activeWorkshopIdProvider);
    final currentUser = ref.read(currentUserProvider).value;
    final workshopId = (widget.workshopId != null && widget.workshopId!.isNotEmpty)
        ? widget.workshopId!
        : (activeId ?? (currentUser?.workshopId ?? ''));
    if (workshopId.isEmpty) return;

    // Engineering Validation (Never allow unmanufacturable dimensions)
    final engine = ref.read(calculatorEngineProvider(workshopId));
    final spec = UnitSpecification(
      widthCm: width,
      heightCm: height,
      quantity: _quantity,
      unitType: _unitType,
      profileSystemId: SeedRules.system2000Beaded,
    );
    final calc = engine.calculate(spec);
    if (!calc.isValid) {
      final firstIssue = calc.issues.isNotEmpty ? calc.issues.first.message : 'الأبعاد غير مطابقة لقواعد التصنيع';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('القياس غير صالح للتصنيع: $firstIssue\n(الحد الأدنى: العرض > 16.2 سم، الارتفاع > 14 سم)'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final unit = ProjectUnit(
        id: '',
        projectId: widget.projectId,
        name: name,
        location: location,
        widthCm: width,
        heightCm: height,
        quantity: _quantity,
        unitType: _unitType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(projectsRepositoryProvider).saveUnit(workshopId, unit);
      widget.onUnitAdded?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت إضافة "$name" بنجاح'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        // Clear fields per Section 13 requirement! Never prefill sample measurements.
        _clearFields();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: AppColors.amberPrimary),
                  const SizedBox(width: 8),
                  Text('إدخال قياسات سريع', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name and Location
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'اسم العنصر *', hintText: 'مثال: شباك المطبخ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'المكان', hintText: 'مثال: الدور 1'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Width, Height, Quantity
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _widthController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'العرض (سم) *',
                    suffixText: 'سم',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'الارتفاع (سم) *',
                    suffixText: 'سم',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _quantity,
                  decoration: const InputDecoration(
                    labelText: 'العدد',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: List.generate(20, (i) => i + 1)
                      .map((q) => DropdownMenuItem(value: q, child: Text('$q')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _quantity = val);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'window',
                label: Text('شباك نافذة'),
                icon: Icon(Icons.window_rounded, size: 18),
              ),
              ButtonSegment<String>(
                value: 'facade',
                label: Text('واجهة زجاجية'),
                icon: Icon(Icons.apartment_rounded, size: 18),
              ),
            ],
            selected: {_unitType},
            onSelectionChanged: (newSelection) {
              setState(() => _unitType = newSelection.first);
            },
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_rounded),
            label: const Text('إضافة العنصر والمتابعة'),
            onPressed: _isSaving ? null : _submit,
          ),
        ],
      ),
    );
  }
}
