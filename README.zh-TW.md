# 🐳 DeepSeek 鯨魚娘 · Mac 桌寵

[简体中文](README.md) · [English](README.en.md) · **繁體中文** · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

一隻住在你 Mac 螢幕底部的 DeepSeek 鯨魚娘。她會到處跑、盯著你的滑鼠游標、被戳了會說話，被拖起來會哭，閒著會深度思考，還會舉著「区」字牌問你「凶」是什麼意思。

![預覽](docs/preview.png)

> 這是社群製作的非官方同人專案，與 DeepSeek（深度求索）沒有隸屬或背書關係。

## 安裝

需要 macOS 13 或更新版本，Intel 和 Apple 晶片都可以。

### 方法一：一行指令安裝（推薦）

打開「終端機」，貼上這一行，按 Return：

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

它會把 App 安裝到你的 `~/Applications` 並直接啟動。

### 方法二：手動下載

1. 到 [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest) 下載 `WhaleGirl-macOS.zip`，按兩下解壓縮。
2. 把 `WhaleGirl.app` 拖進「應用程式」。
3. 第一次打開時，macOS 會提示「無法驗證開發者」，因為這個 App 沒有經過 Apple 公證。處理方法：
   - **按右鍵**點 `WhaleGirl.app` → 選「打開」→ 再按「打開」；
   - 如果還是打不開，在終端機執行：
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleGirl.app
     ```

### 方法三：自己編譯

需要 Xcode 或 Xcode 命令列工具（沒有的話執行 `xcode-select --install`）。

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleGirl.app
```

## 怎麼玩

她說的是簡體中文，台詞都是 DeepSeek 的梗，例如「服务器繁忙，请稍后再试」（伺服器忙碌中，請稍後再試）。

| 操作 | 她的反應 |
|---|---|
| 移動滑鼠 | 轉頭看向游標（16 個方向） |
| 點她一下 | 揮手、蹦跳、說話，或開始「深度思考」 |
| 拖著走 | 哭著喊「放我下來」，放開後掉回地面 |
| 對她按右鍵，或點選單列的 🐳 | 說句話、深度思考、舉牌子、睡覺、回到螢幕中間、結束 |
| 什麼都不做 | 自己跑來跑去、發呆、睡覺、舉牌子 |

她不會擋住你的操作：除了她身體所在的位置，其他透明區域的點擊都會穿透到後面的視窗。

**結束**：點選單列的 🐳 →「退出鲸鱼娘」。她沒有 Dock 圖示，所以 ⌘Q 沒有用。

**再次打開**：用 Spotlight（⌘ 空白鍵）搜尋 `WhaleGirl`。

**解除安裝**：結束後把 `WhaleGirl.app` 丟進垃圾桶就好。

## 改造她

所有程式碼都在 [`main.swift`](main.swift) 這一個檔案裡：

- 她說的話和選單文字都在 `enum Lines`；
- 每種狀態用哪幾格動畫在 `struct Anim`；
- 行為機率（多久走路、睡覺、說話）在 `decide()`。

改完執行 `./build.sh` 重新編譯。

## 致謝與授權

- 角色動畫圖集來自 [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet)（MIT 授權），詳見 [`assets/SOURCE.md`](assets/SOURCE.md) 和 [`assets/LICENSE`](assets/LICENSE)。
- 本專案程式碼以 [MIT 授權](LICENSE) 開源。
- 「DeepSeek」名稱與標誌歸其權利人所有。
