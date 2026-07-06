# Android 16 Desktop Touchpad — 改訂仕様書 v1.1

Android 16 以上の端末を、外部ディスプレイ上の desktop windowing 環境を操作する
タッチパッドに変えるFlutterアプリ。個人利用の実用PoC。

---

## 1. 設計レビュー結果(v1.0 からの変更点)

元仕様に対する指摘と修正。**実装はすべて本改訂仕様に従う。**

| # | 問題点 | 修正 |
|---|--------|------|
| R1 | **設定値を native に渡す経路がない。** `pointerSpeed`・長押し時間は native 側で使うのに、Channel メソッド一覧に設定同期が存在しない | `updateConfig(map)` メソッドを追加。設定変更時と Service 接続時に一括同期 |
| R2 | **moveCursor の呼び出し頻度過多。** `PointerMoveEvent` 毎の MethodChannel 呼び出しは 120Hz 入力で jank する | Flutter 側でデルタを**フレーム単位に集約**(coalesce)して1回だけ送る |
| R3 | **カーソル座標のライフサイクル未定義**(初期位置・境界・画面変化) | 初期位置=対象ディスプレイ中央。移動は常に display bounds にクランプ。`displayChanged` で再クランプ |
| R4 | **Overlay 生成方法が古い。** Android 11+ では `createDisplayContext` 直での `addView` は失敗しうる | `createDisplayContext(display).createWindowContext(TYPE_ACCESSIBILITY_OVERLAY, null)` を正式経路とする |
| R5 | **Foreground Service の型宣言不足**(Android 14+ で必須) | `foregroundServiceType="specialUse"` + `FOREGROUND_SERVICE_SPECIAL_USE` 権限 + `POST_NOTIFICATIONS` ランタイム要求を仕様化 |
| R6 | **`android_intent_plus` が冗長**(`openAccessibilitySettings()` と重複、DRY違反) | パッケージから削除。設定画面起動は Channel 経由の native 実装のみ |
| R7 | **`dispatchGesture` の再入競合。** 進行中ジェスチャは新規 dispatch でキャンセルされる | native 側 `GestureInjector` に直列化ガード:tap/longPress 進行中の新規タップは無視し、結果を `lastGestureResult` に記録 |
| R8 | **2本指タップ判定 120ms は実用上厳しい。** また2本→1本遷移後の move がカーソル移動として誤処理される | 判定窓を **150ms** に緩和。タッチセッション単位の**ステートマシン**(§6)を定義し、2本指解除後の move は全て無視 |
| R9 | **診断情報の取得手段がない**(`lastGestureResult` 等は native 保持) | `getDiagnostics()` メソッドを追加 |
| R10 | **Accessibility 状態検出がポーリング前提** | Service の `onServiceConnected` / `onUnbind` から `accessibilityStateChanged` イベントを push。`isAccessibilityEnabled()` は初期値取得専用 |
| R11 | **タッチロックとタッチパッド入力の関係が未定義** | ロック中は全入力を遮断(カーソル移動も送らない)。解除ホールド中も入力は送らない(§8.7) |
| R12 | **UI仕様に画面中央の十字が未記載**(ユーザー追加要件) | タッチパッド領域の中央に細い十字線を常時表示(§8.2) |

**v1.0 のまま許容する点(PoCとしての割り切り):**
Back/Home/Recents の OEM 依存、右クリック=長押し代替、2本指スクロール/ドラッグの v1 除外、
完全 kill 状態からの自動起動非保証、vivo 等の機種依存は診断画面で対応。

---

## 2. 対象・前提

- Android のみ。`minSdk = targetSdk = compileSdk = 36`
- Android 16 QPR3 以降の connected displays、または Samsung DeX / One UI 8 系が主対象
- Flutter 3.44+ / Dart 3.12+ / Kotlin
- 配布は個人利用(sideload)。Play 配布は想定しない

## 3. アーキテクチャ

