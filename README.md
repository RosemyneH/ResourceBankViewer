<div align="center">
    <img src="https://img.icons8.com/color/160/treasure-chest.png" width="120" height="120" alt="ResourceBankViewer Logo"/>
</div>

<h1 align="center">ResourceBankViewer</h1>

<p align="center">
    <em>Movable Synastria resource bank overlay — totals, session gains, search, and scrape tools for RBankFrame</em>
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-usage">Usage</a> •
  <a href="#-slash-commands">Commands</a> •
  <a href="#-settings--data">Settings</a> •
  <a href="#-project-structure">Structure</a>
</p>

---

## ✨ Features

- 📊 **Live counts**: Reads Synastria resource bank totals via `GetCustomGameData` (type 13) for watched item IDs
- 📈 **Session column**: Tracks gains since baseline; use **Reset** to snapshot current totals as the new zero
- 🔎 **Search**: Filter rows by item name or numeric item ID (case-insensitive substring)
- ↕️ **Sortable headers**: Click **Total** or **Session** to sort; click again to flip ascending / descending
- 🪟 **Movable & resizable**: Drag the frame, resize from the corner grip; position and size persist in `RBVDB`
- 🔄 **Background refresh**: Can briefly nudge `RBankFrame` off-screen so bank data stays fresh without opening the UI
- 🧹 **Scrape helper**: Compare `RBankFrame` line widgets to your preset / extra IDs; optionally append missing IDs to saved extras
- 🎨 **ElvUI font**: If ElvUI is present, the panel prefers its normal font; `/rbv font` adjusts size
- Adds Function to withdraw and Deposit

---

## 📦 Installation

1. Copy or clone this folder into your WoW addons directory, for example:
   ```text
   Synastria/Interface/AddOns/ResourceBankViewer/
   ```
2. Ensure the manifest lists these files (see [Project structure](#-project-structure)).
3. Requires **Synastria** with `RBankFrame` and resource bank APIs (`GetCustomGameData`, etc.).
4. Enable **ResourceBankViewer** on the character selection screen.

---

## 🕹️ Usage

### Open the viewer
- Type `/rbv` (toggles the window)

### Basic flow
1. **Browse**: Scroll the list of watched items with icons, names, **Total**, and **Session** (+gains).
2. **Search**: Use the bottom search box; **Clear** or Escape on the box clears the filter.
3. **Sort**: Click **Total** or **Session** in the header row.
4. **Reset session**: Click **Reset** to set the current bank snapshot as the new baseline (session gains restart from there).
5. **Move / resize**: Drag the title area; use the grip at the bottom-right to resize.

💡 **Tip**: Hover a row for the standard item tooltip (when the client knows the item).

---

## 💬 Slash Commands

| Command | Action |
|:---|:---|
| `/rbv` | Toggle the viewer window |
| `/rbv on` | Enable the addon (show on login, resume polling) |
| `/rbv off` | Disable; hides the frame and stops treating the addon as active |
| `/rbv reset` | Same as in-UI **Reset** — refresh baseline for session gains |
| `/rbv font <n>` | Set UI font size (clamped roughly 8–18) |
| `/rbv refresh` | Nudge bank refresh, invalidate cache, redraw |
| `/rbv scrape` | List item IDs seen on `RBankFrame` that are not in preset + `extraIds` |
| `/rbv scrape add` | Append those missing IDs to saved `RBVDB.extraIds` |
| `/rbv ids` | Print counts: preset IDs, saved extras, total watched |

---

## ⚙️ Settings & data

Saved variables live in **`RBVDB`** (see `ResourceBankViewer.toc`). Notable fields:

| Area | Meaning |
|:---|:---|
| `enabled` | Master on/off (`/rbv on` / `off`) |
| `pos` | Frame anchor and position |
| `ui.w`, `ui.h`, `ui.fontSize` | Window size and font size |
| `sort.key`, `sort.asc` | Last sort column (`count` or `gained`) and direction |
| `filter` | Search string persisted with the character |
| `baseline` | Per–item-id snapshot for session gain math |
| `extraIds` | Additional item IDs beyond `preset_itemids.lua` |
| `updateInterval` | Minimum seconds between bank cache rebuilds (default ~2) |
| `refreshInterval` | How often the background poller invalidates cache and updates UI (default ~10) |

Preset IDs ship in `preset_itemids.lua` as `RBV.PRESET_ITEM_IDS`. Edit that file for repo-wide defaults, or use `/rbv scrape add` for per-character extras.

---

## 📁 Project Structure

```text
ResourceBankViewer/
├── ResourceBankViewer.toc  # Addon manifest (Interface 30300)
├── core.lua                # Slash commands, defaults, login & polling
├── preset_itemids.lua      # RBV.PRESET_ITEM_IDS watch list
├── rbank_datasource.lua    # Bank queries, scrape, sort/filter data, baseline
└── ui.lua                  # Frame, scroll list, search, layout
```

---

<div align="center">
    <sub>Built for Synastria resource tracking. Part of the <b>Synastria</b> addon suite.</sub>
</div>
