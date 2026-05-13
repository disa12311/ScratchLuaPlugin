--[[
    ScratchLua Plugin v3.0
    Tích hợp đầy đủ:
      1.  Lưu layout (PersistenceManager)
      2.  Container drop zone (visual highlight)
      3.  Syntax validation (loadstring)
      4.  Undo / Redo (UndoManager)
      5.  Block search / filter
      6.  Copy / Paste block chain
      7.  Export / Import JSON (ExportImport)
      8.  Canvas minimap
      9.  Block types mới (Tween, Remote, GUI, Humanoid)
      10. Custom blocks (CustomBlockManager)
      11. Runtime error highlight (RuntimeErrorTracker)
--]]

local Selection            = game:GetService("Selection")
local StudioService        = game:GetService("StudioService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local UserInputService     = game:GetService("UserInputService")

local PLUGIN_VERSION = "3.0.0"
local SAVE_DEBOUNCE  = 2

-- ── Modules ──────────────────────────────────────────────────
local BlockDefs      = require(script.Parent.blocks.BlockDefinitions)
local CodeGen        = require(script.Parent.codegen.CodeGenerator)
local UIBuilder      = require(script.Parent.ui.UIBuilder)
local Persistence    = require(script.Parent.utils.PersistenceManager)
local UndoMgr        = require(script.Parent.utils.UndoManager)
local ExportImp      = require(script.Parent.utils.ExportImport)
local CustomBlocks   = require(script.Parent.utils.CustomBlockManager)
local ErrorTracker   = require(script.Parent.utils.RuntimeErrorTracker)

-- ── Load + inject custom blocks vào BlockDefs ─────────────────
local customBlockList = CustomBlocks.load(plugin)
CustomBlocks.inject(BlockDefs, customBlockList)

-- lineMap được rebuild mỗi lần generate code (dùng cho error tracking)
local currentLineMap = {}
local errorTrackConn = nil

-- ═══════════════════════════════════════════════════════════════
-- TOOLBAR & WIDGET
-- ═══════════════════════════════════════════════════════════════

local toolbar      = plugin:CreateToolbar("ScratchLua")
local toggleButton = toolbar:CreateButton(
    "ScratchLua", "Open ScratchLua Editor",
    "rbxassetid://14978048121", "ScratchLua"
)

local widget = plugin:CreateDockWidgetPluginGui("ScratchLuaWidget",
    DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 960, 640, 720, 520)
)
widget.Title = "ScratchLua v2 — Visual Code Editor"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════

local State = {
    placedBlocks  = {},   -- {id, defId, frame, inputs{}, next, prev, parentId}
    blockCounter  = 0,
    selected      = nil,
    clipboard     = nil,  -- snapshot của block chain để paste
    saveTimer     = nil,
}

local function newId()
    State.blockCounter += 1
    return "b" .. State.blockCounter
end

-- ── Theme helper ─────────────────────────────────────────────
local function tc(item, mod)
    return StudioService.Theme:GetColor(item, mod)
end

-- ═══════════════════════════════════════════════════════════════
-- ROOT UI
-- ═══════════════════════════════════════════════════════════════

local root = Instance.new("Frame")
root.Size = UDim2.new(1,0,1,0)
root.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.MainBackground)
root.BorderSizePixel = 0
root.Parent = widget

-- ── TOP BAR ───────────────────────────────────────────────────
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1,0,0,40)
topBar.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.Titlebar)
topBar.BorderSizePixel = 0
topBar.ZIndex = 20
topBar.Parent = root

local function makeBtn(parent, text, w, xRight, color)
    local b = Instance.new("TextButton")
    b.Text = text
    b.Size = UDim2.new(0,w,0,26)
    b.Position = UDim2.new(1,xRight,0.5,-13)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 11
    b.AutoButtonColor = true
    b.ZIndex = 21
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = b
    b.Parent = parent
    return b
end

local titleLbl  = Instance.new("TextLabel")
titleLbl.Text   = "🧱 ScratchLua v3"
titleLbl.Size   = UDim2.new(0,160,1,0)
titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = tc(Enum.StudioStyleGuideColor.TitlebarText)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 21
titleLbl.Parent = topBar

local insertBtn    = makeBtn(topBar,"▶ Insert",      90, -10,  Color3.fromRGB(67,133,245))
local exportBtn    = makeBtn(topBar,"📤 Export",     74, -108, Color3.fromRGB(100,100,110))
local importBtn    = makeBtn(topBar,"📥 Import",     74, -190, Color3.fromRGB(100,100,110))
local undoBtn      = makeBtn(topBar,"↩ Undo",        60, -272, Color3.fromRGB(80,80,90))
local redoBtn      = makeBtn(topBar,"↪ Redo",        60, -340, Color3.fromRGB(80,80,90))
local clearBtn     = makeBtn(topBar,"✕ Clear",       64, -408, Color3.fromRGB(200,60,60))
local newBlockBtn  = makeBtn(topBar,"⭐ New Block",  88, -480, Color3.fromRGB(150,80,210))

-- Validation badge (xanh = ok, đỏ = lỗi)
local validBadge = Instance.new("Frame")
validBadge.Name = "ValidBadge"
validBadge.Size = UDim2.new(0,10,0,10)
validBadge.Position = UDim2.new(0,172,0.5,-5)
validBadge.BackgroundColor3 = Color3.fromRGB(80,200,80)
validBadge.ZIndex = 22
local vc = Instance.new("UICorner"); vc.CornerRadius = UDim.new(0.5,0); vc.Parent = validBadge
validBadge.Parent = topBar

