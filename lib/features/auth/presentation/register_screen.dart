import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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
                      const SizedBox(height: 24),

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
                      const SizedBox(height: 28),

                      // Submit
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            // Phase 1: bootstrapOwner call
                            context.go('/dashboard/owner');
                          }
                        },
                        child: const Text('تسجيل وإنشاء الورشة'),
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
