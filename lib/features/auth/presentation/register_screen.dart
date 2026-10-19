import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/auth_repository.dart';
import 'controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _workshopNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _workshopNameController.dispose();
    _locationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final actionState = ref.watch(authActionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل ورشة جديدة'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'بيانات المعلم والورشة',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'أنشئ حسابك لبدء إدارة القياسات والمشاريع وعروض التوريد',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.slate400 : AppColors.slate600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Error banner if any
                      if (actionState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  actionState.errorMessage!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Full name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل للمعلم',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'يرجى إدخال الاسم الكامل' : null,
                      ),
                      const SizedBox(height: 16),

                      // Workshop name
                      TextFormField(
                        controller: _workshopNameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الورشة',
                          hintText: 'ورشة السلام للألمنيوم والزجاج',
                          prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'يرجى إدخال اسم الورشة' : null,
                      ),
                      const SizedBox(height: 16),

                      // Workshop location
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'موقع الورشة / المدينة',
                          hintText: 'الرياض - المنطقة الصناعية',
                          prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'يرجى إدخال موقع الورشة' : null,
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف / الواتساب',
                          hintText: '+966 50 000 0000',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                          if (!value.contains('@')) return 'يرجى إدخال بريد إلكتروني صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.length < 6 ? 'كلمة المرور يجب ألا تقل عن 6 خانات' : null,
                      ),
                      const SizedBox(height: 24),

                      // Submit
                      ElevatedButton(
                        onPressed: actionState.isLoading
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  final data = SignUpData(
                                    fullName: _nameController.text,
                                    email: _emailController.text,
                                    password: _passwordController.text,
                                    phone: _phoneController.text,
                                    workshopName: _workshopNameController.text,
                                    workshopLocation: _locationController.text,
                                  );

                                  await ref
                                      .read(authActionControllerProvider.notifier)
                                      .signUp(data);
                                }
                              },
                        child: actionState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('تسجيل وإنشاء الورشة'),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('لديك حساب بالفعل؟', style: theme.textTheme.bodySmall),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: const Text('تسجيل الدخول'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