local validLbl = Instance.new("TextLabel")
validLbl.Size = UDim2.new(0,120,1,0)
validLbl.Position = UDim2.new(0,186,0,0)
validLbl.BackgroundTransparency = 1
validLbl.TextColor3 = Color3.fromRGB(150,200,150)
validLbl.Font = Enum.Font.Gotham
validLbl.TextSize = 10
validLbl.TextXAlignment = Enum.TextXAlignment.Left
validLbl.Text = "Code OK"
validLbl.ZIndex = 21
validLbl.Parent = topBar

-- ── MAIN FRAME ────────────────────────────────────────────────
local main = Instance.new("Frame")
main.Size = UDim2.new(1,0,1,-40)
main.Position = UDim2.new(0,0,0,40)
main.BackgroundTransparency = 1
main.Parent = root

-- ── SIDEBAR (190px) ───────────────────────────────────────────
local sidebarFrame = Instance.new("Frame")
sidebarFrame.Name = "SidebarFrame"
sidebarFrame.Size = UDim2.new(0,190,1,0)
sidebarFrame.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.CategoryItem)
sidebarFrame.BorderSizePixel = 0
sidebarFrame.Parent = main

-- Search box
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1,-8,0,26)
searchBox.Position = UDim2.new(0,4,0,4)
searchBox.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.InputFieldBackground)
searchBox.TextColor3 = tc(Enum.StudioStyleGuideColor.MainText)
searchBox.PlaceholderText = "🔍 Search blocks..."
searchBox.PlaceholderColor3 = tc(Enum.StudioStyleGuideColor.DimmedText)
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 11
searchBox.ClearTextOnFocus = false
searchBox.ZIndex = 5
local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0,4); sc.Parent = searchBox
searchBox.Parent = sidebarFrame

local sidebar = Instance.new("ScrollingFrame")
sidebar.Size = UDim2.new(1,0,1,-34)
sidebar.Position = UDim2.new(0,0,0,34)
sidebar.BackgroundTransparency = 1
sidebar.ScrollBarThickness = 5
sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebar.CanvasSize = UDim2.new(0,0,0,0)
sidebar.Parent = sidebarFrame

local sbPad = Instance.new("UIPadding")
sbPad.PaddingLeft = UDim.new(0,6)
sbPad.PaddingRight = UDim.new(0,6)
sbPad.PaddingTop = UDim.new(0,4)
sbPad.Parent = sidebar

local sbLayout = Instance.new("UIListLayout")
sbLayout.Padding = UDim.new(0,3)
sbLayout.SortOrder = Enum.SortOrder.LayoutOrder
sbLayout.Parent = sidebar

-- ── CANVAS AREA ───────────────────────────────────────────────
local canvasArea = Instance.new("Frame")
canvasArea.Name = "CanvasArea"
canvasArea.Size = UDim2.new(1,-380,1,0)   -- sidebar 190 + codePanel 190
canvasArea.Position = UDim2.new(0,190,0,0)
canvasArea.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.ScriptBackground)
canvasArea.ClipsDescendants = true
canvasArea.Parent = main

local canvasHint = Instance.new("TextLabel")
canvasHint.Text = "← Kéo blocks từ sidebar\nBlocks tự snap vào nhau\nCtrl+Z Undo  •  Ctrl+C/V Copy/Paste"
canvasHint.Size = UDim2.new(0,320,0,60)
canvasHint.Position = UDim2.new(0.5,-160,0.5,-30)
canvasHint.BackgroundTransparency = 1
canvasHint.TextColor3 = tc(Enum.StudioStyleGuideColor.DimmedText)
canvasHint.TextXAlignment = Enum.TextXAlignment.Center
canvasHint.Font = Enum.Font.Gotham
canvasHint.TextSize = 12
canvasHint.TextWrapped = true
canvasHint.Parent = canvasArea

-- Drop zone highlight (hiện khi kéo block qua container)
local dropZone = Instance.new("Frame")
dropZone.Name = "DropZone"
dropZone.Size = UDim2.new(0,0,0,0)
dropZone.BackgroundColor3 = Color3.fromRGB(100,200,255)
dropZone.BackgroundTransparency = 0.7
dropZone.BorderSizePixel = 0
dropZone.Visible = false
dropZone.ZIndex = 3
local dzc = Instance.new("UICorner"); dzc.CornerRadius = UDim.new(0,6); dzc.Parent = dropZone
local dzStroke = Instance.new("UIStroke")
dzStroke.Color = Color3.fromRGB(100,200,255)
dzStroke.Thickness = 2
dzStroke.Parent = dropZone
dropZone.Parent = canvasArea

local canvas = Instance.new("ScrollingFrame")
canvas.Name = "Canvas"
canvas.Size = UDim2.new(1,0,1,0)
canvas.BackgroundTransparency = 1
canvas.CanvasSize = UDim2.new(0,2000,0,2000)
canvas.ScrollBarThickness = 8
canvas.ScrollingDirection = Enum.ScrollingDirection.XY
canvas.ZIndex = 4
canvas.Parent = canvasArea

