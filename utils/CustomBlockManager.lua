--[[
    CustomBlockManager.lua
    Cho phép người dùng tạo block riêng với:
    - Tên block, màu sắc, category
    - Inputs tùy chỉnh
    - Code template với {placeholder}
    Lưu vào plugin:GetSetting("ScratchLua_CustomBlocks")
--]]

local HttpService = game:GetService("StudioService") and game:GetService("HttpService")
local SAVE_KEY = "ScratchLua_CustomBlocks_v1"

local CustomBlockManager = {}

-- ─── Load custom blocks từ storage ───────────────────────────

function CustomBlockManager.load(plugin)
    local raw = plugin:GetSetting(SAVE_KEY)
    if not raw or raw == "" then return {} end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
    return (ok and type(data) == "table") and data or {}
end

-- ─── Save custom blocks ───────────────────────────────────────

function CustomBlockManager.save(plugin, customBlocks)
    local ok, json = pcall(HttpService.JSONEncode, HttpService, customBlocks)
    if ok then plugin:SetSetting(SAVE_KEY, json) end
end

-- ─── Inject custom blocks vào BlockDefs runtime ───────────────
-- Gọi sau khi load, trước khi populate sidebar

function CustomBlockManager.inject(BlockDefs, customBlocks)
    -- Xóa category custom cũ nếu có
    for i = #BlockDefs.categories, 1, -1 do
        if BlockDefs.categories[i]._isCustom then
            table.remove(BlockDefs.categories, i)
        end
    end

    if #customBlocks == 0 then return end

    local cat = {
        label     = "⭐ My Blocks",
        color     = Color3.fromRGB(180, 100, 220),
        _isCustom = true,
        blocks    = {},
    }

    for _, cb in ipairs(customBlocks) do
        local color = Color3.fromRGB(
            cb.colorR or 180, cb.colorG or 100, cb.colorB or 220
        )
        local inputs = {}
        for _, inp in ipairs(cb.inputs or {}) do
            table.insert(inputs, {
                name    = inp.name,
                type    = inp.type or "text",
                default = inp.default or "",
                label   = inp.label or inp.name,
            })
        end

        local def = {
            id           = "custom_" .. cb.id,
            label        = cb.label or "Custom Block",
            shape        = cb.shape or "stack",
            color        = color,
            inputs       = inputs,
            codeTemplate = cb.codeTemplate or "-- custom",
            height       = 32 + #inputs * 22,
            _isCustom    = true,
            _customId    = cb.id,
        }
        if cb.isContainer then
            def.isContainer   = true
            def.closeTemplate = cb.closeTemplate or "end"
        end

        table.insert(cat.blocks, def)
        BlockDefs.byId[def.id] = def
    end

    table.insert(BlockDefs.categories, 1, cat)
end

-- ─── Tạo dialog "Create Custom Block" ────────────────────────

