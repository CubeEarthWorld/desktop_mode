# 設計ドキュメント — 外部ディスプレイ用タッチパッド

アプリ ID: `com.xignal.external_touchpad` / Dart パッケージ名: `external_touchpad`

スマートフォンを外部ディスプレイ(HDMI / ワイヤレスディスプレイ)用のタッチパッドに変えるアプリ。
要求仕様は [SPEC.md](SPEC.md) を参照。本書は「どう作られているか」(アーキテクチャ・設計原則・規約)を定義する。

## 1. 全体アーキテクチャ

```
┌────────────────────── Flutter (Dart) ──────────────────────┐
│ features/   画面と画面固有ウィジェット (home/touchpad/…)      │
│ core/       横断関心事 (platform, settings, theme)           │
│ models/     ワイヤ形式と対応する不変データモデル               │
│ l10n/       ARB + 生成コード (7言語)                          │
└──────────────┬─────────────────────────────────────────────┘
               │ MethodChannel "external_touchpad/control"
               │ EventChannel  "external_touchpad/display_events"
┌──────────────┴────────────── Android (Kotlin) ─────────────┐
│ platform/       チャンネル境界 (ExternalTouchpadChannel 等)  │
│ ExternalTouchpadController  唯一の調停者 (シングルトン)       │
│ accessibility/  ジェスチャ注入・ソフトキーボード制御          │
│ apps/           アプリ一覧・起動・起動領域検証                 │
│ display/        外部ディスプレイ検出 (DisplaySessionManager)  │
│ navigation/     外部画面内の戻る・ホーム操作                   │
│ overlay/        仮想カーソル描画 (CursorOverlay*)             │
│ service/        常駐監視 FGS (DisplayMonitorService)          │
└────────────────────────────────────────────────────────────┘
```

### 責務の分割 (SRP)

| 層 | クラス | 責務 |
|---|---|---|
| Flutter | `TouchpadGestureRecognizer` | 生ポインタ列 → 意味づけ(クリック/長押し/ドラッグ/スクロール)。純粋ロジック、タイマー/プラットフォーム呼び出しを持たない |
| Flutter | `TouchpadController` | タイマー・バッチング・native 呼び出しの所有。recognizer の結果を API 呼び出しへ変換 |
| Flutter | `ExternalTouchpadApi` (抽象) / `ExternalTouchpadChannel` (実装) | プラットフォーム境界。UI は抽象のみに依存 (DIP) |
| Flutter | `SettingsNotifier` → `SettingsRepository` | 設定の一方向フロー: 変更 → 永続化 → native 同期 |
| Kotlin | `ExternalTouchpadController` | 状態遷移と各コンポーネントの接続のみ。処理本体は下記へ委譲 |
| Kotlin | `GestureInjector` | AccessibilityService 経由のジェスチャ注入のみ |
| Kotlin | `SoftKeyboardCoordinator` | 外部キーボードの検出、ソフトキーボード表示方針、タッチパッドからの閉じる操作を一元管理 |
| Kotlin | `AppCatalog` | PackageManager からのアプリ一覧取得とアイコンキャッシュ |
| Kotlin | `ExternalAppLauncher` | 外部ディスプレイへのアプリ起動、起動領域の計算と検証 |
| Kotlin | `ExternalDisplayNavigator` | 外部ディスプレイに限定した戻る・ホーム操作とフォールバック |
| Kotlin | `CursorState` | カーソル座標と境界クランプのみ |
| Kotlin | `CursorOverlayController` / `CursorOverlayView` | カーソルの表示のみ(失敗しても注入は継続) |
| Kotlin | `DisplaySessionManager` | ディスプレイの列挙・検出のみ |

### 重要な設計方針

- **セッションのライフサイクルは Android ネイティブ側だけが所有する。**
  Flutter 側の画面マウント/アンマウントはセッションを開始/終了しない。
  根拠となるイベントは「外部ディスプレイの物理的な接続/切断」のみ。
- **認識(Flutter)と注入(Kotlin)の分離。** ジェスチャの意味づけは recognizer が一意に決め、
  native は受け取ったコマンドを実行するだけ。
- **push 型の状態同期。** native → Flutter は EventChannel の push 通知のみでポーリングしない
  (フォアグラウンド復帰時の再取得だけ例外)。

## 2. 識別子の規約