-- ── MINIMAP ───────────────────────────────────────────────────
local minimap = Instance.new("Frame")
minimap.Name = "Minimap"
minimap.Size = UDim2.new(0,110,0,80)
minimap.Position = UDim2.new(1,-118,1,-88)
minimap.BackgroundColor3 = Color3.fromRGB(20,20,24)
minimap.BackgroundTransparency = 0.2
minimap.ZIndex = 30
minimap.ClipsDescendants = true
local mmc = Instance.new("UICorner"); mmc.CornerRadius = UDim.new(0,5); mmc.Parent = minimap
local mmStroke = Instance.new("UIStroke"); mmStroke.Color = Color3.fromRGB(80,80,90); mmStroke.Parent = minimap
minimap.Parent = canvasArea

local minimapDots = {}   -- {frame} dots trên minimap

-- Viewport indicator
local mmViewport = Instance.new("Frame")
mmViewport.Name = "Viewport"
mmViewport.BackgroundColor3 = Color3.fromRGB(255,255,255)
mmViewport.BackgroundTransparency = 0.85
mmViewport.BorderSizePixel = 0
mmViewport.ZIndex = 32
local mmvc = Instance.new("UIStroke"); mmvc.Color = Color3.fromRGB(200,200,255); mmvc.Thickness = 1; mmvc.Parent = mmViewport
mmViewport.Parent = minimap

-- ── CODE PANEL (190px) ────────────────────────────────────────
local codePanel = Instance.new("Frame")
codePanel.Size = UDim2.new(0,190,1,0)
codePanel.Position = UDim2.new(1,-190,0,0)
codePanel.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.ScriptBackground)
codePanel.BorderSizePixel = 1
codePanel.BorderColor3 = tc(Enum.StudioStyleGuideColor.Border)
codePanel.Parent = main

local cpTitle = Instance.new("TextLabel")
cpTitle.Text = "Generated Code"
cpTitle.Size = UDim2.new(1,0,0,22)
cpTitle.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.Titlebar)
cpTitle.TextColor3 = tc(Enum.StudioStyleGuideColor.TitlebarText)
cpTitle.Font = Enum.Font.GothamBold
cpTitle.TextSize = 11
cpTitle.ZIndex = 5
cpTitle.Parent = codePanel

local codeScroll = Instance.new("ScrollingFrame")
codeScroll.Size = UDim2.new(1,0,1,-22)
codeScroll.Position = UDim2.new(0,0,0,22)
codeScroll.BackgroundTransparency = 1
codeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
codeScroll.CanvasSize = UDim2.new(0,0,0,0)
codeScroll.ScrollBarThickness = 4
codeScroll.Parent = codePanel

local codeLbl = Instance.new("TextLabel")
codeLbl.Name = "CodeLabel"
codeLbl.Size = UDim2.new(1,-6,0,0)
codeLbl.Position = UDim2.new(0,3,0,3)
codeLbl.AutomaticSize = Enum.AutomaticSize.Y
codeLbl.BackgroundTransparency = 1
codeLbl.TextColor3 = tc(Enum.StudioStyleGuideColor.ScriptText)
codeLbl.Font = Enum.Font.Code
codeLbl.TextSize = 10
codeLbl.TextXAlignment = Enum.TextXAlignment.Left
codeLbl.TextYAlignment = Enum.TextYAlignment.Top
codeLbl.TextWrapped = true
codeLbl.RichText = true
codeLbl.Text = '<font color="#555">-- code sẽ xuất hiện ở đây</font>'
codeLbl.Parent = codeScroll

-- ═══════════════════════════════════════════════════════════════
-- SIDEBAR POPULATION + SEARCH
-- ═══════════════════════════════════════════════════════════════

local allSidebarItems = {}  -- {frame, def, categoryLabel}

