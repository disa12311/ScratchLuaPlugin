--[[
    ScratchLua Plugin v3.0 — init.server.lua
    Bootstrap: tạo toolbar, widget, UI skeleton, rồi wires các modules lại.

    Cấu trúc module:
        blocks/BlockDefinitions     — định nghĩa 60+ block types
        codegen/CodeGenerator       — block chain → Luau code + highlight
        ui/UIBuilder                — render Frame cho mỗi block
        ui/SidebarManager           — sidebar populate + search
        core/StateManager           — state, placeBlock, rebuild, copy/paste
        core/CanvasManager          — snap, minimap, drop zone
        utils/PersistenceManager    — auto-save qua plugin:SetSetting
        utils/UndoManager           — undo/redo stack
        utils/ExportImport          — JSON export/import dialogs
        utils/CustomBlockManager    — tạo/edit/xóa custom blocks
        utils/RuntimeErrorTracker   — highlight block bị lỗi runtime
--]]

-- ── Services ─────────────────────────────────────────────────
local Selection            = game:GetService("Selection")
local StudioService        = game:GetService("StudioService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local UserInputService     = game:GetService("UserInputService")
local RunService           = game:GetService("RunService")

local PLUGIN_VERSION = "3.0.0"
local SAVE_DEBOUNCE  = 2  -- giây debounce auto-save

-- ── Modules ──────────────────────────────────────────────────
local BlockDefs      = require(script.Parent.blocks.BlockDefinitions)
local CodeGen        = require(script.Parent.codegen.CodeGenerator)
local UIBuilder      = require(script.Parent.ui.UIBuilder)
local SidebarMgr     = require(script.Parent.ui.SidebarManager)
local StateMgr       = require(script.Parent.core.StateManager)
local CanvasMgr      = require(script.Parent.core.CanvasManager)
local Persistence    = require(script.Parent.utils.PersistenceManager)
local UndoMgr        = require(script.Parent.utils.UndoManager)
local ExportImp      = require(script.Parent.utils.ExportImport)
local CustomBlocks   = require(script.Parent.utils.CustomBlockManager)
local ErrorTracker   = require(script.Parent.utils.RuntimeErrorTracker)

-- ── Custom blocks: load + inject vào BlockDefs ────────────────
local customBlockList = CustomBlocks.load(plugin)
CustomBlocks.inject(BlockDefs, customBlockList)

-- ── Runtime error state ───────────────────────────────────────
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
widget.Title = "ScratchLua v3 — Visual Code Editor"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ═══════════════════════════════════════════════════════════════
-- UI SKELETON  (xây dựng layout, không có logic)
-- ═══════════════════════════════════════════════════════════════

local function tc(item, mod) return StudioService.Theme:GetColor(item, mod) end

local root = Instance.new("Frame")
root.Size = UDim2.new(1,0,1,0)
root.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.MainBackground)
root.BorderSizePixel  = 0
root.Parent = widget

-- ── Top bar ───────────────────────────────────────────────────
local topBar = Instance.new("Frame")
topBar.Size  = UDim2.new(1,0,0,40)
topBar.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.Titlebar)
topBar.BorderSizePixel  = 0
topBar.ZIndex = 20
topBar.Parent = root

local function makeBtn(text, w, xRight, color)
    local b = Instance.new("TextButton")
    b.Text = text; b.Size = UDim2.new(0,w,0,26)
    b.Position = UDim2.new(1,xRight,0.5,-13)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamSemibold; b.TextSize = 11
    b.AutoButtonColor = true; b.ZIndex = 21
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = b
    b.Parent = topBar; return b
end

local titleLbl = Instance.new("TextLabel")
titleLbl.Text  = "🧱 ScratchLua v3"
titleLbl.Size  = UDim2.new(0,160,1,0); titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = tc(Enum.StudioStyleGuideColor.TitlebarText)
titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.ZIndex = 21
titleLbl.Parent = topBar

