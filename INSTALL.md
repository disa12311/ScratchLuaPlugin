# Hướng dẫn cài đặt ScratchLua v3.0

## Cấu trúc cần tạo trong Roblox Studio

```
ScratchLuaPlugin          ← Script (paste init.server.lua)
├── blocks/
│   └── BlockDefinitions  ← ModuleScript
├── codegen/
│   └── CodeGenerator     ← ModuleScript
├── ui/
│   └── UIBuilder         ← ModuleScript
└── utils/
    ├── PersistenceManager  ← ModuleScript
    ├── UndoManager         ← ModuleScript
    ├── ExportImport        ← ModuleScript
    ├── CustomBlockManager  ← ModuleScript
    └── RuntimeErrorTracker ← ModuleScript
```

## Bước thực hiện

1. Mở Roblox Studio → View → Explorer
2. Click phải **ServerStorage** → Insert Object → **Script**
   - Đổi tên: `ScratchLuaPlugin`
   - Paste nội dung `init.server.lua`
3. Click phải `ScratchLuaPlugin` → Insert Object → **Folder** → tên `blocks`
   - Click phải `blocks` → Insert Object → **ModuleScript** → tên `BlockDefinitions`
   - Paste nội dung `blocks/BlockDefinitions.lua`
4. Lặp tương tự cho `codegen/CodeGenerator`, `ui/UIBuilder`
5. Tạo Folder `utils`, rồi tạo 5 ModuleScripts bên trong:
   - `PersistenceManager`, `UndoManager`, `ExportImport`, `CustomBlockManager`, `RuntimeErrorTracker`
   - Paste nội dung từ file tương ứng trong thư mục `utils/`
6. Click phải `ScratchLuaPlugin` → **Save as Local Plugin** → đặt tên `ScratchLua`
7. Plugin xuất hiện trong Toolbar → click icon 🧱 để mở

## Tính năng v3

| Phím tắt | Tính năng |
|----------|-----------|
| Ctrl+Z   | Undo |
| Ctrl+Y   | Redo |
| Ctrl+C   | Copy block chain |
| Ctrl+V   | Paste |

| Nút | Tính năng |
|-----|-----------|
| ▶ Insert | Inject code vào Script được chọn |
| 📤 Export | Xuất chương trình dạng JSON |
| 📥 Import | Nhập chương trình từ JSON |
| ⭐ New Block | Tạo custom block mới |
| ✕ Clear | Xóa toàn bộ canvas |

| Tính năng tự động | Mô tả |
|-------------------|-------|
| Auto-save | Lưu layout sau 2 giây không thao tác |
| Syntax validation | Badge xanh/đỏ kiểm tra code realtime |
| Runtime errors | Highlight block bị lỗi khi Play mode |
| Minimap | Xem toàn bộ canvas ở góc dưới phải |

**Custom blocks:** Click phải vào block trong category "⭐ My Blocks" để sửa/xóa.
