import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import 'package:meqyas/features/auth/presentation/controllers/auth_controller.dart';
import '../../data/projects_repository.dart';
import '../../domain/models/project.dart';

final workshopProjectsProvider = StreamProvider.autoDispose.family<List<Project>, String>((ref, workshopId) {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.watchProjects(workshopId);
});

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
    final workshopId = currentUser?.workshopId ?? '';

    final projectsAsync = ref.watch(workshopProjectsProvider(workshopId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('مشاريع الورشة'),
        actions: [
          IconButton(
            tooltip: 'مشروع جديد',
            icon: const Icon(Icons.add_business_rounded, color: AppColors.amberPrimary),
            onPressed: () => _showNewProjectDialog(context, workshopId),
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
                            onPressed: () => _showNewProjectDialog(context, workshopId),
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
                          context.push('/dashboard/owner/projects/${project.id}');
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
        onPressed: () => _showNewProjectDialog(context, workshopId),
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
                context.push('/dashboard/owner/projects/$newId');
              }
            },
            child: const Text('إنشاء ومتابعة'),
          ),
        ],
      ),
    );
  }
}
