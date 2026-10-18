#!/bin/zsh
# Runs the core-logic tests (accounting, peak pricing, vendors, Codex parsing, bubble config).
set -e
cd "$(dirname "$0")"
OUT="$(mktemp -d)/whaleseek-tests"
swiftc -swift-version 5 Sources/Accounting.swift Sources/Pricing.swift Sources/Vendors.swift Sources/Codex.swift \
  Sources/Store.swift Sources/Bubble.swift Sources/Atlas.swift Sources/Subscriptions.swift Sources/AutoPlayPolicy.swift Sources/ChatPersona.swift Tests/main.swift -o "$OUT"
"$OUT"