local function populateSidebar(filter)
    filter = filter and filter:lower() or ""
    -- Xóa cũ
    for _, c in ipairs(sidebar:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
            c:Destroy()
        end
    end

    local order = 0
    for _, cat in ipairs(BlockDefs.categories) do
        local anyVisible = false
        local matchingBlocks = {}
        for _, def in ipairs(cat.blocks) do
            local label = def.label:lower()
            if filter == "" or label:find(filter, 1, true) then
                table.insert(matchingBlocks, def)
                anyVisible = true
            end
        end

        if anyVisible then
            -- Category header
            local hdr = Instance.new("TextLabel")
            hdr.Text = cat.label
            hdr.Size = UDim2.new(1,0,0,18)
            hdr.BackgroundColor3 = cat.color
            hdr.TextColor3 = Color3.fromRGB(255,255,255)
            hdr.Font = Enum.Font.GothamBold
            hdr.TextSize = 10
            hdr.LayoutOrder = order; order += 1
            local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0,3); hc.Parent = hdr
            hdr.Parent = sidebar

            for _, def in ipairs(matchingBlocks) do
                local btn = Instance.new("TextButton")
                btn.Text = def.label:gsub("%[.-%]",""):gsub("%s+"," "):match("^%s*(.-)%s*$")
                btn.Size = UDim2.new(1,0,0,28)
                btn.BackgroundColor3 = def.color
                btn.TextColor3 = Color3.fromRGB(255,255,255)
                btn.Font = Enum.Font.GothamSemibold
                btn.TextSize = 10
                btn.TextTruncate = Enum.TextTruncate.AtEnd
                btn.AutoButtonColor = false
                btn.LayoutOrder = order; order += 1
                local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,5); bc.Parent = btn

                -- Hat notch visual
                if def.shape == "hat" then
                    local hn = Instance.new("Frame")
                    hn.Size = UDim2.new(0,40,0,7)
                    hn.Position = UDim2.new(0,6,0,-4)
                    hn.BackgroundColor3 = def.color
                    hn.BorderSizePixel = 0
                    hn.ZIndex = 2
                    local hnc = Instance.new("UICorner"); hnc.CornerRadius = UDim.new(0,5); hnc.Parent = hn
                    hn.Parent = btn
                end

                btn.MouseEnter:Connect(function()
                    btn.BackgroundColor3 = Color3.new(
                        math.min(def.color.R*1.15,1),
                        math.min(def.color.G*1.15,1),
                        math.min(def.color.B*1.15,1)
                    )
                end)
                btn.MouseLeave:Connect(function() btn.BackgroundColor3 = def.color end)

                btn.MouseButton1Click:Connect(function()
                    placeBlock(def)
                end)

                -- Custom block: right-click → edit dialog
                if def._isCustom then
                    -- Edit icon
                    local editDot = Instance.new("TextLabel")
                    editDot.Text = "✏"
                    editDot.Size = UDim2.new(0,16,0,16)
                    editDot.Position = UDim2.new(1,-18,0.5,-8)
                    editDot.BackgroundTransparency = 1
                    editDot.TextColor3 = Color3.fromRGB(255,255,255)
                    editDot.TextTransparency = 0.4
                    editDot.Font = Enum.Font.Gotham
                    editDot.TextSize = 11
                    editDot.ZIndex = 3
                    editDot.Parent = btn

                    btn.MouseButton2Click:Connect(function()
                        -- Tìm raw custom block data theo id
                        local rawCb
                        for _, cb in ipairs(customBlockList) do
                            if "custom_" .. cb.id == def.id then
                                rawCb = cb; break
                            end
                        end
                        if not rawCb then return end
                        local dialog = CustomBlocks.createDialog(rawCb,
                            -- onSave (update)
                            function(updated)
                                for i, cb in ipairs(customBlockList) do
                                    if cb.id == updated.id then
                                        customBlockList[i] = updated; break
                                    end
                                end
                                CustomBlocks.save(plugin, customBlockList)
                                CustomBlocks.inject(BlockDefs, customBlockList)
                                populateSidebar(searchBox.Text)
                            end,
                            -- onDelete
                            function(cbId)
                                for i, cb in ipairs(customBlockList) do
                                    if cb.id == cbId then
                                        table.remove(customBlockList, i); break
                                    end
                                end
                                CustomBlocks.save(plugin, customBlockList)
                                CustomBlocks.inject(BlockDefs, customBlockList)
                                populateSidebar(searchBox.Text)
                            end,
                            nil
                        )
                        dialog.Parent = root
                    end)
                end

                btn.Parent = sidebar
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- BLOCK HELPERS
-- ═══════════════════════════════════════════════════════════════

local function findById(id)
    for _, bd in ipairs(State.placedBlocks) do
        if bd.id == id then return bd end
    end
end

local function findRoots()
    local roots = {}
    for _, bd in ipairs(State.placedBlocks) do
        if not bd.prev then table.insert(roots, bd) end
    end
    return roots
end

-- Sync TextBox values → bd.inputs
local function syncInputs(bd)
    if not bd.frame then return end
    local inputsF = bd.frame:FindFirstChild("Inputs")
    if not inputsF then return end
    for _, row in ipairs(inputsF:GetChildren()) do
        if row:IsA("Frame") then
            for _, child in ipairs(row:GetChildren()) do
                if child:IsA("TextBox") then
                    local name = child.Name:gsub("^Input_","")
                    bd.inputs[name] = child.Text
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- CODE GENERATION + SYNTAX VALIDATION
-- ═══════════════════════════════════════════════════════════════

local lastCode = ""

local function updateCode()
    local roots = findRoots()
    if #roots == 0 then
        codeLbl.Text = '<font color="#555">-- Chưa có block nào</font>'
        lastCode = ""
        currentLineMap = {}
        validBadge.BackgroundColor3 = Color3.fromRGB(120,120,120)
        validLbl.Text = "Trống"
        validLbl.TextColor3 = Color3.fromRGB(150,150,150)
        return
    end
    for _, bd in ipairs(State.placedBlocks) do syncInputs(bd) end
    local code = CodeGen.generate(roots, State.placedBlocks)
    lastCode = code

    -- Build line map cho error tracking
    local _, lmap = ErrorTracker.annotate(code, State.placedBlocks)
    currentLineMap = lmap

    -- Clear old error highlights khi code thay đổi
    ErrorTracker.clearAll(State.placedBlocks)

    codeLbl.Text = CodeGen.highlight(code)

    -- Syntax validation
    local ok, err = pcall(function()
        local fn, syntaxErr = loadstring(code)
        if fn == nil then error(syntaxErr or "syntax error") end
    end)
    if ok then
        validBadge.BackgroundColor3 = Color3.fromRGB(80,200,80)
        validLbl.Text = "✓ Syntax OK"
        validLbl.TextColor3 = Color3.fromRGB(100,200,120)
    else
        validBadge.BackgroundColor3 = Color3.fromRGB(220,60,60)
        local msg = tostring(err):gsub("^%[.-%]:", "line "):sub(1, 40)
        validLbl.Text = "✗ " .. msg
        validLbl.TextColor3 = Color3.fromRGB(255,120,100)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO-SAVE (debounced)
-- ═══════════════════════════════════════════════════════════════

