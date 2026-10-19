import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'مِقْيَاس'**
  String get appName;

  /// No description provided for @appSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'هندسة وإدارة ورش الألمنيوم والزجاج'**
  String get appSubtitle;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @register.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب ورشة جديدة'**
  String get register;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phone;

  /// No description provided for @workshopName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الورشة'**
  String get workshopName;

  /// No description provided for @workshopLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقع الورشة'**
  String get workshopLocation;

  /// No description provided for @roleOwner.
  ///
  /// In ar, this message translates to:
  /// **'المعلم (صاحب الورشة)'**
  String get roleOwner;

  /// No description provided for @roleSupplier.
  ///
  /// In ar, this message translates to:
  /// **'المورد'**
  String get roleSupplier;

  /// No description provided for @roleAdmin.
  ///
  /// In ar, this message translates to:
  /// **'الأدمن'**
  String get roleAdmin;

  /// No description provided for @dashboard.
  ///
  /// In ar, this message translates to:
  /// **'لوحة التحكم'**
  String get dashboard;

  /// No description provided for @projects.
  ///
  /// In ar, this message translates to:
  /// **'المشاريع'**
  String get projects;

  /// No description provided for @measurements.
  ///
  /// In ar, this message translates to:
  /// **'القياسات'**
  String get measurements;

  /// No description provided for @catalog.
  ///
  /// In ar, this message translates to:
  /// **'دليل الأصناف'**
  String get catalog;

  /// No description provided for @inventory.
  ///
  /// In ar, this message translates to:
  /// **'المخزون والفضلات'**
  String get inventory;

  /// No description provided for @cart.
  ///
  /// In ar, this message translates to:
  /// **'سلة الاحتياجات'**
  String get cart;

  /// No description provided for @orders.
  ///
  /// In ar, this message translates to:
  /// **'طلبات التوريد'**
  String get orders;

  /// No description provided for @reports.
  ///
  /// In ar, this message translates to:
  /// **'التقارير'**
  String get reports;

  /// No description provided for @systemStatus.
  ///
  /// In ar, this message translates to:
  /// **'حالة النظام'**
  String get systemStatus;

  /// No description provided for @engineStatus.
  ///
  /// In ar, this message translates to:
  /// **'محرك الحسابات النقي'**
  String get engineStatus;

  /// No description provided for @emulatorsStatus.
  ///
  /// In ar, this message translates to:
  /// **'محاكيات Firebase'**
  String get emulatorsStatus;

  /// No description provided for @connected.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get connected;

  /// No description provided for @offline.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل'**
  String get offline;

  /// No description provided for @ruleMissing.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قاعدة معتمدة لهذا الصنف'**
  String get ruleMissing;

  /// No description provided for @negativeLengthError.
  ///
  /// In ar, this message translates to:
  /// **'الطول الناتج سالب، تحقق من القياسات'**
  String get negativeLengthError;

  /// No description provided for @widthGreaterThanZero.
  ///
  /// In ar, this message translates to:
  /// **'أدخل عرضاً أكبر من صفر'**
  String get widthGreaterThanZero;

  /// No description provided for @heightGreaterThanZero.
  ///
  /// In ar, this message translates to:
  /// **'أدخل ارتفاعاً أكبر من صفر'**
  String get heightGreaterThanZero;

  /// No description provided for @unitCm.
  ///
  /// In ar, this message translates to:
  /// **'سم'**
  String get unitCm;

  /// No description provided for @unitMm.
  ///
  /// In ar, this message translates to:
  /// **'ملم'**
  String get unitMm;

  /// No description provided for @unitM.
  ///
  /// In ar, this message translates to:
  /// **'متر'**
  String get unitM;

  /// No description provided for @unitPiece.
  ///
  /// In ar, this message translates to:
  /// **'قطعة'**
  String get unitPiece;

  /// No description provided for @unitBar.
  ///
  /// In ar, this message translates to:
  /// **'قضيب'**
  String get unitBar;

  /// No description provided for @unitRoll.
  ///
  /// In ar, this message translates to:
  /// **'لفة'**
  String get unitRoll;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
