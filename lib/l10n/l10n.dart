import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// `AppLocalizations.of(context)` の短縮形。
/// UI 層は文言を直接書かず、必ずこの拡張経由で ARB のキーを参照する。
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
