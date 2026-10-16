# 🐳 DeepSeek クジラ娘 · Mac デスクトップマスコット

[简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md) · **日本語** · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

Mac の画面の下に住んでいる、DeepSeek のクジラ娘です。走り回ったり、マウスカーソルを目で追ったり、クリックするとおしゃべりしたり、つまみ上げると泣いたり、ヒマなときは「深く考え」たりします。「区」と書かれた札を持って、「凶」ってどういう意味？と聞いてくることもあります。

![プレビュー](docs/preview.png)

> これはファンによる非公式プロジェクトです。DeepSeek とは関係がなく、公認も受けていません。

## インストール

macOS 13 以降が必要です。Apple シリコンと Intel のどちらの Mac でも動きます。

### 方法 1：コマンド 1 行でインストール（おすすめ）

「ターミナル」を開いて、次の 1 行を貼り付け、Return キーを押します。

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

アプリが `~/Applications` にインストールされ、そのまま起動します。

### 方法 2：手動でダウンロード

1. [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest) から `WhaleGirl-macOS.zip` をダウンロードし、ダブルクリックで展開します。
2. `WhaleGirl.app` を「アプリケーション」フォルダにドラッグします。
3. 初めて開くとき、アプリが公証されていないため、macOS が「開発元を確認できません」と表示します。次の方法で開けます。
   - `WhaleGirl.app` を**右クリック**して「開く」を選び、もう一度「開く」をクリックします。
   - それでも開けない場合は、ターミナルで次を実行します。
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleGirl.app
     ```

### 方法 3：ソースからビルド

Xcode または Xcode コマンドラインツールが必要です（ない場合は `xcode-select --install` を実行してください）。

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleGirl.app
```

## 遊び方

セリフは中国語です。DeepSeek ネタが中心で、たとえば「服务器繁忙，请稍后再试」（サーバーが混み合っています。しばらくしてから再度お試しください）などと言います。

| あなたの操作 | 彼女の反応 |
|---|---|
| マウスを動かす | カーソルのほうを向く（16 方向） |
| クリックする | 手を振る、跳ねる、しゃべる、または「深く考え」はじめる |
| ドラッグする | 「おろして〜！」と泣き、離すと地面に落ちる |
| 右クリック、またはメニューバーの 🐳 | メニュー：しゃべる、考える、札を掲げる、寝る、画面の中央に戻る、終了 |
| 何もしない | 歩き回ったり、ぼーっとしたり、昼寝したり、札を掲げたりする |

作業のじゃまはしません。彼女の体以外の透明な部分をクリックすると、後ろのウインドウにそのまま届きます。

**終了**：メニューバーの 🐳 から「退出鲸鱼娘」（終了）を選びます。Dock アイコンがないので ⌘Q は効きません。

**もう一度開く**：Spotlight（⌘ + スペース）で `WhaleGirl` を検索します。

**アンインストール**：終了してから `WhaleGirl.app` をゴミ箱に入れるだけです。

## カスタマイズ

コードはすべて [`main.swift`](main.swift) の 1 ファイルにあります。

- セリフとメニューの文字は `enum Lines` にあります。
- 各状態で使うアニメーションのコマは `struct Anim` にあります。
- 歩く・寝る・しゃべる頻度は `decide()` で決めています。

変更したら `./build.sh` をもう一度実行してください。

## クレジットとライセンス

- キャラクターのアニメーション素材は [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet)（MIT ライセンス）によるものです。詳しくは [`assets/SOURCE.md`](assets/SOURCE.md) と [`assets/LICENSE`](assets/LICENSE) をご覧ください。
- このプロジェクトのコードは [MIT ライセンス](LICENSE) で公開しています。
- 「DeepSeek」の名称とロゴは各権利者に帰属します。
