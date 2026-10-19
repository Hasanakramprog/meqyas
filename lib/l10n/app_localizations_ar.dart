// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'مِقْيَاس';

  @override
  String get appSubtitle => 'هندسة وإدارة ورش الألمنيوم والزجاج';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'إنشاء حساب ورشة جديدة';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get phone => 'رقم الهاتف';

  @override
  String get workshopName => 'اسم الورشة';

  @override
  String get workshopLocation => 'موقع الورشة';

  @override
  String get roleOwner => 'المعلم (صاحب الورشة)';

  @override
  String get roleSupplier => 'المورد';

  @override
  String get roleAdmin => 'الأدمن';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get projects => 'المشاريع';

  @override
  String get measurements => 'القياسات';

  @override
  String get catalog => 'دليل الأصناف';

  @override
  String get inventory => 'المخزون والفضلات';

  @override
  String get cart => 'سلة الاحتياجات';

  @override
  String get orders => 'طلبات التوريد';

  @override
  String get reports => 'التقارير';

  @override
  String get systemStatus => 'حالة النظام';

  @override
  String get engineStatus => 'محرك الحسابات النقي';

  @override
  String get emulatorsStatus => 'محاكيات Firebase';

  @override
  String get connected => 'متصل';

  @override
  String get offline => 'غير متصل';

  @override
  String get ruleMissing => 'لا توجد قاعدة معتمدة لهذا الصنف';

  @override
  String get negativeLengthError => 'الطول الناتج سالب، تحقق من القياسات';

  @override
  String get widthGreaterThanZero => 'أدخل عرضاً أكبر من صفر';

  @override
  String get heightGreaterThanZero => 'أدخل ارتفاعاً أكبر من صفر';

  @override
  String get unitCm => 'سم';

  @override
  String get unitMm => 'ملم';

  @override
  String get unitM => 'متر';

  @override
  String get unitPiece => 'قطعة';

  @override
  String get unitBar => 'قضيب';

  @override
  String get unitRoll => 'لفة';
}
