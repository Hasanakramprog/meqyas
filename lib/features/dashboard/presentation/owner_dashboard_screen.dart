import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order_model.dart';
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
  int _selectedTabIndex = 0; // 0: المشاريع, 1: التوريد والموردين, 2: أدوات الورشة
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
    final ordersAsync = ref.watch(workshopOrdersProvider(activeWorkshopId));
    final projectsList = projectsAsync.value ?? [];
    final ordersList = ordersAsync.value ?? [];

    final totalUnits = projectsList.fold<int>(0, (sum, p) => sum + p.unitCount);
    final activeClients = projectsList
        .map((p) => p.clientName)
        .where((n) => n.isNotEmpty)
        .toSet()
        .length;
    final quotedOrdersCount = ordersList
        .where((o) => o.status == OrderStatus.quoted)
        .length;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: _buildCompactUnifiedHeader(
        context: context,
        theme: theme,
        isDark: isDark,
        activeWorkshop: activeWorkshop,
        activeWorkshopId: activeWorkshopId,
        workshops: workshops,
        projectsCount: projectsList.length,
        totalUnits: totalUnits,
        activeClients: activeClients,
        ownerName: currentUser?.fullName ?? '',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Segmented Workspace Tabs + Quick Pill Dock (No vertical stacking!)
          _buildWorkspaceNavAndQuickDock(
            context: context,
            isDark: isDark,
            activeWorkshopId: activeWorkshopId,
            projectsCount: projectsList.length,
            ordersCount: ordersList.length,
            quotedOrdersCount: quotedOrdersCount,
          ),

          // Main Workspace View (Switches cleanly in-place by tab)
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: IndexedStack(
                  index: _selectedTabIndex,
                  children: [
                    // Tab 0: المشاريع والقياسات (Compact Grid View)
                    _buildProjectsTabWorkspace(
                      context: context,
                      projectsAsync: projectsAsync,
                      activeWorkshopId: activeWorkshopId,
                      isDark: isDark,
                      totalUnits: totalUnits,
                      activeClients: activeClients,
                    ),

                    // Tab 1: التوريد والموردين (Side-by-Side Procurement Hub)
                    _buildSupplyAndSuppliersTabWorkspace(
                      context: context,
                      ordersAsync: ordersAsync,
                      activeWorkshopId: activeWorkshopId,
                      isDark: isDark,
                    ),

                    // Tab 2: أدوات وإعدادات الورشة (2x2 Tools Grid + Branches)
                    _buildWorkshopToolsTabWorkspace(
                      context: context,
                      activeWorkshop: activeWorkshop,
                      activeWorkshopId: activeWorkshopId,
                      workshops: workshops,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Slim Technical Status Footer Bar
          _buildCompactStatusBar(
            activeWorkshop: activeWorkshop,
            workshopsCount: workshops.length,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  /// 1. Unified Compact Header + Inline KPI Strip (<= 68px)
  PreferredSizeWidget _buildCompactUnifiedHeader({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required WorkshopInfo activeWorkshop,
    required String activeWorkshopId,
    required List<WorkshopInfo> workshops,
    required int projectsCount,
    required int totalUnits,
    required int activeClients,
    required String ownerName,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showInlineKpis = screenWidth >= 820;

    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                // Right (RTL start): Brand + Workshop Switcher
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.amberPrimary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.amberPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.straighten_rounded,
                    color: AppColors.amberLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'مِقْيَاس',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.amberLight,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: workshops.length > 1
                                    ? DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isDense: true,
                                          isExpanded: true,
                                          value: workshops.any(
                                                (w) =>
                                                    w.id == activeWorkshopId,
                                              )
                                              ? activeWorkshopId
                                              : workshops.first.id,
                                          icon: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: AppColors.amberLight,
                                            size: 18,
                                          ),
                                          dropdownColor: isDark
                                              ? AppColors.darkCard
                                              : AppColors.lightSurface,
                                          items: workshops.map((w) {
                                            return DropdownMenuItem(
                                              value: w.id,
                                              child: Text(
                                                w.name,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (newId) {
                                            if (newId != null) {
                                              ref
                                                  .read(
                                                    activeWorkshopIdProvider
                                                        .notifier,
                                                  )
                                                  .setWorkshopId(newId);
                                            }
                                          },
                                        ),
                                      )
                                    : Text(
                                        activeWorkshop.name.isNotEmpty
                                            ? activeWorkshop.name
                                            : 'لوحة إدارة الورشة',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _showNewWorkshopDialog(context),
                                borderRadius: BorderRadius.circular(4),
                                child: const Tooltip(
                                  message: 'إضافة ورشة جديدة',
                                  child: Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 16,
                                      color: AppColors.amberLight,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Center: 3 Inline KPI Pills side-by-side (on wide screens)
                if (showInlineKpis) ...[
                  const Spacer(),
                  _buildInlineKpiPill(
                    icon: Icons.folder_copy_outlined,
                    label: 'المشاريع',
                    value: '$projectsCount',
                    color: AppColors.amberLight,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildInlineKpiPill(
                    icon: Icons.window_rounded,
                    label: 'وحدات القياس',
                    value: '$totalUnits',
                    color: AppColors.glassBlueLight,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildInlineKpiPill(
                    icon: Icons.people_alt_outlined,
                    label: 'العملاء',
                    value: '$activeClients',
                    color: AppColors.success,
                    isDark: isDark,
                  ),
                  const Spacer(),
                ] else
                  const SizedBox(width: 6),

                // Left (RTL end): Direct Hardware Action Buttons
                _buildTopActionButton(
                  tooltip: 'ماسح قطع الألمنيوم QR',
                  icon: Icons.qr_code_scanner_rounded,
                  label: screenWidth >= 600 ? 'ماسح QR' : null,
                  color: AppColors.glassBlueLight,
                  isDark: isDark,
                  onTap: () => context.push('/scanner'),
                ),
                const SizedBox(width: 6),
                _buildTopActionButton(
                  tooltip: 'قواعد المنشار (660 سم)',
                  icon: Icons.tune_rounded,
                  label: screenWidth >= 600 ? 'القواعد' : null,
                  color: AppColors.amberLight,
                  isDark: isDark,
                  onTap: () => context.push(
                    '/dashboard/owner/rules?workshopId=$activeWorkshopId',
                  ),
                ),
                if (ownerName.isNotEmpty && screenWidth >= 980) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.engineering_outlined,
                          size: 15,
                          color: AppColors.slate400,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ownerName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'تسجيل الخروج',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) context.go('/auth/login');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineKpiPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.slate300 : AppColors.slate700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionButton({
    required String tooltip,
    required IconData icon,
    required String? label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 10 : 8,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              if (label != null) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 2. Horizontal Segmented Workspace Tabs + Quick Action Pill Dock
  Widget _buildWorkspaceNavAndQuickDock({
    required BuildContext context,
    required bool isDark,
    required String activeWorkshopId,
    required int projectsCount,
    required int ordersCount,
    required int quotedOrdersCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              // Horizontal Segmented Tabs (Side-by-side, never stacked vertically!)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWorkspaceTabButton(
                      index: 0,
                      icon: Icons.architecture_rounded,
                      label: 'المشاريع والقياسات ($projectsCount)',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildWorkspaceTabButton(
                      index: 1,
                      icon: Icons.local_shipping_outlined,
                      label: 'التوريد والموردين ($ordersCount)',
                      badgeText: quotedOrdersCount > 0
                          ? '$quotedOrdersCount تسعيرة جديدة'
                          : null,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildWorkspaceTabButton(
                      index: 2,
                      icon: Icons.handyman_outlined,
                      label: 'أدوات وإعدادات الورشة',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              // Quick-Access Pill Dock (1-click jump without scrolling)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'مشروع جديد',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amberLight,
                        foregroundColor: AppColors.darkBackground,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () =>
                          _showNewProjectDialog(context, activeWorkshopId),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickDockPill(
                      icon: Icons.receipt_long_outlined,
                      label: 'طلبات الموردين',
                      color: AppColors.glassBlueLight,
                      isDark: isDark,
                      onTap: () => context.push(
                        '/dashboard/owner/orders?workshopId=$activeWorkshopId',
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildQuickDockPill(
                      icon: Icons.storefront_outlined,
                      label: 'دليل الموردين',
                      color: AppColors.amberLight,
                      isDark: isDark,
                      onTap: () => context.push('/dashboard/owner/suppliers'),
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

  Widget _buildWorkspaceTabButton({
    required int index,
    required IconData icon,
    required String label,
    String? badgeText,
    required bool isDark,
  }) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.amberPrimary.withValues(alpha: 0.18)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.amberLight
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected
                  ? AppColors.amberLight
                  : (isDark ? AppColors.slate300 : AppColors.slate600),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppColors.amberLight
                    : (isDark ? AppColors.slate200 : AppColors.slate800),
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkBackground,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDockPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.slate200 : AppColors.slate800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. TAB 0: Projects & Measurements Workspace (2-Column Grid, Immediately Visible!)
  Widget _buildProjectsTabWorkspace({
    required BuildContext context,
    required AsyncValue<List<Project>> projectsAsync,
    required String activeWorkshopId,
    required bool isDark,
    required int totalUnits,
    required int activeClients,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showMobileKpiStrip = screenWidth < 820;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Slim KPI strip on mobile/small tablets
          if (showMobileKpiStrip) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildInlineKpiPill(
                    icon: Icons.folder_copy_outlined,
                    label: 'المشاريع',
                    value: '${projectsAsync.value?.length ?? 0}',
                    color: AppColors.amberLight,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildInlineKpiPill(
                    icon: Icons.window_rounded,
                    label: 'وحدات القياس',
                    value: '$totalUnits',
                    color: AppColors.glassBlueLight,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildInlineKpiPill(
                    icon: Icons.people_alt_outlined,
                    label: 'العملاء',
                    value: '$activeClients',
                    color: AppColors.success,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Search Bar Row
          TextField(
            decoration: InputDecoration(
              hintText:
                  'ابحث باسم المشروع أو العميل أو الهاتف أو الموقع...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.glassBlueLight,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.glassBlueLight),
              ),
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),

          // Projects Grid (2 columns on desktop/tablet so user sees 4+ projects at once without scrolling!)
          Expanded(
            child: projectsAsync.when(
              data: (projects) {
                final filtered = projects.where((p) {
                  if (_searchQuery.isEmpty) return true;
                  return p.name.toLowerCase().contains(_searchQuery) ||
                      p.clientName.toLowerCase().contains(_searchQuery) ||
                      p.clientPhone.toLowerCase().contains(_searchQuery) ||
                      p.location.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyProjectsState(
                    context,
                    activeWorkshopId,
                    isDark,
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1060
                        ? 3
                        : (constraints.maxWidth >= 660 ? 2 : 1);

                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: filtered.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 168,
                      ),
                      itemBuilder: (context, index) {
                        final project = filtered[index];
                        return _buildCompactProjectCard(
                          context: context,
                          project: project,
                          activeWorkshopId: activeWorkshopId,
                          isDark: isDark,
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'حدث خطأ أثناء تحميل المشاريع: $err',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactProjectCard({
    required BuildContext context,
    required Project project,
    required String activeWorkshopId,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: isDark ? AppColors.darkCard : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(
          '/dashboard/owner/projects/${project.id}?workshopId=$activeWorkshopId',
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // RTL Right-Edge Amber Indicator Bar
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Title + Unit Count Badge + Delete Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.amberPrimary.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.architecture_rounded,
                            color: AppColors.amberLight,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glassBlue.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.glassBlueLight.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Text(
                            '${project.unitCount} وحدة',
                            style: const TextStyle(
                              color: AppColors.glassBlueLight,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Row 2: Client & Location Metadata
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (project.clientName.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 13,
                                color: AppColors.slate400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${project.clientName}${project.clientPhone.isNotEmpty ? " • ${project.clientPhone}" : ""}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.slate300
                                      : AppColors.slate600,
                                ),
                              ),
                            ],
                          ),
                        if (project.location.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 13,
                                color: AppColors.slate400,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                project.location,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.slate400
                                      : AppColors.slate600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const Spacer(),

                    // Row 3: 3 Direct 1-Click Action Buttons (as designed in Stitch!)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.straighten_rounded, size: 15),
                            label: const Text(
                              'فتح القياسات',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.amberLight,
                              foregroundColor: AppColors.darkBackground,
                              elevation: 0,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () => context.push(
                              '/dashboard/owner/projects/${project.id}?workshopId=$activeWorkshopId',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.assignment_outlined,
                              size: 15,
                              color: AppColors.glassBlueLight,
                            ),
                            label: const Text(
                              'الاحتياجات والتوريد',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.glassBlueLight,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              side: BorderSide(
                                color: AppColors.glassBlueLight.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () => context.push(
                              '/dashboard/owner/projects/${project.id}/requirements?workshopId=$activeWorkshopId',
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'حذف المشروع',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          onPressed: () => _confirmDeleteProject(
                            context,
                            activeWorkshopId,
                            project,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProjectsState(
    BuildContext context,
    String activeWorkshopId,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 52,
              color: isDark ? AppColors.slate600 : AppColors.slate400,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty
                  ? 'لا توجد مشاريع مسجلة لهذه الورشة بعد'
                  : 'لا توجد مشاريع مطابقة لبحثك',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isEmpty
                  ? 'ابدأ بإضافة أول مشروع لحفظ قياسات الشبابيك وحساب الاحتياجات والتقطيع.'
                  : 'جرب البحث باسم آخر أو مسح نص البحث.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.slate400,
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('إنشاء أول مشروع الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amberLight,
                  foregroundColor: AppColors.darkBackground,
                ),
                onPressed: () =>
                    _showNewProjectDialog(context, activeWorkshopId),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 4. TAB 1: Supply, Orders & Suppliers Workspace (Side-by-Side Hub)
  Widget _buildSupplyAndSuppliersTabWorkspace({
    required BuildContext context,
    required AsyncValue<List<OrderModel>> ordersAsync,
    required String activeWorkshopId,
    required bool isDark,
  }) {
    final orders = ordersAsync.value ?? [];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top 2 Side-by-Side Action Cards (Orders & Suppliers Directory)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 680;
              final cards = [
                _buildHubActionCard(
                  title: 'طلبات التوريد وأوامر الشراء',
                  subtitle:
                      'متابعة الطلبات المرسلة من احتياجات المشاريع، مراجعة تسعيرات الموردين واعتمادها',
                  badgeText: '${orders.length} طلب',
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.glassBlueLight,
                  isDark: isDark,
                  onTap: () => context.push(
                    '/dashboard/owner/orders?workshopId=$activeWorkshopId',
                  ),
                ),
                _buildHubActionCard(
                  title: 'دليل الموردين المعتمدين',
                  subtitle:
                      'استعراض الموردين وأرقام التواصل المباشر عبر واتساب والعناوين',
                  badgeText: 'دليل الموردين',
                  icon: Icons.storefront_rounded,
                  color: AppColors.amberLight,
                  isDark: isDark,
                  onTap: () => context.push('/dashboard/owner/suppliers'),
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                );
              }
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 8),
                  cards[1],
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Live Recent Orders Table / Grid right inside the tab
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'أحدث طلبات التوريد وعروض الأسعار من الموردين',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('عرض كل الطلبات'),
                onPressed: () => context.push(
                  '/dashboard/owner/orders?workshopId=$activeWorkshopId',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد طلبات توريد مرسلة بعد — يمكنك إرسال طلب مباشرة من شاشة احتياجات أي مشروع.',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.slate400
                            : AppColors.slate600,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: orders.take(6).length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final isQuoted = order.status == OrderStatus.quoted;
                      return Material(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isQuoted
                                ? AppColors.amberLight
                                : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          onTap: () => context.push(
                            '/dashboard/owner/orders/${order.id}?workshopId=$activeWorkshopId',
                          ),
                          leading: Icon(
                            isQuoted
                                ? Icons.request_quote_rounded
                                : Icons.receipt_long_rounded,
                            color: isQuoted
                                ? AppColors.amberLight
                                : AppColors.glassBlueLight,
                          ),
                          title: Text(
                            '${order.orderNumber} • ${order.supplierName}${order.projectName.isNotEmpty ? " (${order.projectName})" : ""}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'الأصناف المتوفرة: ${order.availableItemsCount}/${order.items.length} • الإجمالي: ${order.computedTotal.toStringAsFixed(2)} ${order.currency}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (isQuoted
                                      ? AppColors.amberLight
                                      : AppColors.glassBlueLight)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              order.status.arabicLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isQuoted
                                    ? AppColors.amberLight
                                    : AppColors.glassBlueLight,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 5. TAB 2: Workshop Tools, Rules & Branches (Side-by-Side Grid)
  Widget _buildWorkshopToolsTabWorkspace({
    required BuildContext context,
    required WorkshopInfo activeWorkshop,
    required String activeWorkshopId,
    required List<WorkshopInfo> workshops,
    required bool isDark,
  }) {
    final tools = [
      {
        'title': 'قواعد التقطيع ومعايير منشار 660 سم',
        'desc': 'تخصيص معادلات الخصم وسماكة شفرة المنشار وطول القضيب القياسي',
        'icon': Icons.tune_rounded,
        'color': AppColors.amberLight,
        'onTap': () =>
            context.push('/dashboard/owner/rules?workshopId=$activeWorkshopId'),
      },
      {
        'title': 'مخزون الفضلات (Remnants)',
        'desc': 'إدارة بواقي قضبان الألمنيوم الصالحة لإعادة الاستخدام وتقليل الهدر',
        'icon': Icons.inventory_2_outlined,
        'color': AppColors.success,
        'onTap': () => context.push(
          '/dashboard/owner/remnants?workshopId=$activeWorkshopId',
        ),
      },
      {
        'title': 'ماسح قطع الألمنيوم QR',
        'desc': 'مسح ملصقات القطع المقصوصة في الورشة للتحقق من الأبعاد والوحدة',
        'icon': Icons.qr_code_scanner_rounded,
        'color': AppColors.glassBlueLight,
        'onTap': () => context.push('/scanner'),
      },
      {
        'title': 'إضافة فرع / ورشة عمل جديدة',
        'desc': 'تسجيل ورشة إضافية تحت حسابك والتبديل الفوري بينها من الشريط العلوي',
        'icon': Icons.add_home_work_rounded,
        'color': AppColors.amberPrimary,
        'onTap': () => _showNewWorkshopDialog(context),
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 680 ? 2 : 1;
          return GridView.builder(
            itemCount: tools.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 112,
            ),
            itemBuilder: (context, index) {
              final t = tools[index];
              final color = t['color'] as Color;
              return _buildHubActionCard(
                title: t['title'] as String,
                subtitle: t['desc'] as String,
                badgeText: 'أداة هندسية',
                icon: t['icon'] as IconData,
                color: color,
                isDark: isDark,
                onTap: t['onTap'] as VoidCallback,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHubActionCard({
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? AppColors.darkCard : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }

  /// 6. Compact Technical Status Footer Bar (32px)
  Widget _buildCompactStatusBar({
    required WorkshopInfo activeWorkshop,
    required int workshopsCount,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.precision_manufacturing_outlined,
                size: 13,
                color: AppColors.amberLight,
              ),
              const SizedBox(width: 6),
              Text(
                'الورشة: ${activeWorkshop.name}${activeWorkshop.location.isNotEmpty ? " (${activeWorkshop.location})" : ""}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'طول القضيب القياسي: 660 سم  •  الفروع المرتبطة: $workshopsCount',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteProject(
    BuildContext context,
    String workshopId,
    Project project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('حذف المشروع نهائياً'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف مشروع «${project.name}»؟\n\n'
          'سيتم حذف جميع البيانات المرتبطة به في قاعدة البيانات:\n'
          '• وحدات القياس والشبابيك\n'
          '• جدول احتياجات المشروع من المواد\n'
          '• خطط القص والملفات والفضلات المرتبطة به\n'
          '• بنود السلة والمسودات المرتبطة بالمشروع',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'حذف نهائي',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(projectsRepositoryProvider)
            .deleteProject(workshopId, project.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم حذف مشروع «${project.name}» وجميع بياناته المرتبطة بنجاح ✅',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ أثناء حذف المشروع: $e')),
          );
        }
      }
    }
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
                            context.push(
                              '/dashboard/owner/projects/$id?workshopId=$workshopId',
                            );
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