function CustomBlockManager.createDialog(existingBlock, onSave, onDelete, onClose)
    -- existingBlock = nil (tạo mới) hoặc table (edit)

    local overlay = Instance.new("Frame")
    overlay.Name  = "CustomBlockOverlay"
    overlay.Size  = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.45
    overlay.ZIndex = 100

    local dlg = Instance.new("Frame")
    dlg.Size     = UDim2.new(0, 480, 0, 520)
    dlg.Position = UDim2.new(0.5, -240, 0.5, -260)
    dlg.BackgroundColor3 = Color3.fromRGB(38, 38, 42)
    dlg.ZIndex   = 101
    local dlgC = Instance.new("UICorner"); dlgC.CornerRadius = UDim.new(0, 8); dlgC.Parent = dlg

    local dlgStroke = Instance.new("UIStroke")
    dlgStroke.Color = Color3.fromRGB(80, 80, 100)
    dlgStroke.Parent = dlg
    dlg.Parent = overlay

    -- Title
    local title = Instance.new("TextLabel")
    title.Text  = existingBlock and "✏️  Edit Custom Block" or "⭐  Create Custom Block"
    title.Size  = UDim2.new(1, -16, 0, 32)
    title.Position = UDim2.new(0, 8, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(220, 220, 235)
    title.Font  = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = dlg

    -- Scrollable content
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size  = UDim2.new(1, -16, 0, 380)
    scroll.Position = UDim2.new(0, 8, 0, 46)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 5
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ZIndex = 102
    scroll.Parent = dlg

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.Parent = scroll

    local eb = existingBlock or {}

    -- ── Helper: row label + input ──────────────────────────────
    local function makeRow(labelText, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 48)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        row.ZIndex = 102
        row.Parent = scroll

        local lbl = Instance.new("TextLabel")
        lbl.Text  = labelText
        lbl.Size  = UDim2.new(1, 0, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(160, 160, 180)
        lbl.Font  = Enum.Font.GothamSemibold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 103
        lbl.Parent = row

        local box = Instance.new("TextBox")
        box.Size  = UDim2.new(1, 0, 0, 26)
        box.Position = UDim2.new(0, 0, 0, 18)
        box.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
        box.TextColor3 = Color3.fromRGB(200, 200, 210)
        box.Font  = Enum.Font.Code
        box.TextSize = 11
        box.ClearTextOnFocus = false
        box.ZIndex = 103
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = box
        box.Parent = row
        return box
    end

    -- Block Label
    local labelBox = makeRow("Block Label (emoji + tên):", 1)
    labelBox.Text = eb.label or "🔧 My Block"
    labelBox.PlaceholderText = "🔧 Do something [value]"

    -- Code Template
    local tmplRow = Instance.new("Frame")
    tmplRow.Size = UDim2.new(1, 0, 0, 80)
    tmplRow.BackgroundTransparency = 1
    tmplRow.LayoutOrder = 2
    tmplRow.ZIndex = 102
    tmplRow.Parent = scroll

    local tmplLbl = Instance.new("TextLabel")
    tmplLbl.Text = "Code Template (dùng {name} cho inputs):"
    tmplLbl.Size = UDim2.new(1, 0, 0, 16)
    tmplLbl.BackgroundTransparency = 1
    tmplLbl.TextColor3 = Color3.fromRGB(160, 160, 180)
    tmplLbl.Font = Enum.Font.GothamSemibold
    tmplLbl.TextSize = 11
    tmplLbl.TextXAlignment = Enum.TextXAlignment.Left
    tmplLbl.ZIndex = 103
    tmplLbl.Parent = tmplRow

    local tmplBox = Instance.new("TextBox")
    tmplBox.Size = UDim2.new(1, 0, 0, 58)
    tmplBox.Position = UDim2.new(0, 0, 0, 18)
    tmplBox.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    tmplBox.TextColor3 = Color3.fromRGB(180, 220, 170)
    tmplBox.Font = Enum.Font.Code
    tmplBox.TextSize = 10
    tmplBox.MultiLine = true
    tmplBox.TextWrapped = true
    tmplBox.ClearTextOnFocus = false
    tmplBox.Text = eb.codeTemplate or 'print("{value}")'
    tmplBox.PlaceholderText = 'print("{value}")'
    tmplBox.ZIndex = 103
    local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0, 4); tbc.Parent = tmplBox
    tmplBox.Parent = tmplRow

    -- Shape
    local shapeBox = makeRow("Shape (stack / hat / cap):", 3)
    shapeBox.Text = eb.shape or "stack"
    shapeBox.PlaceholderText = "stack"

    -- Is Container
    local containerBox = makeRow("Container (true/false) — cho if/while:", 4)
    containerBox.Text = tostring(eb.isContainer or false)

    -- Close Template (chỉ khi container)
    local closeBox = makeRow("Close Template (nếu container):", 5)
    closeBox.Text = eb.closeTemplate or "end"

    -- Color RGB
    local colorRow = Instance.new("Frame")
    colorRow.Size = UDim2.new(1, 0, 0, 48)
    colorRow.BackgroundTransparency = 1
    colorRow.LayoutOrder = 6
    colorRow.ZIndex = 102
    colorRow.Parent = scroll

    local colorLbl = Instance.new("TextLabel")
    colorLbl.Text = "Màu sắc  R:"
    colorLbl.Size = UDim2.new(0, 70, 0, 16)
    colorLbl.BackgroundTransparency = 1
    colorLbl.TextColor3 = Color3.fromRGB(160, 160, 180)
    colorLbl.Font = Enum.Font.GothamSemibold
    colorLbl.TextSize = 11
    colorLbl.ZIndex = 103
    colorLbl.Parent = colorRow

    local function makeColorBox(x, placeholder, val)
        local b = Instance.new("TextBox")
        b.Size = UDim2.new(0, 50, 0, 26)
        b.Position = UDim2.new(0, x, 0, 18)
        b.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
        b.TextColor3 = Color3.fromRGB(200, 200, 210)
        b.Font = Enum.Font.Code
        b.TextSize = 11
        b.ClearTextOnFocus = false
        b.Text = tostring(val or placeholder)
        b.PlaceholderText = tostring(placeholder)
        b.ZIndex = 103
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = b
        b.Parent = colorRow
        return b
    end

    local colorPreview = Instance.new("Frame")
    colorPreview.Size = UDim2.new(0, 26, 0, 26)
    colorPreview.Position = UDim2.new(0, 170, 0, 18)
    colorPreview.BackgroundColor3 = Color3.fromRGB(eb.colorR or 180, eb.colorG or 100, eb.colorB or 220)
    colorPreview.ZIndex = 103
    local cpc = Instance.new("UICorner"); cpc.CornerRadius = UDim.new(0, 4); cpc.Parent = colorPreview
    colorPreview.Parent = colorRow

    local rBox = makeColorBox(0, 180, eb.colorR)
    local gBox = makeColorBox(58, 100, eb.colorG)
    local bBox = makeColorBox(116, 220, eb.colorB)

    local function updatePreview()
        local r = tonumber(rBox.Text) or 180
        local g = tonumber(gBox.Text) or 100
        local bv = tonumber(bBox.Text) or 220
        colorPreview.BackgroundColor3 = Color3.fromRGB(
            math.clamp(r, 0, 255),
            math.clamp(g, 0, 255),
            math.clamp(bv, 0, 255)
        )
    end
    rBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)
    gBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)
    bBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)

    -- ── Inputs editor ─────────────────────────────────────────
    local inputsHeader = Instance.new("TextLabel")
    inputsHeader.Text = "Inputs (mỗi dòng: name|label|default):"
    inputsHeader.Size = UDim2.new(1, 0, 0, 16)
    inputsHeader.BackgroundTransparency = 1
    inputsHeader.TextColor3 = Color3.fromRGB(160, 160, 180)
    inputsHeader.Font = Enum.Font.GothamSemibold
    inputsHeader.TextSize = 11
    inputsHeader.TextXAlignment = Enum.TextXAlignment.Left
    inputsHeader.LayoutOrder = 7
    inputsHeader.ZIndex = 103
    inputsHeader.Parent = scroll

    local inputsArea = Instance.new("Frame")
    inputsArea.Size = UDim2.new(1, 0, 0, 80)
    inputsArea.LayoutOrder = 8
    inputsArea.BackgroundTransparency = 1
    inputsArea.ZIndex = 102
    inputsArea.Parent = scroll

    local inputsBox = Instance.new("TextBox")
    inputsBox.Size = UDim2.new(1, 0, 1, 0)
    inputsBox.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    inputsBox.TextColor3 = Color3.fromRGB(200, 200, 210)
    inputsBox.Font = Enum.Font.Code
    inputsBox.TextSize = 10
    inputsBox.MultiLine = true
    inputsBox.TextWrapped = true
    inputsBox.ClearTextOnFocus = false
    inputsBox.TextYAlignment = Enum.TextYAlignment.Top
    inputsBox.ZIndex = 103
    inputsBox.PlaceholderText = "value|Value|0\nname|Player name|Player1"

    -- Serialize existing inputs
    if eb.inputs and #eb.inputs > 0 then
        local lines = {}
        for _, inp in ipairs(eb.inputs) do
            table.insert(lines, (inp.name or "") .. "|" .. (inp.label or "") .. "|" .. (inp.default or ""))
        end
        inputsBox.Text = table.concat(lines, "\n")
    end

    local ibc = Instance.new("UICorner"); ibc.CornerRadius = UDim.new(0, 4); ibc.Parent = inputsBox
    inputsBox.Parent = inputsArea

    -- ── Error label ───────────────────────────────────────────
    local errLbl = Instance.new("TextLabel")
    errLbl.Name = "ErrLbl"
    errLbl.Size = UDim2.new(1, -16, 0, 16)
    errLbl.Position = UDim2.new(0, 8, 0, 434)
    errLbl.BackgroundTransparency = 1
    errLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
    errLbl.Font = Enum.Font.Gotham
    errLbl.TextSize = 10
    errLbl.TextXAlignment = Enum.TextXAlignment.Left
    errLbl.Text = ""
    errLbl.ZIndex = 102
    errLbl.Parent = dlg

    -- ── Buttons ───────────────────────────────────────────────
    local function mkBtn(text, x, w, color)
        local b = Instance.new("TextButton")
        b.Text = text
        b.Size = UDim2.new(0, w, 0, 28)
        b.Position = UDim2.new(0, x, 0, 456)
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 12
        b.ZIndex = 102
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = b
        b.Parent = dlg
        return b
    end

    local cancelBtn = mkBtn("Hủy",   8,   70, Color3.fromRGB(70, 70, 78))
    local saveBtn   = mkBtn("💾 Save", 86, 100, Color3.fromRGB(67, 133, 245))

    if existingBlock then
        mkBtn("🗑 Xóa", 194, 70, Color3.fromRGB(200, 50, 50)).MouseButton1Click:Connect(function()
            overlay:Destroy()
            if onDelete then onDelete(existingBlock.id) end
        end)
    end

    cancelBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
        if onClose then onClose() end
    end)

    saveBtn.MouseButton1Click:Connect(function()
        -- Validate
        if labelBox.Text:match("^%s*$") then
            errLbl.Text = "⚠ Block label không được để trống"
            return
        end
        if tmplBox.Text:match("^%s*$") then
            errLbl.Text = "⚠ Code template không được để trống"
            return
        end

        -- Parse inputs
        local parsedInputs = {}
        for line in (inputsBox.Text .. "\n"):gmatch("([^\n]*)\n") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then
                local parts = line:split("|")
                if #parts >= 1 and parts[1] ~= "" then
                    table.insert(parsedInputs, {
                        name    = parts[1]:match("^%s*(.-)%s*$"),
                        label   = (#parts >= 2) and parts[2]:match("^%s*(.-)%s*$") or parts[1],
                        default = (#parts >= 3) and parts[3]:match("^%s*(.-)%s*$") or "",
                        type    = "text",
                    })
                end
            end
        end

        local isContainer = containerBox.Text:lower() == "true"

        local cb = {
            id           = existingBlock and existingBlock.id or ("cb_" .. os.time()),
            label        = labelBox.Text,
            codeTemplate = tmplBox.Text,
            shape        = shapeBox.Text:match("^%s*(.-)%s*$"),
            isContainer  = isContainer,
            closeTemplate = isContainer and closeBox.Text or nil,
            colorR       = math.clamp(tonumber(rBox.Text) or 180, 0, 255),
            colorG       = math.clamp(tonumber(gBox.Text) or 100, 0, 255),
            colorB       = math.clamp(tonumber(bBox.Text) or 220, 0, 255),
            inputs       = parsedInputs,
        }

        overlay:Destroy()
        if onSave then onSave(cb) end
    end)

    return overlay
end

return CustomBlockManager