local function scheduleSave()
    if State.saveTimer then
        task.cancel(State.saveTimer)
    end
    State.saveTimer = task.delay(SAVE_DEBOUNCE, function()
        Persistence.save(plugin, State.placedBlocks, State.blockCounter)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- MINIMAP UPDATE
-- ═══════════════════════════════════════════════════════════════

local CANVAS_W, CANVAS_H = 2000, 2000
local MM_W, MM_H = 110, 80

local function updateMinimap()
    -- Xóa dots cũ
    for _, d in ipairs(minimapDots) do d:Destroy() end
    minimapDots = {}

    for _, bd in ipairs(State.placedBlocks) do
        if bd.frame then
            local px = bd.frame.Position.X.Offset
            local py = bd.frame.Position.Y.Offset
            local mx = (px / CANVAS_W) * MM_W
            local my = (py / CANVAS_H) * MM_H
            local def = BlockDefs.byId[bd.defId]
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0,8,0,5)
            dot.Position = UDim2.new(0, math.clamp(mx,0,MM_W-8), 0, math.clamp(my,0,MM_H-5))
            dot.BackgroundColor3 = def and def.color or Color3.fromRGB(150,150,150)
            dot.BorderSizePixel = 0
            dot.ZIndex = 31
            local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0,2); dc.Parent = dot
            dot.Parent = minimap
            table.insert(minimapDots, dot)
        end
    end

    -- Viewport rect
    local vx = (canvas.CanvasPosition.X / CANVAS_W) * MM_W
    local vy = (canvas.CanvasPosition.Y / CANVAS_H) * MM_H
    local vw = (canvasArea.AbsoluteSize.X / CANVAS_W) * MM_W
    local vh = (canvasArea.AbsoluteSize.Y / CANVAS_H) * MM_H
    mmViewport.Size = UDim2.new(0, math.max(vw,10), 0, math.max(vh,8))
    mmViewport.Position = UDim2.new(0, math.clamp(vx,0,MM_W-10), 0, math.clamp(vy,0,MM_H-8))
end

canvas:GetPropertyChangedSignal("CanvasPosition"):Connect(updateMinimap)

-- ═══════════════════════════════════════════════════════════════
-- REBUILD CANVAS từ snapshot data (dùng cho load/undo/redo/import)
-- ═══════════════════════════════════════════════════════════════

local function rebuildFromData(data)
    -- Xóa frames hiện tại
    for _, bd in ipairs(State.placedBlocks) do
        if bd.frame and bd.frame.Parent then bd.frame:Destroy() end
    end
    State.placedBlocks = {}

    if not data or not data.blocks or #data.blocks == 0 then
        canvasHint.Visible = true
        updateCode()
        updateMinimap()
        return
    end

    canvasHint.Visible = false
    State.blockCounter = data.blockCounter or 0

    -- Pass 1: tạo frames
    local tempMap = {}   -- id → blockData
    for _, entry in ipairs(data.blocks) do
        local def = BlockDefs.byId[entry.defId]
        if def then
            local frame = UIBuilder.createBlockFrame(def, entry.id, canvas)
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
            -- Restore TextBox values
            local inputsF = frame:FindFirstChild("Inputs")
            if inputsF then
                for _, row in ipairs(inputsF:GetChildren()) do
                    if row:IsA("Frame") then
                        for _, child in ipairs(row:GetChildren()) do
                            if child:IsA("TextBox") then
                                local n = child.Name:gsub("^Input_","")
                                if bd.inputs[n] then child.Text = bd.inputs[n] end
                                child:GetPropertyChangedSignal("Text"):Connect(function()
                                    bd.inputs[n] = child.Text
                                    updateCode()
                                    scheduleSave()
                                end)
                            end
                        end
                    end
                end
            end

            -- Delete handler
            frame:GetAttributeChangedSignal("DeleteRequested"):Connect(function()
                if frame:GetAttribute("DeleteRequested") then
                    frame:SetAttribute("DeleteRequested", false)
                    UndoMgr.push(UndoMgr.snapshot(State.placedBlocks))
                    -- Unlink
                    if bd.prev then bd.prev.next = nil end
                    if bd.next then bd.next.prev = nil end
                    -- Remove from list
                    for i, x in ipairs(State.placedBlocks) do
                        if x.id == bd.id then table.remove(State.placedBlocks, i); break end
                    end
                    frame:Destroy()
                    if #State.placedBlocks == 0 then canvasHint.Visible = true end
                    updateCode(); updateMinimap(); scheduleSave()
                end
            end)

            -- Drag ended → snap + update
            frame:GetAttributeChangedSignal("DragEnded"):Connect(function()
                if frame:GetAttribute("DragEnded") then
                    frame:SetAttribute("DragEnded", false)
                    trySnap(bd)
                    updateCode(); updateMinimap(); scheduleSave()
                end
            end)

            table.insert(State.placedBlocks, bd)
            tempMap[entry.id] = bd
        end
    end

    -- Pass 2: reconnect next/prev
    for _, entry in ipairs(data.blocks) do
        local bd = tempMap[entry.id]
        if bd then
            if entry.nextId then bd.next = tempMap[entry.nextId] end
            if entry.prevId then bd.prev = tempMap[entry.prevId] end
        end
    end

    updateCode()
    updateMinimap()
end

-- ═══════════════════════════════════════════════════════════════
-- PLACE NEW BLOCK (kéo từ sidebar)
-- ═══════════════════════════════════════════════════════════════

