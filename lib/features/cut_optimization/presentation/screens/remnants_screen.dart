import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/cut_plan_repository.dart';

class RemnantsScreen extends ConsumerStatefulWidget {
  final String workshopId;

  const RemnantsScreen({super.key, required this.workshopId});

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

    return Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: const Text('مخزن الفضلات'),
          centerTitle: false,
          backgroundColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          elevation: 0,
          actions: [
            // Toggle available only
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
        body: remnantsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('خطأ في تحميل الفضلات: $e')),
          data: (allRemnants) {
            final filtered = allRemnants.where((r) {
              if (_showAvailableOnly && !r.isAvailable) return false;
              if (_filterItemCode != null &&
                  r.itemCode != _filterItemCode) return false;
              return true;
            }).toList();

            // Get unique item codes for filter
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
                      ));
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
                        horizontal: 16, vertical: 12),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _filterItemCode,
                          decoration: InputDecoration(
                            labelText: 'تصفية حسب الصنف',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('الكل')),
                            ...itemCodes.map((code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(code),
                                )),
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
                          padding: const EdgeInsets.all(16),
                          children: grouped.entries.map((entry) {
                            return _ItemGroupSection(
                              itemCode: entry.key,
                              remnants: entry.value,
                              isDark: isDark,
                              onMarkUsed: (remnantId) =>
                                  _markUsed(remnantId),
                            );
                          }).toList(),
                        ),
                ),
              ],
            );
          },
        ),
      );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_clear_rounded,
              size: 64,
              color: isDark ? AppColors.slate500 : AppColors.slate400),
          const SizedBox(height: 16),
          Text(
            _showAvailableOnly
                ? 'لا توجد فضلات متاحة حالياً'
                : 'لا توجد فضلات مسجّلة',
            style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.slate400 : AppColors.slate500),
          ),
          const SizedBox(height: 8),
          Text(
            'الفضلات تُحفظ تلقائياً عند حفظ خطة القص',
            style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.slate500 : AppColors.slate400),
          ),
        ],
      ),
    );
  }

  Future<void> _markUsed(String remnantId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الاستخدام'),
        content: const Text(
            'هل تم استخدام هذه الفضلة فعلاً؟\nلا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('نعم، تم استخدامها',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref
          .read(cutPlanRepositoryProvider)
          .markRemnantUsed(widget.workshopId, remnantId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حالة الفضلة')),
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

  const _ItemGroupSection({
    required this.itemCode,
    required this.remnants,
    required this.isDark,
    required this.onMarkUsed,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '${available.length} متاحة · ${available.fold(0.0, (s, r) => s + r.lengthCm).toStringAsFixed(0)} سم',
                          style: TextStyle(
                              fontSize: 12,
                              color: widget.isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500),
                        ),
                      ],
                    ),
                  ),
                  Icon(_expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ),

          // Remnant tiles
          if (_expanded)
            ...widget.remnants.map((r) => _RemnantTile(
                  remnant: r,
                  isDark: widget.isDark,
                  onMarkUsed: () => widget.onMarkUsed(r.id),
                )),
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

  const _RemnantTile({
    required this.remnant,
    required this.isDark,
    required this.onMarkUsed,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = remnant.isAvailable;
    final dateFmt = DateFormat('d MMM yyyy', 'ar');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAvailable
            ? (isDark
                ? AppColors.success.withValues(alpha: 0.08)
                : AppColors.success.withValues(alpha: 0.05))
            : (isDark
                ? AppColors.slate700
                : AppColors.slate100),
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
                Text('سم',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.slate400
                            : AppColors.slate500)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Color chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.slate600
                            : AppColors.slate100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.slate300),
                      ),
                      child: Text(remnant.color,
                          style: const TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    // State chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
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
                                : AppColors.slate500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'من: ${remnant.sourceProjectName}',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? AppColors.slate300 : AppColors.slate600),
                ),
                Text(
                  dateFmt.format(remnant.createdAt),
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? AppColors.slate500 : AppColors.slate400),
                ),
              ],
            ),
          ),

          // Action button
          if (isAvailable)
            TextButton(
              onPressed: onMarkUsed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text('تم\nاستخدامها',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11)),
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
        border:
            Border.all(color: AppColors.amberPrimary.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count فضلة · ${totalCm.toStringAsFixed(0)} سم',
        style: TextStyle(
            fontSize: 12,
            color: AppColors.amberPrimary,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ItemSummary {
  final String nameArabic;
  int count;
  double totalLengthCm;

  _ItemSummary(
      {required this.nameArabic,
      required this.count,
      required this.totalLengthCm});
}
