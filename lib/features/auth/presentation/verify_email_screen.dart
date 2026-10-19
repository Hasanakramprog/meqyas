import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import 'controllers/auth_controller.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _resent = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تأكيد البريد الإلكتروني'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authActionControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/auth/login');
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.glassBlue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: AppColors.glassBlueLight,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'تحقق من صندوق بريدك الإلكتروني',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    userAsync.when(
                      data: (user) => Text(
                        'أرسلنا رابط التحقق إلى:\n${user?.email ?? ""}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.slate300 : AppColors.slate700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'يرجى فتح الرابط المرسل لتفعيل حساب ورشتك، ثم اضغط على زر "تحقق من التفعيل" أدناه.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.slate400 : AppColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Reload/Check status button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('تحقق من التفعيل الآن'),
                      onPressed: () async {
                        await ref.read(authActionControllerProvider.notifier).reloadUser();
                        final refreshedUser = ref.read(authRepositoryProvider).currentUser;
                        if (refreshedUser?.isEmailVerified == true) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تأكيد البريد الإلكتروني بنجاح!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            context.go('/dashboard/owner');
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('لم يتم تأكيد البريد بعد، تفقد بريدك واضغط الرابط'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Resend button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(_resent ? 'تم إرسال الرابط مجدداً' : 'إعادة إرسال رابط التحقق'),
                      onPressed: _resent
                          ? null
                          : () async {
                              await ref.read(authActionControllerProvider.notifier).sendEmailVerification();
                              setState(() => _resent = true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تمت إعادة إرسال رابط التحقق بنجاح')),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
