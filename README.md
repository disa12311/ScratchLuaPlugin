# ScratchLua v3.0 — Visual Block-based Luau Editor

Plugin Roblox Studio cho phép viết Luau code bằng cách kéo-thả blocks giống Scratch.

---

## Cấu trúc file

```
ScratchLuaPlugin/
│
├── init.server.lua              ← Bootstrap: toolbar, widget, UI, wires modules
│
├── blocks/
│   └── BlockDefinitions.lua    ← 60+ block definitions (Events, Control, Tween, Remote, GUI, Humanoid...)
│
├── codegen/
│   └── CodeGenerator.lua       ← Block chain → Luau code + syntax highlight
│
├── core/
│   ├── StateManager.lua        ← State, placeBlock, rebuildFromData, copy/paste, delete
│   └── CanvasManager.lua       ← Snap logic, container drop zone, minimap
│
├── ui/
│   ├── UIBuilder.lua           ← Render Frame cho mỗi block (drag, notch, inputs)
│   └── SidebarManager.lua      ← Populate sidebar, search filter, custom block editing
│
└── utils/
    ├── PersistenceManager.lua  ← Auto-save layout qua plugin:SetSetting
    ├── UndoManager.lua         ← Undo/Redo stack (tối đa 50 bước)
    ├── ExportImport.lua        ← Export/Import chương trình dạng JSON
    ├── CustomBlockManager.lua  ← Tạo, chỉnh sửa, xóa custom blocks
    └── RuntimeErrorTracker.lua ← Highlight block bị lỗi runtime khi Play mode
```

---

## Cài đặt trong Roblox Studio

**1. Tạo cây Scripts**

Trong Explorer, tạo `Script` đặt tên `ScratchLuaPlugin`, rồi tạo Folders và ModuleScripts theo đúng cấu trúc trên. Paste nội dung từng file `.lua` tương ứng vào.

```
ScratchLuaPlugin          Script         ← init.server.lua
├── blocks/               Folder
│   └── BlockDefinitions  ModuleScript
├── codegen/              Folder
│   └── CodeGenerator     ModuleScript
├── core/                 Folder
│   ├── StateManager      ModuleScript
│   └── CanvasManager     ModuleScript
├── ui/                   Folder
│   ├── UIBuilder         ModuleScript
│   └── SidebarManager    ModuleScript
└── utils/                Folder
    ├── PersistenceManager ModuleScript
    ├── UndoManager        ModuleScript
    ├── ExportImport       ModuleScript
    ├── CustomBlockManager ModuleScript
    └── RuntimeErrorTracker ModuleScript
```

**2. Publish thành plugin**

Click phải vào `ScratchLuaPlugin` → **Save as Local Plugin** → đặt tên `ScratchLua` → Save.

Plugin xuất hiện trong Toolbar. Click icon 🧱 để mở.

---

## Giao diện

```
┌──────────────────────────────────────────────────────────────────────┐
│ 🧱 ScratchLua v3  ● Syntax OK   [⭐ New Block][✕][↩][↪][📥][📤][▶] │
├─────────────────┬──────────────────────────────────┬─────────────────┤
│  🔍 Search...   │                                  │  Generated Code │
│                 │                                  │                 │
│ ⚡ Events       │        CANVAS                    │  local x = 5   │
│ 🔁 Control      │                                  │  print(x)       │
│ 📦 Variables    │  ← Kéo blocks từ sidebar         │  ...            │
│ 🎮 Parts        │  Blocks tự snap vào nhau         │                 │
│ 🎬 Tween        │                                  │         ┌──────┐│
│ 📡 Remote       │                          Minimap→│         │ ···  ││
│ 🖼️ GUI          │                                  │         └──────┘│
│ 🧍 Humanoid     │                                  │                 │
│ 👤 Player       │                                  │                 │
│ 📢 Output       │                                  │                 │
│ 🔢 Math         │                                  │                 │
│ 🧩 Functions    │                                  │                 │
│ ⭐ My Blocks    │                                  │                 │
└─────────────────┴──────────────────────────────────┴─────────────────┘
```

---

## Tính năng