local insertBtn   = makeBtn("▶ Insert",    90,  -10, Color3.fromRGB(67,133,245))
local exportBtn   = makeBtn("📤 Export",   74, -108, Color3.fromRGB(100,100,110))
local importBtn   = makeBtn("📥 Import",   74, -190, Color3.fromRGB(100,100,110))
local undoBtn     = makeBtn("↩ Undo",      60, -272, Color3.fromRGB(80,80,90))
local redoBtn     = makeBtn("↪ Redo",      60, -340, Color3.fromRGB(80,80,90))
local clearBtn    = makeBtn("✕ Clear",     64, -408, Color3.fromRGB(200,60,60))
local newBlockBtn = makeBtn("⭐ New Block", 88, -480, Color3.fromRGB(150,80,210))

-- Syntax badge
local validBadge = Instance.new("Frame")
validBadge.Size  = UDim2.new(0,10,0,10); validBadge.Position = UDim2.new(0,172,0.5,-5)
validBadge.BackgroundColor3 = Color3.fromRGB(120,120,120); validBadge.ZIndex = 22
local _vc = Instance.new("UICorner"); _vc.CornerRadius = UDim.new(0.5,0); _vc.Parent = validBadge
validBadge.Parent = topBar

local validLbl = Instance.new("TextLabel")
validLbl.Size  = UDim2.new(0,150,1,0); validLbl.Position = UDim2.new(0,186,0,0)
validLbl.BackgroundTransparency = 1; validLbl.TextColor3 = Color3.fromRGB(150,150,150)
validLbl.Font  = Enum.Font.Gotham; validLbl.TextSize = 10
validLbl.TextXAlignment = Enum.TextXAlignment.Left; validLbl.Text = "Trống"; validLbl.ZIndex = 21
validLbl.Parent = topBar

-- ── Main layout ───────────────────────────────────────────────
local main = Instance.new("Frame")
main.Size  = UDim2.new(1,0,1,-40); main.Position = UDim2.new(0,0,0,40)
main.BackgroundTransparency = 1; main.Parent = root

-- Sidebar frame
local sidebarFrame = Instance.new("Frame")
sidebarFrame.Size  = UDim2.new(0,190,1,0)
sidebarFrame.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.CategoryItem)
sidebarFrame.BorderSizePixel  = 0; sidebarFrame.Parent = main

local searchBox = Instance.new("TextBox")
searchBox.Size  = UDim2.new(1,-8,0,26); searchBox.Position = UDim2.new(0,4,0,4)
searchBox.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.InputFieldBackground)
searchBox.TextColor3 = tc(Enum.StudioStyleGuideColor.MainText)
searchBox.PlaceholderText = "🔍 Search blocks..."
searchBox.PlaceholderColor3 = tc(Enum.StudioStyleGuideColor.DimmedText)
searchBox.Font = Enum.Font.Gotham; searchBox.TextSize = 11
searchBox.ClearTextOnFocus = false; searchBox.ZIndex = 5
local _sc = Instance.new("UICorner"); _sc.CornerRadius = UDim.new(0,4); _sc.Parent = searchBox
searchBox.Parent = sidebarFrame

local sidebar = Instance.new("ScrollingFrame")
sidebar.Size  = UDim2.new(1,0,1,-34); sidebar.Position = UDim2.new(0,0,0,34)
sidebar.BackgroundTransparency = 1; sidebar.ScrollBarThickness = 5
sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebar.CanvasSize = UDim2.new(0,0,0,0); sidebar.Parent = sidebarFrame
local _sbp = Instance.new("UIPadding")
_sbp.PaddingLeft = UDim.new(0,6); _sbp.PaddingRight = UDim.new(0,6); _sbp.PaddingTop = UDim.new(0,4)
_sbp.Parent = sidebar
local _sbl = Instance.new("UIListLayout")
_sbl.Padding = UDim.new(0,3); _sbl.SortOrder = Enum.SortOrder.LayoutOrder; _sbl.Parent = sidebar

