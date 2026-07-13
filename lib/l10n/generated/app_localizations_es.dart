// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Panel táctil para pantalla externa';

  @override
  String get appTitleShort => 'Panel táctil';

  @override
  String get displayDisconnected => 'Se desconectó la pantalla externa';

  @override
  String sessionEndedUnexpectedly(String reason) {
    return 'La sesión terminó de forma inesperada ($reason)';
  }

  @override
  String get settingsTooltip => 'Ajustes';

  @override
  String get diagnosticsTooltip => 'Diagnóstico';

  @override
  String get accessibilityStatusLabel => 'Accesibilidad';

  @override
  String get statusEnabled => 'Activado';

  @override
  String get statusDisabledRequired =>
      'Desactivado (necesario para el control)';

  @override
  String get openAccessibilitySettings => 'Abrir ajustes de accesibilidad';

  @override
  String get externalDisplayLabel => 'Pantalla externa';

  @override
  String displayConnectedValue(String displays) {
    return '$displays (toca para cambiar la resolución)';
  }

  @override
  String get displayNotConnected => 'No conectada';

  @override
  String get openTouchpad => 'Abrir panel táctil';

  @override
  String get sideloadHint =>
      'Si el ajuste de accesibilidad aparece en gris en una app instalada manualmente, activa «Permitir ajustes restringidos» desde la información de la app.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String settingsLoadFailed(String error) {
    return 'No se pudieron cargar los ajustes: $error';
  }

  @override
  String get sectionStartup => 'Inicio';

  @override
  String get autoStartLabel => 'Inicio automático';

  @override
  String get autoStartDescription =>
      'Abrir automáticamente la pantalla del panel táctil al conectar una pantalla externa';

  @override
  String get residentMonitoringLabel => 'Supervisión en segundo plano';

  @override
  String get residentMonitoringDescription =>
      'Vigilar la conexión de pantallas externas incluso con la app cerrada';

  @override
  String get sectionDisplay => 'Pantalla';

  @override
  String get showCursorLabel => 'Cursor externo';

  @override
  String get showCursorDescription =>
      'Mostrar un cursor virtual en la pantalla externa';

  @override
  String get touchGlowLabel => 'Efecto de confirmación';

  @override
  String get touchGlowDescription =>
      'Mostrar solo en el momento en que se confirma un clic o una pulsación larga';

  @override
  String get sectionInput => 'Control';

  @override
  String get pointerSpeedLabel => 'Velocidad del puntero';

  @override
  String get longPressDurationLabel =>
      'Tiempo de pulsación larga/inicio de arrastre';

  @override
  String get cursorIdleTimeoutLabel =>
      'Tiempo de ocultación automática del cursor';

  @override
  String get cursorIdleOff => 'OFF';

  @override
  String secondsValue(String seconds) {
    return '${seconds}s';
  }

  @override
  String get targetDisplayLabel => 'Pantalla de destino';

  @override
  String get targetDisplayAuto => 'Automático (la pantalla externa más grande)';

  @override
  String get homeAppLabel => 'App de inicio de la pantalla externa';

  @override
  String get homeAppDescription =>
      'App que se abre al ir al inicio con el botón de inicio o el gesto de volver. Si el lanzador predeterminado no admite pantallas horizontales, puedes elegir otro lanzador.';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get displayModeLabel => 'Resolución de la pantalla externa';

  @override
  String get displayModeDescription =>
      'Elige entre las resoluciones/tasas de refresco que admite el dispositivo conectado. Si no se selecciona, se usa el modo predeterminado. Este ajuste no se aplica si el cursor está oculto.';

  @override
  String get displayModeSingle =>
      'Este dispositivo no admite varias resoluciones.';

  @override
  String get displayModeDefault => 'Predeterminado';

  @override
  String get sectionProtection =>
      'Prevención de errores y protección de pantalla';

  @override
  String get touchLockLabel => 'Bloqueo táctil';

  @override
  String get touchLockDescription =>
      'Evita pulsaciones accidentales; mantén pulsado 1 segundo para desbloquear';

  @override
  String get touchLockTimeoutLabel => 'Bloquear tras inactividad';

  @override
  String get minimizeBrightnessWhileLockedLabel =>
      'Reducir el brillo al mínimo durante el bloqueo';

  @override
  String get minimizeBrightnessWhileLockedDescription =>
      'Usa el brillo mínimo durante el bloqueo táctil y lo restaura al desbloquear';

  @override
  String get lockNowTooltip => 'Bloquear ahora';

  @override
  String get oledProtectionLabel => 'Protección de pantalla OLED';

  @override
  String get oledProtectionDescription =>
      'Desplaza ligeramente la interfaz, incluida la pantalla de bloqueo, cada pocos minutos';

  @override
  String get sectionHowTo => 'Cómo se usa';

  @override
  String get howToText =>
      'Mover: mueve un dedo para desplazar el cursor\n\nClic: toca con un dedo y suéltalo rápido sin moverlo\n\nPulsación larga: mantén un dedo quieto un momento y suéltalo sin moverlo (los ratones de Android no tienen clic derecho, así que esta pulsación larga lo sustituye)\n\nArrastrar: mantén un dedo quieto durante el tiempo de pulsación larga y, sin levantarlo, muévelo para empezar a arrastrar. Levanta el dedo para terminar\n\nDesplazamiento: mueve dos dedos para reenviar un deslizamiento continuo a la pantalla externa. Muévelos despacio para desplazarte; suéltalos rápido para un impulso\n\nBarra inferior «Atrás»: envía un deslizamiento desde el borde a la pantalla externa. Puede no responder si la app o el lanzador de la pantalla externa no reconoce la navegación por gestos (Android no ofrece una forma oficial de enviar «Atrás» a una pantalla concreta)\n\nBarra inferior «Inicio»: abre en la pantalla externa la app de inicio configurada (o la del sistema)\n\nBarra inferior «Apps»: abre la lista de apps instaladas y ejecuta la seleccionada en la pantalla externa';

  @override
  String get openDiagnostics => 'Abrir diagnóstico';

  @override
  String get diagnosticsTitle => 'Diagnóstico';

  @override
  String get deviceLabel => 'Dispositivo';

  @override
  String get loadingEllipsis => 'Cargando…';

  @override
  String get androidVersionLabel => 'Versión de Android';

  @override
  String get manufacturerModelLabel => 'Fabricante / modelo';

  @override
  String get appVersionLabel => 'Versión de la app';

  @override
  String diagnosticsFetchFailed(String error) {
    return 'No se pudo obtener: $error';
  }

  @override
  String get statusDisabled => 'Desactivado';

  @override
  String get statusPresent => 'Sí';

  @override
  String get statusAbsent => 'No';

  @override
  String get statusNotSet => 'Sin configurar';

  @override
  String get statusYes => 'Sí';

  @override
  String get statusNo => 'No';

  @override
  String get statusNone => 'Ninguno';

  @override
  String get connectedDisplaysLabel => 'Pantallas conectadas';

  @override
  String get appListTitle => 'Apps';

  @override
  String get searchHint => 'Buscar';

  @override
  String get reloadAppList => 'Recargar lista de apps';

  @override
  String get noMatchingApps => 'No hay apps que coincidan';

  @override
  String get unlockByLongPress => 'Mantén pulsado para desbloquear';

  @override
  String get sectionAbout => 'Acerca de';

  @override
  String get openSourceLicenses => 'Licencias de código abierto';

  @override
  String get openSourceLicensesDescription =>
      'Avisos de licencia del software de código abierto utilizado en esta aplicación';

  @override
  String get resetSettingsButton => 'Restablecer valores predeterminados';

  @override
  String get resetSettingsConfirmTitle => '¿Restablecer los ajustes?';

  @override
  String get resetSettingsConfirmMessage =>
      'Todos los ajustes volverán a sus valores predeterminados.';

  @override
  String get resetSettingsCancel => 'Cancelar';

  @override
  String get resetSettingsConfirmAction => 'Restablecer';

  @override
  String get resetSettingsDone =>
      'Los ajustes se han restablecido a los valores predeterminados';
}
