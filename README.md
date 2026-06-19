# claudeTokenMonitor

A tiny always-on-top Windows desktop widget that shows your **Claude Code usage** in real time — the same numbers as the `/usage` panel, plus a per-session token breakdown.

[English](#claudetokenmonitor) · [繁體中文](#繁體中文說明)

![widget](docs/widget.png)

## What it shows

- **5-hour limit**, **Weekly (all models)**, **Sonnet only** — official utilization % and reset times, pulled live from Anthropic's usage endpoint (`/api/oauth/usage`, the same source `/usage` uses).
- **This session** — Input / Output / Cache read / Cache write token counts, read from the most recently active local transcript (deduped by message id).

## Requirements

- Windows + Windows PowerShell 5.1
- Claude Code installed and logged in (the widget reads your OAuth token from `~/.claude/.credentials.json`; nothing is stored or sent anywhere except Anthropic's own API)

## Usage

- Double-click **`桌面小工具.vbs`** to launch (no console window).
- Double-click **`全部關閉.cmd`** to close all running instances.
- **Drag** to move, **right-click** or **X** to close, **TOP** toggles always-on-top.

Auto-start on login: drop a shortcut to `桌面小工具.vbs` into `shell:startup`.

## Notes

- The token is read fresh on every poll (every 15s), so when Claude Code refreshes it the widget keeps working. If it expires and isn't refreshed, the widget shows `auth? run Claude Code`.
- "This session" matches `/usage` only at the same instant — it keeps changing as you work.

## How it works

`widget.ps1` is a single PowerShell + WinForms script. No dependencies, no install.

---

## 繁體中文說明

一個常駐桌面、可置頂的 Windows 小工具，即時顯示你的 **Claude Code 用量**——數字跟 `/usage` 面板一致，外加當前 session 的 token 明細。

### 顯示內容

- **5-hour limit**、**Weekly（所有模型）**、**Sonnet only**——官方使用率 % 與重置時間，即時取自 Anthropic 的用量 endpoint（`/api/oauth/usage`，跟 `/usage` 同一來源）。
- **This session**——Input / Output / Cache read / Cache write 的 token 數，讀取最近活動的本機 transcript（依 message id 去重）。

### 需求

- Windows + Windows PowerShell 5.1
- 已安裝並登入 Claude Code（小工具會從 `~/.claude/.credentials.json` 讀取你的 OAuth token；不儲存、也不送往 Anthropic 官方 API 以外的任何地方）

### 使用方式

- 雙擊 **`桌面小工具.vbs`** 啟動（無黑色終端機視窗）。
- 雙擊 **`全部關閉.cmd`** 關閉所有執行中的實例。
- **拖曳**移動、**右鍵**或 **X** 關閉、**TOP** 切換是否置頂。

開機自動啟動：把 `桌面小工具.vbs` 的捷徑放進 `shell:startup`。

### 說明

- 每次輪詢（每 15 秒）都會重新讀取 token，所以 Claude Code 換新 token 後仍可運作；若 token 過期且未刷新，會顯示 `auth? run Claude Code`。
- **This session** 只有在同一瞬間才會跟 `/usage` 完全一致——你持續操作時數字會一直變動。

### 運作原理

`widget.ps1` 是單一支 PowerShell + WinForms 腳本，無相依套件、免安裝。
