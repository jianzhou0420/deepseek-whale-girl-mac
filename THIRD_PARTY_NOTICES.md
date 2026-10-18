# Third-party notices

## DeepSeek-Balance-Whale-Widget (code)

Feature design, the balance-observation accounting rules (`Sources/Accounting.swift`), the peak/off-peak
calendar (`Sources/Pricing.swift`), vendor templates (`Sources/Vendors.swift`), Codex log parsing rules
(`Sources/Codex.swift`), gradient presets, and default bubble content (`Sources/Bubble.swift`) are ported
from https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget (commit 5247dd6).

    MIT License
    Copyright (c) 2026 MeteorNOX

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

The original project's images, GIFs and sound effects (its `assets/` folder) are **not** covered by its
MIT license and are **not** used here. Built-in sounds in this app are macOS system sounds.

## deepseek-girl-codex-pet (artwork)

`assets/spritesheet.webp` is from https://github.com/f0909172434/deepseek-girl-codex-pet,
MIT License, Copyright (c) 2026 f0909172434. Its license text is in `assets/LICENSE`.
The app icon is generated from a frame of that sheet.

## Generated images

The images in `assets/generated/` were produced by the pipeline in `art-pipeline/` with OpenAI's gpt-image-2
(through Codex CLI), using a frame of the deepseek-girl atlas above as the character reference. They are
derivative of that MIT-licensed character design. AI-generated images may not be eligible for copyright
protection in some jurisdictions; they are distributed here under the same MIT terms as the rest of the
project, to the extent any rights exist, and subject to OpenAI's terms for generated output.
