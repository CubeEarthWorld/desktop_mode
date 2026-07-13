<p align="center">
  <img src="asetts/external_display_touchpad_icon.png" width="160" alt="External Display Touchpad icon">
</p>

<h1 align="center">External Display Touchpad</h1>

<p align="center">
  スマートフォンを外部ディスプレイ用のタッチパッドに変える、Android向けFlutterアプリです。
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT--0-blue.svg" alt="MIT-0 License"></a>
  <img src="https://img.shields.io/badge/Android-16%2B-3DDC84?logo=android&logoColor=white" alt="Android 16 or later">
  <img src="https://img.shields.io/badge/Flutter-3.44%2B-02569B?logo=flutter&logoColor=white" alt="Flutter">
</p>

HDMIやワイヤレスディスプレイへ接続したAndroid端末から、外部画面上のカーソルやアプリを操作します。root、Shizuku、ADB常駐、非公開APIには依存せず、Androidの公開APIとAccessibilityServiceを使用します。

> [!IMPORTANT]
> Android 16（API 36）以降専用です。connected displays / desktop windowingへの対応状況は端末やOEM実装によって異なります。現在は開発中で、リリースビルドの正式な署名設定も未完了です。

## 主な機能

- 1本指の相対移動による外部カーソル操作
- タップによるクリック、長押しと移動によるドラッグ
- 2本指スクロール
- 外部ディスプレイへのアプリ一覧表示とアプリ起動
- アプリごとのウィンドウ比率指定（自動、縦長、横長、外部画面全体）
- 外部画面向けの戻る、ホーム、アプリ一覧操作
- 外部ディスプレイ接続の常駐監視と自動遷移
- 診断画面、操作感度、長押し時間などの設定
- 日本語、英語、中国語、韓国語、スペイン語、ロシア語、ドイツ語

## 動作要件

- Android 16（API 36）以降
- connected displays / desktop windowingを利用できる端末
- HDMIまたはワイヤレスディスプレイによる外部画面
- ユーザーによる本アプリのAccessibilityServiceの有効化

AccessibilityServiceのジェスチャーはマウスイベントではなく、外部画面へのタッチ入力として送信されます。このため、対象アプリや端末によって操作感が異なる場合があります。

## 権限とプライバシー

| 項目 | 用途 |
|---|---|
| AccessibilityService | 外部画面への公開APIによるジェスチャー送信 |
| `FOREGROUND_SERVICE` | 外部ディスプレイ接続の監視 |
| `FOREGROUND_SERVICE_SPECIAL_USE` | 接続監視サービスの用途宣言 |
| `POST_NOTIFICATIONS` | 接続監視中の常駐通知 |

- AccessibilityServiceは利用者がAndroidの設定画面で明示的に有効化します。
- リリース版はネットワーク権限を要求しません。debug/profile版の`INTERNET`はFlutter開発ツール用です。
- root権限、Shizuku、ADB常駐は不要です。

## セットアップ

FlutterのstableチャンネルとAndroid SDKを用意してください。本プロジェクトのDart SDK要件は`pubspec.yaml`を参照してください。

```sh
git clone https://github.com/CubeEarthWorld/external-display-touchpad.git
cd external-display-touchpad
flutter pub get
flutter gen-l10n
flutter run
```

## テストとビルド

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Androidネイティブ側のユニットテストは、FlutterによるGradle Wrapper生成後に実行できます。

```sh
cd android
./gradlew testDebugUnitTest          # macOS / Linux
.\gradlew.bat testDebugUnitTest     # Windows
```

ランチャーアイコンを再生成する場合:

```sh
dart run flutter_launcher_icons
```

## プロジェクト構成

```text
lib/features/     画面と画面固有のUI
lib/core/         プラットフォーム境界、設定、テーマ
lib/models/       Dartのデータモデル
lib/l10n/         7言語のARBと生成コード
android/app/src/  Kotlin実装とAndroidリソース
test/             Dartテスト
```

詳細は次のドキュメントを参照してください。

- [SPEC.md](SPEC.md) — 入力、外部表示、アプリ起動の要求仕様
- [DESIGN.md](DESIGN.md) — アーキテクチャ、識別子、権限、テスト、リリース方針

## コントリビューション

Issue、Pull Request、fork、独自改造を歓迎します。別途の合意がない限り、このリポジトリへ提供されたコントリビューションもMIT-0で提供されるものとします。

不具合報告には、端末名、Androidバージョン、外部ディスプレイの接続方法、再現手順を含めてください。セキュリティ上の問題や個人情報は公開Issueへ投稿しないでください。

## ライセンス

特に別記のない限り、このリポジトリの独自コード、ドキュメント、画像資産は[MIT No Attribution License（MIT-0）](LICENSE)で提供されます。利用、複製、改変、結合、公開、再配布、サブライセンス、販売が可能で、著作権表示やクレジット表記も必須ではありません。

Flutter SDKと依存パッケージは、それぞれのライセンスに従います。アプリ内では「設定 → オープンソースライセンス」から同梱コンポーネントのライセンスを確認できます。
