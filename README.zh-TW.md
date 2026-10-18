# 🐋 WhaleBalance · DeepSeek 餘額小鯨魚（Mac 原生版）

[简体中文](README.md) · [English](README.en.md) · **繁體中文** · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

一隻住在 Mac 螢幕角落的 DeepSeek 鯨魚娘。對話泡泡裡顯示 DeepSeek 餘額、今日已用和峰谷時段倒數。這是 [DSH 小鯨魚記帳掛件](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) 的 Mac 原生移植版，不需要安裝 DeepSeek Harness。

![預覽](docs/preview.png)

> 這是社群製作的非官方同人專案，與 DeepSeek（深度求索）沒有隸屬或背書關係。

## 功能

- **餘額**：用 DeepSeek API 金鑰查詢餘額，預設每 60 秒自動更新，點角色立即更新。總餘額、贈金、儲值餘額都能分別顯示。
- **今日已用**：依餘額下降累計花費。儲值會另外記錄，不會抵銷花費，任何一天都能手動校正。每把 API 金鑰各記一本帳。
- **記帳視窗**：今日、近 7 天、全部紀錄，可依日期展開逐筆明細、依日期或模型名稱搜尋，並附花費組成圖。
- **峰谷時段**：平日 9–12 點、14–18 點（北京時間）為尖峰，週末和中國法定假日全天離峰。五種顯示樣式，包括逐秒倒數。
- **自訂泡泡**：點擊序列、A/B 加權抽選；模組有文字、連結、隨機語句、圖片、餘額、今日已用、峰谷、其他廠商、Codex 用量，每個模組都能分別設定字級、顏色、跑馬燈漸層和字型。
- **提醒**：餘額預警和今日預算，提醒內容可以自由編輯。
- **其他廠商**：34 個範本，包括 OpenRouter、Kimi、階躍、Novita 的餘額，智譜、Kimi Coding、MiniMax、OpenCode Go 的訂閱額度，以及 OpenAI 相容中轉站。金鑰只會送往範本裡的官方端點，自訂位址需要你手動允許。
- **Codex 統計**：讀取本機 Codex 對話紀錄，統計 token 用量和訂閱時段，不連網。
- **Mac 原生**：隨意拖曳，放開後吸附到螢幕邊緣，貼左時自動翻轉；選單列顯示餘額、登入時自動啟動、金鑰存在鑰匙圈。

沒有移植的功能：每輪對話花費、任務結束音、提問 / 授權提示、對話名稱模組。它們依賴 DeepSeek Harness 內部的對話事件，獨立 App 取得不到。

## 安裝

需要 macOS 13 或更新版本，Intel 和 Apple 晶片都可以。

### 方法一：一行指令安裝（推薦）

打開「終端機」，貼上這一行，按 Return：

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

它會把 App 安裝到 `~/Applications` 並直接啟動。

### 方法二：手動下載

1. 到 [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest) 下載 `WhaleBalance-macOS.zip`，按兩下解壓縮。
2. 把 `WhaleBalance.app` 拖進「應用程式」。
3. 第一次打開時，macOS 會提示「無法驗證開發者」，因為這個 App 沒有經過 Apple 公證。處理方法：
   - **按右鍵**點 `WhaleBalance.app` → 選「打開」→ 再按「打開」；
   - 如果還是打不開，在終端機執行：
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleBalance.app
     ```

### 方法三：自己編譯

需要 Xcode 或 Xcode 命令列工具（沒有的話執行 `xcode-select --install`）。

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleBalance.app
```

第一次啟動會打開設定視窗，貼上 DeepSeek API 金鑰後按「保存密钥」即可。金鑰只存在 macOS 鑰匙圈裡。

## 怎麼用

| 操作 | 效果 |
|---|---|
| 點一下角色 | 更新餘額，彈出餘額泡泡 |
| 點一下泡泡 | 進入下一項（隨機台詞和圖片），最後一項後收起 |
| 拖曳角色 | 移動位置，放開後吸附到最近的邊緣 |
| 對角色按右鍵、懸停的 ⋯ 按鈕，或選單列的 🐳 | 選單：大小、音效、泡泡、吸附、記帳、設定、結束 |

## 美術素材產線

`art-pipeline/` 用 Codex CLI 內建的圖像生成功能批次產生鯨魚娘的新姿勢，使用 ChatGPT 訂閱額度，不需要 API 金鑰。它會自動去背、清理邊緣、逐張檢查，不合格的重新產生，合格的裝進 App 的內建圖庫。在 `art-pipeline/assets.json` 寫好新姿勢後執行：

```bash
codex login
./art.sh all
```

每張圖大約 40 秒。圖像生成消耗 Codex 額度的速度約為文字對話的 3–5 倍。

![產線產生的圖片](docs/generated-art.png)

想找第一版那隻會到處走的桌寵？它還在 [v0.0.1 Release](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/tag/v0.0.1) 裡。

## 致謝與授權

- 功能設計、記帳規則、廠商範本和預設台詞移植自 [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)（MIT 授權）。原專案的圖片和音效不在 MIT 範圍內，本專案沒有使用。
- 角色美術來自 [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet)（MIT 授權）。
- `assets/generated` 裡的圖片由美術產線呼叫 OpenAI 的 gpt-image-2、以上述角色為參考產生，詳見 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
- 本專案程式碼以 [MIT 授權](LICENSE) 開源。
