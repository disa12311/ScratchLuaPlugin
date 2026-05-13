--[[
    UndoManager.lua
    Stack-based undo/redo cho mọi thao tác trên canvas.

    Mỗi action lưu snapshot toàn bộ State.placedBlocks (shallow copy
    của metadata, không bao gồm frame Instance).  Khi undo/redo,
    main script rebuild frames từ snapshot.

    API:
        UndoManager.push(snapshot)   -- ghi lại trạng thái TRƯỚC khi thay đổi
        UndoManager.undo()           → snapshot | nil
        UndoManager.redo()           → snapshot | nil
        UndoManager.canUndo()        → bool
        UndoManager.canRedo()        → bool
        UndoManager.clear()
--]]

local UndoManager = {}

local MAX_HISTORY = 50   -- tối đa 50 bước undo

local undoStack = {}     -- { snapshot, ... }  (index 1 = oldest)
local redoStack = {}

-- ─── Tạo snapshot từ placedBlocks (deep copy metadata) ───────

function UndoManager.snapshot(placedBlocks)
    local snap = {}
    for _, bd in ipairs(placedBlocks) do
        local inputsCopy = {}
        for k, v in pairs(bd.inputs or {}) do
            inputsCopy[k] = v
        end
        table.insert(snap, {
            id       = bd.id,
            defId    = bd.defId,
            posX     = bd.frame and bd.frame.Position.X.Offset or 0,
            posY     = bd.frame and bd.frame.Position.Y.Offset or 0,
            inputs   = inputsCopy,
            nextId   = bd.next   and bd.next.id   or nil,
            prevId   = bd.prev   and bd.prev.id   or nil,
            parentId = bd.parentId or nil,
        })
    end
    return snap
end

-- ─── Đẩy snapshot vào undo stack (gọi TRƯỚC khi thay đổi) ────

function UndoManager.push(snapshot)
    table.insert(undoStack, snapshot)
    if #undoStack > MAX_HISTORY then
        table.remove(undoStack, 1)
    end
    -- Xóa redo khi có action mới
    redoStack = {}
end

-- ─── Undo: trả về snapshot trước đó ──────────────────────────

function UndoManager.undo(currentSnapshot)
    if #undoStack == 0 then return nil end
    -- Lưu trạng thái hiện tại vào redo
    if currentSnapshot then
        table.insert(redoStack, currentSnapshot)
    end
    return table.remove(undoStack, #undoStack)
end

-- ─── Redo: trả về snapshot tiếp theo ─────────────────────────

function UndoManager.redo(currentSnapshot)
    if #redoStack == 0 then return nil end
    if currentSnapshot then
        table.insert(undoStack, currentSnapshot)
    end
    return table.remove(redoStack, #redoStack)
end

function UndoManager.canUndo() return #undoStack > 0 end
function UndoManager.canRedo() return #redoStack > 0 end

function UndoManager.clear()
    undoStack = {}
    redoStack = {}
end

return UndoManager