function placeBlock(def)
    canvasHint.Visible = false
    UndoMgr.push(UndoMgr.snapshot(State.placedBlocks))

    local id = newId()
    local frame = UIBuilder.createBlockFrame(def, id, canvas)
    -- Xếp tự động tránh chồng
    local offsetX = 40 + (#State.placedBlocks % 5) * 20
    local offsetY = 40 + #State.placedBlocks * 46
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

    -- TextBox change → update code
    local inputsF = frame:FindFirstChild("Inputs")
    if inputsF then
        for _, row in ipairs(inputsF:GetChildren()) do
            if row:IsA("Frame") then
                for _, child in ipairs(row:GetChildren()) do
                    if child:IsA("TextBox") then
                        local n = child.Name:gsub("^Input_","")
                        child:GetPropertyChangedSignal("Text"):Connect(function()
                            bd.inputs[n] = child.Text
                            updateCode(); scheduleSave()
                        end)
                    end
                end
            end
        end
    end

    -- Delete
    frame:GetAttributeChangedSignal("DeleteRequested"):Connect(function()
        if frame:GetAttribute("DeleteRequested") then
            frame:SetAttribute("DeleteRequested", false)
            UndoMgr.push(UndoMgr.snapshot(State.placedBlocks))
            if bd.prev then bd.prev.next = nil end
            if bd.next then bd.next.prev = nil end
            for i, x in ipairs(State.placedBlocks) do
                if x.id == bd.id then table.remove(State.placedBlocks, i); break end
            end
            frame:Destroy()
            if #State.placedBlocks == 0 then canvasHint.Visible = true end
            updateCode(); updateMinimap(); scheduleSave()
        end
    end)

    -- Drag ended
    frame:GetAttributeChangedSignal("DragEnded"):Connect(function()
        if frame:GetAttribute("DragEnded") then
            frame:SetAttribute("DragEnded", false)
            trySnap(bd)
            updateCode(); updateMinimap(); scheduleSave()
        end
    end)

    table.insert(State.placedBlocks, bd)
    updateCode(); updateMinimap(); scheduleSave()
end

-- ═══════════════════════════════════════════════════════════════
-- SNAP LOGIC + CONTAINER DROP ZONE
-- ═══════════════════════════════════════════════════════════════

local SNAP_DIST = 28

function trySnap(movedBd)
    local mf   = movedBd.frame
    local mPos = mf.AbsolutePosition
    local mSz  = mf.AbsoluteSize
    local best, bestDist, bestSide = nil, SNAP_DIST * 2, nil

    for _, other in ipairs(State.placedBlocks) do
        if other.id == movedBd.id then continue end
        local of  = other.frame
        local oAP = of.AbsolutePosition
        local oSz = of.AbsoluteSize
        local dx  = math.abs(oAP.X - mPos.X)

        -- Snap below other
        local dBelow = math.abs((oAP.Y + oSz.Y) - mPos.Y) + dx * 0.4
        if dBelow < bestDist and dx < 50 then
            bestDist, best, bestSide = dBelow, other, "below"
        end
        -- Snap above other
        local dAbove = math.abs(mPos.Y + mSz.Y - oAP.Y) + dx * 0.4
        if dAbove < bestDist and dx < 50 then
            bestDist, best, bestSide = dAbove, other, "above"
        end
    end

    if best then
        local tf  = best.frame
        local tP  = tf.Position
        local tSz = tf.AbsoluteSize
        if bestSide == "below" then
            mf.Position = UDim2.new(tP.X.Scale, tP.X.Offset, tP.Y.Scale, tP.Y.Offset + tSz.Y + 2)
            -- Unlink old chain
            if movedBd.prev then movedBd.prev.next = nil end
            if best.next    then best.next.prev = nil end
            movedBd.prev = best
            best.next    = movedBd
        else
            mf.Position = UDim2.new(tP.X.Scale, tP.X.Offset, tP.Y.Scale, tP.Y.Offset - mSz.Y - 2)
            if movedBd.next then movedBd.next.prev = nil end
            if best.prev    then best.prev.next = nil end
            movedBd.next = best
            best.prev    = movedBd
        end
    end

    -- ── Container drop zone: highlight container blocks khi kéo qua ──
    dropZone.Visible = false
    if best == nil then
        -- Kiểm tra có đang hover trên container block không
        for _, other in ipairs(State.placedBlocks) do
            local def = BlockDefs.byId[other.defId]
            if def and def.isContainer then
                local of  = other.frame
                local oAP = of.AbsolutePosition
                local oSz = of.AbsoluteSize
                -- Check overlap
                if mPos.X < oAP.X + oSz.X and mPos.X + mSz.X > oAP.X
                and mPos.Y < oAP.Y + oSz.Y and mPos.Y + mSz.Y > oAP.Y then
                    -- Hiện drop zone bên trong container
                    local relX = oAP.X - canvasArea.AbsolutePosition.X + canvas.CanvasPosition.X
                    local relY = oAP.Y - canvasArea.AbsolutePosition.Y + canvas.CanvasPosition.Y
                    dropZone.Position = UDim2.new(0, relX + 8, 0, relY + oSz.Y - 16)
                    dropZone.Size     = UDim2.new(0, oSz.X - 16, 0, 14)
                    dropZone.Visible  = true
                    movedBd.parentId  = other.id
                    break
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- COPY / PASTE
-- ═══════════════════════════════════════════════════════════════

local function copySelected()
    if not State.selected then return end
    -- Serialize chain từ selected
    local chain = {}
    local cur = State.selected
    while cur do
        syncInputs(cur)
        table.insert(chain, {
            defId    = cur.defId,
            inputs   = table.clone(cur.inputs),
            parentId = cur.parentId,
        })
        cur = cur.next
    end
    State.clipboard = chain
    -- Visual feedback
    if State.selected.frame then
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(255,220,0)
        s.Thickness = 2.5
        s.Parent = State.selected.frame
        task.delay(0.5, function() if s.Parent then s:Destroy() end end)
    end
end

local function pasteClipboard()
    if not State.clipboard or #State.clipboard == 0 then return end
    UndoMgr.push(UndoMgr.snapshot(State.placedBlocks))
    canvasHint.Visible = false

    local prevBd = nil
    for i, entry in ipairs(State.clipboard) do
        local def = BlockDefs.byId[entry.defId]
        if not def then continue end

        local id    = newId()
        local frame = UIBuilder.createBlockFrame(def, id, canvas)
        local offsetX = 80 + (i-1) * 5
        local offsetY = 80 + #State.placedBlocks * 46
        frame.Position = UDim2.new(0, offsetX, 0, math.min(offsetY, 1600))

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

        -- Restore TextBox values
        local inputsF = frame:FindFirstChild("Inputs")
        if inputsF then
            for _, row in ipairs(inputsF:GetChildren()) do
                if row:IsA("Frame") then
                    for _, child in ipairs(row:GetChildren()) do
                        if child:IsA("TextBox") then
                            local n = child.Name:gsub("^Input_","")
                            if bd.inputs[n] then child.Text = bd.inputs[n] end
                            child:GetPropertyChangedSignal("Text"):Connect(function()
                                bd.inputs[n] = child.Text
                                updateCode(); scheduleSave()
                            end)
                        end
                    end
                end
            end
        end

        -- Chain paste
        if prevBd then
            prevBd.next = bd
            bd.prev = prevBd
            local pf  = prevBd.frame
            local pSz = pf.AbsoluteSize
            frame.Position = UDim2.new(
                pf.Position.X.Scale, pf.Position.X.Offset,
                pf.Position.Y.Scale, pf.Position.Y.Offset + pSz.Y + 2
            )
        end

        frame:GetAttributeChangedSignal("DeleteRequested"):Connect(function()
            if frame:GetAttribute("DeleteRequested") then
                frame:SetAttribute("DeleteRequested", false)
                UndoMgr.push(UndoMgr.snapshot(State.placedBlocks))
                if bd.prev then bd.prev.next = nil end
                if bd.next then bd.next.prev = nil end
                for i2, x in ipairs(State.placedBlocks) do
                    if x.id == bd.id then table.remove(State.placedBlocks, i2); break end
                end
                frame:Destroy()
                if #State.placedBlocks == 0 then canvasHint.Visible = true end
                updateCode(); updateMinimap(); scheduleSave()
            end
        end)
        frame:GetAttributeChangedSignal("DragEnded"):Connect(function()
            if frame:GetAttribute("DragEnded") then
                frame:SetAttribute("DragEnded", false)
                trySnap(bd)
                updateCode(); updateMinimap(); scheduleSave()
            end
        end)

        table.insert(State.placedBlocks, bd)
        prevBd = bd
    end

    updateCode(); updateMinimap(); scheduleSave()
end

-- ═══════════════════════════════════════════════════════════════
-- KEYBOARD SHORTCUTS (Ctrl+Z, Ctrl+Y, Ctrl+C, Ctrl+V)
-- ═══════════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
              or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

    if ctrl and input.KeyCode == Enum.KeyCode.Z then
        -- Undo
        local snap = UndoMgr.undo(UndoMgr.snapshot(State.placedBlocks))
        if snap then
            rebuildFromData({ blockCounter = State.blockCounter, blocks = snap })
        end
    elseif ctrl and input.KeyCode == Enum.KeyCode.Y then
        -- Redo
        local snap = UndoMgr.redo(UndoMgr.snapshot(State.placedBlocks))
        if snap then
            rebuildFromData({ blockCounter = State.blockCounter, blocks = snap })
        end
    elseif ctrl and input.KeyCode == Enum.KeyCode.C then
        copySelected()
    elseif ctrl and input.KeyCode == Enum.KeyCode.V then
        pasteClipboard()
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- SEARCH FILTER
-- ═══════════════════════════════════════════════════════════════

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    populateSidebar(searchBox.Text)
end)