-- Canvas area
local canvasArea = Instance.new("Frame")
canvasArea.Name  = "CanvasArea"
canvasArea.Size  = UDim2.new(1,-380,1,0); canvasArea.Position = UDim2.new(0,190,0,0)
canvasArea.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.ScriptBackground)
canvasArea.ClipsDescendants = true; canvasArea.Parent = main

local canvasHint = Instance.new("TextLabel")
canvasHint.Text  = "← Kéo blocks từ sidebar\nBlocks tự snap vào nhau\nCtrl+Z Undo  •  Ctrl+C/V Copy/Paste"
canvasHint.Size  = UDim2.new(0,320,0,60); canvasHint.Position = UDim2.new(0.5,-160,0.5,-30)
canvasHint.BackgroundTransparency = 1; canvasHint.TextColor3 = tc(Enum.StudioStyleGuideColor.DimmedText)
canvasHint.TextXAlignment = Enum.TextXAlignment.Center; canvasHint.Font = Enum.Font.Gotham
canvasHint.TextSize = 12; canvasHint.TextWrapped = true; canvasHint.Parent = canvasArea

local dropZone = Instance.new("Frame")
dropZone.Name  = "DropZone"; dropZone.Visible = false; dropZone.ZIndex = 3
dropZone.BackgroundColor3 = Color3.fromRGB(100,200,255); dropZone.BackgroundTransparency = 0.7
dropZone.BorderSizePixel  = 0
local _dzc = Instance.new("UICorner"); _dzc.CornerRadius = UDim.new(0,6); _dzc.Parent = dropZone
local _dzs = Instance.new("UIStroke"); _dzs.Color = Color3.fromRGB(100,200,255); _dzs.Thickness = 2; _dzs.Parent = dropZone
dropZone.Parent = canvasArea

local canvas = Instance.new("ScrollingFrame")
canvas.Name  = "Canvas"; canvas.Size = UDim2.new(1,0,1,0)
canvas.BackgroundTransparency = 1; canvas.CanvasSize = UDim2.new(0,2000,0,2000)
canvas.ScrollBarThickness = 8; canvas.ScrollingDirection = Enum.ScrollingDirection.XY
canvas.ZIndex = 4; canvas.Parent = canvasArea

-- Minimap
local minimap = Instance.new("Frame")
minimap.Name  = "Minimap"; minimap.Size = UDim2.new(0,110,0,80)
minimap.Position = UDim2.new(1,-118,1,-88)
minimap.BackgroundColor3 = Color3.fromRGB(20,20,24); minimap.BackgroundTransparency = 0.2
minimap.ZIndex = 30; minimap.ClipsDescendants = true
local _mmc = Instance.new("UICorner"); _mmc.CornerRadius = UDim.new(0,5); _mmc.Parent = minimap
local _mms = Instance.new("UIStroke"); _mms.Color = Color3.fromRGB(80,80,90); _mms.Parent = minimap
minimap.Parent = canvasArea

local mmViewport = Instance.new("Frame")
mmViewport.BackgroundColor3 = Color3.fromRGB(255,255,255); mmViewport.BackgroundTransparency = 0.85
mmViewport.BorderSizePixel  = 0; mmViewport.ZIndex = 32
local _mmvs = Instance.new("UIStroke"); _mmvs.Color = Color3.fromRGB(200,200,255); _mmvs.Thickness = 1; _mmvs.Parent = mmViewport
mmViewport.Parent = minimap

-- Code panel
local codePanel = Instance.new("Frame")
codePanel.Size  = UDim2.new(0,190,1,0); codePanel.Position = UDim2.new(1,-190,0,0)
codePanel.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.ScriptBackground)
codePanel.BorderSizePixel = 1; codePanel.BorderColor3 = tc(Enum.StudioStyleGuideColor.Border)
codePanel.Parent = main

local cpTitle = Instance.new("TextLabel")
cpTitle.Text  = "Generated Code"; cpTitle.Size = UDim2.new(1,0,0,22)
cpTitle.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.Titlebar)
cpTitle.TextColor3 = tc(Enum.StudioStyleGuideColor.TitlebarText)
cpTitle.Font = Enum.Font.GothamBold; cpTitle.TextSize = 11; cpTitle.ZIndex = 5
cpTitle.Parent = codePanel

