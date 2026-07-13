import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('ja'),
    Locale('ko'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// Application title shown in the task switcher
  ///
  /// In en, this message translates to:
  /// **'External Display Touchpad'**
  String get appTitle;

  /// Snackbar shown when the external display is unplugged
  ///
  /// In en, this message translates to:
  /// **'External display disconnected'**
  String get displayDisconnected;

  /// No description provided for @sessionEndedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The session ended unexpectedly ({reason})'**
  String sessionEndedUnexpectedly(String reason);

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @diagnosticsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTooltip;

  /// No description provided for @accessibilityStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibilityStatusLabel;

  /// No description provided for @statusEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get statusEnabled;

  /// No description provided for @statusDisabledRequired.
  ///
  /// In en, this message translates to:
  /// **'Disabled (required for input)'**
  String get statusDisabledRequired;

  /// No description provided for @openAccessibilitySettings.
  ///
  /// In en, this message translates to:
  /// **'Open accessibility settings'**
  String get openAccessibilitySettings;

  /// No description provided for @externalDisplayLabel.
  ///
  /// In en, this message translates to:
  /// **'External display'**
  String get externalDisplayLabel;

  /// No description provided for @displayConnectedValue.
  ///
  /// In en, this message translates to:
  /// **'{displays} (tap to change resolution)'**
  String displayConnectedValue(String displays);

  /// No description provided for @displayNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get displayNotConnected;

  /// No description provided for @openTouchpad.
  ///
  /// In en, this message translates to:
  /// **'Open touchpad'**
  String get openTouchpad;

  /// No description provided for @sideloadHint.
  ///
  /// In en, this message translates to:
  /// **'If the accessibility setting is greyed out for a sideloaded app, enable \"Allow restricted settings\" from the app info screen.'**
  String get sideloadHint;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load settings: {error}'**
  String settingsLoadFailed(String error);

  /// No description provided for @sectionStartup.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get sectionStartup;

  /// No description provided for @autoStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto start'**
  String get autoStartLabel;

  /// No description provided for @autoStartDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the touchpad screen automatically when an external display is connected'**
  String get autoStartDescription;

  /// No description provided for @residentMonitoringLabel.
  ///
  /// In en, this message translates to:
  /// **'Background monitoring'**
  String get residentMonitoringLabel;

  /// No description provided for @residentMonitoringDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep watching for external display connections even when the app is closed'**
  String get residentMonitoringDescription;

  /// No description provided for @sectionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get sectionDisplay;

  /// No description provided for @showCursorLabel.
  ///
  /// In en, this message translates to:
  /// **'External cursor'**
  String get showCursorLabel;

  /// No description provided for @showCursorDescription.
  ///
  /// In en, this message translates to:
  /// **'Show a virtual cursor on the external display'**
  String get showCursorDescription;

  /// No description provided for @touchGlowLabel.
  ///
  /// In en, this message translates to:
  /// **'Action feedback effect'**
  String get touchGlowLabel;

  /// No description provided for @touchGlowDescription.
  ///
  /// In en, this message translates to:
  /// **'Show a brief effect only when a click or long press is committed'**
  String get touchGlowDescription;

  /// No description provided for @sectionInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get sectionInput;

  /// No description provided for @pointerSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Pointer speed'**
  String get pointerSpeedLabel;

  /// No description provided for @longPressDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Long-press / drag start time'**
  String get longPressDurationLabel;

  /// No description provided for @cursorIdleTimeoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Cursor auto-hide time'**
  String get cursorIdleTimeoutLabel;

  /// No description provided for @cursorIdleOff.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get cursorIdleOff;

  /// No description provided for @secondsValue.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String secondsValue(String seconds);

  /// No description provided for @targetDisplayLabel.
  ///
  /// In en, this message translates to:
  /// **'Target display'**
  String get targetDisplayLabel;

  /// No description provided for @targetDisplayAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (largest external display)'**
  String get targetDisplayAuto;

  /// No description provided for @homeAppLabel.
  ///
  /// In en, this message translates to:
  /// **'Home app for the external display'**
  String get homeAppLabel;

  /// No description provided for @homeAppDescription.
  ///
  /// In en, this message translates to:
  /// **'App launched when opening Home via the home button or back navigation. If the default launcher does not support landscape screens, you can pick another launcher.'**
  String get homeAppDescription;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @displayModeLabel.
  ///
  /// In en, this message translates to:
  /// **'External display resolution'**
  String get displayModeLabel;

  /// No description provided for @displayModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose from the resolutions/refresh rates supported by the connected device. When unset, the device default mode is used. This setting has no effect while the cursor is hidden.'**
  String get displayModeDescription;

  /// No description provided for @displayModeSingle.
  ///
  /// In en, this message translates to:
  /// **'This device does not support multiple resolutions.'**
  String get displayModeSingle;

  /// No description provided for @displayModeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get displayModeDefault;

  /// No description provided for @sectionProtection.
  ///
  /// In en, this message translates to:
  /// **'Accident prevention & screen protection'**
  String get sectionProtection;

  /// No description provided for @touchLockLabel.
  ///
  /// In en, this message translates to:
  /// **'Touch lock'**
  String get touchLockLabel;

  /// No description provided for @touchLockDescription.
  ///
  /// In en, this message translates to:
  /// **'Prevent accidental input; hold for 1 second to unlock'**
  String get touchLockDescription;

  /// No description provided for @touchLockTimeoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Lock after inactivity'**
  String get touchLockTimeoutLabel;

  /// No description provided for @minimizeBrightnessWhileLockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimize brightness while locked'**
  String get minimizeBrightnessWhileLockedLabel;

  /// No description provided for @minimizeBrightnessWhileLockedDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the lowest screen brightness during touch lock and restore it after unlocking'**
  String get minimizeBrightnessWhileLockedDescription;

  /// No description provided for @lockNowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get lockNowTooltip;

  /// No description provided for @oledProtectionLabel.
  ///
  /// In en, this message translates to:
  /// **'OLED display protection'**
  String get oledProtectionLabel;

  /// No description provided for @oledProtectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Slightly shift the UI, including the lock screen, every few minutes'**
  String get oledProtectionDescription;

  /// No description provided for @sectionHowTo.
  ///
  /// In en, this message translates to:
  /// **'How to use'**
  String get sectionHowTo;

  /// No description provided for @howToText.
  ///
  /// In en, this message translates to:
  /// **'Move: move one finger to move the cursor\n\nClick: tap with one finger and release quickly without moving\n\nLong press: hold one finger still for a while, then release without moving (Android mice have no right click, so use this long press as the right-click substitute)\n\nDrag: hold one finger still for the long-press start time, then move it without lifting to start dragging. Lift the finger to finish\n\nScroll: move two fingers to forward a continuous swipe to the external display. Move slowly to scroll, release quickly to fling\n\nBottom nav \"Back\": sends an edge swipe to the external display. It may not respond if the app/launcher on the external display does not recognize gesture navigation (Android has no official way to send \"Back\" to a specific display)\n\nBottom nav \"Home\": launches the configured home app (or the system default) on the external display\n\nBottom nav \"Apps\": opens the list of installed apps and launches the selected app on the external display'**
  String get howToText;

  /// No description provided for @openDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Open diagnostics'**
  String get openDiagnostics;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @deviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceLabel;

  /// No description provided for @loadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingEllipsis;

  /// No description provided for @androidVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Android version'**
  String get androidVersionLabel;

  /// No description provided for @manufacturerModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer / model'**
  String get manufacturerModelLabel;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersionLabel;

  /// No description provided for @diagnosticsFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch: {error}'**
  String diagnosticsFetchFailed(String error);

  /// No description provided for @statusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get statusDisabled;

  /// No description provided for @statusPresent.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get statusPresent;

  /// No description provided for @statusAbsent.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get statusAbsent;

  /// No description provided for @statusNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get statusNotSet;

  /// No description provided for @statusYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get statusYes;

  /// No description provided for @statusNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get statusNo;

  /// No description provided for @statusNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get statusNone;

  /// No description provided for @connectedDisplaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Connected displays'**
  String get connectedDisplaysLabel;

  /// No description provided for @appListTitle.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get appListTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @reloadAppList.
  ///
  /// In en, this message translates to:
  /// **'Reload app list'**
  String get reloadAppList;

  /// No description provided for @noMatchingApps.
  ///
  /// In en, this message translates to:
  /// **'No matching apps'**
  String get noMatchingApps;

  /// No description provided for @windowModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Window aspect ratio at launch'**
  String get windowModeTooltip;

  /// No description provided for @windowModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get windowModeAuto;

  /// No description provided for @windowModePhonePortrait.
  ///
  /// In en, this message translates to:
  /// **'Phone portrait'**
  String get windowModePhonePortrait;

  /// No description provided for @windowModePhoneLandscape.
  ///
  /// In en, this message translates to:
  /// **'Phone landscape'**
  String get windowModePhoneLandscape;

  /// No description provided for @windowModeFullExternal.
  ///
  /// In en, this message translates to:
  /// **'Full external screen'**
  String get windowModeFullExternal;

  /// No description provided for @unlockByLongPress.
  ///
  /// In en, this message translates to:
  /// **'Hold to unlock'**
  String get unlockByLongPress;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @openSourceLicensesDescription.
  ///
  /// In en, this message translates to:
  /// **'License notices for open-source software used in this app'**
  String get openSourceLicensesDescription;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'ja',
    'ko',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
