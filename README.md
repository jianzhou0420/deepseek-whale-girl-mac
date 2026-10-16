# 🐳 DeepSeek 鲸鱼娘 · Mac 桌宠

**简体中文** · [English](README.en.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

一只住在你 Mac 屏幕底部的 DeepSeek 鲸鱼娘。她会到处跑、看着你的鼠标、被戳了会说话，拖起来会哭，闲着会深度思考，还会举着「区」字牌问你「凶」是什么意思。

![预览](docs/preview.png)

> 这是社区制作的非官方同人项目，与 DeepSeek（深度求索）没有隶属或背书关系。

## 安装

需要 macOS 13 或更新版本，Intel 和 Apple 芯片都可以。

### 方法一：一行命令安装（推荐）

打开「终端」，粘贴这一行，回车：

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

它会把应用装到你的 `~/Applications` 里并直接启动。

### 方法二：手动下载

1. 到 [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest) 下载 `WhaleGirl-macOS.zip`，双击解压。
2. 把 `WhaleGirl.app` 拖进「应用程序」。
3. 第一次打开时，macOS 会提示「无法验证开发者」，因为这个应用没有经过苹果公证。处理办法：
   - **右键**点 `WhaleGirl.app` → 选「打开」→ 再点「打开」；
   - 如果还是打不开，在终端运行：
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleGirl.app
     ```

### 方法三：自己编译

需要 Xcode 或 Xcode 命令行工具（没有的话运行 `xcode-select --install`）。

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleGirl.app
```

## 怎么玩

| 操作 | 她的反应 |
|---|---|
| 晃动鼠标 | 转头看向鼠标（16 个方向） |
| 单击 | 挥手、蹦跳、说话，或者开始「深度思考」 |
| 拖着走 | 哭着喊「放我下来」，松手后掉回地面 |
| 右键她，或点菜单栏的 🐳 | 说句话、深度思考、举牌子、睡觉、回到屏幕中间、退出 |
| 什么都不做 | 自己跑来跑去、发呆、睡觉、举牌子 |

她不会挡住你的操作：除了她身体所在的位置，其他透明区域的点击都会穿透到后面的窗口。

**退出**：点菜单栏的 🐳 →「退出鲸鱼娘」。她没有 Dock 图标，所以 ⌘Q 不管用。

**再次打开**：用聚焦搜索（⌘ 空格）搜 `WhaleGirl`。

**卸载**：退出后把 `WhaleGirl.app` 丢进废纸篓就行。

## 改造她

所有代码都在 [`main.swift`](main.swift) 一个文件里：

- 她说的话和菜单文字都在 `enum Lines`，直接改中文就行；
- 每种状态用哪几帧动画在 `struct Anim`；
- 行为概率（多久走路、睡觉、说话）在 `decide()`。

改完运行 `./build.sh` 重新编译。

## 致谢与许可

- 角色动画图集来自 [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet)（MIT 许可），详见 [`assets/SOURCE.md`](assets/SOURCE.md) 和 [`assets/LICENSE`](assets/LICENSE)。
- 本项目代码以 [MIT 许可](LICENSE) 开源。
- 「DeepSeek」名称和标志归其权利人所有。
