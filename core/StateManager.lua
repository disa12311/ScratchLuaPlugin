--[[
    core/StateManager.lua
    Quản lý toàn bộ trạng thái plugin:
    - State table (placedBlocks, blockCounter, clipboard...)
    - Block helpers: newId, findById, findRoots, syncInputs
    - placeBlock: tạo block mới từ def
    - rebuildFromData: rebuild canvas từ snapshot (load/undo/import)
    - copySelected / pasteClipboard
    - deleteBlock (unlink + destroy frame)
--]]

local BlockDefs  = require(script.Parent.Parent.blocks.BlockDefinitions)
local UIBuilder  = require(script.Parent.Parent.ui.UIBuilder)
local UndoMgr    = require(script.Parent.Parent.utils.UndoManager)

local StateManager = {}

-- ── State ─────────────────────────────────────────────────────
StateManager.state = {
    placedBlocks = {},
    blockCounter = 0,
    selected     = nil,
    clipboard    = nil,
    saveTimer    = nil,
}

-- ── Callbacks (được gắn bởi init sau khi UI sẵn sàng) ─────────
-- Tránh circular dependency: StateManager không require init
StateManager.onChanged    = nil   -- fn() gọi updateCode + updateMinimap + scheduleSave
StateManager.canvas       = nil   -- ScrollingFrame
StateManager.canvasHint   = nil   -- TextLabel hint
StateManager.dropZone     = nil   -- Frame drop zone
StateManager.canvasArea   = nil   -- Frame

-- ─── Helpers ─────────────────────────────────────────────────

function StateManager.newId()
    StateManager.state.blockCounter += 1
    return "b" .. StateManager.state.blockCounter
end

function StateManager.findById(id)
    for _, bd in ipairs(StateManager.state.placedBlocks) do
        if bd.id == id then return bd end
    end
end

function StateManager.findRoots()
    local roots = {}
    for _, bd in ipairs(StateManager.state.placedBlocks) do
        if not bd.prev then table.insert(roots, bd) end
    end
    return roots
end

function StateManager.syncInputs(bd)
    if not bd.frame then return end
    local inputsF = bd.frame:FindFirstChild("Inputs")
    if not inputsF then return end
    for _, row in ipairs(inputsF:GetChildren()) do
        if row:IsA("Frame") then
            for _, child in ipairs(row:GetChildren()) do
                if child:IsA("TextBox") then
                    bd.inputs[child.Name:gsub("^Input_", "")] = child.Text
                end
            end
        end
    end
end

-- ─── Wire up TextBox listeners cho một frame ──────────────────
local function wireInputs(frame, bd)
    local inputsF = frame:FindFirstChild("Inputs")
    if not inputsF then return end
    for _, row in ipairs(inputsF:GetChildren()) do
        if row:IsA("Frame") then
            for _, child in ipairs(row:GetChildren()) do
                if child:IsA("TextBox") then
                    local n = child.Name:gsub("^Input_", "")
                    -- Restore value
                    if bd.inputs[n] then child.Text = bd.inputs[n] end
                    child:GetPropertyChangedSignal("Text"):Connect(function()
                        bd.inputs[n] = child.Text
                        if StateManager.onChanged then StateManager.onChanged() end
                    end)
                end
            end
        end
    end
end

-- ─── Wire up Delete + DragEnded signals cho một block ─────────
local function wireSignals(frame, bd, trySnapFn)
    frame:GetAttributeChangedSignal("DeleteRequested"):Connect(function()
        if not frame:GetAttribute("DeleteRequested") then return end
        frame:SetAttribute("DeleteRequested", false)
        StateManager.deleteBlock(bd)
    end)

    frame:GetAttributeChangedSignal("DragEnded"):Connect(function()
        if not frame:GetAttribute("DragEnded") then return end
        frame:SetAttribute("DragEnded", false)
        if trySnapFn then trySnapFn(bd) end
        if StateManager.onChanged then StateManager.onChanged() end
    end)
end

-- ─── deleteBlock ──────────────────────────────────────────────
function StateManager.deleteBlock(bd)
    UndoMgr.push(UndoMgr.snapshot(StateManager.state.placedBlocks))
    if bd.prev then bd.prev.next = nil end
    if bd.next then bd.next.prev = nil end
    for i, x in ipairs(StateManager.state.placedBlocks) do
        if x.id == bd.id then table.remove(StateManager.state.placedBlocks, i); break end
    end
    if bd.frame and bd.frame.Parent then bd.frame:Destroy() end
    if #StateManager.state.placedBlocks == 0 and StateManager.canvasHint then
        StateManager.canvasHint.Visible = true
    end
    if StateManager.onChanged then StateManager.onChanged() end
end

