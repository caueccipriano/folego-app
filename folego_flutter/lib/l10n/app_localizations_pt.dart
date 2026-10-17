// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Fôlego';

  @override
  String get home => 'Início';

  @override
  String get transactions => 'Lançamentos';

  @override
  String get plan => 'Plano';

  @override
  String get wallet => 'Carteira';

  @override
  String get profile => 'Perfil';

  @override
  String get newExpense => 'Novo gasto';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get appName => 'Fôlego';

  @override
  String get home => 'Início';

  @override
  String get transactions => 'Lançamentos';

  @override
  String get plan => 'Plano';

  @override
  String get wallet => 'Carteira';

  @override
  String get profile => 'Perfil';

  @override
  String get newExpense => 'Novo gasto';
}
