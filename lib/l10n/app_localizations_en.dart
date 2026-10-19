// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Meqyas';

  @override
  String get appSubtitle => 'Aluminum & Glass Workshop Engineering Suite';

  @override
  String get login => 'Sign In';

  @override
  String get register => 'Register Workshop';

  @override
  String get email => 'Email Address';

  @override
  String get password => 'Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get phone => 'Phone Number';

  @override
  String get workshopName => 'Workshop Name';

  @override
  String get workshopLocation => 'Workshop Location';

  @override
  String get roleOwner => 'Workshop Owner';

  @override
  String get roleSupplier => 'Supplier';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get projects => 'Projects';

  @override
  String get measurements => 'Measurements';

  @override
  String get catalog => 'Catalog';

  @override
  String get inventory => 'Inventory & Remnants';

  @override
  String get cart => 'Cart';

  @override
  String get orders => 'Supply Orders';

  @override
  String get reports => 'Reports';

  @override
  String get systemStatus => 'System Status';

  @override
  String get engineStatus => 'Pure Calculation Engine';

  @override
  String get emulatorsStatus => 'Firebase Emulators';

  @override
  String get connected => 'Connected';

  @override
  String get offline => 'Offline';

  @override
  String get ruleMissing => 'No approved rule for this item';

  @override
  String get negativeLengthError =>
      'Result length is negative, check measurements';

  @override
  String get widthGreaterThanZero => 'Enter width greater than zero';

  @override
  String get heightGreaterThanZero => 'Enter height greater than zero';

  @override
  String get unitCm => 'cm';

  @override
  String get unitMm => 'mm';

  @override
  String get unitM => 'm';

  @override
  String get unitPiece => 'pcs';

  @override
  String get unitBar => 'bar';

  @override
  String get unitRoll => 'roll';
}