-- ═══════════════════════════════════════════════════════════════
-- BUTTON HANDLERS
-- ═══════════════════════════════════════════════════════════════

-- Insert into Script
insertBtn.MouseButton1Click:Connect(function()
    if lastCode == "" then return end
    local sel = Selection:Get()
    local target
    for _, obj in ipairs(sel) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            target = obj; break
        end
    end
    if not target then
        ChangeHistoryService:SetWaypoint("ScratchLua: Create Script")
        target = Instance.new("Script")
        target.Name = "ScratchLuaOutput"
        target.Parent = game:GetService("ServerScriptService")
    end
    ChangeHistoryService:SetWaypoint("ScratchLua: Insert Code")
    target.Source = "-- Generated by ScratchLua v" .. PLUGIN_VERSION
        .. "\n-- " .. os.date("%Y-%m-%d %H:%M") .. "\n\n" .. lastCode
    insertBtn.Text = "✓ Inserted!"
    insertBtn.BackgroundColor3 = Color3.fromRGB(46,185,95)
    task.delay(2, function()
        insertBtn.Text = "▶ Insert"
        insertBtn.BackgroundColor3 = Color3.fromRGB(67,133,245)
    end)
end)

-- Export
exportBtn.MouseButton1Click:Connect(function()
    local json = ExportImp.toJSON(State.placedBlocks, State.blockCounter)
    if json then
        local dialog = ExportImp.createExportDialog(json)
        dialog.Parent = root
    end
end)

