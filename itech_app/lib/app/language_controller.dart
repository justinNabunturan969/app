import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The supported languages available in the app. The choice is retained across
/// launches, updates the app's common navigation labels, and is passed to the
/// device/browser speech-recognition engine for voice search.
enum AppLanguage {
  english('English', 'en-US'),
  tagalog('Tagalog', 'fil-PH'),
  cebuano('Cebuano', 'ceb-PH');

  const AppLanguage(this.label, this.speechLocaleId);

  final String label;
  final String speechLocaleId;
}

class LanguageController extends ChangeNotifier {
  LanguageController({this.prefs});

  static const _prefsKey = 'app_language';
  SharedPreferences? prefs;
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;

  Future<void> load() async {
    prefs ??= await SharedPreferences.getInstance();
    final saved = prefs!.getString(_prefsKey);
    _language = switch (saved) {
      'tagalog' => AppLanguage.tagalog,
      'cebuano' => AppLanguage.cebuano,
      _ => AppLanguage.english,
    };
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    prefs ??= await SharedPreferences.getInstance();
    await prefs!.setString(_prefsKey, language.name);
  }
}

/// Shared copy used by the navigation, app-language setting, and voice search.
/// Individual feature pages can progressively use this same class as their
/// labels are localized.
class AppCopy {
  const AppCopy(this.language);

  final AppLanguage language;
  bool get _english => language == AppLanguage.english;
  bool get _tagalog => language == AppLanguage.tagalog;

  String get home => _english ? 'Home' : (_tagalog ? 'Tahanan' : 'Balay');
  String get analytics =>
      _english ? 'Analytics' : (_tagalog ? 'Pagsusuri' : 'Analitika');
  String get borrowings =>
      _english ? 'Borrowings' : (_tagalog ? 'Mga Hiniram' : 'Mga Hinulam');
  String get profile => _tagalog ? 'Profile' : 'Profile';
  String get notifications =>
      _english ? 'Notifications' : (_tagalog ? 'Mga Abiso' : 'Mga Pahibalo');
  String get dashboard => _tagalog ? 'Dashboard' : 'Dashboard';
  String get live => _tagalog ? 'Live' : 'Live';
  String get inventory => _english ? 'Inventory' : 'Imbentaryo';
  String get pending =>
      _english ? 'Pending' : (_tagalog ? 'Nakabinbin' : 'Pending');
  String get scan => _english ? 'Scan' : 'I-scan';
  String get appLanguage => _english
      ? 'App language'
      : (_tagalog ? 'Wika ng app' : 'Pinulongan sa app');
  String get chooseAppLanguage => _english
      ? 'Choose app language'
      : (_tagalog ? 'Piliin ang wika ng app' : 'Pilia ang pinulongan sa app');
  String get appLanguageHelp => _english
      ? 'This changes the app’s main labels and the language used for voice search.'
      : (_tagalog
            ? 'Babaguhin nito ang mga pangunahing label ng app at ang wikang ginagamit sa paghahanap gamit ang boses.'
            : 'Usbon niini ang mga pangunang label sa app ug ang pinulongan nga gamiton sa pagpangita pinaagi sa tingog.');
  String get listening =>
      _english ? 'Listening…' : (_tagalog ? 'Nakikinig…' : 'Namati…');
  String readyFor(String languageName) => _english
      ? 'Ready for $languageName'
      : (_tagalog
            ? 'Handa para sa $languageName'
            : 'Andam para sa $languageName');
  String get microphoneUnavailable => _english
      ? 'Mic unavailable'
      : (_tagalog
            ? 'Hindi available ang mikropono'
            : 'Dili magamit ang mikropono');
  String get cancel =>
      _english ? 'Cancel' : (_tagalog ? 'Kanselahin' : 'Kanselahon');
  String get search =>
      _english ? 'Search' : (_tagalog ? 'Maghanap' : 'Pangitaa');
  String microphoneOrSpeechUnavailable() => _english
      ? 'Microphone or speech recognition is unavailable.'
      : (_tagalog
            ? 'Hindi available ang mikropono o pagkilala ng boses.'
            : 'Dili magamit ang mikropono o pag-ila sa tingog.');
  String languageNotInstalled(String languageName) => _english
      ? '$languageName speech recognition is not installed on this device.'
      : (_tagalog
            ? 'Hindi naka-install ang pagkilala ng boses para sa $languageName sa device na ito.'
            : 'Wala na-install ang pag-ila sa tingog alang sa $languageName niining device.');
  String languageSelected(String languageName) => _english
      ? '$languageName is now the app language.'
      : (_tagalog
            ? '$languageName ang napiling wika ng app.'
            : '$languageName ang gipiling pinulongan sa app.');
}
