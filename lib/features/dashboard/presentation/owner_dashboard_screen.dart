import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../projects/data/projects_repository.dart';
import '../../projects/domain/models/project.dart';
import '../../rules/data/rules_repository.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUser = ref.watch(currentUserProvider).value;
    final ownerUid = currentUser?.uid ?? '';

    final workshops = ref.watch(ownerWorkshopsProvider(ownerUid)).value ?? [];
    final activeWorkshopId =
        ref.watch(activeWorkshopIdProvider) ??
        (workshops.isNotEmpty
            ? workshops.first.id
            : (currentUser?.workshopId ?? ''));

    final activeWorkshop = workshops.firstWhere(
      (w) => w.id == activeWorkshopId,
      orElse: () => WorkshopInfo(
        id: activeWorkshopId,
        name: workshops.isNotEmpty ? workshops.first.name : 'ورشة العمل',
        location: workshops.isNotEmpty ? workshops.first.location : '',
        phone: workshops.isNotEmpty ? workshops.first.phone : '',
      ),
    );

    final projectsAsync = ref.watch(workshopProjectsProvider(activeWorkshopId));

    return Scaffold(
      appBar: AppBar(
        title: workshops.length > 1
            ? DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: workshops.any((w) => w.id == activeWorkshopId)
                      ? activeWorkshopId
                      : workshops.first.id,
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppColors.amberPrimary,
                  ),
                  dropdownColor: isDark
                      ? AppColors.darkCard
                      : AppColors.lightSurface,
                  items: workshops.map((w) {
                    return DropdownMenuItem(
                      value: w.id,
                      child: Text(
                        w.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      ref
                          .read(activeWorkshopIdProvider.notifier)
                          .setWorkshopId(newId);
                    }
                  },
                ),
              )
            : Text(
                activeWorkshop.name.isNotEmpty
                    ? activeWorkshop.name
                    : 'لوحة إدارة الورشة',
              ),
        leading: IconButton(
          tooltip: 'الرئيسية',
          icon: const Icon(Icons.home_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            tooltip: 'إضافة ورشة جديدة',
            icon: const Icon(
              Icons.add_home_work_rounded,
              color: AppColors.amberPrimary,
            ),
            onPressed: () => _showNewWorkshopDialog(context),
          ),
          IconButton(
            tooltip: 'ماسح قطع الألمنيوم QR',
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.amberPrimary,
            ),
            onPressed: () => context.push('/scanner'),
          ),
          IconButton(
            tooltip: 'إعدادات المنشار والقواعد',
            icon: const Icon(Icons.tune_rounded, color: AppColors.amberPrimary),
            onPressed: () {
              context.push(
                '/dashboard/owner/rules?workshopId=$activeWorkshopId',
              );
            },
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/auth/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Dynamic Workshop Info Banner
                _buildWorkshopBanner(
                  context,
                  activeWorkshop,
                  workshops,
                  isDark,
                ),
                const SizedBox(height: 20),

                // 2. Real Live Metrics (KPIs)
                projectsAsync.when(
                  data: (projects) =>
                      _buildMetricsCards(context, projects, isDark),
                  loading: () => const LinearProgressIndicator(),
                  error: (err, stack) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),

                // 3. Quick Operation Actions
                _buildQuickActions(context, activeWorkshopId, isDark),
                const SizedBox(height: 32),

                // 4. View All Projects Section
                _buildProjectsSectionHeader(
                  context,
                  activeWorkshopId,
                  projectsAsync,
                ),
                const SizedBox(height: 12),

                // Projects Search Field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'البحث في المشاريع بالاسم، العميل، الهاتف، أو الموقع...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
                const SizedBox(height: 16),

                // 5. Projects Live List / Cards
                projectsAsync.when(
                  data: (projects) => _buildProjectsList(
                    context,
                    projects,
                    activeWorkshopId,
                    isDark,
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'حدث خطأ أثناء تحميل المشاريع: $err',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('مشروع جديد'),
        onPressed: () => _showNewProjectDialog(context, activeWorkshopId),
      ),
    );
  }

  Widget _buildWorkshopBanner(
    BuildContext context,
    WorkshopInfo activeWorkshop,
    List<WorkshopInfo> workshops,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider).value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amberPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.amberPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          activeWorkshop.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppColors.success,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'الورشة النشطة',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        if (currentUser?.fullName != null &&
                            currentUser!.fullName.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 15,
                                color: AppColors.slate400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'صاحب الورشة: ${currentUser.fullName}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        if (activeWorkshop.location.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: AppColors.slate400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                activeWorkshop.location,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        if (activeWorkshop.phone.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 15,
                                color: AppColors.slate400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                activeWorkshop.phone,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Workshop Switcher Chips if multiple workshops exist
          if (workshops.length > 1) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.swap_horiz_rounded,
                  size: 18,
                  color: AppColors.amberPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  'التبديل بين ورشك (${workshops.length}):',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: workshops.map((w) {
                final isSelected = w.id == activeWorkshop.id;
                return ChoiceChip(
                  label: Text(w.name),
                  selected: isSelected,
                  selectedColor: AppColors.amberPrimary.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(activeWorkshopIdProvider.notifier)
                          .setWorkshopId(w.id);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsCards(
    BuildContext context,
    List<Project> projects,
    bool isDark,
  ) {
    final totalUnits = projects.fold<int>(0, (sum, p) => sum + p.unitCount);
    final activeClients = projects
        .map((p) => p.clientName)
        .where((n) => n.isNotEmpty)
        .toSet()
        .length;

    final metrics = [
      {
        'title': 'إجمالي المشاريع',
        'value': '${projects.length}',
        'icon': Icons.business_center_rounded,
        'color': AppColors.amberPrimary,
        'subtitle': 'مشاريع مسجلة بالورشة',
      },
      {
        'title': 'وحدات وشبابيك القياس',
        'value': '$totalUnits',
        'icon': Icons.window_rounded,
        'color': AppColors.glassBlue,
        'subtitle': 'إجمالي عناصر القياس',
      },
      {
        'title': 'العملاء النشطين',
        'value': '$activeClients',
        'icon': Icons.people_alt_rounded,
        'color': AppColors.success,
        'subtitle': 'عملاء متعامل معهم',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 1 : 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isMobile ? 3.0 : 1.7,
          ),
          itemBuilder: (context, index) {
            final m = metrics[index];
            final color = m['color'] as Color;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(m['icon'] as IconData, color: color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          m['value'] as String,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          m['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    String activeWorkshopId,
    bool isDark,
  ) {
    final actions = [
      {
        'title': 'مشروع جديد',
        'desc': 'فتح مشروع وتسجيل بيانات العميل والقياسات',
        'icon': Icons.add_business_rounded,
        'color': AppColors.amberPrimary,
        'onTap': () => _showNewProjectDialog(context, activeWorkshopId),
      },
      {
        'title': 'قواعد ومعايير الورشة',
        'desc': 'تخصيص معادلات التقطيع وإعدادات منشار 660سم',
        'icon': Icons.tune_rounded,
        'color': AppColors.amberPrimary,
        'onTap': () =>
            context.push('/dashboard/owner/rules?workshopId=$activeWorkshopId'),
      },
      {
        'title': 'إضافة ورشة عمل',
        'desc': 'تسجيل ورشة إضافية تحت إدارتك والتبديل بينها',
        'icon': Icons.add_home_work_rounded,
        'color': AppColors.glassBlue,
        'onTap': () => _showNewWorkshopDialog(context),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 1 : 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isMobile ? 3.0 : 2.0,
          ),
          itemBuilder: (context, index) {
            final a = actions[index];
            final color = a['color'] as Color;
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: a['onTap'] as VoidCallback,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          a['icon'] as IconData,
                          color: color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              a['title'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a['desc'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.slate400
                                    : AppColors.slate600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProjectsSectionHeader(
    BuildContext context,
    String activeWorkshopId,
    AsyncValue<List<Project>> projectsAsync,
  ) {
    final count = projectsAsync.value?.length ?? 0;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_shared_rounded,
              color: AppColors.amberPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              'كافة مشاريع الورشة ($count)',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('مشروع جديد'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.amberPrimary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => _showNewProjectDialog(context, activeWorkshopId),
        ),
      ],
    );
  }

  Widget _buildProjectsList(
    BuildContext context,
    List<Project> projects,
    String activeWorkshopId,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    final filtered = projects.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery) ||
          p.clientName.toLowerCase().contains(_searchQuery) ||
          p.clientPhone.toLowerCase().contains(_searchQuery) ||
          p.location.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: isDark ? AppColors.slate600 : AppColors.slate400,
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty
                    ? 'لا توجد مشاريع مسجلة لهذه الورشة بعد'
                    : 'لا توجد مشاريع مطابقة لبحثك',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isEmpty
                    ? 'ابدأ بإضافة أول مشروع لحفظ قياسات الشبابيك وإجراء حسابات التقطيع وقص المقاطع.'
                    : 'جرب البحث باسم آخر أو إزالة نص البحث لعرض المشاريع.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.slate400,
                ),
              ),
              if (_searchQuery.isEmpty) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('إنشاء أول مشروع الآن'),
                  onPressed: () =>
                      _showNewProjectDialog(context, activeWorkshopId),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final project = filtered[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.amberPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.business_rounded,
                          color: AppColors.amberLight,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (project.clientName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'العميل: ${project.clientName}${project.clientPhone.isNotEmpty ? " • ${project.clientPhone}" : ""}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.slate400
                                      : AppColors.slate600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
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
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.slate400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          project.location,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate600,
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
  }

  void _showNewProjectDialog(BuildContext context, String workshopId) {
    final nameCtrl = TextEditingController();
    final clientNameCtrl = TextEditingController();
    final clientPhoneCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('مشروع جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المشروع *',
                      hintText: 'مثال: فيلا النرجس، عمارة الياسمين',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: clientNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم العميل',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: clientPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم هاتف العميل',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الموقع / العنوان',
                      border: OutlineInputBorder(),
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
                            const SnackBar(
                              content: Text('يرجى إدخال اسم المشروع'),
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        try {
                          final repo = ref.read(projectsRepositoryProvider);
                          final newProj = Project(
                            id: '',
                            workshopId: workshopId,
                            name: name,
                            clientName: clientNameCtrl.text.trim(),
                            clientPhone: clientPhoneCtrl.text.trim(),
                            location: locationCtrl.text.trim(),
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          );
                          final id = await repo.createProject(newProj);
                          if (context.mounted) {
                            ctx.pop();
                            context.push('/dashboard/owner/projects/$id?workshopId=$workshopId');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل حفظ المشروع: $e')),
                            );
                          }
                        } finally {
                          setDialogState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ وفتح المشروع'),
              ),
            ],
          );
        },
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
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('إضافة ورشة عمل جديدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'قم بإدخال بيانات الورشة الجديدة، وسيتم إضافتها إلى حسابك وإمكانية إدارتها فوراً.',
                    style: TextStyle(fontSize: 13, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الورشة *',
                      hintText: 'مثال: ورشة الأمل، فرع العليا',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storefront_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الموقع / المدينة',
                      hintText: 'مثال: الرياض - الصناعية الثانية',
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
                            const SnackBar(
                              content: Text('يرجى إدخال اسم الورشة'),
                            ),
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

                          ref
                              .read(activeWorkshopIdProvider.notifier)
                              .setWorkshopId(newId);

                          if (context.mounted) {
                            ctx.pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم إنشاء ورشة "$name" بنجاح'),
                              ),
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
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('إنشاء الورشة'),
              ),
            ],
          );
        },
      ),
    );
  }
}
