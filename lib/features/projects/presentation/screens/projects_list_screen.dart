import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import 'package:meqyas/features/auth/presentation/controllers/auth_controller.dart';
import '../../../../features/rules/data/rules_repository.dart';
import '../../data/projects_repository.dart';
import '../../domain/models/project.dart';


class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider).value;
    final ownerUid = currentUser?.uid ?? '';

    final workshops = ref.watch(ownerWorkshopsProvider(ownerUid)).value ?? [];
    final activeWorkshopId = ref.watch(activeWorkshopIdProvider) ??
        (workshops.isNotEmpty ? workshops.first.id : (currentUser?.workshopId ?? ''));

    final projectsAsync = ref.watch(workshopProjectsProvider(activeWorkshopId));

    return Scaffold(
      appBar: AppBar(
        title: workshops.length > 1
            ? DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: workshops.any((w) => w.id == activeWorkshopId)
                      ? activeWorkshopId
                      : workshops.first.id,
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.amberPrimary),
                  dropdownColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  items: workshops.map((w) {
                    return DropdownMenuItem(
                      value: w.id,
                      child: Text(
                        w.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      ref.read(activeWorkshopIdProvider.notifier).setWorkshopId(newId);
                    }
                  },
                ),
              )
            : Text(
                workshops.isNotEmpty ? 'مشاريع ${workshops.first.name}' : 'مشاريع الورشة',
              ),
        actions: [
          IconButton(
            tooltip: 'إضافة ورشة جديدة',
            icon: const Icon(Icons.add_home_work_rounded, color: AppColors.amberPrimary),
            onPressed: () => _showNewWorkshopDialog(context),
          ),
          IconButton(
            tooltip: 'إعدادات وقواعد الورشة',
            icon: const Icon(Icons.tune_rounded, color: AppColors.amberPrimary),
            onPressed: () {
              context.push('/dashboard/owner/rules?workshopId=$activeWorkshopId');
            },
          ),
          IconButton(
            tooltip: 'مشروع جديد',
            icon: const Icon(Icons.add_business_rounded, color: AppColors.amberPrimary),
            onPressed: () => _showNewProjectDialog(context, activeWorkshopId),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'البحث باسم المشروع أو اسم العميل...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Projects List
          Expanded(
            child: projectsAsync.when(
              data: (projects) {
                final filtered = projects.where((p) {
                  if (_searchQuery.isEmpty) return true;
                  return p.name.toLowerCase().contains(_searchQuery) ||
                      p.clientName.toLowerCase().contains(_searchQuery) ||
                      p.location.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_rounded, size: 56, color: isDark ? AppColors.slate600 : AppColors.slate400),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty ? 'لا توجد مشاريع مسجلة بعد' : 'لا توجد نتائج مطابقة للبحث',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ابدأ بفتح أول مشروع لورشة العمل لإضافة قياسات الشبابيك وحساب التقطيع',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('إنشاء مشروع جديد'),
                            onPressed: () => _showNewProjectDialog(context, activeWorkshopId),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final project = filtered[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          context.push('/dashboard/owner/projects/${project.id}?workshopId=$activeWorkshopId');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.amberPrimary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.business_rounded, color: AppColors.amberLight, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          project.name,
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        if (project.clientName.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'العميل: ${project.clientName}${project.clientPhone.isNotEmpty ? " (${project.clientPhone})" : ""}',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: isDark ? AppColors.slate400 : AppColors.slate600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    ),
                                    child: Text(
                                      '${project.unitCount} عناصر قياس',
                                      style: const TextStyle(
                                        color: AppColors.amberPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (project.location.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.place_outlined, size: 14, color: AppColors.slate400),
                                    const SizedBox(width: 4),
                                    Text(
                                      project.location,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDark ? AppColors.slate400 : AppColors.slate600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('خطأ في تحميل المشاريع: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('مشروع جديد'),
        onPressed: () => _showNewProjectDialog(context, activeWorkshopId),
      ),
    );
  }

  void _showNewProjectDialog(BuildContext context, String workshopId) {
    final nameCtrl = TextEditingController();
    final clientNameCtrl = TextEditingController();
    final clientPhoneCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_business_rounded, color: AppColors.amberPrimary),
            SizedBox(width: 8),
            Text('مشروع ورشة جديد'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'اسم المشروع *',
                  hintText: 'مثال: فيلا النرجس - شقق الروضة',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل / المالك',
                  hintText: 'مثال: م. أحمد الغامدي',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم هاتف العميل',
                  hintText: '05xxxxxxxx',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'الموقع / العنوان',
                  hintText: 'الرياض - حي الياسمين',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final project = Project(
                id: '',
                workshopId: workshopId,
                name: name,
                clientName: clientNameCtrl.text.trim(),
                clientPhone: clientPhoneCtrl.text.trim(),
                location: locationCtrl.text.trim(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              final newId = await ref.read(projectsRepositoryProvider).createProject(project);
              if (ctx.mounted) {
                ctx.pop();
                context.push('/dashboard/owner/projects/$newId?workshopId=$workshopId');
              }
            },
            child: const Text('إنشاء ومتابعة'),
          ),
        ],
      ),
    );
  }

  void _showNewWorkshopDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_home_work_rounded, color: AppColors.amberPrimary),
                SizedBox(width: 8),
                Text('إضافة ورشة عمل جديدة'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'يمكنك إنشاء ورشة جديدة مستقلة بمشاريعها الخاصة وقواعد التقطيع وإعدادات المنشار.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الورشة *',
                      hintText: 'مثال: ورشة الأمل للألمنيوم',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storefront_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الموقع / المدينة',
                      hintText: 'مثال: الرياض - حي السلي',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم هاتف الورشة',
                      hintText: 'مثال: 05xxxxxxxx',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => ctx.pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى إدخال اسم الورشة')),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        try {
                          final repo = ref.read(rulesRepositoryProvider);
                          final newId = await repo.createWorkshop(
                            name: name,
                            location: locationCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                          );

                          ref.read(activeWorkshopIdProvider.notifier).setWorkshopId(newId);

                          if (context.mounted) {
                            ctx.pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تم إنشاء ورشة "$name" بنجاح')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل إنشاء الورشة: $e')),
                            );
                          }
                        } finally {
                          setDialogState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('إنشاء الورشة'),
              ),
            ],
          );
        },
      ),
    );
  }
}
