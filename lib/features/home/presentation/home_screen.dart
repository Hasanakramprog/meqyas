import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/domain/user_role.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.amberPrimary, AppColors.amberHover],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.amberPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.straighten_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'مِقْيَاس',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'هندسة الألمنيوم والزجاج',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDark ? AppColors.slate300 : AppColors.slate700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? AppColors.amberLight : AppColors.slate700,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Hero / Project Banner
                _buildHeroBanner(context, isDark),
                const SizedBox(height: 24),

                // Phase 0 System Verification Grid
                _buildSystemStatusGrid(context, isDark),
                const SizedBox(height: 24),

                // Roles & Portal Launchers
                Text(
                  'بوابات الدخول ومسارات النظام',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildRoleCards(context, isDark),
                const SizedBox(height: 28),

                // Live Preview: Mathematical Calculation Verification Vector
                Text(
                  'المعاينة الهندسية لقطاع 2000 بحاجب (شباك 120 × 150 سم)',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'عينة من أبعاد التقطيع والزجاج المعتمدة وفقاً لمعايير وثيقة المواصفات',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTestVectorCard(context, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'المرحلة 0: التأسيس والنظام التصميمي مكتمل',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'v1.0.0 (Phase 0 Setup)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'منظومة مِقْيَاس لحسابات الألمنيوم والزجاج',
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تصميم معماري صناعي مخصص، محرك حسابات نقي (Pure Dart)، دعم كامل للاتجاه العربي (RTL)، ومزامنة سحابية آمنة مع Firebase.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? AppColors.slate300 : AppColors.slate600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusGrid(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900
            ? 3
            : (constraints.maxWidth > 580 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossCount == 3 ? 2.6 : (crossCount == 2 ? 3.0 : 3.4),
          children: [
            _buildStatusItem(
              context,
              title: 'محرك الحسابات النقي',
              subtitle: 'Pure Dart (packages/maqyas_engine)',
              icon: Icons.precision_manufacturing_rounded,
              statusText: 'جاهز ومعزول',
              color: AppColors.amberPrimary,
              isDark: isDark,
            ),
            _buildStatusItem(
              context,
              title: 'بيئة Firebase ومحاكياتها',
              subtitle: 'Auth, Firestore, Functions, Storage',
              icon: Icons.cloud_done_rounded,
              statusText: 'مهيأة محلياً',
              color: AppColors.glassBlue,
              isDark: isDark,
            ),
            _buildStatusItem(
              context,
              title: 'قواعد الأمان والصلاحيات',
              subtitle: 'Custom Claims & Workshop Isolation',
              icon: Icons.security_rounded,
              statusText: 'إصدار v1 مفعل',
              color: AppColors.success,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String statusText,
    required Color color,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.slate100 : AppColors.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        statusText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCards(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 700 ? 3 : 1;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: constraints.maxWidth > 700 ? 1.45 : 2.5,
          children: [
            _buildRoleCard(
              context,
              role: UserRole.owner,
              description: 'إدخال القياسات، حسابات المقاطع، التقطيع، السلة وإرسال الطلبات',
              icon: Icons.storefront_rounded,
              color: AppColors.amberPrimary,
              route: '/dashboard/owner',
              isDark: isDark,
            ),
            _buildRoleCard(
              context,
              role: UserRole.supplier,
              description: 'إدارة الأسعار والمخزون ومتابعة طلبات التوريد الواردة',
              icon: Icons.local_shipping_rounded,
              color: AppColors.glassBlue,
              route: '/dashboard/supplier',
              isDark: isDark,
            ),
            _buildRoleCard(
              context,
              role: UserRole.admin,
              description: 'إدارة المستخدمين، الكتالوج، وقواعد الحسابات المعتمدة',
              icon: Icons.admin_panel_settings_rounded,
              color: AppColors.success,
              route: '/dashboard/admin',
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required UserRole role,
    required String description,
    required IconData icon,
    required Color color,
    required String route,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return Card(
      color: isDark ? AppColors.darkCard : AppColors.lightSurface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                    size: 18,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                role.labelAr,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestVectorCard(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    final items = [
      {'name': 'سكة 2000 بحاجب (Track)', 'qty': '2', 'formula': 'W - 3', 'len': '117.0 سم'},
      {'name': 'يو 2000 (U-Profile)', 'qty': '2', 'formula': 'H - 3.3', 'len': '146.7 سم'},
      {'name': 'كعب 2000 مفرد (Kaab)', 'qty': '4', 'formula': '(W - 2.5) / 2', 'len': '58.75 سم'},
      {'name': 'درفة منخل عامودي (Screen Vert.)', 'qty': '2', 'formula': 'H - 4.1', 'len': '145.9 سم'},
      {'name': 'درفة منخل أفقي (Screen Horiz.)', 'qty': '2', 'formula': 'kaab_len + 2', 'len': '60.75 سم'},
      {'name': 'ارتفاع الزجاج (Glass Height)', 'qty': '2', 'formula': 'H - 14', 'len': '136.0 سم'},
      {'name': 'عرض الزجاج للدرفة (Glass Width)', 'qty': '2', 'formula': '(W - 16.2) / 2', 'len': '51.9 سم'},
      {'name': 'مساحة اللوح (Pane Area)', 'qty': '2', 'formula': '136 × 51.9 / 10000', 'len': '0.70584 م²'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.slate100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('العنصر / المقاس',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 1,
                  child: Text('الكمية',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('معادلة القطاع',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('الناتج الدقيق',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final it = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        it['name']!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amberPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '×${it['qty']}',
                          style: const TextStyle(
                            color: AppColors.amberLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        it['formula']!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: isDark ? AppColors.slate400 : AppColors.slate600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        it['len']!,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.glassBlueLight,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