-- ─── placeBlock ───────────────────────────────────────────────
function StateManager.placeBlock(def, trySnapFn)
    local S = StateManager.state
    if StateManager.canvasHint then StateManager.canvasHint.Visible = false end
    UndoMgr.push(UndoMgr.snapshot(S.placedBlocks))

    local id    = StateManager.newId()
    local frame = UIBuilder.createBlockFrame(def, id, StateManager.canvas)
    local offsetX = 40 + (#S.placedBlocks % 5) * 20
    local offsetY = 40 + #S.placedBlocks * 46
    frame.Position = UDim2.new(0, offsetX, 0, math.min(offsetY, 1600))

    local bd = {
        id = id, defId = def.id, frame = frame,
        inputs = {}, next = nil, prev = nil, parentId = nil,
    }
    if def.inputs then
        for _, inp in ipairs(def.inputs) do
            bd.inputs[inp.name] = inp.default or ""
        end
    end

    wireInputs(frame, bd)
    wireSignals(frame, bd, trySnapFn)
    table.insert(S.placedBlocks, bd)
    if StateManager.onChanged then StateManager.onChanged() end
    return bd
end

-- ─── rebuildFromData ──────────────────────────────────────────
function StateManager.rebuildFromData(data, trySnapFn)
    local S = StateManager.state
    for _, bd in ipairs(S.placedBlocks) do
        if bd.frame and bd.frame.Parent then bd.frame:Destroy() end
    end
    S.placedBlocks = {}

    if not data or not data.blocks or #data.blocks == 0 then
        if StateManager.canvasHint then StateManager.canvasHint.Visible = true end
        if StateManager.onChanged then StateManager.onChanged() end
        return
    end

    if StateManager.canvasHint then StateManager.canvasHint.Visible = false end
    S.blockCounter = data.blockCounter or 0

    -- Pass 1: tạo frames
    local tempMap = {}
    for _, entry in ipairs(data.blocks) do
        local def = BlockDefs.byId[entry.defId]
        if not def then continue end

        local frame = UIBuilder.createBlockFrame(def, entry.id, StateManager.canvas)
        frame.Position = UDim2.new(0, entry.posX or 60, 0, entry.posY or 60)

        local bd = {
            id       = entry.id,
            defId    = entry.defId,
            frame    = frame,
            inputs   = entry.inputs or {},
            next     = nil,
            prev     = nil,
            parentId = entry.parentId,
        }

        wireInputs(frame, bd)
        wireSignals(frame, bd, trySnapFn)
        table.insert(S.placedBlocks, bd)
        tempMap[entry.id] = bd
    end

    -- Pass 2: reconnect
    for _, entry in ipairs(data.blocks) do
        local bd = tempMap[entry.id]
        if bd then
            if entry.nextId then bd.next = tempMap[entry.nextId] end
            if entry.prevId then bd.prev = tempMap[entry.prevId] end
        end
    end

    if StateManager.onChanged then StateManager.onChanged() end
end

-- ─── copySelected ─────────────────────────────────────────────
function StateManager.copySelected()
    local S = StateManager.state
    if not S.selected then return end
    local chain = {}
    local cur = S.selected
    while cur do
        StateManager.syncInputs(cur)
        table.insert(chain, {
            defId    = cur.defId,
            inputs   = table.clone(cur.inputs),
            parentId = cur.parentId,
        })
        cur = cur.next
    end
    S.clipboard = chain

    -- Visual flash
    local body = S.selected.frame and S.selected.frame:FindFirstChild("Body")
    if body then
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(255, 220, 0)
        s.Thickness = 2.5
        s.Parent = body
        task.delay(0.5, function() if s.Parent then s:Destroy() end end)
    end
end

-- ─── pasteClipboard ───────────────────────────────────────────
function StateManager.pasteClipboard(trySnapFn)
    local S = StateManager.state
    if not S.clipboard or #S.clipboard == 0 then return end
    UndoMgr.push(UndoMgr.snapshot(S.placedBlocks))
    if StateManager.canvasHint then StateManager.canvasHint.Visible = false end

    local prevBd = nil
    for i, entry in ipairs(S.clipboard) do
        local def = BlockDefs.byId[entry.defId]
        if not def then continue end

        local id    = StateManager.newId()
        local frame = UIBuilder.createBlockFrame(def, id, StateManager.canvas)
        frame.Position = UDim2.new(0, 80 + (i-1)*5, 0, math.min(80 + #S.placedBlocks*46, 1600))

        local bd = {
            id = id, defId = def.id, frame = frame,
            inputs = table.clone(entry.inputs or {}), next = nil, prev = nil,
            parentId = entry.parentId,
        }
        if def.inputs then
            for _, inp in ipairs(def.inputs) do
                if not bd.inputs[inp.name] then bd.inputs[inp.name] = inp.default or "" end
            end
        end

        wireInputs(frame, bd)
        wireSignals(frame, bd, trySnapFn)

        -- Chain pasted blocks
        if prevBd then
            prevBd.next = bd
            bd.prev = prevBd
            local pf = prevBd.frame
            frame.Position = UDim2.new(
                pf.Position.X.Scale, pf.Position.X.Offset,
                pf.Position.Y.Scale, pf.Position.Y.Offset + pf.AbsoluteSize.Y + 2
            )
        end

        table.insert(S.placedBlocks, bd)
        prevBd = bd
    end

    if StateManager.onChanged then StateManager.onChanged() end
end

return StateManager