```
┌─ Flutter (本体画面 UI / 設定 / ジェスチャ認識) ─────────────┐
│  TouchpadScreen ─ TouchpadGestureRecognizer(純Dartステートマシン)│
│  SettingsScreen / DiagnosticsScreen / HomeScreen             │
│  Riverpod providers ── DesktopModeApi (抽象)                 │
└───────────────┬──────────────────────────────┘
     MethodChannel `desktop_mode/control`
     EventChannel  `desktop_mode/display_events`
┌───────────────┴─ Kotlin native ─────────────────┐
│ DesktopModeChannel(Channel 終端・ルーティングのみ)          │
│ DisplaySessionManager(display 監視・target 選択・セッション)│
│ RemoteInputAccessibilityService(接続状態・global action)    │
│ GestureInjector(tap / longPress 注入・直列化ガード)         │
│ CursorState(カーソル座標の唯一の所有者・クランプ)           │
│ CursorOverlayController / CursorOverlayView(外部画面の描画) │
│ DisplayMonitorService(任意の常駐監視 FGS)                   │
└─────────────────────────────────────────┘
```

**責務の原則(SOLID 対応)**
- **S(単一責任):** `DesktopModeChannel` は変換とルーティングのみ。認識(Flutter)/
  注入(native)/座標管理(`CursorState`)/表示(Overlay)を別クラスに分離
- **O(開放閉鎖):** イベントは sealed class、ジェスチャは認識器のステートマシンに閉じる。
  v2 のスクロール/ドラッグ追加は「認識器に状態を足す + Channel にメソッドを足す」だけで済む
- **L(置換可能):** `DesktopModeApi` のフェイク実装でテスト・プレビューが成立する契約にする
- **I(インターフェース分離):** UI が使うのは Riverpod provider の公開型のみ。
  Channel の生 Map は models 層より外に漏らさない
- **D(依存性逆転):** Flutter 側は `DesktopModeApi` 抽象に依存。MethodChannel 実装は
  Riverpod の provider 差し替えで交換可能

**DRY の適用箇所**
- カーソル座標の情報源は native の `CursorState` のみ(Flutter に複製を持たない)
- 色・寸法・文言はトークン/定数ファイルに一元化(§8.1)
- 設定は `AppSettings` → `SettingsRepository` → `updateConfig` の一方向フローで、
  デフォルト値の定義は `AppSettings` のコンストラクタ既定値の1箇所のみ
  (Kotlin 側 `InjectorConfig` の既定値は Service 未同期時のフォールバックとして同値を明記)
- 設定画面の各行は共通ウィジェット(トグル行・スライダー行)の再利用で構成

## 4. データ構造

### 4.1 Dart

```dart
/// 外部ディスプレイ情報(native → Flutter、読み取り専用)
class DisplayInfo {
  final int id;
  final String name;
  final int widthPx, heightPx;
  final double densityDpi;
  final bool isDefault;
}

/// アプリ設定(不変、copyWith、shared_preferences に JSON 保存)
class AppSettings {
  final bool autoStart;            // 初期 true
  final bool residentMonitoring;   // 初期 false(常駐監視 FGS)
  final bool showCursor;           // 初期 true
  final bool showTouchGlow;        // 初期 true
  final double pointerSpeed;       // 0.5–4.0、初期 1.8
  final int longPressDurationMs;   // 400–800、初期 550
  final int? preferredDisplayId;   // null = 最大面積を自動選択
  final bool touchLockEnabled;     // 誤操作防止、初期 false
  final bool oledProtection;       // 有機EL保護、初期 false
}

/// セッション状態
enum SessionStatus { idle, active }
class SessionState {
  final SessionStatus status;
  final int? targetDisplayId;
  final bool overlayActive;   // false でもタップ注入は継続(カーソル非表示と診断に表示)
}

/// native → Flutter イベント(sealed)
sealed class DesktopModeEvent {
  DisplayAdded / DisplayRemoved / DisplayChanged(displayId)
  SessionStarted(sessionState) / SessionStopped(reason)
  AccessibilityStateChanged(enabled)
  NativeError(code, message)
}

/// エラーコード(文字列定数)
/// accessibility_disabled | display_not_found | overlay_failed
/// | gesture_failed | gesture_busy | session_not_active | activity_launch_denied
```

### 4.2 Kotlin

