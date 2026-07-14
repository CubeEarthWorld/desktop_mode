// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Touchpad für externes Display';

  @override
  String get appTitleShort => 'Touchpad';

  @override
  String get displayDisconnected => 'Verbindung zum externen Display getrennt';

  @override
  String sessionEndedUnexpectedly(String reason) {
    return 'Die Sitzung wurde unerwartet beendet ($reason)';
  }

  @override
  String get settingsTooltip => 'Einstellungen';

  @override
  String get diagnosticsTooltip => 'Diagnose';

  @override
  String get accessibilityStatusLabel => 'Bedienungshilfen';

  @override
  String get statusEnabled => 'Aktiviert';

  @override
  String get statusDisabledRequired =>
      'Deaktiviert (für die Steuerung erforderlich)';

  @override
  String get openAccessibilitySettings =>
      'Bedienungshilfen-Einstellungen öffnen';

  @override
  String get externalDisplayLabel => 'Externes Display';

  @override
  String displayConnectedValue(String displays) {
    return '$displays (zum Ändern der Auflösung tippen)';
  }

  @override
  String get displayNotConnected => 'Nicht verbunden';

  @override
  String get openTouchpad => 'Touchpad öffnen';

  @override
  String get sideloadHint =>
      'Wenn die Bedienungshilfen-Einstellung bei einer per Sideload installierten App ausgegraut ist, aktiviere in den App-Infos „Eingeschränkte Einstellungen zulassen“.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String settingsLoadFailed(String error) {
    return 'Einstellungen konnten nicht geladen werden: $error';
  }

  @override
  String get sectionStartup => 'Start';

  @override
  String get autoStartLabel => 'Autostart';

  @override
  String get autoStartDescription =>
      'Touchpad-Bildschirm automatisch öffnen, wenn ein externes Display angeschlossen wird';

  @override
  String get residentMonitoringLabel => 'Hintergrundüberwachung';

  @override
  String get residentMonitoringDescription =>
      'Auch bei geschlossener App auf externe Display-Verbindungen achten';

  @override
  String get sectionDisplay => 'Anzeige';

  @override
  String get showCursorLabel => 'Externer Cursor';

  @override
  String get showCursorDescription =>
      'Virtuellen Cursor auf dem externen Display anzeigen';

  @override
  String get touchGlowLabel => 'Bestätigungseffekt';

  @override
  String get touchGlowDescription =>
      'Nur im Moment eines bestätigten Klicks oder langen Drückens anzeigen';

  @override
  String get sectionInput => 'Steuerung';

  @override
  String get pointerSpeedLabel => 'Zeigergeschwindigkeit';

  @override
  String get dragSensitivityLabel => 'Ziehempfindlichkeit';

  @override
  String get longPressDurationLabel => 'Zeit für langes Drücken/Ziehbeginn';

  @override
  String get cursorIdleTimeoutLabel => 'Cursor automatisch ausblenden nach';

  @override
  String get cursorIdleOff => 'AUS';

  @override
  String secondsValue(String seconds) {
    return '$seconds s';
  }

  @override
  String get targetDisplayLabel => 'Ziel-Display';

  @override
  String get targetDisplayAuto => 'Automatisch (größtes externes Display)';

  @override
  String get homeAppLabel => 'Home-App des externen Displays';

  @override
  String get homeAppDescription =>
      'App, die beim Öffnen des Startbildschirms über die Home-Taste oder die Zurück-Geste gestartet wird. Falls der Standard-Launcher kein Querformat unterstützt, kann ein anderer Launcher gewählt werden.';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get displayModeLabel => 'Auflösung des externen Displays';

  @override
  String get displayModeDescription =>
      'Wähle aus den vom angeschlossenen Gerät unterstützten Auflösungen/Bildwiederholraten. Ohne Auswahl wird der Standardmodus verwendet. Bei ausgeblendetem Cursor hat diese Einstellung keine Wirkung.';

  @override
  String get displayModeSingle =>
      'Dieses Gerät unterstützt keine mehreren Auflösungen.';

  @override
  String get displayModeDefault => 'Standard';

  @override
  String get sectionProtection => 'Fehlbedienungsschutz & Displayschutz';

  @override
  String get touchLockLabel => 'Touch-Sperre';

  @override
  String get touchLockDescription =>
      'Verhindert versehentliche Eingaben; zum Entsperren 1 Sekunde gedrückt halten';

  @override
  String get touchLockTimeoutLabel => 'Sperren nach Inaktivität';

  @override
  String get minimizeBrightnessWhileLockedLabel =>
      'Helligkeit während der Sperre minimieren';

  @override
  String get minimizeBrightnessWhileLockedDescription =>
      'Verwendet während der Touch-Sperre die niedrigste Bildschirmhelligkeit und stellt sie nach dem Entsperren wieder her';

  @override
  String get lockNowTooltip => 'Jetzt sperren';

  @override
  String get oledProtectionLabel => 'OLED-Displayschutz';

  @override
  String get oledProtectionDescription =>
      'Verschiebt die Oberfläche einschließlich Sperrbildschirm alle paar Minuten leicht';

  @override
  String get sectionHowTo => 'Bedienung';

  @override
  String get howToText =>
      'Bewegen: Bewege einen Finger, um den Cursor zu bewegen\n\nKlick: Mit einem Finger tippen und schnell loslassen, ohne ihn zu bewegen\n\nLanges Drücken: Einen Finger eine Weile still halten und dann ohne Bewegung loslassen (Android-Mäuse haben keinen Rechtsklick, dieses lange Drücken ersetzt ihn)\n\nZiehen: Einen Finger für die Dauer des langen Drückens still halten und dann ohne Anheben bewegen – das Ziehen beginnt. Finger anheben, um es zu beenden\n\nScrollen: Bewege zwei Finger, um ein kontinuierliches Wischen an das externe Display weiterzuleiten. Langsam bewegen zum Scrollen, schnell loslassen zum Schwungscrollen\n\nUntere Leiste „Zurück“: Sendet ein Wischen vom Bildschirmrand an das externe Display. Reagiert eventuell nicht, wenn die App/der Launcher auf dem externen Display keine Gestennavigation erkennt (Android bietet keinen offiziellen Weg, „Zurück“ an ein bestimmtes Display zu senden)\n\nUntere Leiste „Home“: Startet die eingestellte Home-App (oder den Systemstandard) auf dem externen Display\n\nUntere Leiste „Apps“: Öffnet die Liste der installierten Apps und startet die ausgewählte App auf dem externen Display';

  @override
  String get openDiagnostics => 'Diagnose öffnen';

  @override
  String get diagnosticsTitle => 'Diagnose';

  @override
  String get deviceLabel => 'Gerät';

  @override
  String get loadingEllipsis => 'Wird geladen…';

  @override
  String get androidVersionLabel => 'Android-Version';

  @override
  String get manufacturerModelLabel => 'Hersteller / Modell';

  @override
  String get appVersionLabel => 'App-Version';

  @override
  String diagnosticsFetchFailed(String error) {
    return 'Abruf fehlgeschlagen: $error';
  }

  @override
  String get statusDisabled => 'Deaktiviert';

  @override
  String get statusPresent => 'Ja';

  @override
  String get statusAbsent => 'Nein';

  @override
  String get statusNotSet => 'Nicht festgelegt';

  @override
  String get statusYes => 'Ja';

  @override
  String get statusNo => 'Nein';

  @override
  String get statusNone => 'Keiner';

  @override
  String get connectedDisplaysLabel => 'Verbundene Displays';

  @override
  String get appListTitle => 'Apps';

  @override
  String get searchHint => 'Suchen';

  @override
  String get reloadAppList => 'App-Liste neu laden';

  @override
  String get noMatchingApps => 'Keine passenden Apps';

  @override
  String get unlockByLongPress => 'Zum Entsperren gedrückt halten';

  @override
  String get sectionAbout => 'Info';

  @override
  String get openSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get openSourceLicensesDescription =>
      'Lizenzhinweise für die in dieser App verwendete Open-Source-Software';

  @override
  String get resetSettingsButton => 'Auf Standard zurücksetzen';

  @override
  String get resetSettingsConfirmTitle => 'Einstellungen zurücksetzen?';

  @override
  String get resetSettingsConfirmMessage =>
      'Alle Einstellungen werden auf die Standardwerte zurückgesetzt.';

  @override
  String get resetSettingsCancel => 'Abbrechen';

  @override
  String get resetSettingsConfirmAction => 'Zurücksetzen';

  @override
  String get resetSettingsDone =>
      'Die Einstellungen wurden auf die Standardwerte zurückgesetzt';
}