local codeScroll = Instance.new("ScrollingFrame")
codeScroll.Size  = UDim2.new(1,0,1,-22); codeScroll.Position = UDim2.new(0,0,0,22)
codeScroll.BackgroundTransparency = 1; codeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
codeScroll.CanvasSize = UDim2.new(0,0,0,0); codeScroll.ScrollBarThickness = 4
codeScroll.Parent = codePanel

local codeLbl = Instance.new("TextLabel")
codeLbl.Name  = "CodeLabel"; codeLbl.Size = UDim2.new(1,-6,0,0); codeLbl.Position = UDim2.new(0,3,0,3)
codeLbl.AutomaticSize = Enum.AutomaticSize.Y; codeLbl.BackgroundTransparency = 1
codeLbl.TextColor3 = tc(Enum.StudioStyleGuideColor.ScriptText)
codeLbl.Font = Enum.Font.Code; codeLbl.TextSize = 10
codeLbl.TextXAlignment = Enum.TextXAlignment.Left; codeLbl.TextYAlignment = Enum.TextYAlignment.Top
codeLbl.TextWrapped = true; codeLbl.RichText = true
codeLbl.Text = '<font color="#555">-- code sẽ xuất hiện ở đây</font>'
codeLbl.Parent = codeScroll

-- ═══════════════════════════════════════════════════════════════
-- WIRE MODULES
-- ═══════════════════════════════════════════════════════════════

-- ── CanvasManager refs ────────────────────────────────────────
CanvasMgr.canvas     = canvas
CanvasMgr.canvasArea = canvasArea
CanvasMgr.minimap    = minimap
CanvasMgr.mmViewport = mmViewport
CanvasMgr.dropZone   = dropZone

-- ── StateManager refs ─────────────────────────────────────────
StateMgr.canvas     = canvas
StateMgr.canvasHint = canvasHint

-- ── SidebarManager refs ───────────────────────────────────────
SidebarMgr.sidebar         = sidebar
SidebarMgr.BlockDefs       = BlockDefs
SidebarMgr.CustomBlocks    = CustomBlocks
SidebarMgr.customBlockList = customBlockList
SidebarMgr.root            = root
SidebarMgr.searchBox       = searchBox
SidebarMgr._plugin         = plugin
SidebarMgr.onBlockClick    = function(def)
    StateMgr.placeBlock(def, function(bd)
        CanvasMgr.trySnap(bd, StateMgr.state.placedBlocks)
    end)
end

-- ── Auto-save debounce ────────────────────────────────────────
local saveTimer = nil
local function scheduleSave()
    if saveTimer then task.cancel(saveTimer) end
    saveTimer = task.delay(SAVE_DEBOUNCE, function()
        Persistence.save(plugin, StateMgr.state.placedBlocks, StateMgr.state.blockCounter)
    end)
end

-- ── updateCode (code gen + syntax check + error tracking) ─────
local lastCode = ""
local function updateCode()
    local roots = StateMgr.findRoots()
    if #roots == 0 then
        codeLbl.Text = '<font color="#555">-- Chưa có block nào</font>'
        lastCode = ""; currentLineMap = {}
        validBadge.BackgroundColor3 = Color3.fromRGB(120,120,120)
        validLbl.Text = "Trống"; validLbl.TextColor3 = Color3.fromRGB(150,150,150)
        return
    end
    for _, bd in ipairs(StateMgr.state.placedBlocks) do StateMgr.syncInputs(bd) end
    local code = CodeGen.generate(roots, StateMgr.state.placedBlocks)
    lastCode = code
    local _, lmap = ErrorTracker.annotate(code, StateMgr.state.placedBlocks)
    currentLineMap = lmap
    ErrorTracker.clearAll(StateMgr.state.placedBlocks)
    codeLbl.Text = CodeGen.highlight(code)

    local ok, err = pcall(function()
        local fn, se = loadstring(code)
        if fn == nil then error(se or "syntax error") end
    end)
    if ok then
        validBadge.BackgroundColor3 = Color3.fromRGB(80,200,80)
        validLbl.Text = "✓ Syntax OK"; validLbl.TextColor3 = Color3.fromRGB(100,200,120)
    else
        validBadge.BackgroundColor3 = Color3.fromRGB(220,60,60)
        validLbl.Text = "✗ " .. tostring(err):gsub("^%[.-%]:", "line "):sub(1,40)
        validLbl.TextColor3 = Color3.fromRGB(255,120,100)
    end
