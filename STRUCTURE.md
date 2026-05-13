# ScratchLua Plugin v2.0 — File Structure

```
src/
├── init.server.lua              ← Main plugin script (copy vào Script)
├── blocks/
│   └── BlockDefinitions.lua    ← 60+ block definitions
├── codegen/
│   └── CodeGenerator.lua       ← Block chain → Luau code
├── ui/
│   └── UIBuilder.lua           ← Render block frames
└── utils/
    ├── PersistenceManager.lua  ← Auto-save layout
    ├── UndoManager.lua         ← Undo/Redo stack
    └── ExportImport.lua        ← JSON export/import dialogs
```

## Cài đặt trong Roblox Studio

1. Tạo Script tên `ScratchLuaPlugin` → paste `init.server.lua`
2. Tạo Folder `blocks` → ModuleScript `BlockDefinitions` → paste
3. Tạo Folder `codegen` → ModuleScript `CodeGenerator` → paste
4. Tạo Folder `ui` → ModuleScript `UIBuilder` → paste
5. Tạo Folder `utils` → 3 ModuleScripts: PersistenceManager, UndoManager, ExportImport → paste
6. Right-click Script → "Save as Local Plugin"

## Tính năng v2

| Tính năng | Cách dùng |
|-----------|-----------|
| Lưu layout | Tự động sau 2s |
| Undo | Ctrl+Z hoặc nút ↩ |
| Redo | Ctrl+Y hoặc nút ↪ |
| Copy block | Ctrl+C (sau khi click chọn block) |
| Paste | Ctrl+V |
| Search | Gõ vào ô tìm kiếm trên sidebar |
| Export JSON | Nút 📤 Export |
| Import JSON | Nút 📥 Import → paste JSON |
| Syntax check | Badge xanh/đỏ realtime |
| Minimap | Góc dưới phải canvas |
| Container | Kéo block vào vùng if/while/for |