| 識別子 | 値 | 変更可否 |
|---|---|---|
| applicationId / namespace | `com.xignal.external_touchpad` | リリース後変更不可 |
| MethodChannel | `external_touchpad/control` | Flutter と Android の両側で同じ値を使用する内部名 |
| EventChannel | `external_touchpad/display_events` | 同上 |
| SharedPreferences キー | `external_touchpad.settings` (native からは `flutter.external_touchpad.settings`) | Flutter と Android の両側で同じ値を使用する |
| 通知チャンネル ID | `external_touchpad_monitor` | アプリ固有の通知チャンネル ID |

チャンネル名・prefs キーはパッケージ名と独立した内部プロトコル名であり、
内部識別子もアプリ名に合わせて `external_touchpad` に統一する。

## 3. 設定 (AppSettings) とスキーマ移行

- `AppSettings` (Dart) の JSON が唯一の情報源。native (`InjectorConfig`) は
  Flutter 起動前に Accessibility Service が接続された場合のフォールバック読み込みのみ行う。
- 既定値を変更するときは **スキーマバージョンを上げ、「旧既定値のみ」を新既定値へ移行**する
  (ユーザーが明示的に変えた値は保持)。移行ロジックは Dart (`AppSettings.fromJson`) と
  Kotlin (`readConfigFromPrefs`) の両方に同じ規則で実装する。
  - v1→v2: 長押し 550ms → 1000ms
  - v2→v3: 長押し 1000ms → 500ms (ドラッグ開始基準 0.5 秒)
  - v4→v5: アプリごとのウィンドウ比率設定を廃止

## 4. デザイントークン

- 色: `core/theme/app_colors.dart` (`AppColors`) が唯一の定義箇所。
  ダークテーマ固定、モノクロ + 青アクセント(#448AFF)。
  native 側カーソルの色もこのパレットに合わせる(通常=グレー、ドラッグ中=アクセント青)。
- 寸法/タイミング: `core/theme/app_dimens.dart` (`AppDimens`)。
  タッチロックの解除ホールド(1s)/解除失敗スロップ(12px)などもここが正。
  アイドル時間の選択肢(5s/10s/30s、既定30s)は `AppSettings` が正。
- 面の階層: 背景 `#000000` → 浮いた面(シート/ダイアログ/ドロップダウン) `surfaceElevated #0A0A0A`。

## 5. 多言語対応 (l10n)

- 対応言語: en(テンプレート), ja, zh, ko, es, ru, de。
- Flutter 側: `lib/l10n/app_<locale>.arb` → `flutter gen-l10n` で
  `lib/l10n/generated/` に生成。UI は `context.l10n.<key>`(`lib/l10n/l10n.dart` の拡張)経由でのみ文言を参照し、
  ハードコード文字列を書かない。
- Android 側: `res/values[-<locale>]/strings.xml`。
  アプリ名・常駐監視通知・Accessibility サービスの名称/説明が対象。
- 文言を追加/変更する手順:
  1. `app_en.arb` にキー追加(プレースホルダーは `@key` メタデータも)
  2. 残り 6 言語の ARB に同キーを追加
  3. `flutter gen-l10n` を実行
  4. Android 側の文言なら 7 つの `strings.xml` すべてを更新

## 6. 権限ポリシー

宣言する権限は常駐監視 FGS に必要な最小限のみ:

- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE`: 外部ディスプレイ接続監視サービス
- `POST_NOTIFICATIONS`: 上記サービスの常駐通知
- (`BIND_ACCESSIBILITY_SERVICE` はサービス保護属性でありアプリが要求する権限ではない)
- debug/profile の `INTERNET` は Flutter 開発ツール用でリリースには含まれない

新しい権限を追加する場合は、この節に用途を追記すること。

## 7. テスト戦略

- Dart: 純粋ロジック(recognizer / AppSettings)はユニットテスト、
  Controller はフェイク `ExternalTouchpadApi` + `ProviderContainer` で振る舞いテスト
  (`test/features/touchpad/`)。
- Kotlin: 純粋ロジック(`ContinuousStrokeState`、`SoftKeyboardPolicy` 等)は JUnit (`android/app/src/test/`)。
- チャンネル境界・overlay 表示など OS 依存部分は実機確認を基本とする
  (診断画面 `/diagnostics` が観測点)。

## 8. リリースチェックリスト

- [ ] `android/app/build.gradle.kts` の release 署名を正規の keystore に差し替える(現状 debug 署名)
- [ ] `flutter analyze` / `flutter test` / `gradlew testDebugUnitTest` がグリーン
- [ ] 7 言語で設定画面・通知・Accessibility 設定画面の文言を目視確認
- [ ] minSdk 36 (Android 16) 前提: connected displays / desktop windowing 対応端末で動作確認
