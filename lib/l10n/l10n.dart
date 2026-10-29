import 'package:flutter/widgets.dart';

/// Locale state kept separate so screens can be redesigned independently.
class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  void toggle() {
    _locale = _locale.languageCode == 'en'
        ? const Locale('ha')
        : const Locale('en');
    notifyListeners();
  }

  void setLocale(Locale locale) {
    if (!{'en', 'ha'}.contains(locale.languageCode) || locale == _locale) {
      return;
    }
    _locale = Locale(locale.languageCode);
    notifyListeners();
  }
}