end

-- ── onChanged callback (cập nhật code + minimap + save) ───────
local function onChanged()
    updateCode()
    CanvasMgr.updateMinimap(StateMgr.state.placedBlocks)
    scheduleSave()
end
StateMgr.onChanged = onChanged

canvas:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    CanvasMgr.updateMinimap(StateMgr.state.placedBlocks)
end)

-- ═══════════════════════════════════════════════════════════════
-- BUTTON HANDLERS
-- ═══════════════════════════════════════════════════════════════

-- ▶ Insert
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
    insertBtn.Text = "✓ Inserted!"; insertBtn.BackgroundColor3 = Color3.fromRGB(46,185,95)
    task.delay(2, function()
        insertBtn.Text = "▶ Insert"; insertBtn.BackgroundColor3 = Color3.fromRGB(67,133,245)
    end)
end)

-- 📤 Export
exportBtn.MouseButton1Click:Connect(function()
    local json = ExportImp.toJSON(StateMgr.state.placedBlocks, StateMgr.state.blockCounter)
    if json then ExportImp.createExportDialog(json).Parent = root end
end)

-- 📥 Import
importBtn.MouseButton1Click:Connect(function()
    ExportImp.createImportDialog(function(data)
        UndoMgr.push(UndoMgr.snapshot(StateMgr.state.placedBlocks))
        StateMgr.rebuildFromData(data, function(bd)
            CanvasMgr.trySnap(bd, StateMgr.state.placedBlocks)
        end)
        scheduleSave()
    end).Parent = root
end)

-- ↩ Undo / ↪ Redo
local function doUndo()
    local snap = UndoMgr.undo(UndoMgr.snapshot(StateMgr.state.placedBlocks))
    if snap then
        StateMgr.rebuildFromData({ blockCounter = StateMgr.state.blockCounter, blocks = snap },
            function(bd) CanvasMgr.trySnap(bd, StateMgr.state.placedBlocks) end)
    end
    undoBtn.BackgroundTransparency = UndoMgr.canUndo() and 0 or 0.5
    redoBtn.BackgroundTransparency = UndoMgr.canRedo() and 0 or 0.5
end
local function doRedo()
    local snap = UndoMgr.redo(UndoMgr.snapshot(StateMgr.state.placedBlocks))
    if snap then
        StateMgr.rebuildFromData({ blockCounter = StateMgr.state.blockCounter, blocks = snap },
            function(bd) CanvasMgr.trySnap(bd, StateMgr.state.placedBlocks) end)
    end
    undoBtn.BackgroundTransparency = UndoMgr.canUndo() and 0 or 0.5
    redoBtn.BackgroundTransparency = UndoMgr.canRedo() and 0 or 0.5
end
undoBtn.MouseButton1Click:Connect(doUndo)
redoBtn.MouseButton1Click:Connect(doRedo)

-- ✕ Clear
clearBtn.MouseButton1Click:Connect(function()
    UndoMgr.push(UndoMgr.snapshot(StateMgr.state.placedBlocks))
    for _, bd in ipairs(StateMgr.state.placedBlocks) do
        if bd.frame and bd.frame.Parent then bd.frame:Destroy() end
    end
    StateMgr.state.placedBlocks = {}
    canvasHint.Visible = true; dropZone.Visible = false
    updateCode(); CanvasMgr.updateMinimap({})
    Persistence.clear(plugin)
end)

