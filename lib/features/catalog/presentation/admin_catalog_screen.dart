import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../app/theme/app_colors.dart';
import '../data/catalog_repository.dart';
import '../data/excel_service.dart';
import '../domain/catalog_item.dart';

class AdminCatalogScreen extends ConsumerStatefulWidget {
  const AdminCatalogScreen({super.key});

  @override
  ConsumerState<AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends ConsumerState<AdminCatalogScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catalogAsync = ref.watch(allCatalogItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الكتالوج العام للأصناف والمواد'),
      ),
      body: catalogAsync.when(
        data: (allItems) {
          final filtered = allItems.where((item) {
            if (_selectedCategory != 'all' &&
                item.categoryId != _selectedCategory) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              return item.code.toLowerCase().contains(q) ||
                  item.arabicName.toLowerCase().contains(q) ||
                  item.engineItemCode.toLowerCase().contains(q) ||
                  item.color.toLowerCase().contains(q);
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Action Bar
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 720;

                  final searchField = TextField(
                    decoration: InputDecoration(
                      hintText: 'بحث بالكود، الاسم بالعربية، أو كود المحرك...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                  );

                  final actionButtons = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cloud_download_outlined, size: 16),
                        label: const Text('تثبيت الأصناف القياسية'),
                        onPressed: () => _seedDefaults(context),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('استيراد Excel'),
                        onPressed: () => _importExcel(context, allItems),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('تصدير Excel'),
                        onPressed: () => _exportExcel(context, allItems),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('إضافة صنف جديد'),
                        onPressed: () => _showItemFormDialog(context, null),
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 12),
                        actionButtons,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      actionButtons,
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('الكل (${allItems.length})', 'all'),
                    const SizedBox(width: 8),
                    for (final cat in CatalogCategory.all) ...[
                      _buildCategoryChip(
                        '${cat.nameArabic} (${allItems.where((i) => i.categoryId == cat.id).length})',
                        cat.id,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (filtered.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('لا توجد أصناف مطابقة للبحث الحالي'),
                  ),
                )
              else
                ...filtered.map(
                  (item) => _buildCatalogItemCard(context, item, isDark, theme),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل الكتالوج: $e')),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String categoryId) {
    final isSelected = _selectedCategory == categoryId;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.amberPrimary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.amberPrimary : null,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedCategory = categoryId);
      },
    );
  }

  Widget _buildCatalogItemCard(
    BuildContext context,
    CatalogItem item,
    bool isDark,
    ThemeData theme,
  ) {
    final statusColor = item.isActive ? AppColors.success : AppColors.slate400;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        item.arabicName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amberPrimary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.code,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.amberPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      if (item.engineItemCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glassBlue.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'محرك: ${item.engineItemCode}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.glassBlueLight,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.isActive ? 'نشط' : 'غير نشط',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _metaBadge(
                  Icons.category_outlined,
                  'التصنيف: ${CatalogCategory.arabicLabel(item.categoryId)}',
                ),
                _metaBadge(
                  Icons.straighten_rounded,
                  'الوحدة: ${CatalogUnit.arabicLabel(item.unit)}',
                ),
                if (item.color.isNotEmpty)
                  _metaBadge(Icons.palette_outlined, 'اللون: ${item.color}'),
                if (item.thickness.isNotEmpty)
                  _metaBadge(
                    Icons.line_weight_rounded,
                    'السماكة: ${item.thickness}',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('تعديل'),
                  onPressed: () => _showItemFormDialog(context, item),
                ),
                TextButton.icon(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppColors.error,
                  ),
                  label: const Text(
                    'حذف',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onPressed: () => _confirmDelete(context, item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.slate400),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.slate400),
        ),
      ],
    );
  }

  Future<void> _seedDefaults(BuildContext context) async {
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final count = await repo.seedDefaultCatalogToFirestore();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'تم تثبيت $count صنف قياسي في قاعدة البيانات بنجاح'
                  : 'جميع الأصناف القياسية مثبتة بالفعل في قاعدة البيانات',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تثبيت الأصناف: $e')),
        );
      }
    }
  }

  Future<void> _exportExcel(
    BuildContext context,
    List<CatalogItem> items,
  ) async {
    try {
      final bytes = CatalogExcelService.exportCatalogToExcel(items);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'maqyas_catalog.xlsx',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تصدير ملف الإكسل: $e')),
        );
      }
    }
  }

  Future<void> _importExcel(
    BuildContext context,
    List<CatalogItem> currentItems,
  ) async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final bytes = picked.files.first.bytes;
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر قراءة محتوى الملف المحدد')),
          );
        }
        return;
      }

      final existingCodes = currentItems.map((i) => i.code).toSet();
      final result = CatalogExcelService.parseCatalogExcel(
        bytes,
        existingCodes: existingCodes,
      );

      if (!context.mounted) return;

      if (result.hasErrors) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('نتيجة فحص ملف الإكسل'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'الأصناف الصالحة للاستيراد: ${result.validItems.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'الأخطاء المكتشفة (تم استبعاد الصفوف المكررة أو غير الصالحة):',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...result.errors.map(
                      (err) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $err',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إغلاق'),
              ),
              if (result.validItems.isNotEmpty)
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final count = await ref
                        .read(catalogRepositoryProvider)
                        .importCatalogItemsBatch(result.validItems);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم استيراد $count صنف صالح بنجاح'),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'استيراد الأصناف الصالحة (${result.validItems.length})',
                  ),
                ),
            ],
          ),
        );
      } else if (result.validItems.isNotEmpty) {
        final count = await ref
            .read(catalogRepositoryProvider)
            .importCatalogItemsBatch(result.validItems);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم استيراد $count صنف من الإكسل بنجاح')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء استيراد الإكسل: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, CatalogItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الصنف'),
        content: Text('هل أنت متأكد من حذف الصنف «${item.arabicName}»؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(catalogRepositoryProvider).deleteCatalogItem(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الصنف من الكتالوج')),
        );
      }
    }
  }

  Future<void> _showItemFormDialog(
    BuildContext context,
    CatalogItem? existing,
  ) async {
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final engineCodeCtrl = TextEditingController(
      text: existing?.engineItemCode ?? '',
    );
    final nameCtrl = TextEditingController(text: existing?.arabicName ?? '');
    final colorCtrl = TextEditingController(text: existing?.color ?? '');
    final thicknessCtrl = TextEditingController(
      text: existing?.thickness ?? '',
    );
    var categoryId = existing?.categoryId ?? 'aluminum';
    var unit = existing?.unit ?? 'bar';
    var status = existing?.status ?? 'active';
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(
              existing == null ? 'إضافة صنف جديد للكتالوج' : 'تعديل بيانات الصنف',
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كود الصنف الفريد (Code) *',
                        hintText: 'مثال: AL-TRK-2000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الاسم بالعربية *',
                        hintText: 'مثال: سكة 2000 بحاجب',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: engineCodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كود الربط مع محرك الحسابات (اختياري)',
                        hintText: 'مثال: track, kaab, glass_handle',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(
                        labelText: 'التصنيف',
                        border: OutlineInputBorder(),
                      ),
                      items: CatalogCategory.all
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nameArabic),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            categoryId = val;
                            if (CatalogCategory.requiresRollUnit(categoryId)) {
                              unit = 'roll';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: unit,
                      decoration: const InputDecoration(
                        labelText: 'وحدة القياس والبيع',
                        border: OutlineInputBorder(),
                      ),
                      items: CatalogUnit.all
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.code,
                              child: Text(u.nameArabic),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => unit = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: colorCtrl,
                            decoration: const InputDecoration(
                              labelText: 'اللون',
                              hintText: 'مثال: أبيض / برونز',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: thicknessCtrl,
                            decoration: const InputDecoration(
                              labelText: 'السماكة',
                              hintText: 'مثال: 1.3 مم',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'الحالة',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('نشط')),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('غير نشط'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => status = val);
                      },
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMsg!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final candidate = CatalogItem(
                    id: existing?.id ?? '',
                    code: codeCtrl.text.trim().toUpperCase(),
                    engineItemCode: engineCodeCtrl.text.trim(),
                    arabicName: nameCtrl.text.trim(),
                    categoryId: categoryId,
                    unit: unit,
                    color: colorCtrl.text.trim(),
                    thickness: thicknessCtrl.text.trim(),
                    status: status,
                  );

                  final err = candidate.validate();
                  if (err != null) {
                    setDialogState(() => errorMsg = err);
                    return;
                  }

                  try {
                    await ref
                        .read(catalogRepositoryProvider)
                        .saveCatalogItem(candidate);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم حفظ الصنف في الكتالوج بنجاح'),
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => errorMsg = e.toString());
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }
}
