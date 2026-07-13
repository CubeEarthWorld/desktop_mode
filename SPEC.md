# Desktop Touchpad 入力・外部表示仕様 v2

## 1. 対象環境

- Android 16 / API 36 以上。
- 通常アプリ権限と AccessibilityService の公開 API だけを使用する。
- `InputManager` の非公開入力注入、root、Shizuku、ADB 常駐には依存しない。
- Accessibility の `dispatchGesture` はマウスイベントではなくタッチ入力として配送される。

## 2. タッチセッション

最初の pointer down から全 pointer が離れるまでを一つのセッションとする。
各セッションにはプロセス内で重複しない単調増加 ID を割り当てる。タイマー、フレーム
コールバック、MethodChannel 呼び出し、native の継続ストロークはすべてこの ID を照合する。

### 状態

| 状態 | 動作 |
|---|---|
| `idle` | 入力待ち |
| `oneFingerPending` | クリック、カーソル移動、ドラッグ待ち。down だけでは何も出力しない |
| `cursorMoving` | 1本指の相対移動をカーソルへ送る |
| `dragArmed` | 静止長押し時間を満たした状態。まだ外部接触は開始しない |
| `dragging` | 外部カーソル位置を起点とする1点の連続接触 |
| `twoFingerPending` | 二点の重心が移動閾値を超えるまで待つ |
| `scrolling` | 重心移動を1点の連続スワイプへ変換する |
| `suppressed` | 残った指や3本目以降を全指 release まで無視する |

`PointerUpEvent` の最終座標も pointer を除去する前に move として評価する。
したがって `dragArmed` 後に移動して離した場合は必ず
`begin → update → end` となり、移動せず離した場合だけ長押しを確定する。

### 判定値

- クリック: 250ms 以下、down から12 logical px以下で release。
- カーソル移動: 12 logical pxを超えた時点で、down からの累積差分を最初に送る。
- ドラッグ武装: 既定1000ms、設定範囲400–1500ms。
- ドラッグ開始: 武装後に1 logical pxを超えて移動。
- 二本指開始: 二本目の受付時間制限は設けない。重心が12 logical pxを超えるとスクロール開始。
- 二本指タップは無操作。片方が離れた瞬間にスクロールを終了し、残った指は無視する。
- pointer cancel、3本目、ロック、画面破棄、セッション停止では実行中の連続入力を一度だけ終了する。

## 3. Flutter から native への入力 API

| Method | 引数 | 結果 |
|---|---|---|
| `commitPointerAction` | `type: click/longPress`, `showFeedback` | GestureAck |
| `beginContinuousGesture` | `id`, `kind: drag/scroll` | GestureAck |
| `updateContinuousGesture` | `id`, `dx`, `dy` | GestureAck |
| `endContinuousGesture` | `id`, `cancelled` | 最終 release 完了後に GestureAck |
| `updateInputDiagnostics` | `phase`, `sessionId` | なし |

GestureAck は `accepted / queued / alreadyEnded / stale / cancelled / failed`。
旧 `pointerDown/Move/Up` と `twoFingerMove*` API は存在しない。

Flutter はカーソル差分と連続ジェスチャー差分をフレーム単位で集約する。ただし end を
受け取った時は同じフレームの保留差分を先にキューへ移し、必ず
`begin → update → end` の順に直列送信する。end 後のフレームコールバックは同じ ID の
update を送信できない。

## 4. native 継続ストローク

- 初回接触は `StrokeDescription(..., willContinue=true)`。
- 次のセグメントは、直前の `StrokeDescription.continueStroke()` からだけ作る。
- continuation の `startTime` は新しい GestureDescription 基準の `0`。
- 前セグメントの完了 callback 前に次の `dispatchGesture` を呼ばない。
- 移動中に届いた座標は最新値へ集約する。
- end は最後の移動を含む `willContinue=false` セグメントを送信し、その callback 後に完了する。
- system cancel はセッションを終端させる。move 失敗時の自動 pointerDown 再送は行わない。
- ドラッグはカーソルと接触点を同時に移動する。スクロールではカーソルを固定する。

## 5. 操作エフェクト

- pointer down、カーソル移動、二本指待機では表示しない。
- クリックまたは長押しが release により確定した時だけ、本体と外部カーソル位置へ表示する。
- `showTouchGlow=false` の場合は両方を表示しない。

## 6. 外部アプリのウィンドウ比率

manifest に固定向きが指定されたアプリは、本体ディスプレイの縦横比を使って
起動範囲を自動計算する。向きが固定されていないアプリは起動範囲を指定しない。

電話比率のウィンドウは、本体と外部ディスプレイ双方の system bar / display cutout を
除いた領域から計算し、外部領域へ最大内接・中央配置する。固定9:16は使用しない。

端末が freeform window 対応を宣言していない場合も、OEMのdesktop mode実装が
範囲指定を受け付ける可能性があるため電話比率の bounds は送る。起動後に取得できる
AccessibilityWindowInfo の比率が要求値から5%以上ずれた場合は
`launch_bounds_ignored` を記録する。

アプリ一覧からの起動は `NEW_TASK | MULTIPLE_TASK` と `setLaunchDisplayId` を併用する。
これによりメイン画面にある同一アプリの既存タスクを前面化する検索を抑止し、
外部ディスプレイ用タスクとして起動する。

## 7. アプリ一覧

- ボトムシートは4列グリッドで、48pxアイコンの下に小さいアプリ名を表示する。
- グリッドは DraggableScrollableSheet の controller を使って縦スクロールする。
- PackageManager の一覧取得は platform thread 外で実行し、結果を5分間保持する。
- アイコンは一覧と分離し、表示範囲の項目だけ96px PNGとして遅延取得する。
- native はアイコンを4MiBのLRUキャッシュへ保持し、Flutterはシート終了時に解放する。
- アイコン取得完了時は該当セルだけを再構築し、一覧全体を再構築しない。
- 検索欄はシート表示時にフォーカスし、スクロール開始時にキーボードを閉じる。
- アプリごとの表示サイズ設定は持たない。

## 8. 設定移行

- 設定 schema version は5。
- 新規既定の長押し時間は500ms。
- schema version 1で値が旧既定550msの場合は1000msへ移行し、version 3未満の
  旧既定1000msは500msへ移行する。
- その他の既存値は利用者が選択した値として保持する。
- `showTouchGlow` は「接触表示」ではなく「確定操作エフェクト」として引き継ぐ。
- タッチロックの無操作時間は5秒、10秒、30秒のみとし、既定値と不正値の
  フォールバックは30秒とする。
- 旧 `appWindowModes` は読み込まず、保存時にも出力しない。

## 9. 必須テスト

- down 時に platform action と glow が0件。
- tap は release 時に click と glow が各1件。
- 遅い二本目、二本指タップ、二本指後の残り指から click が発生しない。
- 同一フレームの drag/scroll move + up が begin → update → end になる。
- cancel、3本目、ロック、dispose 後に次のセッションが正常動作する。
- native で1操作あたり ACTION_DOWN 1回、ACTION_UP 1回となり、各 move が同一継続ストロークに属する。
- manifest固定向きによる電話比率と、起動範囲非対応・無視の診断を確認する。
- ロック表示全体の不透明度0.5とOLEDピクセルシフトを確認する。
- アプリ一覧の検索欄フォーカスと、表示サイズ設定が存在しないことを確認する。
