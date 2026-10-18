# 🐋 WhaleSeek · an AI usage whale girl for your Mac

[简体中文](README.md) · **English** · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

A DeepSeek whale girl who lives in a corner of your Mac screen. Her speech bubble shows your DeepSeek balance, today's spending, and a countdown to the next peak / off-peak switch. It is a native Mac port of the [DSH balance whale widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) and does not need DeepSeek Harness.

![Preview](docs/preview.png)

![10 AI-generated moves](docs/animations.gif)

> This is an unofficial fan project. It is not affiliated with or endorsed by DeepSeek.
>
> Formerly WhaleBalance; renamed to WhaleSeek in v0.3.0. Settings, the ledger and API keys are migrated automatically when you upgrade.

## Features

- **Balance**: checks your DeepSeek balance with your API key, refreshes every 60 seconds, and refreshes when you click her. Total, granted, and topped-up balances are all available.
- **Today's spending**: adds up balance drops as spending. Top-ups are recorded separately and never cancel spending, and you can correct any day by hand. Each API key gets its own ledger.
- **Ledger window**: today, the last 7 days, or all records, with per-entry details, search by date or model, and a spending breakdown.
- **Peak / off-peak**: weekdays 9–12 and 14–18 Beijing time are peak; weekends and Chinese public holidays are off-peak. Five display styles, including a live countdown.
- **Custom bubbles**: a click sequence, weighted A/B choices, and modules for text, links, random lines, images, balance, today's spending, peak status, other vendors, and Codex usage. Each module has its own size, colors, animated gradient, and font.
- **Alerts**: low-balance and daily-budget alerts with editable content.
- **Other vendors**: 34 templates, including balances for OpenRouter, Kimi, StepFun, and Novita, subscription quotas for Zhipu, Kimi Coding, MiniMax, and OpenCode Go, and OpenAI-compatible gateways. Keys only go to each template's official endpoint unless you allow a custom one.
- **Codex stats**: reads local Codex session logs for token usage and subscription windows, with no network access.
- **Native Mac app**: drag her anywhere and she snaps to screen edges and flips when snapped left. Balance in the menu bar, launch at login, and API keys stored only on your Mac.
- **Subscriptions and API costs**: automatically detects cswap (every Claude account's 5-hour, 7-day, extra spend, and per-model usage), your Claude Code plan and token usage, and the ChatGPT plan behind Codex. With an organization Admin key it also shows OpenAI API and Claude API costs.
- **Autoplay**: every 1–3 minutes she does something on her own: a small move, a random bubble, or a usage report. Each move comes with 5 matching lines that don't repeat. She also speaks up when peak/off-peak switches or a subscription crosses its threshold or resets, and stays quiet in full screen, during meetings, when you're away, and at night. Autoplay never makes sound.
- **AI-generated moves**: 10 frame-by-frame animations made by the art pipeline (stretching, eating, dozing, typing, dancing, counting money and more), mixed in with the original moves.
- **Chat with her**: a full DeepSeek assistant with the whale girl's personality. Code, debugging, research, translation: answers stream in with Markdown, copyable code blocks and tables. Toggle deep thinking (with expandable reasoning), switch between Flash and V4 Pro, edit and resend, regenerate, stop mid-answer, and attach text, code or PDF files. Conversations are grouped by date and can be searched, renamed and deleted. **Automatic long-term memory**: after each chat she notes lasting facts about you (who you are, your projects, your preferences) and uses them in later chats; you can view, edit or delete every memory. She can also speak up on her own during autoplay (off by default). Chatting sends the persona, memories, your balance, today's spend, subscription percentages and the conversation to api.deepseek.com, billed to your DeepSeek balance; conversations and memories stay on your Mac. She replies in Chinese by default and switches to your language when you write in it.

Per-turn cost, task-end sounds, question and approval prompts, and the session-name module are not ported. They depend on events inside DeepSeek Harness, which a standalone app cannot see.

## Install

Requires macOS 13 or later. Works on both Apple Silicon and Intel Macs.

### Option 1: one-line install (recommended)

Open Terminal, paste this line, and press Return:

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/whaleseek/main/install.sh | bash
```

It installs the app into `~/Applications` and launches it.

### Option 2: download manually

1. Download `WhaleSeek-macOS.zip` from [Releases](https://github.com/jianzhou0420/whaleseek/releases/latest) and double-click it to unzip.
2. Drag `WhaleSeek.app` into your Applications folder.
3. The first time you open it, macOS will say it can't verify the developer, because the app isn't notarized. To open it anyway:
   - **Right-click** `WhaleSeek.app`, choose **Open**, then click **Open** again.
   - If it still won't open, run this in Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleSeek.app
     ```

### Option 3: build from source

You need Xcode or the Xcode Command Line Tools (run `xcode-select --install` if you don't have them).

```bash
git clone https://github.com/jianzhou0420/whaleseek.git
cd whaleseek
./build.sh
open WhaleSeek.app
```

On first launch the settings window opens. Paste your DeepSeek API key and click Save. The key is stored only on your Mac, in a file only your user account can read (keys.json), so macOS never asks for your password.

## How to use

| You | She |
|---|---|
| Click her | Refreshes the balance and shows the balance bubble |
| Click the bubble | Shows the next item (random lines and images) and closes after the last one |
| Drag her | Moves her; she snaps to the nearest edge when you let go |
| Chat button (on hover), or the menu's 「和鲸鱼娘聊天」 | Open the chat window |
| Right-click her, the ⋯ button, or 🐳 in the menu bar | Menu: size, sounds, bubbles, snapping, ledger, settings, quit |

## Art pipeline

`art-pipeline/` generates new whale-girl poses with the image generation built into Codex CLI, using your ChatGPT plan instead of an API key. It keys out the background, cleans the edges, checks each image for problems, regenerates failures, and installs the results into the app's built-in gallery. List new poses in `art-pipeline/assets.json`, then run:

```bash
codex login
./art.sh all
```

`./art.sh anim` generates frame animations from `art-pipeline/anims.json`: 6 frames per image, split automatically, aligned at the feet and checked for consistency. `./art.sh anim-install` then adds them to the app.

Each image takes about 40 seconds. Image generation uses Codex limits 3–5 times faster than text.

![Images made by the art pipeline](docs/generated-art.png)

Looking for the walking desktop pet from the first version? It is still available in the [v0.0.1 release](https://github.com/jianzhou0420/whaleseek/releases/tag/v0.0.1).

## Credits and license

- Features, accounting rules, vendor templates, and default lines are ported from [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) (MIT). Its images and sounds are not MIT licensed and are not used here.
- Character art by [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet) (MIT).
- The images in `assets/generated` were made by the art pipeline with OpenAI's gpt-image-2, using that character as the reference. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- The code in this project is released under the [MIT License](LICENSE).
