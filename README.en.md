# 🐳 DeepSeek Whale Girl · macOS Desktop Pet

[简体中文](README.md) · **English** · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

A DeepSeek whale girl who lives at the bottom of your Mac screen. She runs around, watches your cursor, talks when you click her, cries when you pick her up, and does some "deep thinking" when she gets bored. Sometimes she holds up a sign with "区" on it and asks what "凶" means.

![Preview](docs/preview.png)

> This is an unofficial fan project. It is not affiliated with or endorsed by DeepSeek.

## Install

Requires macOS 13 or later. Works on both Apple Silicon and Intel Macs.

### Option 1: one-line install (recommended)

Open Terminal, paste this line, and press Return:

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

It installs the app into `~/Applications` and launches it.

### Option 2: download manually

1. Download `WhaleGirl-macOS.zip` from [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest) and double-click it to unzip.
2. Drag `WhaleGirl.app` into your Applications folder.
3. The first time you open it, macOS will say it can't verify the developer, because the app isn't notarized. To open it anyway:
   - **Right-click** `WhaleGirl.app`, choose **Open**, then click **Open** again.
   - If it still won't open, run this in Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleGirl.app
     ```

### Option 3: build from source

You need Xcode or the Xcode Command Line Tools (run `xcode-select --install` if you don't have them).

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleGirl.app
```

## How to play

She speaks Chinese. Her lines are DeepSeek in-jokes, such as "服务器繁忙，请稍后再试" ("The server is busy, please try again later").

| You | She |
|---|---|
| Move the mouse | Turns her head toward the cursor (16 directions) |
| Click her | Waves, hops, says something, or starts "deep thinking" |
| Drag her | Cries "put me down!" and falls back to the ground when you let go |
| Right-click her, or click 🐳 in the menu bar | Menu: talk, think, hold up the sign, sleep, move to the center, quit |
| Leave her alone | Wanders around, daydreams, naps, and holds up her sign |

She won't get in your way. Clicks on the transparent area around her go straight through to the window behind.

**Quit**: Click 🐳 in the menu bar and choose 退出鲸鱼娘 (Quit). The app has no Dock icon, so ⌘Q doesn't work.

**Open again**: Search for `WhaleGirl` in Spotlight (⌘ Space).

**Uninstall**: Quit her, then move `WhaleGirl.app` to the Trash.

## Make her your own

All the code is in a single file, [`main.swift`](main.swift):

- Everything she says, plus the menu text, is in `enum Lines`.
- The animation frames each state uses are in `struct Anim`.
- How often she walks, sleeps, and talks is set in `decide()`.

Run `./build.sh` again after making changes.

## Credits and license

- Character animation atlas by [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet) (MIT License). See [`assets/SOURCE.md`](assets/SOURCE.md) and [`assets/LICENSE`](assets/LICENSE).
- The code in this project is released under the [MIT License](LICENSE).
- The DeepSeek name and logo belong to their respective owners.