```kotlin
// カーソル座標の唯一の所有者。全操作で bounds にクランプ
class CursorState(bounds: Rect) {
  var x: Float; var y: Float          // 初期値 = bounds 中央
  fun moveBy(dx: Float, dy: Float)    // speed 適用済みデルタ
  fun updateBounds(bounds: Rect)      // displayChanged 時に再クランプ
}

// native 側の可変設定(updateConfig で更新)
data class InjectorConfig(
  val pointerSpeed: Float = 1.8f,
  val longPressDurationMs: Long = 550L,
  val showCursor: Boolean = true,
)

// 診断スナップショット(getDiagnostics の戻り値)
data class Diagnostics(
  accessibilityEnabled, displays, targetDisplayId, displayBounds,
  hasSecondaryDisplayFeature, overlayActive,
  lastGestureResult, lastError,
)
```

## 5. Platform Channel 契約

- MethodChannel: `desktop_mode/control`
- EventChannel: `desktop_mode/display_events`(§4.1 のイベントを Map で送出)

| メソッド | 引数 | 戻り値 | 備考 |
|---|---|---|---|
| `getDisplays` | — | `List<Map>` | DEFAULT_DISPLAY 含む全一覧(isDefault で区別) |
| `getSessionState` | — | `Map` | |
| `startSession` | `{displayId?}` | `Map`(SessionState) | displayId 省略時: 設定の preferredDisplayId → 無ければ最大面積 |
| `stopSession` | — | — | |
| `moveCursor` | `{dx, dy}`(物理px、フレーム集約済み) | — | native が pointerSpeed を掛けて反映 |
| `leftClick` | — | — | 現在カーソル位置に 50ms tap |
| `rightClick` | — | — | 現在カーソル位置に longPressDurationMs の長押し |
| `systemAction` | `{action: "back"\|"home"\|"recents"}` | `bool` | performGlobalAction の結果 |
| `updateConfig` | `{pointerSpeed, longPressDurationMs, showCursor}` | — | **R1: 新規追加** |
| `getDiagnostics` | — | `Map` | **R9: 新規追加** |
| `isAccessibilityEnabled` | — | `bool` | 初期値取得専用(R10) |
| `openAccessibilitySettings` | — | — | |
| `setResidentMonitoring` | `{enabled}` | `bool` | FGS の起動/停止。通知権限が無ければ false |

**エラー規約:** 呼び出し失敗は `PlatformException(code = §4.1 のエラーコード)`。
非同期の失敗(ジェスチャ完了コールバック等)は EventChannel の `NativeError` で通知。

## 6. ジェスチャ認識ステートマシン(Flutter 側・純 Dart)

定数: `tapMaxDurationMs=220` / `tapSlop=12 logical px` / `twoFingerWindowMs=150`

```
idle
 └ 1本目 down ────────────────→ singleTracking(downTime, downPos)
singleTracking
 ├ move: 累積移動 > tapSlop → moved=true。以後デルタを moveCursor へ(フレーム集約)
 ├ up:   !moved && 経過 < 220ms → leftClick → idle / それ以外 → idle
 └ 2本目 down: 1本目から150ms以内 && !moved → twoFingerTracking
              それ以外 → dead
twoFingerTracking
 ├ いずれかの指の移動 > tapSlop → dead(v1 はスクロール非対応)
 └ 全指 up: 両指とも保持 < 400ms → rightClick → idle / それ以外 → idle
dead(誤動作防止: カーソル移動もクリックも送らない)
 └ 全指 up → idle
```

- **デルタ集約(R2):** move 中の `delta * devicePixelRatio` を controller 内で加算し、
  フレームコールバックで 1 回だけ `moveCursor` を呼ぶ
- 3本以上のタッチは即 `dead`
- 認識器は Flutter/Channel に依存しない純 Dart クラスとして実装し、ユニットテストを書く

## 7. Native 実装仕様

### 7.1 ジェスチャ注入(GestureInjector)
- 左クリック: `GestureDescription.Builder().setDisplayId(targetId)` +
  `StrokeDescription(path(cursorX, cursorY), 0, 50)` → `dispatchGesture`
