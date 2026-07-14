// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '外部ディスプレイ用タッチパッド';

  @override
  String get appTitleShort => 'タッチパッド';

  @override
  String get displayDisconnected => '外部ディスプレイの接続が切れました';

  @override
  String sessionEndedUnexpectedly(String reason) {
    return 'セッションが予期せず終了しました ($reason)';
  }

  @override
  String get settingsTooltip => '設定';

  @override
  String get diagnosticsTooltip => '診断';

  @override
  String get accessibilityStatusLabel => 'Accessibility';

  @override
  String get statusEnabled => '有効';

  @override
  String get statusDisabledRequired => '無効（操作に必要です）';

  @override
  String get openAccessibilitySettings => 'Accessibility設定を開く';

  @override
  String get externalDisplayLabel => '外部ディスプレイ';

  @override
  String displayConnectedValue(String displays) {
    return '$displays(タップして解像度を変更)';
  }

  @override
  String get displayNotConnected => '未接続';

  @override
  String get openTouchpad => 'タッチパッドを開く';

  @override
  String get sideloadHint =>
      'サイドロード時に Accessibility 設定がグレーアウトする場合は、アプリ情報から「制限付き設定を許可」を有効にしてください。';

  @override
  String get settingsTitle => '設定';

  @override
  String settingsLoadFailed(String error) {
    return '設定の読み込みに失敗しました: $error';
  }

  @override
  String get sectionStartup => '起動';

  @override
  String get autoStartLabel => '自動起動';

  @override
  String get autoStartDescription => '外部ディスプレイ接続時に自動でタッチパッド画面を開く';

  @override
  String get residentMonitoringLabel => '常駐監視';

  @override
  String get residentMonitoringDescription => 'アプリを閉じていても外部ディスプレイ接続を監視する';

  @override
  String get sectionDisplay => '表示';

  @override
  String get showCursorLabel => '外部カーソル表示';

  @override
  String get showCursorDescription => '外部ディスプレイ上に仮想カーソルを表示する';

  @override
  String get touchGlowLabel => '操作確定エフェクト';

  @override
  String get touchGlowDescription => 'クリックまたは長押しが確定した瞬間だけ表示する';

  @override
  String get sectionInput => '操作';

  @override
  String get pointerSpeedLabel => 'ポインター速度';

  @override
  String get dragSensitivityLabel => 'ドラッグの感度';

  @override
  String get longPressDurationLabel => '長押し/ドラッグ開始時間';

  @override
  String get cursorIdleTimeoutLabel => 'カーソル自動非表示時間';

  @override
  String get cursorIdleOff => 'OFF';

  @override
  String secondsValue(String seconds) {
    return '$seconds秒';
  }

  @override
  String get targetDisplayLabel => '対象ディスプレイ';

  @override
  String get targetDisplayAuto => '自動(最大の外部ディスプレイ)';

  @override
  String get homeAppLabel => '外部ディスプレイのホームアプリ';

  @override
  String get homeAppDescription =>
      'ホームボタンや戻る操作でホームを開く際に起動するアプリ。標準ランチャーが横画面に対応していない場合、別のランチャーを指定できます。';

  @override
  String get systemDefault => 'システム標準';

  @override
  String get displayModeLabel => '外部ディスプレイの解像度';

  @override
  String get displayModeDescription =>
      '接続機器が対応する解像度/リフレッシュレートから選択します。未選択の場合は端末の既定モードのまま動作します。カーソル表示がオフの場合、この設定は反映されません。';

  @override
  String get displayModeSingle => 'この接続機器は複数の解像度に対応していません。';

  @override
  String get displayModeDefault => '既定';

  @override
  String get sectionProtection => '誤操作防止・画面保護';

  @override
  String get touchLockLabel => 'タッチロック';

  @override
  String get touchLockDescription => '誤操作を防止し、1秒長押しで解除する';

  @override
  String get touchLockTimeoutLabel => '無操作でロックするまで';

  @override
  String get minimizeBrightnessWhileLockedLabel => 'ロック中は画面の明るさを最低にする';

  @override
  String get minimizeBrightnessWhileLockedDescription =>
      'タッチロック中のみ画面を最低輝度にし、解除時に元に戻す';

  @override
  String get lockNowTooltip => '今すぐロック';

  @override
  String get oledProtectionLabel => '有機ELディスプレイの保護';

  @override
  String get oledProtectionDescription => 'ロック画面を含むUI位置を数分ごとにわずかにずらす';

  @override
  String get sectionHowTo => '使い方';

  @override
  String get howToText =>
      '移動: 1本指で動かすとカーソルが移動します\n\nクリック: 1本指でタッチして、動かさずに素早く離すとクリック\n\n長押し: 1本指を動かさずにしばらく押さえてから、動かさずに離す(Android のマウスに右クリックは無いため、右クリックの代わりにこの長押し操作を使います)\n\nドラッグ: 1本指を動かさずにしばらく(長押し開始時間)押さえたあと、そのまま指を離さずに動かすとドラッグ開始。指を離すとドラッグ終了です\n\nスクロール: 2本指を動かすと、外部ディスプレイ側へ連続スワイプとして転送されます。ゆっくり動かすとスクロール、素早く離すとフリングになります\n\n下部ナビ「戻る」: 外部ディスプレイへ画面端からのスワイプを送ります。外部ディスプレイ側のアプリ/ランチャーがジェスチャーナビゲーションの編集を認識していない場合、反応しないことがあります(Android にディスプレイを指定して「戻る」を送る公式手段が無いための制約です)\n\n下部ナビ「ホーム」: 設定したホームアプリ(未設定ならシステム標準)を外部ディスプレイで起動します\n\n下部ナビ「アプリ一覧」: インストール済みアプリの一覧を開き、選択したアプリを外部ディスプレイで起動します';

  @override
  String get openDiagnostics => '診断画面を開く';

  @override
  String get diagnosticsTitle => '診断';

  @override
  String get deviceLabel => '端末';

  @override
  String get loadingEllipsis => '読み込み中…';

  @override
  String get androidVersionLabel => 'Android バージョン';

  @override
  String get manufacturerModelLabel => 'メーカー / モデル';

  @override
  String get appVersionLabel => 'アプリバージョン';

  @override
  String diagnosticsFetchFailed(String error) {
    return '取得に失敗しました: $error';
  }

  @override
  String get statusDisabled => '無効';

  @override
  String get statusPresent => 'あり';

  @override
  String get statusAbsent => 'なし';

  @override
  String get statusNotSet => '未設定';

  @override
  String get statusYes => 'はい';

  @override
  String get statusNo => 'いいえ';

  @override
  String get statusNone => 'なし';

  @override
  String get connectedDisplaysLabel => '接続 Display 一覧';

  @override
  String get appListTitle => 'アプリ一覧';

  @override
  String get searchHint => '検索';

  @override
  String get reloadAppList => 'アプリ一覧を再読み込み';

  @override
  String get noMatchingApps => '該当するアプリがありません';

  @override
  String get unlockByLongPress => '長押しで解除';

  @override
  String get sectionAbout => 'このアプリについて';

  @override
  String get openSourceLicenses => 'オープンソースライセンス';

  @override
  String get openSourceLicensesDescription =>
      'このアプリで使用しているオープンソースソフトウェアのライセンス情報';

  @override
  String get resetSettingsButton => 'デフォルトに戻す';

  @override
  String get resetSettingsConfirmTitle => '設定をリセットしますか？';

  @override
  String get resetSettingsConfirmMessage => 'すべての設定が既定値に戻ります。';

  @override
  String get resetSettingsCancel => 'キャンセル';

  @override
  String get resetSettingsConfirmAction => 'リセット';

  @override
  String get resetSettingsDone => '設定を既定値にリセットしました';
}
