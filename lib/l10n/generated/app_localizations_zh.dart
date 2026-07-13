// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '外接显示器触控板';

  @override
  String get displayDisconnected => '外接显示器已断开连接';

  @override
  String sessionEndedUnexpectedly(String reason) {
    return '会话意外结束 ($reason)';
  }

  @override
  String get settingsTooltip => '设置';

  @override
  String get diagnosticsTooltip => '诊断';

  @override
  String get accessibilityStatusLabel => '无障碍服务';

  @override
  String get statusEnabled => '已启用';

  @override
  String get statusDisabledRequired => '已停用（操作所必需）';

  @override
  String get openAccessibilitySettings => '打开无障碍设置';

  @override
  String get externalDisplayLabel => '外接显示器';

  @override
  String displayConnectedValue(String displays) {
    return '$displays（点按可更改分辨率）';
  }

  @override
  String get displayNotConnected => '未连接';

  @override
  String get openTouchpad => '打开触控板';

  @override
  String get sideloadHint => '如果侧载应用的无障碍设置呈灰色不可用，请在应用信息页面启用「允许受限设置」。';

  @override
  String get settingsTitle => '设置';

  @override
  String settingsLoadFailed(String error) {
    return '加载设置失败：$error';
  }

  @override
  String get sectionStartup => '启动';

  @override
  String get autoStartLabel => '自动启动';

  @override
  String get autoStartDescription => '连接外接显示器时自动打开触控板界面';

  @override
  String get residentMonitoringLabel => '后台监控';

  @override
  String get residentMonitoringDescription => '即使关闭应用也持续监测外接显示器的连接';

  @override
  String get sectionDisplay => '显示';

  @override
  String get showCursorLabel => '外部光标显示';

  @override
  String get showCursorDescription => '在外接显示器上显示虚拟光标';

  @override
  String get touchGlowLabel => '操作确认效果';

  @override
  String get touchGlowDescription => '仅在点击或长按被确认的瞬间显示';

  @override
  String get sectionInput => '操作';

  @override
  String get pointerSpeedLabel => '指针速度';

  @override
  String get longPressDurationLabel => '长按/拖动开始时间';

  @override
  String get cursorIdleTimeoutLabel => '光标自动隐藏时间';

  @override
  String get cursorIdleOff => '关闭';

  @override
  String secondsValue(String seconds) {
    return '$seconds秒';
  }

  @override
  String get targetDisplayLabel => '目标显示器';

  @override
  String get targetDisplayAuto => '自动（最大的外接显示器）';

  @override
  String get homeAppLabel => '外接显示器的主屏幕应用';

  @override
  String get homeAppDescription =>
      '通过主屏幕按钮或返回操作打开主屏幕时启动的应用。如果默认启动器不支持横屏，可以指定其他启动器。';

  @override
  String get systemDefault => '系统默认';

  @override
  String get displayModeLabel => '外接显示器分辨率';

  @override
  String get displayModeDescription =>
      '从连接设备支持的分辨率/刷新率中选择。未选择时将使用设备的默认模式。光标显示关闭时此设置不生效。';

  @override
  String get displayModeSingle => '此连接设备不支持多种分辨率。';

  @override
  String get displayModeDefault => '默认';

  @override
  String get sectionProtection => '防误触与屏幕保护';

  @override
  String get touchLockLabel => '触摸锁定';

  @override
  String get touchLockDescription => '防止误触，长按 1 秒解锁';

  @override
  String get touchLockTimeoutLabel => '无操作后锁定';

  @override
  String get minimizeBrightnessWhileLockedLabel => '锁定时将屏幕亮度调至最低';

  @override
  String get minimizeBrightnessWhileLockedDescription =>
      '仅在触摸锁定期间使用最低屏幕亮度，解锁后恢复';

  @override
  String get lockNowTooltip => '立即锁定';

  @override
  String get oledProtectionLabel => 'OLED 屏幕保护';

  @override
  String get oledProtectionDescription => '每隔几分钟轻微移动包括锁定画面在内的界面位置';

  @override
  String get sectionHowTo => '使用方法';

  @override
  String get howToText =>
      '移动：单指移动即可移动光标\n\n点击：单指触摸后不移动并快速松开即为点击\n\n长按：单指按住不动一段时间后，不移动直接松开（Android 的鼠标没有右键，此长按操作可代替右键）\n\n拖动：单指按住不动一段时间（长按开始时间）后，不松开手指直接移动即开始拖动。松开手指结束拖动\n\n滚动：双指移动时，会作为连续滑动转发到外接显示器。缓慢移动为滚动，快速松开为快速滑动\n\n底部导航「返回」：向外接显示器发送屏幕边缘滑动手势。如果外接显示器上的应用/启动器不识别手势导航，可能没有反应（Android 没有向指定显示器发送「返回」的官方方式）\n\n底部导航「主屏幕」：在外接显示器上启动设置的主屏幕应用（未设置时为系统默认）\n\n底部导航「应用列表」：打开已安装应用的列表，在外接显示器上启动所选应用';

  @override
  String get openDiagnostics => '打开诊断页面';

  @override
  String get diagnosticsTitle => '诊断';

  @override
  String get deviceLabel => '设备';

  @override
  String get loadingEllipsis => '加载中…';

  @override
  String get androidVersionLabel => 'Android 版本';

  @override
  String get manufacturerModelLabel => '制造商 / 型号';

  @override
  String get appVersionLabel => '应用版本';

  @override
  String diagnosticsFetchFailed(String error) {
    return '获取失败：$error';
  }

  @override
  String get statusDisabled => '已停用';

  @override
  String get statusPresent => '有';

  @override
  String get statusAbsent => '无';

  @override
  String get statusNotSet => '未设置';

  @override
  String get statusYes => '是';

  @override
  String get statusNo => '否';

  @override
  String get statusNone => '无';

  @override
  String get connectedDisplaysLabel => '已连接的显示器列表';

  @override
  String get appListTitle => '应用列表';

  @override
  String get searchHint => '搜索';

  @override
  String get reloadAppList => '重新加载应用列表';

  @override
  String get noMatchingApps => '没有符合条件的应用';

  @override
  String get windowModeTooltip => '启动时的窗口比例';

  @override
  String get windowModeAuto => '自动';

  @override
  String get windowModePhonePortrait => '手机竖屏';

  @override
  String get windowModePhoneLandscape => '手机横屏';

  @override
  String get windowModeFullExternal => '外接屏幕全屏';

  @override
  String get unlockByLongPress => '长按解锁';

  @override
  String get sectionAbout => '关于';

  @override
  String get openSourceLicenses => '开源许可';

  @override
  String get openSourceLicensesDescription => '本应用所使用开源软件的许可信息';
}