- 右クリック相当: 同座標 `StrokeDescription(0, longPressDurationMs)`
- **直列化ガード(R7):** 注入中フラグが立っている間の新規要求は破棄し
  `lastGestureResult = "busy"` を記録(カーソル移動は影響を受けない)
- 完了/キャンセルは `GestureResultCallback` で受け、`lastGestureResult` 更新。
  キャンセル時は `NativeError(gesture_failed)` を送出
- Back/Home/Recents: `performGlobalAction(...)`。戻り値を Flutter に返す(OEM 依存は許容)

### 7.2 カーソル overlay(CursorOverlayController)
- `TYPE_ACCESSIBILITY_OVERLAY`。生成経路は
  `createDisplayContext(display).createWindowContext(TYPE_ACCESSIBILITY_OVERLAY, null)`(R4)
- flags: `FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCHABLE | FLAG_LAYOUT_NO_LIMITS`
- 描画: 半透明の灰色リング(外径 24dp・線 2dp)+ 中心点。移動は `View.translationX/Y` で反映
- 追加失敗時: 例外を握り、`overlayActive=false` のままタップ注入は継続。
  `NativeError(overlay_failed)` を送出し、Flutter 側は「カーソル表示不可」バナー表示

### 7.3 ディスプレイ管理(DisplaySessionManager)
- `DisplayManager.getDisplays()` から `DEFAULT_DISPLAY` 以外を外部候補とする
- target 選択: `startSession` の明示指定 > 設定 `preferredDisplayId` > 最大面積
- `registerDisplayListener`: added/removed/changed をイベント送出。
  セッション中に target が removed → セッション自動停止 + `SessionStopped(reason: displayRemoved)`。
  changed → bounds 再取得、`CursorState.updateBounds`、overlay 再レイアウト(R3)
- `FEATURE_ACTIVITIES_ON_SECONDARY_DISPLAYS` は診断情報として取得のみ

### 7.4 AccessibilityService(RemoteInputAccessibilityService)
- `onServiceConnected` / `onUnbind` で static 参照を管理し、
  `accessibilityStateChanged` を送出(R10)
- XML: `canPerformGestures="true"`、`canRetrieveWindowContent="false"`、
  `accessibilityEventTypes` は最小(`typeWindowsChanged` のみ)
- Service 接続時に保存済み設定で `InjectorConfig` を初期化(Flutter 起動前でも整合)

### 7.5 常駐監視(DisplayMonitorService、設定 ON のときのみ)
- Foreground Service。`foregroundServiceType="specialUse"`(R5)
- display added → MainActivity 起動を試行。BAL 拒否時は
  「タップしてタッチパッドを開く」通知(PendingIntent)にフォールバックし
  `NativeError(activity_launch_denied)` を記録
- 有効化時に `POST_NOTIFICATIONS` をランタイム要求。拒否されたら FGS を開始しない
  (`setResidentMonitoring` が false を返し、設定トグルは OFF に戻る)