### Block categories (60+ blocks)
| Category | Nội dung |
|----------|----------|
| ⚡ Events | game start, player join/leave, touched, key pressed, heartbeat |
| 🔁 Control | wait, repeat, for, while, if, if/else, break, return, spawn, defer |
| 📦 Variables | local, assign, change, table, insert |
| 🎮 Parts | move, set position/color/transparency/anchored, destroy, clone, find |
| 🎬 Tween | tween move, tween property |
| 📡 Remote | FireServer, FireClient, OnServerEvent, OnClientEvent |
| 🖼️ GUI | set text/visible, slide, on click, notify |
| 🧍 Humanoid | get, set health/speed/jump, moveTo, on died |
| 👤 Player | get character, teleport, kick, give tool |
| 📢 Output | print, print var, warn, error |
| 🔢 Math | random, abs, floor, clamp, lerp |
| 🧩 Functions | define, call, comment, section |
| ⭐ My Blocks | Custom blocks do người dùng tạo |

### Thao tác
| Hành động | Cách thực hiện |
|-----------|----------------|
| Thêm block | Click block trong sidebar |
| Xóa block | Hover → click × |
| Di chuyển | Kéo block trên canvas |
| Snap | Kéo gần block khác, tự ghép |
| Chọn block | Click |
| Copy chain | Ctrl+C |
| Paste | Ctrl+V |
| Undo | Ctrl+Z hoặc nút ↩ |
| Redo | Ctrl+Y hoặc nút ↪ |
| Tìm block | Gõ vào ô Search |
| Insert code | Chọn Script → nút ▶ Insert |
| Export | Nút 📤, copy JSON |
| Import | Nút 📥, paste JSON |
| Tạo custom block | Nút ⭐ New Block |
| Sửa custom block | Right-click block trong sidebar |

### Tự động
| Tính năng | Mô tả |
|-----------|-------|
| Auto-save | Lưu layout sau 2 giây không thao tác, restore khi mở lại Studio |
| Syntax check | Badge xanh ✓/đỏ ✗ kiểm tra code realtime bằng `loadstring` |
| Runtime errors | Khi Play mode, block gây lỗi bị highlight đỏ + badge `!` |
| Minimap | Góc dưới phải canvas, hiển thị vị trí tất cả blocks |
| Theme sync | Tự cập nhật màu theo Studio light/dark theme |

---

## Tạo Custom Block

1. Click **⭐ New Block** trên toolbar
2. Điền:
   - **Block Label**: tên hiển thị, có thể dùng emoji
   - **Code Template**: code Luau, dùng `{tên}` cho inputs
   - **Shape**: `stack`, `hat`, hoặc `cap`
   - **Container**: `true` nếu block chứa code bên trong (như if/while)
   - **Close Template**: dòng đóng khi container (thường là `end`)
   - **Màu R/G/B**: 0–255
   - **Inputs**: mỗi dòng một input theo format `name|label|default`

**Ví dụ — block in tên player:**
```
Label:    👋 Greet [player]
Template: print("Hello, " .. {player}.Name)
Shape:    stack
Inputs:   player|player var|player
```

Để **sửa hoặc xóa** custom block: right-click block trong sidebar (có icon ✏).

---

## Ví dụ chương trình

**In Hello World khi game bắt đầu:**
```
[🚀 When game starts]
    [🖨️ Print "Hello, World!"]
    [⏱️ Wait 1 seconds]
    [🖨️ Print "Done!"]
```

Code sinh ra:
```lua
-- Generated by ScratchLua v3.0.0

game:GetService('RunService').Heartbeat:Once(function()
	print("Hello, World!")
	task.wait(1)
	print("Done!")
end)
```

**Teleport player khi chạm vào part:**
```
[✋ When part touched]  hit var = hit
    [👤 Get character of player]  save as = char
    [⚡ Teleport player to XYZ]   X=0 Y=50 Z=0
```

---

## Ghi chú kỹ thuật

- Plugin lưu layout qua `plugin:SetSetting` — không mất khi đóng Studio
- Export JSON tương thích giữa các máy (dùng để chia sẻ chương trình)
- Syntax validation dùng `loadstring()` — chỉ check syntax, không chạy code
- Runtime error tracking dùng `ScriptContext.Error` — chỉ hoạt động khi Play mode và script được insert từ plugin
- Undo stack tối đa 50 bước, tự xóa cũ khi đầy
