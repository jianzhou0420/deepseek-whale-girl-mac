# 🐋 WhaleBalance · DeepSeek 余额小鲸鱼（Mac 原生版）

**简体中文** · [English](README.en.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

一只住在 Mac 屏幕角落的 DeepSeek 鲸鱼娘。气泡里显示 DeepSeek 余额、今日已用和峰谷时段倒计时。这是 [DSH 小鲸鱼记账挂件](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) 的 Mac 原生移植版，不需要安装 DeepSeek Harness。

![预览](docs/preview.png)

> 这是社区制作的非官方同人项目，与 DeepSeek（深度求索）没有隶属或背书关系。

## 功能

- **余额**：用 DeepSeek API 密钥查余额，默认 60 秒自动刷新，点角色立即刷新。总余额、赠金、充值余额都能单独显示。
- **今日已用**：按余额下降累计消费。充值单独记录，不会冲掉消费，任何一天都能手动校正。每个 API 密钥各记一本账。
- **记账窗口**：今日、近 7 天、全部记录，按日期展开逐条明细，按日期或模型名搜索，附消费构成图。
- **峰谷时段**：工作日 9–12 点、14–18 点（北京时间）为高峰，周末和法定节假日全天空闲。五种显示样式，包括逐秒倒计时。
- **自定义泡泡**：点击序列、A/B 加权抽选；模块有文本、链接、随机语句、图片、余额、今日已用、峰谷、其它厂商、Codex 用量，每个模块都能单独设置字号、颜色、跑马灯渐变和字体。
- **提醒**：余额预警和今日预算，提醒内容可以自由编辑。
- **其它厂商**：34 个模板，包括 OpenRouter、Kimi、阶跃、Novita 的余额，智谱、Kimi Coding、MiniMax、OpenCode Go 的订阅额度，以及 OpenAI 兼容中转站。密钥只会发往模板里的官方接口，自定义地址需要你手动允许。
- **Codex 统计**：读取本机 Codex 会话日志，统计 token 用量和订阅窗口，不联网。
- **Mac 原生**：随意拖动，松手吸附屏幕边缘，贴左时自动翻转；菜单栏显示余额，开机自动启动，密钥保存在钥匙串。
- **订阅与 API 费用**：自动识别本机的 cswap（显示每个 Claude 账号的 5 小时、7 天、额外用量和各模型额度）、Claude Code 的订阅和 token 用量，以及 Codex 背后的 ChatGPT 订阅。填入组织的 Admin Key 后还能显示 OpenAI API 和 Claude API 的费用。

没有移植的功能：每轮对话消耗、任务结束音、提问 / 授权提示、对话名模块。它们依赖 DeepSeek Harness 内部的会话事件，独立应用拿不到。

## 安装

需要 macOS 13 或更新版本，Intel 和 Apple 芯片都可以。

### 方法一：一行命令安装（推荐）

打开「终端」，粘贴这一行，回车：

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

它会把应用装到 `~/Applications` 并直接启动。

### 方法二：手动下载

1. 到 [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest) 下载 `WhaleBalance-macOS.zip`，双击解压。
2. 把 `WhaleBalance.app` 拖进「应用程序」。
3. 第一次打开时，macOS 会提示「无法验证开发者」，因为这个应用没有经过苹果公证。处理办法：
   - **右键**点 `WhaleBalance.app` → 选「打开」→ 再点「打开」；
   - 如果还是打不开，在终端运行：
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleBalance.app
     ```

### 方法三：自己编译

需要 Xcode 或 Xcode 命令行工具（没有的话运行 `xcode-select --install`）。

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleBalance.app
```

第一次启动会打开设置窗口，粘贴 DeepSeek API 密钥后点「保存密钥」即可。密钥只保存在 macOS 钥匙串里。

## 怎么用

| 操作 | 效果 |
|---|---|
| 单击角色 | 刷新余额，弹出余额气泡 |
| 单击气泡 | 进入下一项（随机台词和图片），最后一项后收起 |
| 拖动角色 | 移动位置，松手吸附到最近的边缘 |
| 右键角色、悬停的 ⋯ 按钮，或菜单栏 🐳 | 菜单：大小、音效、气泡、吸附、记账、设置、退出 |

## 美术资产流水线

`art-pipeline/` 用 Codex CLI 自带的图像生成功能批量生成鲸鱼娘的新姿势，走 ChatGPT 订阅额度，不需要 API 密钥。它会自动抠背景、清理边缘、逐张质检，不合格的重新生成，合格的装进应用的内置图库。在 `art-pipeline/assets.json` 里写好新姿势，然后运行：

```bash
codex login
./art.sh all
```

每张图大约 40 秒。图像生成消耗 Codex 额度的速度约为文字对话的 3–5 倍。

![流水线生成的图片](docs/generated-art.png)

想找第一版那只会到处走的桌宠？它还在 [v0.0.1 Release](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/tag/v0.0.1) 里。

## 致谢与许可

- 功能设计、记账规则、厂商模板和默认台词移植自 [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)（MIT 许可）。原项目的图片和音效不在 MIT 范围内，本项目没有使用。
- 角色美术来自 [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet)（MIT 许可）。
- `assets/generated` 里的图片由美术流水线调用 OpenAI 的 gpt-image-2、以上述角色为参考生成，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
- 本项目代码以 [MIT 许可](LICENSE) 开源。
