// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Тачпад для внешнего дисплея';

  @override
  String get displayDisconnected => 'Внешний дисплей отключён';

  @override
  String sessionEndedUnexpectedly(String reason) {
    return 'Сеанс неожиданно завершился ($reason)';
  }

  @override
  String get settingsTooltip => 'Настройки';

  @override
  String get diagnosticsTooltip => 'Диагностика';

  @override
  String get accessibilityStatusLabel => 'Специальные возможности';

  @override
  String get statusEnabled => 'Включено';

  @override
  String get statusDisabledRequired => 'Выключено (необходимо для управления)';

  @override
  String get openAccessibilitySettings =>
      'Открыть настройки спец. возможностей';

  @override
  String get externalDisplayLabel => 'Внешний дисплей';

  @override
  String displayConnectedValue(String displays) {
    return '$displays (нажмите, чтобы изменить разрешение)';
  }

  @override
  String get displayNotConnected => 'Не подключён';

  @override
  String get openTouchpad => 'Открыть тачпад';

  @override
  String get sideloadHint =>
      'Если настройка специальных возможностей недоступна для приложения, установленного вручную, включите «Разрешить ограниченные настройки» на странице сведений о приложении.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String settingsLoadFailed(String error) {
    return 'Не удалось загрузить настройки: $error';
  }

  @override
  String get sectionStartup => 'Запуск';

  @override
  String get autoStartLabel => 'Автозапуск';

  @override
  String get autoStartDescription =>
      'Автоматически открывать экран тачпада при подключении внешнего дисплея';

  @override
  String get residentMonitoringLabel => 'Фоновое отслеживание';

  @override
  String get residentMonitoringDescription =>
      'Отслеживать подключение внешнего дисплея, даже когда приложение закрыто';

  @override
  String get sectionDisplay => 'Отображение';

  @override
  String get showCursorLabel => 'Внешний курсор';

  @override
  String get showCursorDescription =>
      'Показывать виртуальный курсор на внешнем дисплее';

  @override
  String get touchGlowLabel => 'Эффект подтверждения';

  @override
  String get touchGlowDescription =>
      'Показывать только в момент подтверждения нажатия или долгого нажатия';

  @override
  String get sectionInput => 'Управление';

  @override
  String get pointerSpeedLabel => 'Скорость указателя';

  @override
  String get longPressDurationLabel =>
      'Время долгого нажатия/начала перетаскивания';

  @override
  String get cursorIdleTimeoutLabel => 'Время автоскрытия курсора';

  @override
  String get cursorIdleOff => 'ВЫКЛ';

  @override
  String secondsValue(String seconds) {
    return '$seconds с';
  }

  @override
  String get targetDisplayLabel => 'Целевой дисплей';

  @override
  String get targetDisplayAuto =>
      'Автоматически (самый большой внешний дисплей)';

  @override
  String get homeAppLabel => 'Домашнее приложение внешнего дисплея';

  @override
  String get homeAppDescription =>
      'Приложение, запускаемое при переходе на главный экран кнопкой «Домой» или жестом «Назад». Если стандартный лаунчер не поддерживает горизонтальный экран, можно выбрать другой.';

  @override
  String get systemDefault => 'Системное по умолчанию';

  @override
  String get displayModeLabel => 'Разрешение внешнего дисплея';

  @override
  String get displayModeDescription =>
      'Выберите из разрешений/частот обновления, поддерживаемых подключённым устройством. Если ничего не выбрано, используется режим по умолчанию. Настройка не применяется, если курсор скрыт.';

  @override
  String get displayModeSingle =>
      'Это устройство не поддерживает несколько разрешений.';

  @override
  String get displayModeDefault => 'По умолчанию';

  @override
  String get sectionProtection => 'Защита от случайных нажатий и экрана';

  @override
  String get touchLockLabel => 'Блокировка сенсора';

  @override
  String get touchLockDescription =>
      'Предотвращает случайные нажатия; удерживайте 1 секунду для разблокировки';

  @override
  String get touchLockTimeoutLabel => 'Блокировать после бездействия';

  @override
  String get minimizeBrightnessWhileLockedLabel =>
      'Минимальная яркость во время блокировки';

  @override
  String get minimizeBrightnessWhileLockedDescription =>
      'Устанавливает минимальную яркость при блокировке сенсора и восстанавливает её после разблокировки';

  @override
  String get lockNowTooltip => 'Заблокировать сейчас';

  @override
  String get oledProtectionLabel => 'Защита OLED-дисплея';

  @override
  String get oledProtectionDescription =>
      'Слегка сдвигает интерфейс, включая экран блокировки, каждые несколько минут';

  @override
  String get sectionHowTo => 'Как пользоваться';

  @override
  String get howToText =>
      'Перемещение: двигайте одним пальцем, чтобы перемещать курсор\n\nКлик: коснитесь одним пальцем и быстро отпустите, не двигая его\n\nДолгое нажатие: удерживайте палец неподвижно некоторое время, затем отпустите, не двигая (у мыши в Android нет правой кнопки, поэтому долгое нажатие заменяет правый клик)\n\nПеретаскивание: удерживайте палец неподвижно в течение времени начала долгого нажатия, затем, не отрывая, двигайте — начнётся перетаскивание. Отпустите палец, чтобы закончить\n\nПрокрутка: движение двумя пальцами передаётся на внешний дисплей как непрерывный свайп. Двигайте медленно для прокрутки, быстро отпустите для инерционной прокрутки\n\nНижняя панель «Назад»: отправляет на внешний дисплей свайп от края экрана. Может не сработать, если приложение/лаунчер на внешнем дисплее не распознаёт жестовую навигацию (в Android нет официального способа отправить «Назад» на конкретный дисплей)\n\nНижняя панель «Домой»: запускает на внешнем дисплее настроенное домашнее приложение (или системное по умолчанию)\n\nНижняя панель «Приложения»: открывает список установленных приложений и запускает выбранное на внешнем дисплее';

  @override
  String get openDiagnostics => 'Открыть диагностику';

  @override
  String get diagnosticsTitle => 'Диагностика';

  @override
  String get deviceLabel => 'Устройство';

  @override
  String get loadingEllipsis => 'Загрузка…';

  @override
  String get androidVersionLabel => 'Версия Android';

  @override
  String get manufacturerModelLabel => 'Производитель / модель';

  @override
  String get appVersionLabel => 'Версия приложения';

  @override
  String diagnosticsFetchFailed(String error) {
    return 'Не удалось получить: $error';
  }

  @override
  String get statusDisabled => 'Выключено';

  @override
  String get statusPresent => 'Есть';

  @override
  String get statusAbsent => 'Нет';

  @override
  String get statusNotSet => 'Не задано';

  @override
  String get statusYes => 'Да';

  @override
  String get statusNo => 'Нет';

  @override
  String get statusNone => 'Нет';

  @override
  String get connectedDisplaysLabel => 'Подключённые дисплеи';

  @override
  String get appListTitle => 'Приложения';

  @override
  String get searchHint => 'Поиск';

  @override
  String get reloadAppList => 'Обновить список приложений';

  @override
  String get noMatchingApps => 'Подходящих приложений нет';

  @override
  String get windowModeTooltip => 'Пропорции окна при запуске';

  @override
  String get windowModeAuto => 'Автоматически';

  @override
  String get windowModePhonePortrait => 'Телефон вертикально';

  @override
  String get windowModePhoneLandscape => 'Телефон горизонтально';

  @override
  String get windowModeFullExternal => 'Весь внешний экран';

  @override
  String get unlockByLongPress => 'Удерживайте для разблокировки';

  @override
  String get sectionAbout => 'О приложении';

  @override
  String get openSourceLicenses => 'Лицензии открытого ПО';

  @override
  String get openSourceLicensesDescription =>
      'Сведения о лицензиях открытого программного обеспечения, используемого в приложении';
}
