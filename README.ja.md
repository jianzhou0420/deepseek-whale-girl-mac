# 🐋 WhaleBalance · DeepSeek 残高クジラ（Mac ネイティブ版）

[简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md) · **日本語** · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

Mac の画面の隅に住む DeepSeek のクジラ娘です。吹き出しに DeepSeek の残高、今日の利用額、ピーク / オフピーク切り替えまでのカウントダウンを表示します。[DSH 残高クジラウィジェット](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) の Mac ネイティブ移植版で、DeepSeek Harness は不要です。

![プレビュー](docs/preview.png)

> これはファンによる非公式プロジェクトです。DeepSeek とは関係がなく、公認も受けていません。

## 機能

- **残高**：DeepSeek の API キーで残高を取得し、60 秒ごとに自動更新、キャラをクリックすると即更新します。合計残高・付与分・チャージ分を個別に表示できます。
- **今日の利用額**：残高の減少分を利用額として積み上げます。チャージは別に記録されて利用額を打ち消さず、どの日も手動で補正できます。API キーごとに別の帳簿になります。
- **帳簿ウィンドウ**：今日・直近 7 日・全記録。日付ごとの明細、日付やモデル名での検索、利用内訳グラフつき。
- **ピーク / オフピーク**：平日 9–12 時と 14–18 時（北京時間）がピーク、週末と中国の祝日は終日オフピーク。秒単位のカウントダウンを含む 5 種類の表示スタイル。
- **吹き出しのカスタマイズ**：クリック順のシーケンス、重み付き A/B 抽選。テキスト・リンク・ランダムなセリフ・画像・残高・今日の利用額・ピーク状態・他社・Codex 使用量のモジュールがあり、それぞれ文字サイズ・色・流れるグラデーション・フォントを設定できます。
- **アラート**：残高不足と今日の予算のアラート。内容は自由に編集できます。
- **他社サービス**：34 種類のテンプレート。OpenRouter・Kimi・StepFun・Novita の残高、智譜・Kimi Coding・MiniMax・OpenCode Go のサブスク枠、OpenAI 互換ゲートウェイに対応。キーは各テンプレートの公式エンドポイントにだけ送られ、独自 URL は手動で許可が必要です。
- **Codex 統計**：ローカルの Codex セッションログからトークン使用量とサブスク枠を集計します。通信はしません。
- **Mac ネイティブ**：ドラッグで自由に動かせて画面の端に吸着、左端では左右反転。メニューバーに残高表示、ログイン時に自動起動、API キーはキーチェーンに保存。
- **サブスクと API 費用**：この Mac の cswap（各 Claude アカウントの 5 時間・7 日・追加利用・モデル別の使用量）、Claude Code のプランとトークン使用量、Codex の ChatGPT プランを自動で検出します。組織の Admin キーを入れると OpenAI API と Claude API の費用も表示します。

移植していない機能：ターンごとのコスト、タスク終了音、質問 / 承認の通知、会話名モジュール。これらは DeepSeek Harness 内部のイベントに依存しており、単体アプリからは取得できません。

## インストール

macOS 13 以降が必要です。Apple シリコンと Intel のどちらの Mac でも動きます。

### 方法 1：コマンド 1 行でインストール（おすすめ）

「ターミナル」を開いて、次の 1 行を貼り付け、Return キーを押します。

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

アプリが `~/Applications` にインストールされ、そのまま起動します。

### 方法 2：手動でダウンロード

1. [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest) から `WhaleBalance-macOS.zip` をダウンロードし、ダブルクリックで展開します。
2. `WhaleBalance.app` を「アプリケーション」フォルダにドラッグします。
3. 初めて開くとき、アプリが公証されていないため、macOS が「開発元を確認できません」と表示します。次の方法で開けます。
   - `WhaleBalance.app` を**右クリック**して「開く」を選び、もう一度「開く」をクリックします。
   - それでも開けない場合は、ターミナルで次を実行します。
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleBalance.app
     ```

### 方法 3：ソースからビルド

Xcode または Xcode コマンドラインツールが必要です（ない場合は `xcode-select --install` を実行してください）。

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleBalance.app
```

初回起動時に設定ウィンドウが開きます。DeepSeek の API キーを貼り付けて保存してください。キーは macOS のキーチェーンにだけ保存されます。

## 使い方

| 操作 | 動作 |
|---|---|
| キャラをクリック | 残高を更新して残高の吹き出しを表示 |
| 吹き出しをクリック | 次の項目（ランダムなセリフと画像）を表示、最後の項目のあとで閉じる |
| キャラをドラッグ | 位置を移動、離すと近くの端に吸着 |
| キャラを右クリック、⋯ ボタン、またはメニューバーの 🐳 | メニュー：サイズ、効果音、吹き出し、吸着、帳簿、設定、終了 |

## アート素材パイプライン

`art-pipeline/` は Codex CLI に内蔵された画像生成で、クジラ娘の新しいポーズをまとめて生成します。API キーではなく ChatGPT のサブスク枠を使います。背景の除去、輪郭の整理、1 枚ずつの品質チェック、不合格分の再生成を自動で行い、合格した画像をアプリの内蔵ギャラリーに組み込みます。`art-pipeline/assets.json` に新しいポーズを書いて、次を実行します。

```bash
codex login
./art.sh all
```

1 枚あたり約 40 秒です。画像生成はテキストより 3–5 倍速く Codex の利用枠を消費します。

![パイプラインで生成した画像](docs/generated-art.png)

最初のバージョンの歩き回るデスクトップマスコットをお探しですか？ [v0.0.1 リリース](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/tag/v0.0.1) から入手できます。

## クレジットとライセンス

- 機能設計、帳簿のルール、ベンダーテンプレート、デフォルトのセリフは [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)（MIT）から移植しました。元プロジェクトの画像と効果音は MIT の対象外のため使用していません。
- キャラクターのアートは [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet)（MIT）によるものです。
- `assets/generated` の画像は、上記のキャラクターを参考にアートパイプラインが OpenAI の gpt-image-2 で生成したものです。詳しくは [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) をご覧ください。
- このプロジェクトのコードは [MIT ライセンス](LICENSE) で公開しています。