### 7.6 Manifest
- `MainActivity`: `resizeableActivity="true"`、orientation 固定なし
- AccessibilityService: `BIND_ACCESSIBILITY_SERVICE` 付き宣言 + XML メタデータ
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`
- `SYSTEM_ALERT_WINDOW` は**使わない**

## 8. UI 仕様

ダークテーマのみ。モノクロ + 青アクセント。

### 8.0 UIデザイン原則(認知負荷の最小化)

参照: [SHIFT: 認知負荷とUX](https://service.shiftinc.jp/column/7638/)、
[Adobe: 認知負荷を減らす6つの方法](https://blog.adobe.com/jp/publish/2020/11/16/cc-web-ux-6-ways-to-reduce-cognitive-load-for-a-better-ui)。
各原則を本アプリの具体的決定に落とす:

| 原則(出典) | 本アプリでの適用 |
|---|---|
| 過剰な演出を避ける(Adobe 1) | アニメーションはタッチ発光 fade・ロック進捗リングの2つのみ。どちらも機能(触覚フィードバック代替・誤解除防止)を持つ |
| 選択肢を絞る(Adobe 2) | 1画面1目的。ホーム画面の主ボタンは常に1つ。設定は関連項目でグルーピング |
| 一貫性(Adobe 3 / SHIFT 5) | 色・寸法トークンを `app_colors.dart` / `app_dimens.dart` に一元定義し、全画面が同じトークンだけを使う(DRYと同根) |
| アクション最小(Adobe 4) | 通常フローは「接続 → 自動遷移」の0タップ。設定は即時保存で保存ボタンなし |
| 馴染みのあるパターン(Adobe 5) | ナビは Android 標準 3 ボタン(◁ ○ □)の並びと図形を踏襲。アイコンは Material Icons のみ |
| シンプルに保つ(Adobe 6) | 黒背景 + 余白で要素を分離。装飾的な枠・影・グラデーションは使わない |
| 色だけで伝えない(SHIFT 2) | 状態は必ず「アイコン + 文言」で表現。accent 色は補助。無効状態も文言で理由を示す |
| アイコンにラベル併記(SHIFT 3) | ホーム・設定・診断の全アイコンにラベル併記。タッチパッドのナビ3ボタンのみ標準図形につきアイコン単体 |
| 入力負荷の軽減(SHIFT 4) | テキスト入力ゼロ。全設定はトグル・スライダー・選択のみ |
| 段階的表示(SHIFT 1) | 診断情報・restricted settings 注意文はホームに出さず診断画面/案内モードに退避 |

### 8.1 カラートークン(唯一の定義箇所 `core/theme/app_colors.dart`)
| トークン | 値 | 用途 |
|---|---|---|
| background | `#000000` | 全画面背景 |
| foreground | `#9E9E9E` | 通常文字/アイコン |
| foregroundPressed | `#D0D0D0` | 押下時 |
| disabled | `#4A4A4A` | 無効状態 |
| divider | `#242424` | 区切り線 |
| accent | `#448AFF` | 有効トグル・スライダー・強調(唯一の有彩色) |
| glow | `rgba(180,180,180,0.18)` | タッチ発光 |
| danger 相当も使わない。エラーも foreground 文字で表現 | | |

### 8.2 タッチパッド画面
- タッチパッド領域: 下部ナビ以外の全面。背景 `#000000`
- **中央十字(R12):** 領域中央に線幅 1px・長さ 24dp の十字を `divider` 色で常時表示。
  カーソル初期位置(外部画面中央)との対応を直感化する
- タッチ発光: 指ごとに円形 glow(色 `glow`、blur 32px)。指を離すと 300ms で fade out。
  2本指時は2箇所表示。`showTouchGlow=false` で無効
- 下部ナビ: 高さ 80dp、`divider` 上罫線。左から Back / Home / Recents
  (Material Icons: `arrow_back` / `circle` (outlined) / `crop_square`)。
  押下で `foregroundPressed`、Accessibility 未接続時は `disabled`
- 画面表示中は wakelock 有効、離脱で解除
- 右上に小さく設定アイコン(`settings`)→ 設定画面へ

### 8.3 ホーム画面(起動時)
状態表示 + 導線のみの最小構成:
- Accessibility 状態(未有効なら「設定を開く」ボタン=accent)
- 外部ディスプレイ状態(未接続 / 接続中: 名称と解像度)
- 「タッチパッドを開く」ボタン(外部ディスプレイ + Accessibility が揃うまで disabled)
- 設定 / 診断への導線
- autoStart=ON かつ外部ディスプレイ検出時は自動でタッチパッド画面へ遷移

### 8.4 初回セットアップ
- Accessibility 無効ならホーム画面が案内モードになる(別画面は作らない):
  手順文 + 「Accessibility設定を開く」ボタン
- restricted settings(sideload 制限)の注意文を常設で小さく表示

### 8.5 設定画面
§4.1 `AppSettings` の全項目 + 操作方法の掲示(静的テキスト)+ 診断画面への導線。
変更は即保存・即 `updateConfig` 同期。スライダー/トグルの有効色は accent。

### 8.6 診断画面
Android version/SDK、メーカー/モデル(device_info_plus)、アプリバージョン
(package_info_plus)、`getDiagnostics()` の全項目、接続 display 一覧。
「更新」ボタンで再取得。