-- ⭐ New Block
newBlockBtn.MouseButton1Click:Connect(function()
    CustomBlocks.createDialog(nil, function(cb)
        table.insert(customBlockList, cb)
        CustomBlocks.save(plugin, customBlockList)
        CustomBlocks.inject(BlockDefs, customBlockList)
        SidebarMgr.populate(searchBox.Text)
    end, nil, nil).Parent = root
end)

-- ═══════════════════════════════════════════════════════════════
-- KEYBOARD SHORTCUTS
-- ═══════════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
               or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
    if not ctrl then return end

    if     input.KeyCode == Enum.KeyCode.Z then doUndo()
    elseif input.KeyCode == Enum.KeyCode.Y then doRedo()
    elseif input.KeyCode == Enum.KeyCode.C then StateMgr.copySelected()
    elseif input.KeyCode == Enum.KeyCode.V then
        StateMgr.pasteClipboard(function(bd)
            CanvasMgr.trySnap(bd, StateMgr.state.placedBlocks)
        end)
    end
end)

-- Search
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    SidebarMgr.populate(searchBox.Text)
end)

-- ═══════════════════════════════════════════════════════════════
-- RUNTIME ERROR TRACKING
-- ═══════════════════════════════════════════════════════════════

RunService:GetPropertyChangedSignal("IsRunMode"):Connect(function()
    if errorTrackConn then errorTrackConn:Disconnect(); errorTrackConn = nil end
    ErrorTracker.clearAll(StateMgr.state.placedBlocks)
    if RunService.IsRunMode then
        errorTrackConn = ErrorTracker.hookScriptContext(
            StateMgr.state.placedBlocks, currentLineMap,
            function(_, msg)
                validBadge.BackgroundColor3 = Color3.fromRGB(255,140,0)
                validLbl.Text = "⚡ " .. msg:gsub("^.+:%d+: ",""):sub(1,50)
                validLbl.TextColor3 = Color3.fromRGB(255,180,80)
            end
        )
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- THEME SYNC
-- ═══════════════════════════════════════════════════════════════

StudioService.ThemeChanged:Connect(function()
    root.BackgroundColor3        = tc(Enum.StudioStyleGuideColor.MainBackground)
    topBar.BackgroundColor3      = tc(Enum.StudioStyleGuideColor.Titlebar)
    titleLbl.TextColor3          = tc(Enum.StudioStyleGuideColor.TitlebarText)
    canvasArea.BackgroundColor3  = tc(Enum.StudioStyleGuideColor.ScriptBackground)
    codePanel.BackgroundColor3   = tc(Enum.StudioStyleGuideColor.ScriptBackground)
    codeLbl.TextColor3           = tc(Enum.StudioStyleGuideColor.ScriptText)
    sidebarFrame.BackgroundColor3 = tc(Enum.StudioStyleGuideColor.CategoryItem)
    searchBox.BackgroundColor3   = tc(Enum.StudioStyleGuideColor.InputFieldBackground)
    searchBox.TextColor3         = tc(Enum.StudioStyleGuideColor.MainText)
end)

-- ═══════════════════════════════════════════════════════════════
-- TOGGLE WIDGET
-- ═══════════════════════════════════════════════════════════════

toggleButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
    toggleButton:SetActive(widget.Enabled)
end)
widget:BindToClose(function()
    widget.Enabled = false; toggleButton:SetActive(false)
end)

-- ═══════════════════════════════════════════════════════════════
-- STARTUP
-- ═══════════════════════════════════════════════════════════════

SidebarMgr.populate()

local savedData = Persistence.load(plugin)
if savedData and savedData.blocks and #savedData.blocks > 0 then
    print("[ScratchLua] Restoring " .. #savedData.blocks .. " blocks...")
    StateMgr.rebuildFromData(savedData, function(bd)
        CanvasMgr.trySnap(bd, StateMgr.state.placedBlocks)
    end)
else
    canvasHint.Visible = true
end

print("[ScratchLua] v" .. PLUGIN_VERSION .. " loaded ✓")
