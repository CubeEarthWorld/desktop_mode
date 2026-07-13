// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'External Display Touchpad';

  @override
  String get appTitleShort => 'Touchpad';

  @override
  String get displayDisconnected => 'External display disconnected';

  @override
  String sessionEndedUnexpectedly(String reason) {
    return 'The session ended unexpectedly ($reason)';
  }

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get diagnosticsTooltip => 'Diagnostics';

  @override
  String get accessibilityStatusLabel => 'Accessibility';

  @override
  String get statusEnabled => 'Enabled';

  @override
  String get statusDisabledRequired => 'Disabled (required for input)';

  @override
  String get openAccessibilitySettings => 'Open accessibility settings';

  @override
  String get externalDisplayLabel => 'External display';

  @override
  String displayConnectedValue(String displays) {
    return '$displays (tap to change resolution)';
  }

  @override
  String get displayNotConnected => 'Not connected';

  @override
  String get openTouchpad => 'Open touchpad';

  @override
  String get sideloadHint =>
      'If the accessibility setting is greyed out for a sideloaded app, enable \"Allow restricted settings\" from the app info screen.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String settingsLoadFailed(String error) {
    return 'Failed to load settings: $error';
  }

  @override
  String get sectionStartup => 'Startup';

  @override
  String get autoStartLabel => 'Auto start';

  @override
  String get autoStartDescription =>
      'Open the touchpad screen automatically when an external display is connected';

  @override
  String get residentMonitoringLabel => 'Background monitoring';

  @override
  String get residentMonitoringDescription =>
      'Keep watching for external display connections even when the app is closed';

  @override
  String get sectionDisplay => 'Display';

  @override
  String get showCursorLabel => 'External cursor';

  @override
  String get showCursorDescription =>
      'Show a virtual cursor on the external display';

  @override
  String get touchGlowLabel => 'Action feedback effect';

  @override
  String get touchGlowDescription =>
      'Show a brief effect only when a click or long press is committed';

  @override
  String get sectionInput => 'Input';

  @override
  String get pointerSpeedLabel => 'Pointer speed';

  @override
  String get longPressDurationLabel => 'Long-press / drag start time';

  @override
  String get cursorIdleTimeoutLabel => 'Cursor auto-hide time';

  @override
  String get cursorIdleOff => 'OFF';

  @override
  String secondsValue(String seconds) {
    return '${seconds}s';
  }

  @override
  String get targetDisplayLabel => 'Target display';

  @override
  String get targetDisplayAuto => 'Auto (largest external display)';

  @override
  String get homeAppLabel => 'Home app for the external display';

  @override
  String get homeAppDescription =>
      'App launched when opening Home via the home button or back navigation. If the default launcher does not support landscape screens, you can pick another launcher.';

  @override
  String get systemDefault => 'System default';

  @override
  String get displayModeLabel => 'External display resolution';

  @override
  String get displayModeDescription =>
      'Choose from the resolutions/refresh rates supported by the connected device. When unset, the device default mode is used. This setting has no effect while the cursor is hidden.';

  @override
  String get displayModeSingle =>
      'This device does not support multiple resolutions.';

  @override
  String get displayModeDefault => 'Default';

  @override
  String get sectionProtection => 'Accident prevention & screen protection';

  @override
  String get touchLockLabel => 'Touch lock';

  @override
  String get touchLockDescription =>
      'Prevent accidental input; hold for 1 second to unlock';

  @override
  String get touchLockTimeoutLabel => 'Lock after inactivity';

  @override
  String get minimizeBrightnessWhileLockedLabel =>
      'Minimize brightness while locked';

  @override
  String get minimizeBrightnessWhileLockedDescription =>
      'Use the lowest screen brightness during touch lock and restore it after unlocking';

  @override
  String get lockNowTooltip => 'Lock now';

  @override
  String get oledProtectionLabel => 'OLED display protection';

  @override
  String get oledProtectionDescription =>
      'Slightly shift the UI, including the lock screen, every few minutes';

  @override
  String get sectionHowTo => 'How to use';

  @override
  String get howToText =>
      'Move: move one finger to move the cursor\n\nClick: tap with one finger and release quickly without moving\n\nLong press: hold one finger still for a while, then release without moving (Android mice have no right click, so use this long press as the right-click substitute)\n\nDrag: hold one finger still for the long-press start time, then move it without lifting to start dragging. Lift the finger to finish\n\nScroll: move two fingers to forward a continuous swipe to the external display. Move slowly to scroll, release quickly to fling\n\nBottom nav \"Back\": sends an edge swipe to the external display. It may not respond if the app/launcher on the external display does not recognize gesture navigation (Android has no official way to send \"Back\" to a specific display)\n\nBottom nav \"Home\": launches the configured home app (or the system default) on the external display\n\nBottom nav \"Apps\": opens the list of installed apps and launches the selected app on the external display';

  @override
  String get openDiagnostics => 'Open diagnostics';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get deviceLabel => 'Device';

  @override
  String get loadingEllipsis => 'Loading…';

  @override
  String get androidVersionLabel => 'Android version';

  @override
  String get manufacturerModelLabel => 'Manufacturer / model';

  @override
  String get appVersionLabel => 'App version';

  @override
  String diagnosticsFetchFailed(String error) {
    return 'Failed to fetch: $error';
  }

  @override
  String get statusDisabled => 'Disabled';

  @override
  String get statusPresent => 'Yes';

  @override
  String get statusAbsent => 'No';

  @override
  String get statusNotSet => 'Not set';

  @override
  String get statusYes => 'Yes';

  @override
  String get statusNo => 'No';

  @override
  String get statusNone => 'None';

  @override
  String get connectedDisplaysLabel => 'Connected displays';

  @override
  String get appListTitle => 'Apps';

  @override
  String get searchHint => 'Search';

  @override
  String get reloadAppList => 'Reload app list';

  @override
  String get noMatchingApps => 'No matching apps';

  @override
  String get unlockByLongPress => 'Hold to unlock';

  @override
  String get sectionAbout => 'About';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get openSourceLicensesDescription =>
      'License notices for open-source software used in this app';

  @override
  String get resetSettingsButton => 'Reset to defaults';

  @override
  String get resetSettingsConfirmTitle => 'Reset settings?';

  @override
  String get resetSettingsConfirmMessage =>
      'All settings will be restored to their default values.';

  @override
  String get resetSettingsCancel => 'Cancel';

  @override
  String get resetSettingsConfirmAction => 'Reset';

  @override
  String get resetSettingsDone => 'Settings have been reset to defaults';
}