### 8.7 誤操作防止(タッチロック、設定 ON のときのみ)
- タッチパッド画面表示から 30 秒無操作でロック状態へ
- ロック中: 全入力遮断。画面には錠アイコンと「長押しで解除」のみ表示
- 2 秒間の連続タッチで解除(ホールド中は進捗リングを accent で表示。
  ホールド中のタッチはカーソル移動として送らない)

### 8.8 有機EL保護(設定 ON のときのみ)
- 3 分ごとに、ナビバー・十字・固定 UI 要素の描画位置を標準位置から
  ランダムに最大 ±8 logical px オフセット(アニメーションなしで静かに切替)

## 9. 画面遷移(go_router)

```
/            HomeScreen(状態 + セットアップ案内を兼ねる)
/touchpad    TouchpadScreen
/settings    SettingsScreen
/diagnostics DiagnosticsScreen
```
- `displayAdded` && autoStart && Accessibility 有効 → `/touchpad` へ push
- セッション中に `SessionStopped(displayRemoved)` → `/` へ戻す + 理由をスナックバー表示

## 10. ファイル構成

### Flutter
```
lib/
  main.dart
  app.dart                                  # MaterialApp.router + ダークテーマ
  core/
    theme/app_colors.dart                   # §8.1 カラートークン(唯一の定義)
    theme/app_dimens.dart                   # 寸法トークン(唯一の定義)
    theme/app_theme.dart
    platform/desktop_mode_api.dart          # 抽象(DIP)
    platform/desktop_mode_channel.dart      # MethodChannel/EventChannel 実装
    settings/app_settings.dart              # 不変モデル
    settings/settings_repository.dart       # shared_preferences 永続化
    settings/settings_provider.dart         # Riverpod Notifier(保存 + native 同期)
  models/
    display_info.dart
    session_state.dart
    desktop_mode_event.dart                 # sealed イベント + エラーコード
    diagnostics_info.dart
  features/
    touchpad/
      touchpad_gesture_recognizer.dart      # §6 純Dartステートマシン
      touchpad_controller.dart              # 認識器と API の接続・デルタ集約
      touchpad_screen.dart
      widgets/touch_surface.dart
      widgets/system_nav_bar.dart
      widgets/touch_glow_painter.dart
      widgets/center_crosshair.dart
      widgets/lock_overlay.dart
    home/home_screen.dart
    settings/settings_screen.dart
    diagnostics/diagnostics_screen.dart
```

### Android
```
android/app/src/main/kotlin/dev/mosim/desktop_mode/
  MainActivity.kt
  platform/DesktopModeChannel.kt
  display/DisplaySessionManager.kt
  accessibility/RemoteInputAccessibilityService.kt
  accessibility/GestureInjector.kt
  accessibility/CursorState.kt
  overlay/CursorOverlayController.kt
  overlay/CursorOverlayView.kt
  service/DisplayMonitorService.kt
android/app/src/main/res/xml/remote_input_accessibility_service.xml
```

## 11. 依存パッケージ

```yaml
flutter_riverpod / go_router / shared_preferences
device_info_plus / package_info_plus / wakelock_plus
# android_intent_plus は削除(R6)
```

## 12. 受け入れ条件

v1.0 の受け入れ条件に以下を追加:
- 設定変更(ポインター速度・長押し時間)が再起動なしで native に反映される
- タッチパッド画面の中央に十字が表示される
- 連続タップ連打でジェスチャが競合せずクラッシュしない(busy は診断に記録)
- タッチロック ON 時: 30秒無操作でロック、2秒ホールドで解除、ロック中は入力が送られない
- ユニットテスト(ジェスチャ認識器・設定シリアライズ)が全て通る
- `flutter analyze` 警告 0、`flutter build apk --debug` 成功

## 13. 動作確認計画

| 段階 | 内容 | 実行環境 |
|---|---|---|
| 静的検証 | `flutter analyze` 警告 0 | CI/ローカル |
| ユニットテスト | ジェスチャ認識器の全遷移・タップ判定境界値、AppSettings round-trip、イベントパース | `flutter test` |
| ビルド検証 | `flutter build apk --debug` | ローカル |
| 実機確認 | §12 の受け入れ条件チェックリスト | Android 16 実機 + 外部ディスプレイ(手動) |