-- Import
importBtn.MouseButton1Click:Connect(function()
    local dialog = ExportImp.createImportDialog(function(data)
        UndoMgr.push(UndoMgr.snapshot(State.placedBlocks))
        rebuildFromData(data)
        scheduleSave()
    end)
    dialog.Parent = root
end)

-- Undo button
undoBtn.MouseButton1Click:Connect(function()
    local snap = UndoMgr.undo(UndoMgr.snapshot(State.placedBlocks))
    if snap then
        rebuildFromData({ blockCounter = State.blockCounter, blocks = snap })
    end
end)

-- Redo button
redoBtn.MouseButton1Click:Connect(function()
    local snap = UndoMgr.redo(UndoMgr.snapshot(State.placedBlocks))
    if snap then
        rebuildFromData({ blockCounter = State.blockCounter, blocks = snap })
    end
end)

-- Clear
clearBtn.MouseButton1Click:Connect(function()
    UndoMgr.push(UndoMgr.snapshot(State.placedBlocks))
    for _, bd in ipairs(State.placedBlocks) do
        if bd.frame and bd.frame.Parent then bd.frame:Destroy() end
    end
    State.placedBlocks = {}
    canvasHint.Visible = true
    dropZone.Visible   = false
    updateCode(); updateMinimap()
    Persistence.clear(plugin)
end)

-- ── New Custom Block ──────────────────────────────────────────
newBlockBtn.MouseButton1Click:Connect(function()
    local dialog = CustomBlocks.createDialog(nil,
        -- onSave
        function(cb)
            table.insert(customBlockList, cb)
            CustomBlocks.save(plugin, customBlockList)
            CustomBlocks.inject(BlockDefs, customBlockList)
            populateSidebar(searchBox.Text)
        end,
        nil, nil
    )
    dialog.Parent = root
end)

-- ── Right-click custom block trong sidebar để edit ────────────
-- (handler được gắn động trong populateSidebar khi def._isCustom)

-- ── Runtime Error Tracking hook ──────────────────────────────
-- Tự động hook vào ScriptContext khi Play mode bắt đầu
local RunService = game:GetService("RunService")

RunService:GetPropertyChangedSignal("IsRunMode"):Connect(function()
    -- Disconnect hook cũ
    if errorTrackConn then
        errorTrackConn:Disconnect()
        errorTrackConn = nil
    end
    ErrorTracker.clearAll(State.placedBlocks)

    if RunService.IsRunMode then
        -- Game đang chạy → hook ScriptContext
        errorTrackConn = ErrorTracker.hookScriptContext(
            State.placedBlocks,
            currentLineMap,
            function(blockId, msg)
                -- Hiện toast thông báo trên code panel
                local shortMsg = msg:gsub("^.+:%d+: ", ""):sub(1, 60)
                validBadge.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
                validLbl.Text = "⚡ Runtime: " .. shortMsg
                validLbl.TextColor3 = Color3.fromRGB(255, 180, 80)
            end
        )
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- UNDO/REDO BUTTON STATE (dim khi không có gì)
-- ═══════════════════════════════════════════════════════════════

local function refreshUndoButtons()
    undoBtn.BackgroundTransparency = UndoMgr.canUndo() and 0 or 0.5
    redoBtn.BackgroundTransparency = UndoMgr.canRedo() and 0 or 0.5
end

-- ═══════════════════════════════════════════════════════════════
-- TOGGLE & THEME
-- ═══════════════════════════════════════════════════════════════

toggleButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
    toggleButton:SetActive(widget.Enabled)
end)
widget:BindToClose(function()
    widget.Enabled = false
    toggleButton:SetActive(false)
end)

StudioService.ThemeChanged:Connect(function()
    root.BackgroundColor3       = tc(Enum.StudioStyleGuideColor.MainBackground)
    topBar.BackgroundColor3     = tc(Enum.StudioStyleGuideColor.Titlebar)
    titleLbl.TextColor3         = tc(Enum.StudioStyleGuideColor.TitlebarText)
    canvasArea.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.ScriptBackground)
    codePanel.BackgroundColor3  = tc(Enum.StudioStyleGuideColor.ScriptBackground)
    codeLbl.TextColor3          = tc(Enum.StudioStyleGuideColor.ScriptText)
    sidebarFrame.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.CategoryItem)
    searchBox.BackgroundColor3  = tc(Enum.StudioStyleGuideColor.InputFieldBackground)
    searchBox.TextColor3        = tc(Enum.StudioStyleGuideColor.MainText)
end)

-- ═══════════════════════════════════════════════════════════════
-- STARTUP: populate sidebar + load saved layout
-- ═══════════════════════════════════════════════════════════════

populateSidebar()

local savedData = Persistence.load(plugin)
if savedData and savedData.blocks and #savedData.blocks > 0 then
    print("[ScratchLua] Đang restore " .. #savedData.blocks .. " blocks từ lần trước...")
    rebuildFromData(savedData)
else
    canvasHint.Visible = true
end

print("[ScratchLua] Plugin v" .. PLUGIN_VERSION .. " loaded ✓")
